class_name HangarTabContainer
extends Control

signal tab_changed(tab_index: int)

const PAGE_SWITCH_ACTIONS := {&"ui_page_up": -1, &"ui_page_down": 1}
const PAGE_FADE_DURATION := 0.18
const PAGE_SLIDE_DISTANCE := 40.0
const INDICATOR_DURATION := 0.25
const TAB_INDEX_FORMAT := "%02d"

@export_group("Scene Nodes")
@export var tab_bar : Container
@export var page_container : Control
@export var indicator : Control

var current_tab : int = 0

var _page_tween : Tween
var _indicator_tween : Tween
var _page_rest_offsets : Dictionary = {}

#region Lifecycle
# Tabs mirror the children of the page container: one tab button per page, extra buttons are hidden.
func _ready() -> void:
	var pages := _get_pages()
	var tab_buttons := _get_tab_buttons()
	if pages.size() > tab_buttons.size():
		push_warning("HangarTabContainer: %d pages but only %d tab buttons." % [pages.size(), tab_buttons.size()])
	for button_index in tab_buttons.size():
		_configure_tab_button(tab_buttons[button_index], button_index, pages)
	tab_bar.sort_children.connect(_move_indicator.bind(false))
	select_tab(current_tab, false)

# Page up and page down switch tabs from anywhere inside the container.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not MenuStyle.has_focus_within(self):
		return
	for action in PAGE_SWITCH_ACTIONS:
		if event.is_action_pressed(action):
			step_tab(PAGE_SWITCH_ACTIONS[action])
			get_viewport().set_input_as_handled()
			return
#endregion

#region Tabs
func select_tab(tab_index: int, animate: bool = true) -> void:
	var pages := _get_pages()
	if pages.is_empty():
		return
	var previous_tab := current_tab
	current_tab = clampi(tab_index, 0, pages.size() - 1)

	var tab_buttons := _get_tab_buttons()
	for button_index in tab_buttons.size():
		tab_buttons[button_index].selected = button_index == current_tab
	for page_index in pages.size():
		pages[page_index].visible = page_index == current_tab

	_play_page_entrance(pages[current_tab], signi(current_tab - previous_tab), animate and current_tab != previous_tab)
	_move_indicator(animate)
	if current_tab != previous_tab:
		tab_changed.emit(current_tab)

func step_tab(direction: int) -> void:
	var page_count := _get_pages().size()
	if page_count > 0:
		select_tab(posmod(current_tab + direction, page_count))

func get_current_page() -> Control:
	var pages := _get_pages()
	return pages[current_tab] if current_tab < pages.size() else null

func _configure_tab_button(tab_button: HangarTabButton, tab_index: int, pages: Array[Control]) -> void:
	tab_button.visible = tab_index < pages.size()
	if not tab_button.visible:
		return
	tab_button.text = pages[tab_index].name.to_upper()
	tab_button.index_text = TAB_INDEX_FORMAT % (tab_index + 1)
	tab_button.pressed.connect(select_tab.bind(tab_index))

func _get_tab_buttons() -> Array[HangarTabButton]:
	var tab_buttons : Array[HangarTabButton] = []
	for child in tab_bar.get_children():
		if child is HangarTabButton:
			tab_buttons.append(child as HangarTabButton)
	return tab_buttons

func _get_pages() -> Array[Control]:
	var pages : Array[Control] = []
	for child in page_container.get_children():
		if child is Control:
			pages.append(child as Control)
	return pages
#endregion

#region Animation
func _play_page_entrance(page: Control, direction: int, animate: bool) -> void:
	_set_page_shift(0.0, page)
	page.modulate.a = 1.0
	if not animate:
		return
	page.modulate.a = 0.0
	_page_tween = MenuStyle.restart_tween(self, _page_tween).set_parallel(true)
	_page_tween.tween_property(page, "modulate:a", 1.0, PAGE_FADE_DURATION)
	_page_tween.tween_method(_set_page_shift.bind(page), direction * PAGE_SLIDE_DISTANCE, 0.0, PAGE_FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# Shifts through offsets rather than position so anchored pages keep their layout.
func _set_page_shift(shift: float, page: Control) -> void:
	var rest_offsets : Vector2 = _page_rest_offsets.get_or_add(page, Vector2(page.offset_left, page.offset_right))
	page.offset_left = rest_offsets.x + shift
	page.offset_right = rest_offsets.y + shift

# The indicator slides under the selected tab; it shares the tab bar's left edge, so the button's x is enough.
func _move_indicator(animate: bool) -> void:
	var tab_buttons := _get_tab_buttons()
	if current_tab >= tab_buttons.size():
		return
	var tab_button := tab_buttons[current_tab]
	if not animate:
		indicator.position.x = tab_button.position.x
		indicator.size.x = tab_button.size.x
		return
	_indicator_tween = MenuStyle.restart_tween(self, _indicator_tween).set_parallel(true)
	_indicator_tween.tween_property(indicator, "position:x", tab_button.position.x, INDICATOR_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_indicator_tween.tween_property(indicator, "size:x", tab_button.size.x, INDICATOR_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
#endregion
