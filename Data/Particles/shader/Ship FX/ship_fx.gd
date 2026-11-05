extends Node2D
class_name ShipFX

signal cough(strength : float)
signal sputter_finished

@export var thrust : GPUParticles2D

@export_group("Burst")
@export var burst_amount : int = 24
@export var burst_lifetime : float = 0.45
@export var burst_params : Dictionary = {
	"spread_deg": 180.0,
	"spread_bias": 1.0,
	"speed_min": 60.0,
	"speed_max": 220.0,
	"drag": 4.0,
	"turb_amp": 0.0,
	"size_start": 0.9,
}

@export_group("Boost")
@export var boost_power : float = 1.5

@export_group("Sputter")
@export var low_fuel_threshold : float = 0.15
@export var sputter_duration : float = 1.4

var _fuel_ratio : float = 1.0
var _dying : bool = false
var _dying_t : float = 0.0
var _dead : bool = false
var _gate : bool = true
var _gate_timer : float = 0.0

var _burst : GPUParticles2D

func _ready() -> void:
	_burst = thrust.duplicate() as GPUParticles2D
	_burst.process_material = thrust.process_material.duplicate()
	_burst.material = thrust.material.duplicate()
	_burst.one_shot = true
	_burst.explosiveness = 1.0
	_burst.amount = burst_amount
	_burst.lifetime = burst_lifetime
	_burst.amount_ratio = 1.0
	_burst.emitting = false
	for key in burst_params:
		_burst.process_material.set_shader_parameter(key, burst_params[key])
	thrust.get_parent().add_child(_burst)

func set_thrust(level : float, boosting : bool = false) -> void:
	if _dying:
		# Weak, random flames while the engine coughs; ignores player input
		var p := clampf(_dying_t / sputter_duration, 0.0, 1.0)
		level = randf_range(0.2, 0.6) * (1.0 - p) if _gate else 0.0
		boosting = false
	elif not _gate:
		level = 0.0

	var on := level > 0.01
	if thrust.emitting != on:
		thrust.emitting = on
	if on:
		thrust.amount_ratio = clampf(level, 0.1, 1.0)
		thrust.process_material.set_shader_parameter("power", level * (boost_power if boosting else 1.0))

func burst(strength : float = 1.0) -> void:
	_burst.process_material.set_shader_parameter("power", strength)
	_burst.restart()

func set_fuel_ratio(ratio : float) -> void:
	_fuel_ratio = ratio
	if ratio > 0.0 and (_dead or _dying):   # refueled
		_dead = false
		_dying = false
	if ratio >= low_fuel_threshold:
		_gate = true

func start_sputter() -> void:
	if _dying or _dead:
		return
	_dying = true
	_dying_t = 0.0
	_gate_timer = 0.0

func _process(delta : float) -> void:
	if _dying:
		_tick_dying(delta)
	elif not _dead and _fuel_ratio < low_fuel_threshold:
		_tick_low_fuel(delta)

func _tick_low_fuel(delta : float) -> void:
	_gate_timer -= delta
	if _gate_timer > 0.0:
		return
	var severity := 1.0 - _fuel_ratio / low_fuel_threshold
	_gate_timer = randf_range(0.04, 0.2)
	var was_on := _gate
	_gate = randf() < lerpf(0.9, 0.4, severity)
	if _gate and not was_on:
		burst(0.2 + 0.2 * severity)
		cough.emit(0.3)

func _tick_dying(delta : float) -> void:
	_dying_t += delta
	var p := clampf(_dying_t / sputter_duration, 0.0, 1.0)
	_gate_timer -= delta
	if _gate_timer <= 0.0:
		_gate_timer = lerpf(0.06, 0.3, p) * randf_range(0.6, 1.4)
		var was_on := _gate
		_gate = randf() < lerpf(0.6, 0.0, p)
		if _gate and not was_on:
			var s := lerpf(0.7, 0.2, p)
			burst(s)
			cough.emit(s)
	if p >= 1.0:
		_dying = false
		_dead = true
		_gate = false
		thrust.emitting = false
		sputter_finished.emit()