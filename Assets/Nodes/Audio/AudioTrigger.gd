@tool
class_name AudioTrigger
extends Node

enum Ev {READY, SIGNAL, TIMER, LOOP, HOLD}

const MIN_INTERVAL_SECONDS := 0.05

@export var sound := "":
	set(value):
		sound = value
		update_configuration_warnings()
## "Auto" uses the sound's folder (or sounds.json) bus; pick a bus to force this trigger onto it.
@export var bus := AudioCatalog.AUTO_BUS:
	set(value):
		bus = value
		update_configuration_warnings()
@export var event : Ev = Ev.READY:
	set(value):
		event = value
		notify_property_list_changed()
		update_configuration_warnings()
@export var signal_name := "":
	set(value):
		signal_name = value
		update_configuration_warnings()
@export var stop_signal_name := ""
@export var source : NodePath:
	set(value):
		source = value
		notify_property_list_changed()
		update_configuration_warnings()
@export var positional := true
@export_range(-40.0, 12.0, 0.1) var volume_db := 0.0
@export_range(0.1, 4.0, 0.01) var pitch := 1.0
@export var interval := 1.0
@export var jitter := 0.0
@export var fade_out := 0.2

var _audio : Node
var _host : Node
var _loop_player : Node

# Resolves the node whose signals drive this trigger: the source path, or the parent by default.
func _source_node() -> Node:
	return get_node_or_null(source) if not source.is_empty() else get_parent()

func _uses_signals() -> bool:
	return event == Ev.SIGNAL or event == Ev.HOLD

func _source_signal_names() -> PackedStringArray:
	return AudioCatalog.signal_names(_source_node())

# Decides which inspector fields apply to the current event type.
func _is_property_visible(property_name : String) -> bool:
	match property_name:
		"signal_name", "source": return _uses_signals()
		"stop_signal_name": return event == Ev.HOLD
		"interval", "jitter": return event == Ev.TIMER
		"fade_out": return event == Ev.LOOP or event == Ev.HOLD
	return true

# Hides irrelevant fields and turns sound, bus and signal fields into dropdowns.
func _validate_property(property : Dictionary) -> void:
	if not _is_property_visible(property["name"]):
		property["usage"] = PROPERTY_USAGE_NO_EDITOR
		return
	match property["name"]:
		"sound": AudioCatalog.apply_enum_hint(property, AudioCatalog.sound_names())
		"bus": AudioCatalog.apply_enum_hint(property, AudioCatalog.bus_choices(true))
		"signal_name", "stop_signal_name": 
			AudioCatalog.apply_enum_hint(property, _source_signal_names())

# Flags setups that would silently do nothing, directly in the scene tree.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if sound not in AudioCatalog.sound_names():
		warnings.append("Sound '%s' was not found in %s." % [sound, AudioCatalog.SOUND_DIRECTORY])
	if bus not in AudioCatalog.bus_choices(true):
		warnings.append("Bus '%s' does not exist; the automatic bus will be used." % bus)
	if _uses_signals() and signal_name not in _source_signal_names():
		warnings.append("Signal '%s' was not found on the source node." % signal_name)
	return warnings

func _ready() -> void:
	if Engine.is_editor_hint(): return
	_audio = get_node_or_null("/root/Audio")
	_host = get_parent()
	if _audio == null:
		push_warning("AudioTrigger: Audio autoload is missing.")
		return
	match event:
		Ev.READY: play()
		Ev.SIGNAL: AudioCatalog.connect_ignoring_arguments(_source_node(), signal_name, play)
		Ev.TIMER: _tick()
		Ev.LOOP: _start_loop()
		Ev.HOLD:
			AudioCatalog.connect_ignoring_arguments(_source_node(), signal_name, _start_loop)
			AudioCatalog.connect_ignoring_arguments(_source_node(), stop_signal_name, stop)

# Plays repeatedly with optional random jitter until the trigger leaves the tree.
func _tick() -> void:
	while is_inside_tree():
		await get_tree().create_timer(
			maxf(MIN_INTERVAL_SECONDS, interval + randf_range(-jitter, jitter))
			).timeout
		if is_inside_tree(): play()

func play() -> void:
	if _audio == null: return
	var play_position = AudioCatalog.play_position(_host, positional)
	_audio.play(sound, play_position, volume_db, pitch, bus)

# Starts the loop once; repeated calls 
# (such as a signal firing every frame) are ignored while it runs.
func _start_loop() -> void:
	if is_instance_valid(_loop_player): return
	_loop_player = _audio.loop(sound, _host, volume_db, pitch, positional, bus)

func stop() -> void:
	if _audio == null or not is_instance_valid(_loop_player): return
	_audio.stop_loop(_loop_player, fade_out)
	_loop_player = null

func _exit_tree() -> void:
	if not Engine.is_editor_hint(): stop()