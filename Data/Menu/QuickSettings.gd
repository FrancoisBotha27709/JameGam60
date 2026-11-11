class_name QuickSettings
extends VBoxContainer

const INDEX_FORMAT := "%02d"

## Keys from Settings.SCHEMA to show here, e.g. ["game_mode", "difficulty"]. Key N drives the Nth HangarOptionButton child; spare buttons are hidden.
@export var keys : Array[String] = []

var _buttons : Dictionary = {}

func _ready() -> void:
	var option_buttons := _get_option_buttons()
	if keys.size() > option_buttons.size():
		push_warning("QuickSettings: %d keys but only %d option buttons." % [keys.size(), option_buttons.size()])
	for button_index in option_buttons.size():
		var key := keys[button_index] if button_index < keys.size() else ""
		_bind_button(option_buttons[button_index], key, button_index)
	Settings.changed.connect(_on_changed)

func _get_option_buttons() -> Array[HangarOptionButton]:
	var option_buttons : Array[HangarOptionButton] = []
	for child in get_children():
		if child is HangarOptionButton:
			option_buttons.append(child as HangarOptionButton)
	return option_buttons

func _find_definition(key: String) -> Dictionary:
	for definition : Dictionary in Settings.SCHEMA:
		if definition.key == key:
			return definition
	return {}

func _bind_button(option_button: HangarOptionButton, key: String, button_index: int) -> void:
	var definition := _find_definition(key)
	option_button.visible = not definition.is_empty() and definition.type == "option"
	if not option_button.visible:
		if not key.is_empty():
			push_warning("QuickSettings: '%s' is not an option-type setting in Settings.SCHEMA" % key)
		return

	var option_names : Array[String] = []
	option_names.assign(definition.opts)
	option_button.text = definition.label
	option_button.caption_text = definition.get("tip", "")
	option_button.index_text = INDEX_FORMAT % (button_index + 1)
	option_button.options = option_names
	option_button.selected_index = Settings.get_value(key)
	option_button.selection_changed.connect(_on_selection_changed.bind(key))
	_buttons[key] = option_button

func _on_selection_changed(option_index: int, key: String) -> void:
	Settings.set_value(key, option_index)

func _on_changed(key: String, value: Variant) -> void:
	var option_button : HangarOptionButton = _buttons.get(key)
	if option_button != null:
		option_button.selected_index = value
