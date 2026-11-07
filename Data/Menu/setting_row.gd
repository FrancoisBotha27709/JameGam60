extends PanelContainer
class_name SettingRow

signal value_changed(value : Variant)

@export var node_name_label : Label
@export var node_slider : HSlider
@export var node_option : OptionButton
@export var node_toggle : CheckButton
@export var node_value_label : Label

var _def : Dictionary = {}
var _kind : String = ""   # "slider", "option", "toggle" or "bus"

func _ready() -> void:
	node_slider.value_changed.connect(_on_slider_changed)
	node_option.item_selected.connect(_on_option_selected)
	node_toggle.toggled.connect(_on_toggled)

# Configures the row for one entry of Settings.SCHEMA.
func setup_setting(def : Dictionary, value : Variant) -> void:
	_def = def
	_kind = "slider" if def.type == "slider" else ("option" if def.type == "option" else "toggle")
	node_name_label.text = def.label
	node_name_label.tooltip_text = def.get("tip", "")
	_show_only(_kind)

	match _kind:
		"slider":
			node_slider.min_value = def.lo
			node_slider.max_value = def.hi
			node_slider.step = def.step
		"option":
			node_option.clear()
			for option_name in def.opts:
				node_option.add_item(option_name)

	set_value_silently(value)

# Configures the row as a 0-100% volume slider for an audio bus.
func setup_bus(bus_name : String, percent : float) -> void:
	_kind = "bus"
	node_name_label.text = bus_name
	node_name_label.tooltip_text = "Volume for the %s bus" % bus_name
	_show_only("slider")
	node_slider.min_value = 0.0
	node_slider.max_value = 100.0
	node_slider.step = 1.0
	set_value_silently(percent)

# Updates the controls without emitting value_changed.
func set_value_silently(value : Variant) -> void:
	match _kind:
		"slider", "bus":
			node_slider.set_value_no_signal(float(value))
			node_value_label.text = _format(float(value))
		"option":
			node_option.select(int(value))
		"toggle":
			node_toggle.set_pressed_no_signal(bool(value))

func _show_only(kind : String) -> void:
	node_slider.visible = kind == "slider"
	node_value_label.visible = kind == "slider"
	node_option.visible = kind == "option"
	node_toggle.visible = kind == "toggle"

func _format(value : float) -> String:
	if _kind == "bus":
		return "%d%%" % roundi(value)
	if value == 0.0 and _def.has("zero"):
		return _def.zero
	var result := ("%d" % roundi(value)) if _def.step >= 1.0 else ("%.2f" % value)
	return result + _def.get("suffix", "")

func _on_slider_changed(value : float) -> void:
	node_value_label.text = _format(value)
	value_changed.emit(value)

func _on_option_selected(index : int) -> void:
	value_changed.emit(index)

func _on_toggled(pressed : bool) -> void:
	value_changed.emit(pressed)