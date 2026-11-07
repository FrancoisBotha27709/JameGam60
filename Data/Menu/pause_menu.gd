extends Control
class_name PauseMenu

signal open
signal close

@export_file("*.tscn") var main_menu_path : String = "res://Data/Menu/main_menu.tscn"

@export_group("Nodes", "node_")
@export var node_panel : Control
@export var node_resume_btn : BetterButton
@export var node_option_btn : BetterButton
@export var node_quit_menu_btn : BetterButton
@export var node_quit_desk_btn : BetterButton
@export var node_dither : DitherVignette

@export_group("Timing")
@export var intensity_fade : float = 0.2
@export_range(0.0, 1.0) var backdrop_intensity : float = 0.35
@export var open_time : float = 0.25
@export var close_time : float = 0.15
@export_range(0.5, 1.0) var panel_start_scale : float = 0.92

var _tween : Tween
var _closing : bool = false
var _opening : bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP

	node_panel.resized.connect(_update_pivot)
	node_resume_btn.pressed.connect(_close_menu)
	node_option_btn.pressed.connect(_on_options_btn_pressed)
	node_quit_menu_btn.pressed.connect(_on_quit_menu_btn_pressed)
	node_quit_desk_btn.pressed.connect(_on_quit_desk_btn_pressed)

	node_dither.intensity = 0.0
	hide()

func _input(event : InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return

	# The options menu handles its own ESC (it runs later, in _unhandled_input).
	if Settings.is_options_open():
		return

	get_viewport().set_input_as_handled()

	if _closing or _opening:
		return

	if visible:
		_close_menu()
	else:
		_open_menu()

func _update_pivot() -> void:
	node_panel.pivot_offset = node_panel.size * 0.5

func _open_menu() -> void:
	_kill_tween()
	_opening = true
	_closing = false
	open.emit()
	show()
	get_tree().paused = true

	modulate.a = 0.0
	node_dither.intensity = 0.0
	node_panel.scale = Vector2.ONE * (1.0 if Settings.photosensitive() else panel_start_scale)
	_update_pivot()

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(node_dither, "intensity", backdrop_intensity, intensity_fade)
	_tween.tween_property(self, "modulate:a", 1.0, open_time)
	_tween.tween_property(node_panel, "scale", Vector2.ONE, open_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(_on_opened)

func _on_opened() -> void:
	_opening = false
	node_resume_btn.node_button.grab_focus()

func _close_menu() -> void:
	if _closing:
		return

	_closing = true
	_kill_tween()
	close.emit()

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, close_time)
	_tween.tween_property(node_dither, "intensity", 0.0, close_time)
	_tween.chain().tween_callback(_on_closed)

func _on_closed() -> void:
	hide()
	modulate.a = 1.0
	get_tree().paused = false
	_closing = false

func _on_options_btn_pressed() -> void:
	Settings.show_options()

func _on_quit_menu_btn_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_path)

func _on_quit_desk_btn_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()