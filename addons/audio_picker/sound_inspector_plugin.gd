@tool
extends EditorInspectorPlugin

const SoundProperty := preload("res://addons/audio_picker/sound_property.gd")

# Applies to anything with a "sound" field that the Audio autoload understands.
func _can_handle(object : Object) -> bool:
	return object is AudioTrigger or object is AudioCue

# Swaps the plain "sound" dropdown for the searchable, categorised picker.
func _parse_property(_object : Object, _type : Variant.Type, 
property_name : String, _hint_type : PropertyHint, _hint_string : String, 
_usage_flags : int, _wide : bool) -> bool:
	if property_name != "sound": return false
	add_property_editor(property_name, SoundProperty.new())
	return true