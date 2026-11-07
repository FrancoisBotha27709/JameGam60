@tool
extends EditorProperty

const POPUP_SIZE := Vector2i(420, 540)
const NOT_FOUND_COLOR := Color(1.0, 0.55, 0.45)

var _button := Button.new()
var _popup := PopupPanel.new()
var _search := LineEdit.new()
var _tree := Tree.new()
var _count := Label.new()
# Sound name -> category path 
# (its folder under the sound directory), refreshed every time the popup opens.
var _sounds := {}

func _init() -> void:
	_button.clip_text = true
	_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_button.pressed.connect(_open)
	add_child(_button)
	add_focusable(_button)

	_search.placeholder_text = "Search sounds or categories…"
	_search.clear_button_enabled = true
	_search.text_changed.connect(_rebuild.unbind(1))
	_search.text_submitted.connect(_submit.unbind(1))
	_search.gui_input.connect(_search_key)
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_activated.connect(_activated)
	_count.modulate = Color(1, 1, 1, 0.6)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(POPUP_SIZE - Vector2i(16, 16))
	box.add_child(_search)
	box.add_child(_tree)
	box.add_child(_count)
	_popup.add_child(box)
	add_child(_popup)

# Shows the current sound on the button, tinted when it no longer exists.
func _update_property() -> void:
	var current : String = get_edited_object().get(get_edited_property())
	var missing := not current.is_empty() and current not in AudioCatalog.sound_names()
	_button.text = "(none)" if current.is_empty() else \
    current + ("   (not found)" if missing else "")
	_button.tooltip_text = current
	if missing: _button.add_theme_color_override("font_color", NOT_FOUND_COLOR)
	else: _button.remove_theme_color_override("font_color")

func _open() -> void:
	_sounds = _read_catalog()
	_search.text = ""
	_rebuild()
	_popup.popup(Rect2i(Vector2i(_button.get_screen_position()) \
    + Vector2i(0, int(_button.size.y)), POPUP_SIZE))
	_search.grab_focus()

# Maps every sound to the folder it lives in, so the picker mirrors the exported category folders.
func _read_catalog() -> Dictionary:
	var result := {}
	var catalog := AudioCatalog.scan()
	for sound_name in catalog:
		var first_path : String = catalog[sound_name]["paths"][0]
		result[sound_name] = first_path.get_base_dir().\
        trim_prefix(AudioCatalog.SOUND_DIRECTORY).trim_prefix("/")
	return result

# Lower-cases and turns _ and / into spaces so "boot fail" finds Boot_Fail/boot_fail_0.
func _normalize(text : String) -> String:
	return text.to_lower().replace("_", " ").replace("/", " ")

func _matches(haystack : String, terms : PackedStringArray) -> bool:
	for term in terms:
		if term not in haystack: return false
	return true

# Rebuilds the folder tree: collapsed when browsing, fully expanded and filtered while searching.
func _rebuild() -> void:
	_tree.clear()
	var root := _tree.create_item()
	var terms := _normalize(_search.text).split(" ", false)
	var searching := not terms.is_empty()
	var current : String = get_edited_object().get(get_edited_property())
	var names := _sounds.keys()
	names.sort_custom(func(a, b): return "%s/%s" % [_sounds[a], a] < "%s/%s" % [_sounds[b], b])
	var folders := {"": root}
	var current_item : TreeItem = null
	var shown := 0
	for sound_name in names:
		var category : String = _sounds[sound_name]
		if not _matches(_normalize("%s %s" % [category, sound_name]), terms): continue
		var item := _tree.create_item(_folder_item(category, folders, searching))
		item.set_text(0, sound_name)
		item.set_metadata(0, sound_name)
		if sound_name == current: current_item = item
		shown += 1
	_count.text = "%d of %d sounds" % [shown, _sounds.size()]
	if current_item != null and not searching:
		var ancestor := current_item.get_parent()
		while ancestor != null and ancestor != root:
			ancestor.collapsed = false
			ancestor = ancestor.get_parent()
		current_item.select(0)
		_tree.scroll_to_item.call_deferred(current_item)

# Returns the tree item for a category path, creating it (and its parents) on first use.
func _folder_item(path : String, folders : Dictionary, expanded : bool) -> TreeItem:
	if folders.has(path): return folders[path]
	var item := _tree.create_item(_folder_item(path.get_base_dir(), folders, expanded))
	item.set_text(0, path.get_file())
	item.set_icon(0, get_theme_icon("Folder", "EditorIcons"))
	item.collapsed = not expanded
	folders[path] = item
	return item

func _first_sound(parent : TreeItem) -> TreeItem:
	for child in parent.get_children():
		if child.get_metadata(0) != null: return child
		var found := _first_sound(child)
		if found != null: return found
	return null

# Double-click or Enter: pick a sound, or open/close a category.
func _activated() -> void:
	var item := _tree.get_selected()
	if item == null: return
	if item.get_metadata(0) == null: item.collapsed = not item.collapsed
	else: _choose(item.get_metadata(0))

# Enter in the search box picks the first match.
func _submit() -> void:
	var item := _first_sound(_tree.get_root()) \
    if not _search.text.is_empty() else _tree.get_selected()
	if item != null and item.get_metadata(0) != null: _choose(item.get_metadata(0))

# Down arrow in the search box jumps into the list.
func _search_key(event : InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and event.keycode == KEY_DOWN): return
	_search.accept_event()
	var item := _tree.get_selected()
	if item == null: item = _first_sound(_tree.get_root())
	if item != null: item.select(0)
	_tree.grab_focus()

func _choose(sound_name : String) -> void:
	_popup.hide()
	emit_changed(get_edited_property(), sound_name)