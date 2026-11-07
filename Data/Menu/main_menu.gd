extends Control
class_name MainMenu

const FIRST_LAUNCH_PATH := "user://first_launch.cfg"
const FIRST_LAUNCH_SECTION := "launch"
const FIRST_LAUNCH_KEY := "tutorial_shown"

signal ship_switched

@export var game_path : PackedScene
@export var tut_popup : TutorialPopup
@export_group("Buttons")
@export var play_btn : Button
@export var options_btn : Button
@export var quit_btn : Button
@export var tutorial_btn : Button

@export_subgroup("Carousel Ship")
@export var step_size : int = 1
@export var arrow_left : Button
@export var arrow_right : Button
@export var ship_sprite : PackedScene
@export var ship_sprite_container : Control
@export var ship_name_label : Label

@export_subgroup("Dissolve")
@export var dissolve_shader : Shader
@export var total_time : float = 1.3
@export_range(0.1, 0.9) var swap_ratio : float = 0.46
@export var max_pixel_size : float = 24.0

var _material : ShaderMaterial
var _progress : float = 0.0
var _tween : Tween
var ship_container : ShipContainer

func _ready() -> void:
	play_btn.pressed.connect(_on_play_btn_pressed)
	options_btn.pressed.connect(_on_options_btn_pressed)
	quit_btn.pressed.connect(_on_quit_btn_pressed)
	tutorial_btn.pressed.connect(_show_tutorial)
	arrow_left.pressed.connect(_on_arrow_left)
	arrow_right.pressed.connect(_on_arrow_right)

	_setup_dissolve_material()
	_apply_ship()
	if _is_first_launch():
		_mark_launched()
		# Deferred so the menu layout is finished before the popup opens.
		_show_tutorial.call_deferred()

# True until the tutorial has been shown once; the flag is stored on disk so it survives restarts.
func _is_first_launch() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(FIRST_LAUNCH_PATH) != OK:
		return true
	return not cfg.get_value(FIRST_LAUNCH_SECTION, FIRST_LAUNCH_KEY, false)

func _mark_launched() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(FIRST_LAUNCH_SECTION, FIRST_LAUNCH_KEY, true)
	var error := cfg.save(FIRST_LAUNCH_PATH)
	if error != OK:
		push_warning("MainMenu: failed to save first launch flag. Error: %s" % error)

func _setup_dissolve_material() -> void:
	_material = ShaderMaterial.new()
	_material.shader = dissolve_shader
	_material.set_shader_parameter("max_pixel_size", max_pixel_size)
	_set_progress(0.0)

func _show_tutorial() -> void:
	tut_popup.show_popup()

func _on_play_btn_pressed() -> void:
	if game_path != null:
		get_tree().change_scene_to_packed(game_path)

func _on_options_btn_pressed() -> void:
	Settings.show_options()

func _on_quit_btn_pressed() -> void:
	get_tree().quit()

func _on_arrow_left() -> void:
	_step_ship(-step_size)

func _on_arrow_right() -> void:
	_step_ship(step_size)

func _step_ship(direction: int) -> void:
	var count := DataCollector.ship_designs.size()
	if count == 0:
		return

	DataCollector.selected_ship_index = posmod(
		DataCollector.selected_ship_index + direction,
		count
	)

	_transition_to_ship()

func _transition_to_ship() -> void:
	if _material == null:
		_apply_ship()
		return

	if _tween != null and _tween.is_running():
		_tween.kill()

	var out_time := total_time * swap_ratio
	var in_time := total_time * (1.0 - swap_ratio)

	_tween = create_tween()

	_tween.tween_method(_set_progress, _progress, 1.0, maxf(out_time * (1.0 - _progress), 0.001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_apply_ship)
	_tween.tween_method(_set_progress, 1.0, 0.0, in_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	ship_switched.emit()

func _set_progress(value: float) -> void:
	_progress = value

	if _material != null:
		_material.set_shader_parameter("progress", value)

func _apply_ship() -> void:
	var design := DataCollector.get_selected_ship()

	if design == null:
		push_warning("MainMenu: no selected ship design.")
		return

	if ship_container == null or not is_instance_valid(ship_container):
		if ship_sprite == null:
			push_warning("MainMenu: no ShipContainer scene assigned.")
			return

		ship_container = ship_sprite.instantiate() as ShipContainer

		if ship_container == null:
			push_warning("MainMenu: ship scene must have a ShipContainer root.")
			return

		if ship_sprite_container != null:
			ship_sprite_container.add_child(ship_container)
		else:
			add_child(ship_container)

		ship_container.position = Vector2.ZERO
		ship_container.scale = Vector2(5.0, 5.0)
		ship_container.material = _material

	ship_container.setup(
		true,
		design,
		ship_sprite_container
	)

	if ship_name_label != null:
		ship_name_label.text = design.ship_name