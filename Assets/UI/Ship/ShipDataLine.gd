extends Line2D
class_name ShipDataLine

@export var straight_length: float = 50.0:
	set(value):
		straight_length = maxf(value, 0.0)
		_update_line()

@export_range(0.0, 89.9, 0.1) var turn_angle: float = 45.0:
	set(value):
		turn_angle = clampf(value, 0.0, 89.9)
		_update_line()

## -1 bends left, 1 bends right.
@export_range(-1, 1, 2) var horizontal_direction: int = 1:
	set(value):
		horizontal_direction = -1 if value < 0 else 1
		_update_line()

## -1 bends upward, 1 bends downward.
@export_range(-1, 1, 2) var vertical_direction: int = -1:
	set(value):
		vertical_direction = -1 if value < 0 else 1
		_update_line()

var start_point: Vector2 = Vector2.ZERO:
	set(value):
		start_point = value
		_update_line()

var target_point: Vector2 = Vector2.ZERO:
	set(value):
		target_point = value
		_update_line()

var line_data: Dictionary = {}:
	set(value):
		line_data = value.duplicate(true)

## 0 = nothing drawn, 1 = full line. Tween this to animate the line in.
var reveal: float = 1.0:
	set(value):
		reveal = clampf(value, 0.0, 1.0)
		_apply_reveal()

var _full_path := PackedVector2Array()
var _reveal_tween: Tween


func setup(start: Vector2, target: Vector2, data: Dictionary = {},
		direction_x: int = 1, direction_y: int = -1) -> void:
	start_point = start
	target_point = target
	line_data = data
	horizontal_direction = direction_x
	vertical_direction = direction_y
	_update_line()


func update_endpoints(start: Vector2, target: Vector2) -> void:
	start_point = start
	target_point = target
	_update_line()


func set_data(data: Dictionary) -> void:
	line_data = data


func animate_in(duration: float = 0.35) -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()

	reveal = 0.0
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(self, "reveal", 1.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _update_line() -> void:
	if not is_inside_tree():
		return

	_full_path = _build_path()
	_apply_reveal()


func _apply_reveal() -> void:
	clear_points()

	if _full_path.size() < 2 or reveal >= 1.0:
		for point in _full_path:
			add_point(point)
		return

	var total := 0.0
	for i in range(1, _full_path.size()):
		total += _full_path[i].distance_to(_full_path[i - 1])

	var remaining := total * reveal
	add_point(_full_path[0])

	for i in range(1, _full_path.size()):
		var segment := _full_path[i] - _full_path[i - 1]
		var segment_length := segment.length()

		if remaining >= segment_length:
			add_point(_full_path[i])
			remaining -= segment_length
		else:
			add_point(_full_path[i - 1] + segment.normalized() * remaining)
			break


func _build_path() -> PackedVector2Array:
	var pts := PackedVector2Array([start_point])

	var difference := target_point - start_point
	var distance := difference.length()

	if distance <= 0.001:
		return pts

	var direction := float(horizontal_direction)
	var vertical := float(vertical_direction)

	# First segment always extends horizontally from the marker.
	var straight_distance := minf(straight_length, distance)
	var straight_end := start_point + Vector2(direction * straight_distance, 0.0)
	pts.append(straight_end)

	if straight_distance >= distance:
		return pts

	# The diagonal must move toward the endpoint's horizontal and
	# vertical directions, including for left-side callouts.
	var remaining := target_point - straight_end
	var diagonal_x := signf(remaining.x)
	var diagonal_y := signf(remaining.y)

	if diagonal_x == 0.0:
		diagonal_x = direction

	if diagonal_y == 0.0:
		diagonal_y = vertical

	var angle := deg_to_rad(turn_angle)
	var diagonal_length := minf(
		absf(remaining.x) / maxf(cos(angle), 0.001),
		absf(remaining.y) / maxf(sin(angle), 0.001)
	)

	if turn_angle <= 0.001:
		diagonal_length = absf(remaining.x)

	var diagonal_end := straight_end + Vector2(
		diagonal_x * cos(angle) * diagonal_length,
		diagonal_y * sin(angle) * diagonal_length
	)
	pts.append(diagonal_end)

	if not diagonal_end.is_equal_approx(target_point):
		pts.append(target_point)

	return pts