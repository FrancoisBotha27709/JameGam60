extends PanelContainer
class_name OptionsMenu

signal close_requested

@export var row_scene : PackedScene

@export_group("Nodes", "node_")
@export var node_tabs : HangarTabContainer
@export var node_video_rows : VBoxContainer
@export var node_audio_rows : VBoxContainer
@export var node_graphics_rows : VBoxContainer
@export var node_gameplay_rows : VBoxContainer
@export var node_bus_rows : VBoxContainer
@export var node_reset_btn : HangarButton
@export var node_back_btn : HangarButton

var _rows : Dictionary = {}
var _bus_keys : Array[String] = []

func _ready() -> void:
	_build()
	_refresh_audio_buses()

	node_reset_btn.pressed.connect(_on_reset_pressed)
	node_back_btn.pressed.connect(close_requested.emit)

	if not Settings.changed.is_connected(_on_changed):
		Settings.changed.connect(_on_changed)

	visibility_changed.connect(_on_visibility_changed)

func _exit_tree() -> void:
	if Settings.changed.is_connected(_on_changed):
		Settings.changed.disconnect(_on_changed)

func _on_visibility_changed() -> void:
	if not visible:
		return
	_refresh_audio_buses()
	_focus_current_tab.call_deferred()

# Page up/down only works while focus is inside the tab container, so focus the open tab's button.
func _focus_current_tab() -> void:
	var tab_buttons := node_tabs.tab_bar.get_children().filter(func(node : Node) -> bool: return node is HangarTabButton)
	if node_tabs.current_tab < tab_buttons.size():
		(tab_buttons[node_tabs.current_tab] as HangarTabButton).focus_button()

func _category_box(category : String) -> VBoxContainer:
	match category:
		"video": return node_video_rows
		"audio": return node_audio_rows
		"graphics": return node_graphics_rows
		"gameplay": return node_gameplay_rows
	return null

# Adds one row per schema entry to the box of its category.
func _build() -> void:
	for def in Settings.SCHEMA:
		var box := _category_box(def.cat)
		if box == null:
			push_warning("OptionsMenu: no tab for category '%s'." % def.cat)
			continue

		var key : String = def.key
		var row := row_scene.instantiate() as SettingRow
		box.add_child(row)
		row.setup_setting(def, Settings.get_value(key))
		row.value_changed.connect(func(value : Variant) -> void:
			Settings.set_value(key, value)
		)
		_rows[key] = row

# Rebuilds the bus sliders from the buses that exist right now.
func _refresh_audio_buses() -> void:
	for key in _bus_keys:
		_rows.erase(key)
	_bus_keys.clear()

	for child in node_bus_rows.get_children():
		child.queue_free()

	for bus_index in AudioServer.bus_count:
		var bus_name := AudioServer.get_bus_name(bus_index)
		var key := Settings.get_bus_setting_key(bus_name)

		var row := row_scene.instantiate() as SettingRow
		node_bus_rows.add_child(row)
		row.setup_bus(bus_name, Settings.get_bus_volume(bus_name))
		row.value_changed.connect(func(value : Variant) -> void:
			Settings.set_bus_volume(bus_name, float(value))
		)

		_rows[key] = row
		_bus_keys.append(key)

# Resets only the open tab (the page's node name is the category).
func _on_reset_pressed() -> void:
	var page := node_tabs.get_current_page()
	if page != null:
		Settings.reset_category(page.name.to_lower())

func _on_changed(key : String, value : Variant) -> void:
	var row : SettingRow = _rows.get(key)
	if row != null and is_instance_valid(row):
		row.set_value_silently(value)

func _unhandled_input(event : InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()