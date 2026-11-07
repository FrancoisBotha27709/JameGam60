@tool
class_name AudioCueSet
extends Node

signal cue_played(cue_name : String)

@export var cues : Array[AudioCue] = []:
	set(value):
		cues = value
		for cue in cues:
			if cue and not cue.changed.is_connected(update_configuration_warnings):
				cue.changed.connect(update_configuration_warnings)
		update_configuration_warnings()
## Node whose signals drive cues that name a signal. Empty means the parent.
@export var source : NodePath:
	set(value):
		source = value
		_publish_source_signals()
		update_configuration_warnings()

var _audio : Node
var _host : Node
var _cues_by_name := {}
var _cue_order : Array[String] = []
var _loop_players := {}
var _next_step_index := 0

# Shares this set's source signals with its cues so their signal fields can offer a dropdown.
func _publish_source_signals() -> void:
	if not Engine.is_editor_hint(): return
	AudioCue.source_signals = AudioCatalog.signal_names(_source_node())

func _enter_tree() -> void:
	_publish_source_signals()

# Refreshes the shared signal list each time the inspector shows this node, so cue dropdowns match its source.
func _validate_property(property : Dictionary) -> void:
	if property["name"] == "cues": _publish_source_signals()

# Indexes the cues by name and connects any cue that listens to a signal.
func _ready() -> void:
	if Engine.is_editor_hint(): return
	_audio = get_node_or_null("/root/Audio")
	_host = get_parent()
	if _audio == null:
		push_warning("AudioCueSet: Audio autoload is missing.")
		return
	for cue in cues:
		if cue == null: continue
		var cue_name := cue.display_name()
		_cues_by_name[cue_name] = cue
		_cue_order.append(cue_name)
		_bind_signals(cue_name, cue)

func _source_node() -> Node:
	return get_node_or_null(source) if not source.is_empty() else get_parent()

# Connects a cue's start and stop signals to this set so no extra glue code is needed.
func _bind_signals(cue_name : String, cue : AudioCue) -> void:
	var bindings := [[cue.signal_name, play.bind(cue_name)], [cue.stop_signal_name, stop.bind(cue_name)]]
	for binding in bindings:
		var linked_signal : String = binding[0]
		if linked_signal.is_empty(): continue
		if not AudioCatalog.connect_ignoring_arguments(_source_node(), linked_signal, binding[1]):
			push_warning("AudioCueSet: signal '%s' not found for cue '%s'." % [linked_signal, cue_name])

func play(cue_name : String) -> void:
	_run_cue(cue_name, null)

# Plays the named cue at a fixed world position, such as where something used to be.
func play_at(cue_name : String, world_position : Vector2) -> void:
	_run_cue(cue_name, world_position)

# Runs a cue after its delay: a one-shot, or a loop that lasts until stop(). Uses the host's position unless one is given.
func _run_cue(cue_name : String, world_position : Variant) -> void:
	if _audio == null: return
	var cue : AudioCue = _cues_by_name.get(cue_name)
	if cue == null:
		push_warning("AudioCueSet: no cue named '%s'." % cue_name)
		return
	if cue.delay > 0.0: await get_tree().create_timer(cue.delay).timeout
	if not is_inside_tree(): return
	var play_position : Variant = null
	if cue.positional: play_position = world_position if world_position is Vector2 else AudioCatalog.play_position(_host, true)
	if not cue.loop:
		_audio.play(cue.sound, play_position, cue.volume_db, cue.pitch, cue.bus)
	elif not is_instance_valid(_loop_players.get(cue_name)):
		_loop_players[cue_name] = _audio.loop(cue.sound, _host, cue.volume_db, cue.pitch, cue.positional, cue.bus)
	cue_played.emit(cue_name)

# Plays the next cue in list order, wrapping around, for sequences driven by one "something happened" call.
func step() -> void:
	if _cue_order.is_empty(): return
	play(_cue_order[_next_step_index])
	_next_step_index = (_next_step_index + 1) % _cue_order.size()

func reset_steps() -> void:
	_next_step_index = 0

# Fades out the named looping cue; one-shot cues finish on their own.
func stop(cue_name : String) -> void:
	var cue : AudioCue = _cues_by_name.get(cue_name)
	var loop_player = _loop_players.get(cue_name)
	_loop_players.erase(cue_name)
	if cue == null or not is_instance_valid(loop_player): return
	_audio.stop_loop(loop_player, cue.fade_out)

func stop_all() -> void:
	for cue_name in _loop_players.keys(): stop(cue_name)

func _exit_tree() -> void:
	if not Engine.is_editor_hint(): stop_all()

# Flags empty or duplicate cues and any cue setup that would silently do nothing.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var source_signals := AudioCatalog.signal_names(_source_node())
	var seen_names := {}
	for cue_index in cues.size():
		var cue := cues[cue_index]
		if cue == null:
			warnings.append("Cue %d is empty." % cue_index)
			continue
		if seen_names.has(cue.display_name()): warnings.append("Cue name '%s' is used more than once." % cue.display_name())
		seen_names[cue.display_name()] = true
		warnings.append_array(cue.validate(source_signals))
	return warnings