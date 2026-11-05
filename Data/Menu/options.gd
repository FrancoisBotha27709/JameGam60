
extends PanelContainer
class_name OptionsMenu

signal close_requested

@export_group("Nodes", "node_")
@export var node_tabs: TabContainer

@export_group("Layout")
@export var label_width: float = 220.0
@export var control_width: float = 260.0
@export var value_width: float = 80.0
@export var margin: int = 12

var _controls: Dictionary = {}
var _value_lbls: Dictionary = {}

func _ready() -> void:
	if node_tabs == null:
		node_tabs = $MarginContainer/TabContainer

	for child in node_tabs.get_children():
		node_tabs.remove_child(child)
		child.queue_free()

	_build()

	if not Settings.changed.is_connected(_on_changed):
		Settings.changed.connect(_on_changed)

	visibility_changed.connect(_on_visibility_changed)

func _exit_tree() -> void:
	if Settings.changed.is_connected(_on_changed):
		Settings.changed.disconnect(_on_changed)

func _on_visibility_changed() -> void:
	if visible:
		_refresh_audio_buses()

func _build() -> void:
	var boxes: Dictionary = {}

	for d in Settings.SCHEMA:
		var cat: String = d.cat

		if not boxes.has(cat):
			boxes[cat] = _new_tab(cat)

		_add_row(boxes[cat], d)

	if boxes.has("audio"):
		_add_audio_bus_rows(boxes["audio"])

	for cat in boxes:
		var row := HBoxContainer.new()

		var reset := Button.new()
		reset.text = "Reset %s to defaults" % cat.capitalize()
		reset.pressed.connect(Settings.reset_category.bind(cat))

		var back := Button.new()
		back.text = "Back"
		back.pressed.connect(func() -> void:
			close_requested.emit()
		)

		row.add_child(reset)
		row.add_child(back)
		boxes[cat].add_child(row)

func _new_tab(cat: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = cat.capitalize()
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

# Dynamic audio bus controls

func _add_audio_bus_rows(box: VBoxContainer) -> void:
	var heading := Label.new()
	heading.name = "AudioBusHeading"
	heading.text = "Project Audio Buses"
	heading.add_theme_font_size_override("font_size", 18)
	box.add_child(heading)

	_refresh_audio_buses()

func _refresh_audio_buses() -> void:
	if node_tabs == null:
		return

	var audio_tab := node_tabs.get_node_or_null("Audio")
	if audio_tab == null:
		return

	var box := _find_vbox(audio_tab)
	if box == null:
		return

	var heading := box.get_node_or_null("AudioBusHeading")
	if heading == null:
		return

	# Remove only the generated bus controls. Keep the other audio
	# settings and category buttons.
	for child in box.get_children():
		if child.has_meta("dynamic_audio_bus"):
			var key: String = child.get_meta("setting_key")
			_controls.erase(key)
			_value_lbls.erase(key)
			child.queue_free()

	var insert_index := heading.get_index() + 1

	for i in range(AudioServer.get_bus_count()):
		var bus_name := AudioServer.get_bus_name(i)
		var key := Settings.get_bus_setting_key(bus_name)
		var volume := Settings.get_bus_volume(bus_name)

		var row := HBoxContainer.new()
		row.set_meta("dynamic_audio_bus", true)
		row.set_meta("setting_key", key)

		var lbl := Label.new()
		lbl.text = bus_name
		lbl.custom_minimum_size.x = label_width
		lbl.tooltip_text = "Volume for the %s bus" % bus_name
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(lbl)

		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.custom_minimum_size.x = control_width
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.set_value_no_signal(volume)

		slider.value_changed.connect(
			func(v: float) -> void:
				Settings.set_bus_volume(bus_name, v)
		)

		var value_lbl := Label.new()
		value_lbl.custom_minimum_size.x = value_width
		value_lbl.text = "%d%%" % roundi(volume)

		_controls[key] = slider
		_value_lbls[key] = value_lbl

		row.add_child(slider)
		row.add_child(value_lbl)

		box.add_child(row)
		box.move_child(row, insert_index)
		insert_index += 1

func _find_vbox(node: Node) -> VBoxContainer:
	if node is VBoxContainer:
		return node

	for child in node.get_children():
		var result := _find_vbox(child)
		if result != null:
			return result

	return null

# Standard settings controls

func _add_row(box: VBoxContainer, d: Dictionary) -> void:
	var key: String = d.key
	var value: Variant = Settings.get_value(key)

	var row := HBoxContainer.new()

	var lbl := Label.new()
	lbl.text = d.label
	lbl.custom_minimum_size.x = label_width
	lbl.tooltip_text = d.get("tip", "")
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(lbl)

	var c: Control

	match d.type:
		"slider":
			var slider := HSlider.new()
			slider.min_value = d.lo
			slider.max_value = d.hi
			slider.step = d.step
			slider.set_value_no_signal(value)
			slider.custom_minimum_size.x = control_width
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER

			slider.value_changed.connect(
				func(v: float) -> void:
					Settings.set_value(key, v)
			)

			var value_lbl := Label.new()
			value_lbl.custom_minimum_size.x = value_width
			value_lbl.text = _fmt(d, float(value))
			_value_lbls[key] = value_lbl

			c = slider

		"option":
			var option := OptionButton.new()

			for option_name in d.opts:
				option.add_item(option_name)

			option.select(int(value))
			option.custom_minimum_size.x = control_width

			option.item_selected.connect(
				func(index: int) -> void:
					Settings.set_value(key, index)
			)

			c = option

		_:
			var toggle := CheckButton.new()
			toggle.set_pressed_no_signal(bool(value))

			toggle.toggled.connect(
				func(on: bool) -> void:
					Settings.set_value(key, on)
			)

			c = toggle

	_controls[key] = c
	row.add_child(c)

	if _value_lbls.has(key):
		row.add_child(_value_lbls[key])

	box.add_child(row)

func _fmt(d: Dictionary, v: float) -> String:
	if v == 0.0 and d.has("zero"):
		return d.zero

	var result := (
		"%d" % roundi(v)
		if d.step >= 1.0
		else "%.2f" % v
	)

	return result + d.get("suffix", "")

func _on_changed(key: String, value: Variant) -> void:
	var control: Control = _controls.get(key)

	if control == null:
		return

	if control is HSlider:
		(control as HSlider).set_value_no_signal(float(value))

		if _value_lbls.has(key):
			if key.begins_with("bus_volume:"):
				_value_lbls[key].text = "%d%%" % roundi(float(value))
			else:
				_value_lbls[key].text = _fmt(
					Settings.get_def(key),
					float(value)
				)

	elif control is OptionButton:
		(control as OptionButton).select(int(value))

	elif control is CheckButton:
		(control as CheckButton).set_pressed_no_signal(bool(value))

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()
