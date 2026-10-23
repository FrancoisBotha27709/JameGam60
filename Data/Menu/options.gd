extends PanelContainer
class_name OptionsMenu

signal close_requested

@export_group("Nodes", "node_")
@export var node_tabs : TabContainer
@export_group("Layout")
@export var label_width : float = 220.0
@export var control_width : float = 260.0
@export var value_width : float = 80.0
@export var margin : int = 12

var _controls : Dictionary = {}
var _value_lbls : Dictionary = {}

func _ready() -> void:
	if node_tabs == null:
		node_tabs = $MarginContainer/TabContainer
	for c in node_tabs.get_children():   # drop the placeholder tabs from the scene
		node_tabs.remove_child(c)
		c.queue_free()
	_build()
	Settings.changed.connect(_on_changed)

func _build() -> void:
	var boxes : Dictionary = {}
	for d in Settings.SCHEMA:
		var cat : String = d.cat
		if not boxes.has(cat):
			boxes[cat] = _new_tab(cat)
		_add_row(boxes[cat], d)

	for cat in boxes:
		var row := HBoxContainer.new()
		var reset := Button.new()
		reset.text = "Reset %s to defaults" % cat.capitalize()
		reset.pressed.connect(Settings.reset_category.bind(cat))
		var back := Button.new()
		back.text = "Back"
		back.pressed.connect(func(): close_requested.emit())
		row.add_child(reset)
		row.add_child(back)
		boxes[cat].add_child(row)

func _unhandled_input(event : InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()

func _new_tab(cat : String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = cat.capitalize()   # TabContainer uses the node name as the tab title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	pad.add_child(box)
	scroll.add_child(pad)
	node_tabs.add_child(scroll)
	return box

func _add_row(box : VBoxContainer, d : Dictionary) -> void:
	var key : String = d.key
	var value : Variant = Settings.get_value(key)

	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = d.label
	lbl.custom_minimum_size.x = label_width
	lbl.tooltip_text = d.get("tip", "")
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(lbl)

	var c : Control
	match d.type:
		"slider":
			var s := HSlider.new()
			s.min_value = d.lo
			s.max_value = d.hi
			s.step = d.step
			s.set_value_no_signal(value)
			s.custom_minimum_size.x = control_width
			s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			s.value_changed.connect(func(v : float): Settings.set_value(key, v))
			var vl := Label.new()
			vl.custom_minimum_size.x = value_width
			vl.text = _fmt(d, value)
			_value_lbls[key] = vl
			c = s
		"option":
			var o := OptionButton.new()
			for name in d.opts:
				o.add_item(name)
			o.select(value)
			o.custom_minimum_size.x = control_width
			o.item_selected.connect(func(i : int): Settings.set_value(key, i))
			c = o
		_:
			var t := CheckButton.new()
			t.set_pressed_no_signal(value)
			t.toggled.connect(func(on : bool): Settings.set_value(key, on))
			c = t

	_controls[key] = c
	row.add_child(c)
	if _value_lbls.has(key):
		row.add_child(_value_lbls[key])
	box.add_child(row)

func _fmt(d : Dictionary, v : float) -> String:
	if v == 0.0 and d.has("zero"):
		return d.zero
	return ("%d" % roundi(v) if d.step >= 1.0 else "%.2f" % v) + d.get("suffix", "")

func _on_changed(key : String, value : Variant) -> void:
	var c : Control = _controls.get(key)
	if c is HSlider:
		(c as HSlider).set_value_no_signal(value)
		_value_lbls[key].text = _fmt(Settings.get_def(key), value)
	elif c is OptionButton:
		(c as OptionButton).select(value)
	elif c is CheckButton:
		(c as CheckButton).set_pressed_no_signal(value)