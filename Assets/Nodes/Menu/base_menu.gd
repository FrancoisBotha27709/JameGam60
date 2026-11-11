class_name BaseMenu
extends Control

signal opened
signal closed

@export_group("Menu")
@export var auto_open : bool = true
@export var close_on_cancel : bool = false
@export var focus_on_open : Control

var animated_items : Array[Control] = []

var _reveal_tween : Tween

#region Lifecycle
func _ready() -> void:
	animated_items = _collect_animated_items()
	_set_all_items_reveal(0.0)
	if auto_open:
		open()

func _unhandled_input(event: InputEvent) -> void:
	if close_on_cancel and is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func open() -> void:
	visible = true
	if focus_on_open != null:
		focus_control(focus_on_open)
	await _play_reveal(true)
	opened.emit()

func close() -> void:
	await _play_reveal(false)
	visible = false
	closed.emit()
#endregion

#region Extension points
# Override to change which controls animate and in what order. Default: every control in the reveal group, in tree order.
func _collect_animated_items() -> Array[Control]:
	var items : Array[Control] = []
	for node in find_children("*", "Control", true, false):
		if node.is_in_group(MenuStyle.REVEAL_GROUP):
			items.append(node as Control)
	return items

# Maps each button to its handler. Works with any control exposing a "pressed" signal, such as BetterButton.
func bind_buttons(bindings: Dictionary) -> void:
	for button : Control in bindings:
		button.pressed.connect(bindings[button])

# Wrapper controls such as BetterButton expose focus_button because their focusable node is internal.
func focus_control(control: Control) -> void:
	if control.has_method(&"focus_button"):
		control.focus_button()
	else:
		control.grab_focus()

func restart_tween(previous_tween: Tween) -> Tween:
	return MenuStyle.restart_tween(self, previous_tween)
#endregion

#region Reveal animation
# Items with a set_reveal method animate themselves; everything else fades.
func _play_reveal(showing: bool) -> void:
	if animated_items.is_empty():
		return

	var start_amount := 0.0 if showing else 1.0
	var end_amount := 1.0 - start_amount
	_reveal_tween = restart_tween(_reveal_tween).set_parallel(true)

	for index in animated_items.size():
		var stagger_index := index if showing else animated_items.size() - 1 - index
		_reveal_tween.tween_method(
			_set_item_reveal.bind(animated_items[index]),
			start_amount,
			end_amount,
			MenuStyle.REVEAL_DURATION
		).set_delay(stagger_index * MenuStyle.REVEAL_STAGGER).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await _reveal_tween.finished

func _set_all_items_reveal(amount: float) -> void:
	for item in animated_items:
		_set_item_reveal(amount, item)

func _set_item_reveal(amount: float, item: Control) -> void:
	if not is_instance_valid(item):
		return
	if item.has_method(&"set_reveal"):
		item.set_reveal(amount)
	else:
		item.modulate.a = amount
#endregion
