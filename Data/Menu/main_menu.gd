class_name MainMenu
extends BaseMenu

signal ship_switched

const FIRST_LAUNCH_PATH := "user://first_launch.cfg"
const FIRST_LAUNCH_SECTION := "launch"
const FIRST_LAUNCH_KEY := "tutorial_shown"
const SHIP_STEP_ACTIONS := {&"ui_left": -1, &"ui_right": 1, &"ui_page_up": -1, &"ui_page_down": 1}
const STATUS_REFRESH_SECONDS := 1.0
const NAME_TYPE_DURATION := 0.35
const PIP_SIZE := Vector2(26.0, 6.0)
const PIP_SIZE_SELECTED := Vector2(42.0, 6.0)

@export_group("Flow")
@export var game_path : PackedScene
@export var step_size : int = 1

@export_group("Scene Nodes")
@export_subgroup("Backdrop")
@export var starfield : TextureRect
@export var backdrop : HangarBackdrop
@export var ship_stage : Control
@export var ship_container : ShipContainer
@export_subgroup("Header")
@export var status_label : Label
@export var tutorial_popup : TutorialPopup
@export_subgroup("Buttons")
@export var play_button : HangarButton
@export var tutorial_button : HangarButton
@export var options_button : HangarButton
@export var quit_button : HangarButton
@export_subgroup("Ship Selector")
@export var ship_selector : Control
@export var previous_ship_button : HangarButton
@export var next_ship_button : HangarButton
@export var ship_name_label : Label
@export var ship_index_label : Label
@export var ship_pips : Control

@export_group("Dissolve")
@export var dissolve_duration : float = 1.3
@export_range(0.1, 0.9) var swap_ratio : float = 0.46

@export_group("Ambient")
@export var parallax_smoothing : float = 4.0
@export var starfield_pan_pixels : float = 300.0
@export var ship_parallax_pixels : float = 14.0
@export var ship_bob_height : float = 8.0
@export var ship_bob_speed : float = 1.2
@export_range(0.2, 0.8) var stage_height_ratio : float = 0.5

@export_group("Launch")
## Must be the same preset your PortalEntry uses in-game.
@export var launch_portal_preset : String = "portal"
@export var launch_portal_pixel_scale : float = 2.0
## Portal position relative to ShipStage.
@export var launch_portal_offset : Vector2 = Vector2(360.0, -280.0)
@export var launch_portal_open_time : float = 0.45
@export var launch_turn_time : float = 0.45
@export var launch_fly_time : float = 0.55
@export var launch_portal_close_time : float = 0.3
@export var launch_end_scale : float = 0.03

var _dissolve_material : ShaderMaterial
var _starfield_material : ShaderMaterial
var _dissolve_progress : float = 0.0
var _dissolve_tween : Tween
var _name_tween : Tween
var _parallax := Vector2.ZERO
var _elapsed_seconds : float = 0.0
var _status_timer : float = 0.0
var _is_leaving : bool = false
var _is_launching : bool = false

#region Lifecycle
func _ready() -> void:
	bind_buttons({
		play_button: _on_play_pressed,
		tutorial_button: _show_tutorial,
		options_button: _on_options_pressed,
		quit_button: _on_quit_pressed,
		previous_ship_button: _step_ship.bind(-step_size),
		next_ship_button: _step_ship.bind(step_size),
	})

	_starfield_material = starfield.material as ShaderMaterial
	_dissolve_material = ship_container.material as ShaderMaterial
	_set_dissolve_progress(0.0)
	_apply_ship()
	_update_status_readout()
	super._ready()

	if _is_first_launch():
		_mark_launched()
		# Deferred so the menu layout is finished before the popup opens.
		_show_tutorial.call_deferred()

func _process(delta: float) -> void:
	_elapsed_seconds += delta
	_update_parallax(delta)
	_update_stage()
	_status_timer += delta
	if _status_timer >= STATUS_REFRESH_SECONDS:
		_status_timer = 0.0
		_update_status_readout()

# Only steps ships while a menu button has focus, so popups keep their own input.
func _input(event: InputEvent) -> void:
	if _is_leaving or not _is_hangar_button_focused():
		return
	for action in SHIP_STEP_ACTIONS:
		if event.is_action_pressed(action):
			_step_ship(SHIP_STEP_ACTIONS[action] * step_size)
			get_viewport().set_input_as_handled()
			return

func _is_hangar_button_focused() -> bool:
	var node : Node = get_viewport().gui_get_focus_owner()
	while node != null and node != self:
		# Option buttons handle left/right themselves.
		if node is HangarOptionButton:
			return false
		if node is HangarButton:
			return true
		node = node.get_parent()
	return false
#endregion

#region First launch
# True until the tutorial has been shown once; the flag is stored on disk so it survives restarts.
func _is_first_launch() -> bool:
	var config := ConfigFile.new()
	if config.load(FIRST_LAUNCH_PATH) != OK:
		return true
	return not config.get_value(FIRST_LAUNCH_SECTION, FIRST_LAUNCH_KEY, false)

func _mark_launched() -> void:
	var config := ConfigFile.new()
	config.set_value(FIRST_LAUNCH_SECTION, FIRST_LAUNCH_KEY, true)
	var error := config.save(FIRST_LAUNCH_PATH)
	if error != OK:
		push_warning("MainMenu: failed to save first launch flag. Error: %s" % error)
#endregion

#region Button actions
func _show_tutorial() -> void:
	tutorial_popup.show_popup()

func _on_options_pressed() -> void:
	Settings.show_options()

func _on_play_pressed() -> void:
	if game_path == null or _is_leaving:
		return
	_is_leaving = true
	await _play_launch()
	await _leave_menu()
	get_tree().change_scene_to_packed(game_path)

func _on_quit_pressed() -> void:
	if _is_leaving:
		return
	await _leave_menu()
	get_tree().quit()

func _leave_menu() -> void:
	_is_leaving = true
	backdrop.trigger_pulse()
	await close()
#endregion

#region Ambient motion
func _update_parallax(delta: float) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var mouse_offset := (get_viewport().get_mouse_position() / size - Vector2(0.5, 0.5)) * 2.0
	_parallax = _parallax.lerp(mouse_offset.clamp(-Vector2.ONE, Vector2.ONE), 1.0 - exp(-parallax_smoothing * delta))
	backdrop.parallax = _parallax
	if _starfield_material != null:
		_starfield_material.set_shader_parameter("camera_position", _parallax * starfield_pan_pixels)

# The ship hovers above the center of the ship selector, and the backdrop's landing pad follows it.
func _update_stage() -> void:
	ship_stage.global_position = Vector2(ship_selector.get_global_rect().get_center().x, size.y * stage_height_ratio)
	backdrop.focal_point = ship_stage.global_position - backdrop.global_position
	if not _is_launching:
		ship_container.position = Vector2(
			_parallax.x * ship_parallax_pixels,
			sin(_elapsed_seconds * ship_bob_speed) * ship_bob_height
		)

func _update_status_readout() -> void:
	status_label.text = "SYSTEMS NOMINAL    %s" % Time.get_time_string_from_system()
#endregion

#region Ship carousel
func _step_ship(direction: int) -> void:
	var count := DataCollector.ship_designs.size()
	if count == 0:
		return

	DataCollector.selected_ship_index = posmod(DataCollector.selected_ship_index + direction, count)
	_transition_to_ship()

func _set_dissolve_progress(value: float) -> void:
	_dissolve_progress = value
	if _dissolve_material != null:
		_dissolve_material.set_shader_parameter("progress", value)

func _transition_to_ship() -> void:
	if _dissolve_material == null:
		_apply_ship()
		return

	var out_time := dissolve_duration * swap_ratio
	var in_time := dissolve_duration * (1.0 - swap_ratio)

	_dissolve_tween = restart_tween(_dissolve_tween)
	_dissolve_tween.tween_method(_set_dissolve_progress, _dissolve_progress, 1.0, maxf(out_time * (1.0 - _dissolve_progress), 0.001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_dissolve_tween.tween_callback(_apply_ship)
	_dissolve_tween.tween_method(_set_dissolve_progress, 1.0, 0.0, in_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	backdrop.trigger_pulse()
	ship_switched.emit()

func _apply_ship() -> void:
	var design := DataCollector.get_selected_ship()
	if design == null:
		push_warning("MainMenu: no selected ship design.")
		return

	ship_container.setup(true, design, ship_stage)
	_refresh_ship_readout(design)
#endregion

#region Launch
func _play_launch() -> void:
	# Settle any half-finished dissolve so the right ship is showing.
	if _dissolve_tween != null and _dissolve_tween.is_valid():
		_dissolve_tween.kill()
		_apply_ship()
	_set_dissolve_progress(0.0)
	_is_launching = true

	var portal := FXPlayer.new()
	portal.preset = launch_portal_preset
	portal.pixel_scale = launch_portal_pixel_scale
	portal.position = launch_portal_offset
	portal.scale = Vector2.ONE * 0.05
	ship_stage.add_child(portal)
	ship_stage.move_child(portal, 0) # behind the ship, so it looks like it flies in

	# Assumes the ship faces up at rotation 0.
	var to_portal := launch_portal_offset - ship_container.position
	var turn_angle := Vector2.UP.angle_to(to_portal)

	var tween := create_tween()
	# Step 1: portal opens while the ship turns toward it.
	tween.tween_property(portal, "scale", Vector2.ONE, launch_portal_open_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ship_container, "rotation", turn_angle, launch_turn_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# Step 2: ship accelerates into the portal, shrinking as it goes.
	tween.tween_property(ship_container, "position", launch_portal_offset, launch_fly_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(ship_container, "scale", ship_container.scale * launch_end_scale, launch_fly_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(portal.stop)
	tween.tween_interval(launch_portal_close_time)
	await tween.finished
#endregion

#region Ship readout
func _refresh_ship_readout(design: Variant) -> void:
	ship_name_label.text = design.ship_name
	ship_name_label.visible_ratio = 0.0
	_name_tween = restart_tween(_name_tween)
	_name_tween.tween_property(ship_name_label, "visible_ratio", 1.0, NAME_TYPE_DURATION)

	ship_index_label.text = "BAY %02d / %02d" % [DataCollector.selected_ship_index + 1, DataCollector.ship_designs.size()]
	_refresh_ship_pips()

# Pips are scene nodes; the ones beyond the ship count are hidden.
func _refresh_ship_pips() -> void:
	var ship_count := DataCollector.ship_designs.size()
	for pip_index in ship_pips.get_child_count():
		var pip := ship_pips.get_child(pip_index) as ColorRect
		var is_selected := pip_index == DataCollector.selected_ship_index
		pip.visible = pip_index < ship_count
		pip.color = MenuStyle.ACCENT if is_selected else Color(MenuStyle.ACCENT, 0.3)
		pip.custom_minimum_size = PIP_SIZE_SELECTED if is_selected else PIP_SIZE
#endregion
