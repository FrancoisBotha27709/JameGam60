extends Node

signal sound_missing(sound_name : String)
signal music_changed(track_name : String)

const CONFIG_FILE_NAME := "sounds.json"
const MUSIC_BUS := "Music"
const SILENCE_DB := AudioCatalog.SILENCE_DB
const MASTER_LIMITER_CEILING_DB := -1.0
const MIN_LINEAR_VOLUME := 0.0001
const MUTE_THRESHOLD := 0.001
const VOICE_POOL_SIZE := 32
const MUSIC_PLAYER_COUNT := 2
const MAX_AUDIBLE_DISTANCE := 2200.0
const NEVER_PLAYED_MSEC := -99999
const MSEC_PER_SECOND := 1000.0
const DEFAULT_MUSIC_FADE := 1.5
const DEFAULT_LOOP_FADE := 0.2
# sounds.json fields from the sound tool that map onto engine settings; every other tool field is ignored.
const ENTRY_KEY_MAP := {"max_db": "volume_db", "jitter": "pitch_var"}
# Per-sound defaults; any key can be overridden in sounds.json, including "bus".
const DEFAULT_SETTINGS := {"volume_db": 0.0, "pitch": 1.0, "vol_var": 1.0, "pitch_var": 0.05, "cooldown": 0.03, "max": 8}

var sound_streams := {}
var sound_settings := {}
var last_played_msec := {}
var looped_stream_cache := {}
var reported_missing := {}
var flat_pool : VoicePool
var positional_pool : VoicePool
var music_players : Array[AudioStreamPlayer] = []
var music_tween : Tween
var active_music_index := 0
var current_music_name := ""

# Builds buses, the sound library, the voice pools and the music players.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in AudioCatalog.BUSES: ensure_bus(bus_name)
	_apply_default_bus_volumes()
	_ensure_master_limiter()
	_load_library()
	flat_pool = VoicePool.new(self, VOICE_POOL_SIZE, _create_flat_player)
	positional_pool = VoicePool.new(self, VOICE_POOL_SIZE, _create_positional_player)
	for _music_slot in MUSIC_PLAYER_COUNT:
		var music_player := AudioStreamPlayer.new()
		music_player.bus = MUSIC_BUS
		add_child(music_player)
		music_players.append(music_player)

# Creates the bus under Master when the project's bus layout lacks it, and returns its index.
func ensure_bus(bus_name : String) -> int:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0: return bus_index
	AudioServer.add_bus()
	bus_index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, AudioCatalog.MASTER_BUS)
	return bus_index

# Starts every bus at its quiet default so sounds played before Settings loads are not blasting at 0 dB.
func _apply_default_bus_volumes() -> void:
	for bus_index in AudioServer.bus_count:
		var default_percent := AudioCatalog.default_bus_percent(AudioServer.get_bus_name(bus_index))
		AudioServer.set_bus_volume_db(bus_index, AudioCatalog.percent_to_db(default_percent))

# Adds a limiter to Master when it has no effects, so many overlapping sounds cannot clip into harsh distortion.
func _ensure_master_limiter() -> void:
	var master_index := AudioServer.get_bus_index(AudioCatalog.MASTER_BUS)
	if AudioServer.get_bus_effect_count(master_index) > 0: return
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = MASTER_LIMITER_CEILING_DB
	AudioServer.add_bus_effect(master_index, limiter)

# Loads every catalogued stream and merges defaults, folder bus and sounds.json overrides into per-sound settings.
func _load_library() -> void:
	var config := _read_config()
	var catalog := AudioCatalog.scan()
	for sound_name in catalog:
		var streams : Array[AudioStream] = []
		for resource_path in catalog[sound_name]["paths"]:
			var stream := load(resource_path) as AudioStream
			if stream: streams.append(stream)
		if streams.is_empty(): continue
		var settings := DEFAULT_SETTINGS.duplicate()
		settings["bus"] = catalog[sound_name]["bus"]
		settings.merge(config.get(sound_name, {}), true)
		settings["cooldown_msec"] = float(settings["cooldown"]) * MSEC_PER_SECOND
		ensure_bus(settings["bus"])
		sound_streams[sound_name] = streams
		sound_settings[sound_name] = settings

# Reads sounds.json as a list of entries with an "id", a name-to-settings map, or either nested under "sounds".
func _read_config() -> Dictionary:
	var config_path := AudioCatalog.SOUND_DIRECTORY.path_join(CONFIG_FILE_NAME)
	if not FileAccess.file_exists(config_path): return {}
	var parsed : Variant = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if not (parsed is Dictionary):
		push_warning("Audio: %s is not valid JSON, ignoring it." % config_path)
		return {}
	var entries : Variant = parsed.get("sounds", parsed)
	var config := {}
	if entries is Array:
		for entry in entries:
			if entry is Dictionary and entry.get("id") is String: config[entry["id"]] = _translate_entry(entry)
	else:
		for sound_name in entries:
			if entries[sound_name] is Dictionary: config[sound_name] = _translate_entry(entries[sound_name])
	return config

# Keeps only settings the engine understands, renaming tool fields; an explicit engine key beats its mapped alias.
func _translate_entry(entry : Dictionary) -> Dictionary:
	var settings := {}
	for source_key in entry:
		var engine_key : String = ENTRY_KEY_MAP.get(source_key, source_key)
		var is_known := DEFAULT_SETTINGS.has(engine_key) or engine_key == "bus"
		var is_overridden = engine_key != source_key and entry.has(engine_key)
		if is_known and not is_overridden: settings[engine_key] = entry[source_key]
	return settings

func has(sound_name : String) -> bool:
	return sound_streams.has(sound_name)

func names() -> Array:
	var sorted_names := sound_streams.keys()
	sorted_names.sort()
	return sorted_names

# Returns a sound's settings, or null (reporting it once) when the sound is unknown.
func _settings_for(sound_name : String) -> Variant:
	if sound_settings.has(sound_name): return sound_settings[sound_name]
	if not reported_missing.has(sound_name):
		reported_missing[sound_name] = true
		push_warning("Audio: unknown sound '%s'." % sound_name)
	sound_missing.emit(sound_name)
	return null

# Picks the manual bus when it exists, otherwise the sound's automatic bus.
func _resolve_bus(settings : Dictionary, bus_override : String) -> String:
	if bus_override.is_empty() or bus_override == AudioCatalog.AUTO_BUS: return settings["bus"]
	if AudioServer.get_bus_index(bus_override) >= 0: return bus_override
	push_warning("Audio: bus '%s' does not exist, using '%s'." % [bus_override, settings["bus"]])
	return settings["bus"]

# Writes bus, volume and pitch to a player from the sound's settings plus random variation.
func _configure_player(player : Node, settings : Dictionary, volume_offset_db : float, pitch_multiplier : float, bus_override : String) -> void:
	var volume_variation : float = settings["vol_var"]
	var pitch_variation : float = settings["pitch_var"]
	player.bus = _resolve_bus(settings, bus_override)
	player.volume_db = volume_offset_db + float(settings["volume_db"]) + randf_range(-volume_variation, volume_variation)
	player.pitch_scale = pitch_multiplier * float(settings["pitch"]) * (1.0 + randf_range(-pitch_variation, pitch_variation))

func _create_flat_player() -> AudioStreamPlayer:
	return AudioStreamPlayer.new()

func _create_positional_player() -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.max_distance = MAX_AUDIBLE_DISTANCE
	return player

# Plays a random variation on a pooled voice, honoring cooldown and voice limits. Pass a Vector2 for positional sound.
func play(sound_name : String, at = null, volume_offset_db := 0.0, pitch_multiplier := 1.0, bus_override := ""):
	var settings = _settings_for(sound_name)
	if settings == null: return null
	var now_msec := Time.get_ticks_msec()
	if now_msec - last_played_msec.get(sound_name, NEVER_PLAYED_MSEC) < settings["cooldown_msec"]: return null
	var is_positional := at is Vector2
	var pool : VoicePool = positional_pool if is_positional else flat_pool
	var slot := pool.acquire(sound_name, int(settings["max"]))
	if slot < 0: return null
	last_played_msec[sound_name] = now_msec
	pool.sound_names[slot] = sound_name
	var player = pool.players[slot]
	player.stream = sound_streams[sound_name].pick_random()
	_configure_player(player, settings, volume_offset_db, pitch_multiplier, bus_override)
	if is_positional: player.global_position = at
	player.play()
	return player

func stop(sound_name : String) -> void:
	flat_pool.stop_sound(sound_name)
	positional_pool.stop_sound(sound_name)

# Returns a cached looping copy of the stream so the shared original stays untouched.
func _looped(stream : AudioStream) -> AudioStream:
	if looped_stream_cache.has(stream): return looped_stream_cache[stream]
	var looped_stream : AudioStream = stream.duplicate()
	if looped_stream is AudioStreamWAV:
		looped_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		looped_stream.loop_begin = 0
		looped_stream.loop_end = int(looped_stream.get_length() * looped_stream.mix_rate)
	elif "loop" in looped_stream:
		looped_stream.loop = true
	looped_stream_cache[stream] = looped_stream
	return looped_stream

# Creates a looping player that autoplays once the deferred add puts it in the tree.
func loop(sound_name : String, host : Node, volume_offset_db := 0.0, pitch_multiplier := 1.0, positional := true, bus_override := ""):
	var settings = _settings_for(sound_name)
	if settings == null: return null
	var use_positional := positional and host is Node2D
	var player : Node = _create_positional_player() if use_positional else _create_flat_player()
	player.stream = _looped(sound_streams[sound_name].pick_random())
	_configure_player(player, settings, volume_offset_db, pitch_multiplier, bus_override)
	player.autoplay = true
	_attach_player.call_deferred(host, player)
	return player

# Adds a loop player to its host, discarding it if the host vanished before the deferred call ran.
func _attach_player(host : Node, player : Node) -> void:
	if not is_instance_valid(player): return
	if is_instance_valid(host) and host.is_inside_tree(): host.add_child(player)
	else: player.queue_free()

# Fades a loop player out then frees it; players not yet in the tree are discarded immediately.
func stop_loop(player, fade_seconds := DEFAULT_LOOP_FADE) -> void:
	if not is_instance_valid(player): return
	if not player.is_inside_tree():
		player.autoplay = false
		player.queue_free()
		return
	var fade_tween : Tween = player.create_tween()
	fade_tween.tween_property(player, "volume_db", SILENCE_DB, fade_seconds)
	fade_tween.tween_callback(player.queue_free)

# Crossfades to the named track, or to silence when the name is empty or unknown.
func music(track_name : String, fade_seconds := DEFAULT_MUSIC_FADE, volume_db := 0.0) -> void:
	if track_name == current_music_name: return
	current_music_name = track_name
	if music_tween: music_tween.kill()
	var outgoing := music_players[active_music_index]
	active_music_index = (active_music_index + 1) % MUSIC_PLAYER_COUNT
	var incoming := music_players[active_music_index]
	incoming.stop()
	music_tween = create_tween().set_parallel()
	music_tween.tween_property(outgoing, "volume_db", SILENCE_DB, fade_seconds)
	if sound_streams.has(track_name):
		incoming.stream = _looped(sound_streams[track_name][0])
		incoming.volume_db = SILENCE_DB
		incoming.play()
		music_tween.tween_property(incoming, "volume_db", volume_db, fade_seconds)
	music_tween.chain().tween_callback(outgoing.stop)
	music_changed.emit(track_name)

func music_pitch(pitch_scale : float) -> void:
	for music_player in music_players: music_player.pitch_scale = pitch_scale

func set_volume(bus_name : String, linear_volume : float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0: return
	AudioServer.set_bus_mute(bus_index, linear_volume <= MUTE_THRESHOLD)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(linear_volume, MIN_LINEAR_VOLUME)))

func get_volume(bus_name : String) -> float:
	var bus_index := AudioServer.get_bus_index(bus_name)
	return db_to_linear(AudioServer.get_bus_volume_db(bus_index)) if bus_index >= 0 else 1.0

# A fixed set of players that tracks which sound each slot last played and steals voices round-robin.
class VoicePool:
	var players : Array = []
	var sound_names : Array[String] = []
	var steal_cursor := 0

	func _init(parent : Node, pool_size : int, create_player : Callable) -> void:
		for _slot in pool_size:
			var player : Node = create_player.call()
			parent.add_child(player)
			players.append(player)
			sound_names.append("")

	# Returns a free slot, steals one when all are busy, or -1 when the sound already hit its voice cap.
	func acquire(sound_name : String, max_voices : int) -> int:
		var free_slot := -1
		var same_sound_count := 0
		for slot in players.size():
			if players[slot].playing: same_sound_count += int(sound_names[slot] == sound_name)
			elif free_slot < 0: free_slot = slot
		if same_sound_count >= max_voices: return -1
		if free_slot >= 0: return free_slot
		steal_cursor = (steal_cursor + 1) % players.size()
		return steal_cursor

	func stop_sound(sound_name : String) -> void:
		for slot in players.size():
			if sound_names[slot] == sound_name and players[slot].playing: players[slot].stop()