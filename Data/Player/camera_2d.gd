extends Camera2D
class_name Cam

@export var follow_target : Node2D
@export var follow_speed : float = 5.0
@export var max_history : int = 2
@export var padding : Vector2 = Vector2.ZERO
@export var dither : DitherVignette
@export_group("Shake")
@export var shake_strength : float = 12.0
@export var shake_duration : float = 0.4

@export_group("Heat Shake")
@export_range(0.0, 1.0) var heat_threshold : float = 0.6
@export var heat_max_strength : float = 8.0
@export var heat_curve : float = 2.0

@export_group("Look Ahead")
@export var look_ahead_time : float = 0.5
@export var max_look_ahead : float = 250.0
@export var look_ahead_smoothing : float = 3.0

@export_group("Speed Feel")
@export var speed_reference : float = 400.0
@export var max_speed_look_ahead : float = 450.0
@export var speed_look_ahead_multiplier : float = 1.5
@export var speed_zoom_out : float = 0.12
@export var zoom_smoothing : float = 2.0
@export var velocity_stretch : float = 0.0 # Optional; leave at 0
@export_subgroup("Speed Edge Effect")
@export var speed_effect_start : float = 150.0
@export var speed_effect_max : float = 600.0
@export_range(0.0, 1.0) var speed_effect_min_intensity : float = 0.02
@export_range(0.0, 1.0) var speed_effect_max_intensity : float = 0.35
@export var speed_effect_smoothing : float = 4.0

var _speed_effect_intensity : float = 0.0
var _base_zoom : Vector2

var _look_ahead : Vector2 = Vector2.ZERO

var _holding_position : bool = false
var _hold_position : Vector2 = Vector2.ZERO
var _history : Array[Node2D] = []
var _shake_tween : Tween
var _burst_strength : float = 0.0
var _heat_strength : float = 0.0

func _ready() -> void:
	_base_zoom = zoom
	if follow_target:
		global_position = follow_target.global_position
	SignalBus.fuel_depleted.connect(shake)
	SignalBus.update_heat.connect(_on_update_heat)
	dither.intensity = 0.0

func _process(_delta: float) -> void:
	var strength : float = maxf(_burst_strength, _heat_strength) * Settings.shake_scale()
	if strength > 0.01:
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength
	elif offset != Vector2.ZERO:
		offset = Vector2.ZERO

func _physics_process(delta : float) -> void:
	var speed := 0.0

	if is_instance_valid(follow_target) and follow_target is CharacterBody2D:
		speed = (follow_target as CharacterBody2D).velocity.length()

	var speed_ratio := clampf(speed / speed_reference, 0.0, 1.0)

	var target_lead := _get_velocity_lead()
	target_lead *= lerpf(1.0, speed_look_ahead_multiplier, speed_ratio)
	target_lead = target_lead.limit_length(lerpf(max_look_ahead, max_speed_look_ahead, speed_ratio))

	_look_ahead = _look_ahead.lerp(target_lead, 1.0 - exp(-look_ahead_smoothing * delta))

	var goal := _get_goal()
	global_position = global_position.lerp(goal + _look_ahead, 1.0 - exp(-follow_speed * delta))

	var target_zoom := _base_zoom * (1.0 - speed_zoom_out * speed_ratio)
	zoom = zoom.lerp(target_zoom, 1.0 - exp(-zoom_smoothing * delta))
	_update_speed_effect(speed, delta)

func _get_velocity_lead() -> Vector2:
	if _holding_position or not is_instance_valid(follow_target):
		return Vector2.ZERO
	if not (follow_target is CharacterBody2D):
		return Vector2.ZERO
	var v : Vector2 = (follow_target as CharacterBody2D).velocity
	return (v * look_ahead_time).limit_length(max_look_ahead)

func shake(strength : float = shake_strength, duration : float = shake_duration) -> void:
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_method(_set_burst, strength, 0.0, duration)

func _set_burst(value : float) -> void:
	_burst_strength = value

func _on_update_heat(value : float, max_value : float) -> void:
	if max_value <= 0.0:
		_heat_strength = 0.0
		return
	var ratio := value / max_value
	# Remap threshold..1.0 to 0..1, so nothing happens below 60%
	var t := clampf((ratio - heat_threshold) / (1.0 - heat_threshold), 0.0, 1.0)
	_heat_strength = heat_max_strength * pow(t, heat_curve)

func _get_goal() -> Vector2:
	if _holding_position:
		return _hold_position
	if is_instance_valid(follow_target):
		return follow_target.global_position + padding
	return global_position

func set_target(new_target : Node2D) -> void:
	_push_current_focus()
	follow_target = new_target
	_holding_position = false

func go_to_position(pos : Vector2) -> void:
	_push_current_focus()
	_hold_position = pos
	_holding_position = true

func go_to_previous() -> void:
	while not _history.is_empty():
		var previous = _history.pop_back()

		if previous is Vector2:
			_hold_position = previous
			_holding_position = true
			return
		
		if is_instance_valid(previous):
			follow_target = previous
			_holding_position = false
			return

func _push_current_focus() -> void:
	if _holding_position:
		_history.append(_hold_position)
	elif is_instance_valid(follow_target):
		_history.append(follow_target)
	
	if _history.size() > max_history:
		_history.pop_front()

func set_world_bounds(rect : Rect2) -> void:
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)

func _update_speed_effect(speed : float, delta : float) -> void:
	if not is_instance_valid(dither):
		return

	var speed_ratio := clampf((speed - speed_effect_start) / maxf(speed_effect_max - speed_effect_start, 1.0), 0.0, 1.0)

	# Ease in the effect so it builds gradually.
	speed_ratio = speed_ratio * speed_ratio

	var target_intensity := lerpf(speed_effect_min_intensity, speed_effect_max_intensity, speed_ratio
		) if speed > speed_effect_start else 0.0

	_speed_effect_intensity = lerpf(_speed_effect_intensity, target_intensity, 1.0 - exp(-speed_effect_smoothing * delta))

	dither.intensity = _speed_effect_intensity
