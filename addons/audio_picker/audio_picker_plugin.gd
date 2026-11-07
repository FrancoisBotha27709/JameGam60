@tool
extends EditorPlugin

const SoundInspectorPlugin := preload("res://addons/audio_picker/sound_inspector_plugin.gd")

var _inspector_plugin : EditorInspectorPlugin

func _enter_tree() -> void:
	_inspector_plugin = SoundInspectorPlugin.new()
	add_inspector_plugin(_inspector_plugin)

func _exit_tree() -> void:
	remove_inspector_plugin(_inspector_plugin)