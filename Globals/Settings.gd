
extends Node

signal changed(key: String, value: Variant)

const PATH := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]
const VSYNC := [
	DisplayServer.VSYNC_DISABLED,
	DisplayServer.VSYNC_ENABLED,
	DisplayServer.VSYNC_ADAPTIVE,
	DisplayServer.VSYNC_MAILBOX
]
const MSAA := [
	Viewport.MSAA_DISABLED,
	Viewport.MSAA_2X,
	Viewport.MSAA_4X,
	Viewport.MSAA_8X
]
const PARTICLE_SCALE := [0.35, 0.7, 1.0]
const QUOTA_GROWTH := [1.3, 1.5, 1.8]

enum CONTROLS { MOUSE, KEYBOARD }

const OPTIONS_SCENE := "res://Data/Menu/Options_menu.tscn"

const SCHEMA: Array[Dictionary] = [
	# Video
	{key = "window_mode", cat = "video", label = "Window Mode", type = "option", def = 0, opts = ["Windowed", "Fullscreen", "Borderless"]},
	{key = "resolution", cat = "video", label = "Resolution", type = "option", def = 2, opts = ["1280 x 720", "1600 x 900", "1920 x 1080", "2560 x 1440"], tip = "Windowed mode only"},
	{key = "vsync", cat = "video", label = "VSync", type = "option", def = 1, opts = ["Off", "On", "Adaptive", "Mailbox"]},
	{key = "max_fps", cat = "video", label = "FPS Limit", type = "slider", def = 0.0, lo = 0.0, hi = 240.0, step = 10.0, zero = "Unlimited"},
	{key = "ui_scale", cat = "video", label = "UI Scale", type = "slider", def = 1.0, lo = 0.75, hi = 1.5, step = 0.05, suffix = "x"},

	# Audio
	{key = "mute_unfocused", cat = "audio", label = "Mute When Unfocused", type = "toggle", def = false},

	# Graphics
	{key = "msaa", cat = "graphics", label = "Anti-Aliasing (MSAA)", type = "option", def = 0, opts = ["Off", "2x", "4x", "8x"]},
	{key = "particle_quality", cat = "graphics", label = "Particle Quality", type = "option", def = 2, opts = ["Low", "Medium", "High"], tip = "Scale emitter amounts with Settings.particle_scale()"},
	{key = "show_fps", cat = "graphics", label = "Show FPS", type = "toggle", def = false},

	# Gameplay
	{key = "game_mode", cat = "gameplay", label = "Game Mode", type = "option", def = 0, opts = ["Timer + Fuel", "Timer Only", "Fuel Only", "Free Play"], tip = "Applies on the next run"},
	{key = "difficulty", cat = "gameplay", label = "Difficulty", type = "option", def = 1, opts = ["Easy", "Normal", "Hard"], tip = "How fast the quota grows"},
	{key = "screen_shake", cat = "gameplay", label = "Screen Shake", type = "slider", def = 100.0, lo = 0.0, hi = 100.0, step = 1.0, suffix = "%"},
	{key = "show_speed", cat = "gameplay", label = "Show Speedometer", type = "toggle", def = true},
	{key = "show_waypoint", cat = "gameplay", label = "Show Waypoint Marker", type = "toggle", def = true},
	{key = "photosensitive", cat = "gameplay", label = "Photosensitive Mode", type = "toggle", def = false, tip = "Reduces motion, flashing and strobing"},
	{key = "controls", cat = "gameplay", label = "Control Mode", type = "option", def = 0, opts = ["Mouse", "Keyboard"], tip = "Changes control scheme"}
]

var values: Dictionary = {}
var _defs: Dictionary = {}
var bus_volumes: Dictionary = {}

var _dirty: bool = false
var _save_timer: Timer
var _fps_layer: CanvasLayer
var _fps_label: Label
var _options_layer: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

	for d in SCHEMA:
		_defs[d.key] = d

	_load()

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.5
	_save_timer.timeout.connect(save)
	add_child(_save_timer)

	_apply_all.call_deferred()


# -------------------------------------------------------------------
# General settings
# -------------------------------------------------------------------

func get_value(key: String) -> Variant:
	return values[key]


func get_def(key: String) -> Dictionary:
	return _defs[key]


func set_value(key: String, v: Variant) -> void:
	if not _defs.has(key):
		push_warning("Settings: unknown key '%s'" % key)
		return

	v = _sanitize(_defs[key], v)

	if values[key] == v:
		return

	values[key] = v
	_apply(key)
	changed.emit(key, v)

	_mark_dirty()


func reset_category(cat: String) -> void:
	for d in SCHEMA:
		if d.cat == cat:
			set_value(d.key, d.def)

	if cat == "audio":
		for i in range(AudioServer.get_bus_count()):
			set_bus_volume(AudioServer.get_bus_name(i), 100.0)


func reset_all() -> void:
	for d in SCHEMA:
		set_value(d.key, d.def)

	for i in range(AudioServer.get_bus_count()):
		set_bus_volume(AudioServer.get_bus_name(i), 100.0)


func particle_scale() -> float:
	return PARTICLE_SCALE[values.particle_quality]


func photosensitive() -> bool:
	return values.photosensitive


func get_controls() -> CONTROLS:
	return values.controls


func shake_scale() -> float:
	var s: float = values.screen_shake / 100.0
	return s * 0.2 if values.photosensitive else s


# -------------------------------------------------------------------
# Dynamic audio bus settings
# -------------------------------------------------------------------

func get_bus_setting_key(bus_name: String) -> String:
	return "bus_volume:" + bus_name


func get_bus_volume(bus_name: String) -> float:
	if bus_volumes.has(bus_name):
		return float(bus_volumes[bus_name])

	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return 100.0

	var db: float = AudioServer.get_bus_volume_db(bus_index)

	if db <= -80.0:
		return 0.0

	return clampf(db_to_linear(db) * 100.0, 0.0, 100.0)


func set_bus_volume(bus_name: String, percent: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return

	percent = roundf(clampf(percent, 0.0, 100.0))

	if bus_volumes.get(bus_name, -1.0) == percent:
		_apply_bus_volume(bus_name, percent)
		return

	bus_volumes[bus_name] = percent
	_apply_bus_volume(bus_name, percent)

	changed.emit(get_bus_setting_key(bus_name), percent)
	_mark_dirty()


func _apply_bus_volume(bus_name: String, percent: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return

	if percent <= 0.0:
		AudioServer.set_bus_volume_db(bus_index, -80.0)
	else:
		AudioServer.set_bus_volume_db(
			bus_index,
			linear_to_db(percent / 100.0)
		)


func _load_bus_volumes(cfg: ConfigFile) -> void:
	bus_volumes.clear()

	for i in range(AudioServer.get_bus_count()):
		var bus_name := AudioServer.get_bus_name(i)
		var bus_index := AudioServer.get_bus_index(bus_name)
		var default_volume := 100.0

		if bus_index != -1:
			var db: float = AudioServer.get_bus_volume_db(bus_index)
			if db <= -80.0:
				default_volume = 0.0
			else:
				default_volume = clampf(db_to_linear(db) * 100.0, 0.0, 100.0)

		var stored: Variant = cfg.get_value(
			"audio_buses",
			bus_name,
			default_volume
		)

		var volume := default_volume
		if stored is int or stored is float:
			volume = clampf(float(stored), 0.0, 100.0)

		bus_volumes[bus_name] = volume


func _apply_bus_volumes() -> void:
	# Discover buses each time, so the current project layout is authoritative.
	for i in range(AudioServer.get_bus_count()):
		var bus_name := AudioServer.get_bus_name(i)

		if not bus_volumes.has(bus_name):
			bus_volumes[bus_name] = _get_current_bus_volume(bus_name)

		_apply_bus_volume(bus_name, float(bus_volumes[bus_name]))


func _get_current_bus_volume(bus_name: String) -> float:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return 100.0

	var db: float = AudioServer.get_bus_volume_db(bus_index)
	if db <= -80.0:
		return 0.0

	return clampf(db_to_linear(db) * 100.0, 0.0, 100.0)


func _sync_audio_buses() -> void:
	var current_buses: Dictionary = {}

	for i in range(AudioServer.get_bus_count()):
		var bus_name := AudioServer.get_bus_name(i)
		current_buses[bus_name] = true

		if not bus_volumes.has(bus_name):
			bus_volumes[bus_name] = _get_current_bus_volume(bus_name)

	# Remove settings for buses that no longer exist in the project.
	for bus_name in bus_volumes.keys():
		if not current_buses.has(bus_name):
			bus_volumes.erase(bus_name)

	_apply_bus_volumes()


# -------------------------------------------------------------------
# Loading and saving
# -------------------------------------------------------------------

func _mark_dirty() -> void:
	_dirty = true

	if is_instance_valid(_save_timer):
		_save_timer.start()


func save() -> void:
	var cfg := ConfigFile.new()

	for d in SCHEMA:
		cfg.set_value(d.cat, d.key, values[d.key])

	for bus_name in bus_volumes:
		cfg.set_value(
			"audio_buses",
			bus_name,
			bus_volumes[bus_name]
		)

	var error := cfg.save(PATH)
	if error != OK:
		push_warning("Settings: failed to save settings. Error: %s" % error)
		return

	_dirty = false


func _load() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)

	for d in SCHEMA:
		values[d.key] = _sanitize(
			d,
			cfg.get_value(d.cat, d.key, d.def)
		)

	_load_bus_volumes(cfg)


func _sanitize(d: Dictionary, v: Variant) -> Variant:
	if not (v is int or v is float or v is bool):
		return d.def

	match d.type:
		"slider":
			return clampf(
				snappedf(float(v), d.step),
				d.lo,
				d.hi
			)
		"option":
			return clampi(int(v), 0, d.opts.size() - 1)

	return bool(v)


# -------------------------------------------------------------------
# Applying settings
# -------------------------------------------------------------------

func _apply_all() -> void:
	for d in SCHEMA:
		_apply(d.key)

	_sync_audio_buses()


func _apply(key: String) -> void:
	var v: Variant = values[key]

	match key:
		"window_mode", "resolution":
			_apply_window()

		"vsync":
			DisplayServer.window_set_vsync_mode(VSYNC[int(v)])

		"max_fps":
			Engine.max_fps = int(v)

		"ui_scale":
			get_window().content_scale_factor = float(v)

		"msaa":
			get_viewport().msaa_2d = MSAA[int(v)]

		"show_fps":
			_show_fps(bool(v))

		"game_mode":
			DataCollector.game_mode = int(v)

		"difficulty":
			DataCollector.quota_growth = QUOTA_GROWTH[int(v)]

		"controls":
			get_controls()


func _apply_window() -> void:
	match int(values.window_mode):
		1:
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			)

		2:
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN
			)

		_:
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_WINDOWED
			)

			var rect := DisplayServer.screen_get_usable_rect(
				DisplayServer.window_get_current_screen()
			)

			var size: Vector2i = RESOLUTIONS[int(values.resolution)].min(
				rect.size
			)

			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(
				rect.position + (rect.size - size) / 2
			)


# -------------------------------------------------------------------
# FPS display
# -------------------------------------------------------------------

func _show_fps(on: bool) -> void:
	if on and _fps_layer == null:
		_fps_layer = CanvasLayer.new()
		_fps_layer.layer = 100

		_fps_label = Label.new()
		_fps_label.position = Vector2(8.0, 4.0)

		_fps_layer.add_child(_fps_label)
		add_child(_fps_layer)

	if _fps_layer != null:
		_fps_layer.visible = on

	set_process(on)


func _process(_delta: float) -> void:
	if is_instance_valid(_fps_label):
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


# -------------------------------------------------------------------
# Application focus
# -------------------------------------------------------------------

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if values.get("mute_unfocused", false):
				for i in range(AudioServer.get_bus_count()):
					AudioServer.set_bus_mute(i, true)

		NOTIFICATION_APPLICATION_FOCUS_IN:
			# Restore the user's bus volume settings without assuming
			# any particular bus name or layout.
			for i in range(AudioServer.get_bus_count()):
				var bus_name := AudioServer.get_bus_name(i)
				var volume := get_bus_volume(bus_name)

				AudioServer.set_bus_mute(i, volume <= 0.0)

		NOTIFICATION_WM_CLOSE_REQUEST:
			_flush()


func _exit_tree() -> void:
	_flush()


func _flush() -> void:
	if _dirty:
		save()


# -------------------------------------------------------------------
# Options menu
# -------------------------------------------------------------------

func show_options() -> void:
	if _options_layer != null:
		return

	var scene := load(OPTIONS_SCENE) as PackedScene
	if scene == null:
		push_warning("Settings: options scene could not be loaded.")
		return

	_options_layer = CanvasLayer.new()
	_options_layer.layer = 90
	_options_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_options_layer)

	var menu := scene.instantiate()
	menu.close_requested.connect(hide_options)
	_options_layer.add_child(menu)


func hide_options() -> void:
	if _options_layer != null:
		_options_layer.queue_free()
		_options_layer = null
