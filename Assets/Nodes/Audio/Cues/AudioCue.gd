@tool
class_name AudioCue
extends Resource

## Editor only: signals of the selected AudioCueSet's source node, used for the signal dropdowns.
static var source_signals := PackedStringArray()

## Name used to play this cue from code. Leave empty to use the sound's name.
@export var cue_name := ""
@export var sound := "":
	set(value):
		sound = value
		emit_changed()
## "Auto" uses the sound's folder (or sounds.json) bus; pick a bus to force this cue onto it.
@export var bus := AudioCatalog.AUTO_BUS:
	set(value):
		bus = value
		emit_changed()
## Loops until stopped instead of playing once.
@export var loop := false:
	set(value):
		loop = value
		notify_property_list_changed()
@export var positional := true
@export_range(-40.0, 12.0, 0.1) var volume_db := 0.0
@export_range(0.1, 4.0, 0.01) var pitch := 1.0
## Seconds to wait before the cue starts.
@export var delay := 0.0
@export var fade_out := 0.2
## Optional: play this cue whenever the source node emits this signal.
@export var signal_name := "":
	set(value):
		signal_name = value
		emit_changed()
## Optional, loop cues only: stop the loop when the source node emits this signal.
@export var stop_signal_name := "":
	set(value):
		stop_signal_name = value
		emit_changed()

# The name this cue is played by: its explicit name, or the sound's name.
func display_name() -> String:
	return cue_name if not cue_name.is_empty() else sound

# Lists setup problems for the editor: unknown sound or bus, and signals the source does not have.
func validate(available_signals : PackedStringArray) -> PackedStringArray:
	var warnings := PackedStringArray()
	if sound not in AudioCatalog.sound_names(): warnings.append("Cue '%s': sound '%s' was not found." % [display_name(), sound])
	if bus not in AudioCatalog.bus_choices(true): warnings.append("Cue '%s': bus '%s' does not exist." % [display_name(), bus])
	for linked_signal in [signal_name, stop_signal_name]:
		if not linked_signal.is_empty() and linked_signal not in available_signals:
			warnings.append("Cue '%s': signal '%s' was not found on the source node." % [display_name(), linked_signal])
	return warnings

# Fills the dropdowns and hides loop-only fields on one-shot cues.
func _validate_property(property : Dictionary) -> void:
	if not loop and property["name"] in ["fade_out", "stop_signal_name"]:
		property["usage"] = PROPERTY_USAGE_NO_EDITOR
		return
	match property["name"]:
		"sound": AudioCatalog.apply_enum_hint(property, AudioCatalog.sound_names())
		"bus": AudioCatalog.apply_enum_hint(property, AudioCatalog.bus_choices(true))
		"signal_name", "stop_signal_name": AudioCatalog.apply_enum_hint(property, source_signals, true)