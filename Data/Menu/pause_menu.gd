
extends Control
class_name PauseMenu

@export_group("Nodes", "node_")
@export var node_resume_btn : Button
@export var node_option_btn : Button
@export var node_quit_menu_btn : Button
@export var node_quit_desk_btn : Button
@export var node_dither : DitherVignette

@export_group("Timing")
@export var intensity_fade : float = 0.2
@export_range(0.0, 1.0) var backdrop_intensity : float = 0.35
@export var open_time : float = 0.25
@export var close_time : float = 0.15

var _tween : Tween
var _closing : bool = false
var _opening : bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP

	node_resume_btn.pressed.connect(_on_play_btn_pressed)
	node_option_btn.pressed.connect(_on_options_btn_pressed)
	node_quit_menu_btn.pressed.connect(_on_quit_menu_btn_pressed)
	node_quit_desk_btn.pressed.connect(_on_quit_desk_btn_pressed)
	node_dither.tint = Color(1.0, 0.65, 0.1)
	hide()
	if is_instance_valid(node_dither):
		node_dither.intensity = 0.0

func _input(event : InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return

	get_viewport().set_input_as_handled()

	if _closing or _opening:
		return

	if visible:
		_close_menu()
	else:
		_open_menu()

func _open_menu() -> void:
	_opening = true
	_closing = false

	show()
	get_tree().paused = true

	modulate.a = 1.0
	if is_instance_valid(node_dither):
		node_dither.intensity = 0.0

	_tween = create_tween()
	if is_instance_valid(node_dither):
		_tween.tween_property(node_dither, "intensity", backdrop_intensity, intensity_fade)

	_tween.parallel().tween_property(self, "modulate:a", 1.0, open_time)

	_tween.tween_callback(func() -> void: _opening = false; node_resume_btn.grab_focus())

func _close_menu() -> void:
	if _closing:
		return

	_closing = true
	_kill_tween()

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, close_time)

	if is_instance_valid(node_dither):
		_tween.parallel().tween_property(node_dither, "intensity", 0.0, close_time)

	_tween.tween_callback(func() -> void:
		hide()
		modulate.a = 1.0
		get_tree().paused = false
		_closing = false
		)

func _on_play_btn_pressed() -> void:
	_close_menu()

func _on_options_btn_pressed() -> void:
	Settings.show_options()

func _on_quit_menu_btn_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Data/Menu/main_menu.tscn")

func _on_quit_desk_btn_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()

func _kill_tween() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
