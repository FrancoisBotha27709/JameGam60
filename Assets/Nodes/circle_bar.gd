extends Control
class_name CircleBar


@export_group("Animation")
@export_range(1.0, 600.0, 1.0) var stiffness: float = 260.0
@export_range(1.0, 100.0, 1.0) var damping: float = 24.0
@export_range(0.0, 2.0, 0.05) var ghost_delay: float = 0.2
@export_range(1.0, 200.0, 1.0) var ghost_speed: float = 40.0
@export_range(0.0, 0.2, 0.005) var spring_step: float = 0.016


@export_group("Thresholds")
@export var down_marks: Array[float] = [50.0, 25.0, 5.0]
@export var up_marks: Array[float] = [75.0, 95.0]
@export var ticks: Array[float] = [25.0, 50.0, 75.0]


@export_group("Feedback")
@export var enable_threshold_alerts: bool = true
@export var enable_ghost: bool = true
@export var enable_low_pulse: bool = true
@export var enable_scale_punch: bool = true
@export var enable_flash: bool = true

@export_range(0.0, 100.0, 1.0) var low_threshold: float = 25.0
@export_range(0.0, 100.0, 1.0) var critical_threshold: float = 5.0

@export_range(0.1, 10.0, 0.1) var low_pulse_rate: float = 1.2
@export_range(0.1, 10.0, 0.1) var critical_pulse_rate: float = 3.0
@export_range(0.0, 1.0, 0.05) var pulse_strength: float = 0.45

@export_range(0.01, 1.0, 0.01) var flash_duration: float = 0.07
@export_range(0.0, 1.0, 0.05) var flash_strength: float = 0.9
@export_range(1, 10, 1) var flash_repeats: int = 3

@export_range(1.0, 1.5, 0.01) var warning_punch: float = 1.15
@export_range(1.0, 1.5, 0.01) var recovery_punch: float = 1.08
@export_range(0.01, 1.0, 0.01) var punch_duration: float = 0.25


@export_group("Boost")
@export_range(0.0, 1.0, 0.05) var boost_brightness: float = 0.35
@export_range(0.1, 30.0, 0.5) var boost_response: float = 12.0


@export_group("Colors")
@export var tick_color: Color = Color(1, 1, 1, 0.3)
@export var flash_color: Color = Color.WHITE
@export var color_full: Color = Color(0.4, 1.0, 0.85)
@export var color_mid: Color = Color(1.0, 0.75, 0.2)
@export var color_low: Color = Color(1.0, 0.25, 0.2)

@export var reverse_color_progression: bool = false


@export_group("Scale")
@export var bar_scale: Vector2 = Vector2(1.5, 1.5)

@export_group("Critical Shake")
@export var enable_critical_shake: bool = true
@export_range(0.0, 100.0, 1.0) var shake_threshold: float = 95.0
@export_range(0.0, 30.0, 0.5) var shake_intensity: float = 12.0
@export_range(1.0, 100.0, 1.0) var shake_frequency: float = 45.0

var _shake_time: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO
@onready var bar: TextureProgressBar = $TextureProgressBar
@onready var ghost: TextureProgressBar = get_node_or_null("Ghost")


var _target: float = 100.0
var _shown: float = 100.0
var _vel: float = 0.0

var _ghost_val: float = 100.0
var _ghost_wait: float = 0.0

var _flash: float = 0.0
var _boost: float = 0.0
var _boost_target: float = 0.0

var _t: float = 0.0

var _flash_tween: Tween
var _punch_tween: Tween

var _base_position: Vector2
func _ready() -> void:
	for b in [bar, ghost]:
		if b:
			b.fill_mode = TextureProgressBar.FILL_CLOCKWISE
			b.max_value = 100.0

	scale = bar_scale
	pivot_offset = size * 0.5
	_base_position = position
	resized.connect(_on_resized)


func _on_resized() -> void:
	pivot_offset = size * 0.5
	queue_redraw()


func setup(percent: float) -> void:
	_target = clampf(percent, 0.0, 100.0)
	_shown = _target
	_ghost_val = _target
	_vel = 0.0
	_ghost_wait = 0.0
	_flash = 0.0

	if bar:
		bar.value = _shown

	if ghost:
		ghost.value = _ghost_val


func set_value(value: float) -> void:
	value = clampf(value, 0.0, 100.0)

	if is_equal_approx(value, _target):
		return

	if enable_threshold_alerts:
		_check_marks(_target, value)

	if value < _target:
		_ghost_wait = ghost_delay
	elif value > _target:
		# The ghost follows immediately when recovering.
		_ghost_val = value

	_target = value


func set_boost(on: bool) -> void:
	_boost_target = 1.0 if on else 0.0


func _process(delta: float) -> void:
	_t += delta

	_update_value(delta)
	_update_ghost(delta)
	_update_boost(delta)
	_update_color()
	_update_critical_shake(delta)


func _update_value(delta: float) -> void:
	# Substeps keep the spring stable during frame drops.
	var remaining := delta

	while remaining > 0.0:
		var step := minf(remaining, spring_step)
		remaining -= step

		var acceleration := (_target - _shown) * stiffness - _vel * damping

		_vel += acceleration * step
		_shown += _vel * step

	_shown = clampf(_shown, 0.0, 100.0)

	# Prevent tiny residual movement from causing visual jitter.
	if absf(_target - _shown) < 0.01 and absf(_vel) < 0.1:
		_shown = _target
		_vel = 0.0

	bar.value = _shown

func _update_critical_shake(delta: float) -> void:
	var should_shake := (
		enable_critical_shake
		and reverse_color_progression
		and _shown >= shake_threshold
	)

	if not should_shake:
		_shake_offset = Vector2.ZERO
		position = _base_position
		return

	_shake_time += delta * shake_frequency

	var intensity := clampf(
		(_shown - shake_threshold) / maxf(100.0 - shake_threshold, 0.01),
		0.0,
		1.0
	)

	intensity = pow(intensity, 2.0)

	_shake_offset = Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	) * shake_intensity * intensity

	position = _base_position + _shake_offset

func _update_ghost(delta: float) -> void:
	if not ghost or not enable_ghost:
		return

	if _ghost_val > _shown:
		if _ghost_wait > 0.0:
			_ghost_wait = maxf(_ghost_wait - delta, 0.0)
		else:
			_ghost_val = move_toward(
				_ghost_val,
				_shown,
				ghost_speed * delta
			)
	else:
		_ghost_val = _shown

	ghost.value = _ghost_val


func _update_boost(delta: float) -> void:
	_boost = lerpf(
		_boost,
		_boost_target,
		minf(delta * boost_response, 1.0)
	)


func _update_color() -> void:
	var ratio := _shown / 100.0
	var col: Color

	if reverse_color_progression:
		ratio = 1.0 - ratio

	if ratio < 0.3:
		col = color_low.lerp(color_mid, ratio / 0.3)
	else:
		col = color_mid.lerp(color_full, (ratio - 0.3) / 0.7)

	col = col.lightened(_boost * boost_brightness)

	if enable_low_pulse and _target < low_threshold:
		var rate := (
			critical_pulse_rate
			if _target < critical_threshold
			else low_pulse_rate
		)

		var pulse := (0.5 + 0.5 * sin(_t * TAU * rate)) * pulse_strength
		col = col.darkened(pulse)

	bar.self_modulate = col.lerp(
		flash_color,
		clampf(_flash, 0.0, 1.0)
	)


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5

	for mark in ticks:
		var direction := Vector2.from_angle(
			-PI * 0.5 + mark / 100.0 * TAU
		)

		draw_line(
			center + direction * (radius - 6.0),
			center + direction * (radius + 1.0),
			tick_color,
			2.0
		)


func _check_marks(from: float, to: float) -> void:
	if to < from:
		for mark in down_marks:
			if from > mark and to <= mark:
				_alert(true)
				return

	elif to > from:
		for mark in up_marks:
			if from < mark and to >= mark:
				_alert(false)
				return


func _alert(down: bool) -> void:
	if enable_flash:
		if _flash_tween and _flash_tween.is_running():
			_flash_tween.kill()

		_flash = 0.0

		_flash_tween = create_tween().set_loops(flash_repeats)
		_flash_tween.tween_property(
			self, "_flash", flash_strength, flash_duration
		)
		_flash_tween.tween_property(
			self, "_flash", 0.0, flash_duration
		)

	if enable_scale_punch:
		if _punch_tween and _punch_tween.is_running():
			_punch_tween.kill()

		var punch := warning_punch if down else recovery_punch

		# Punch relative to the configured scale, not Vector2.ONE.
		scale = bar_scale * punch

		_punch_tween = create_tween()
		_punch_tween.tween_property(
			self, "scale", bar_scale, punch_duration
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)