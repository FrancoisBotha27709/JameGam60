extends VBoxContainer
class_name QuickSettings

## Keys from Settings.SCHEMA to show here, e.g. ["game_mode", "difficulty"]
@export var keys : Array[String] = []
@export var label_width : float = 140.0
@export var control_width : float = 200.0

var _controls : Dictionary = {}

func _ready() -> void:
	for key in keys:
		var d : Dictionary = _find_def(key)
		if d.is_empty():
			push_warning("QuickSettings: no setting with key '%s' in Settings.SCHEMA" % key)
			continue
		_add_row(d)
	Settings.changed.connect(_on_changed)

func _find_def(key : String) -> Dictionary:
	for d in Settings.SCHEMA:
		if d.key == key:
			return d
	return {}

func _add_row(d : Dictionary) -> void:
	var key : String = d.key
	var row := HBoxContainer.new()

	var lbl := Label.new()
	lbl.text = d.label
	lbl.custom_minimum_size.x = label_width
	lbl.tooltip_text = d.get("tip", "")
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(lbl)

	var c : Control
	if d.type == "option":
		var o := OptionButton.new()
		for opt_name in d.opts:
			o.add_item(opt_name)
		o.select(Settings.get_value(key))
		o.custom_minimum_size.x = control_width
		o.item_selected.connect(func(i : int): Settings.set_value(key, i))
		c = o
	else:
		push_warning("QuickSettings: '%s' is not an option-type setting" % key)
		return

	_controls[key] = c
	row.add_child(c)
	add_child(row)

func _on_changed(key : String, value : Variant) -> void:
	var c : Control = _controls.get(key)
	if c is OptionButton:
		(c as OptionButton).select(value)