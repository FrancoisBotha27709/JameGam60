extends RefCounted
class_name DebrisRope

const POINT_COUNT := 9
const LAST_INDEX := POINT_COUNT - 1
const CONSTRAINT_PASSES := 4
const HUE_SHIFT := 0.04
const TONE_RANGE := Vector2(0.3, 0.5)
const START_ALPHA := 0.45
const HALF := 0.5

var debris : DebrisObject
var points := PackedVector2Array()
var previous_points := PackedVector2Array()
var pull_speed := 0.0

func _init(owning_debris : DebrisObject) -> void:
	debris = owning_debris

# Builds the rope line with its points laid out evenly between the debris and the target.
func create(target : Node2D) -> void:
	var line := Line2D.new()
	line.top_level = true
	line.width = debris.data.rope_width
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	points.resize(POINT_COUNT)
	for point_index in POINT_COUNT:
		points[point_index] = debris.global_position.lerp(target.global_position, float(point_index) / LAST_INDEX)
	previous_points = points.duplicate()
	pull_speed = 0.0
	line.points = points
	line.gradient = _make_gradient()
	debris.rope = line
	debris.add_child(line)

func release() -> void:
	if debris.rope:
		debris.rope.queue_free()
		debris.rope = null

# A dark-to-light gradient of the debris color with a small shared hue shift.
func _make_gradient() -> Gradient:
	var hue_shift := randf_range(-HUE_SHIFT, HUE_SHIFT)
	var start_color := debris.base_color.darkened(DebrisShapes.random_in(TONE_RANGE))
	start_color.a = START_ALPHA
	var end_color := debris.base_color.lightened(DebrisShapes.random_in(TONE_RANGE))
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([DebrisShapes.shift_hue(start_color, hue_shift), DebrisShapes.shift_hue(end_color, hue_shift)])
	return gradient

func update(delta : float) -> void:
	_pull_toward_anchor(delta)
	_simulate(delta)

# Drags the debris toward its anchor with an accelerating, capped pull once the rope is taut.
func _pull_toward_anchor(delta : float) -> void:
	var to_anchor := debris.anchor.global_position - debris.global_position
	var distance := to_anchor.length()
	if distance <= debris.data.rope_length:
		pull_speed = 0.0
		return
	pull_speed = minf(pull_speed + debris.rope_pull_accel * delta, debris.rope_max_pull_speed)
	var catch_up := (distance - debris.data.rope_length) * minf(debris.data.rope_pull_strength * delta, 1.0)
	debris.global_position += to_anchor / distance * minf(catch_up, pull_speed * delta)

# Verlet rope: inertia, neighbour smoothing, pinned ends, then repeated max-length constraints.
func _simulate(delta : float) -> void:
	var damping := maxf(1.0 - debris.rope_damping * delta, 0.0)
	for point_index in range(1, LAST_INDEX):
		var current := points[point_index]
		points[point_index] = current + (current - previous_points[point_index]) * damping
		previous_points[point_index] = current
	for point_index in range(1, LAST_INDEX):
		var neighbor_average := (points[point_index - 1] + points[point_index + 1]) * HALF
		points[point_index] = points[point_index].lerp(neighbor_average, debris.rope_stiffness)
	points[0] = debris.global_position
	points[LAST_INDEX] = debris.anchor.global_position
	var segment_length := debris.data.rope_length * debris.rope_slack / LAST_INDEX
	for pass_index in CONSTRAINT_PASSES:
		for segment_index in LAST_INDEX:
			_limit_segment(segment_index, segment_length)
	debris.rope.points = points

# Pulls a stretched segment back to its max length; the pinned end points never move.
func _limit_segment(segment_index : int, max_length : float) -> void:
	var span := points[segment_index + 1] - points[segment_index]
	var length := span.length()
	if length <= max_length:
		return
	var correction := span * ((length - max_length) / length)
	var start_share := 0.0 if segment_index == 0 else (1.0 if segment_index == LAST_INDEX - 1 else HALF)
	points[segment_index] += correction * start_share
	points[segment_index + 1] -= correction * (1.0 - start_share)