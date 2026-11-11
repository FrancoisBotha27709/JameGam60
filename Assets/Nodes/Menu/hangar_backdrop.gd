class_name HangarBackdrop
extends Control

const SURFACE_EDGES := [
	[Vector2(0.0, 0.0), Vector2(1.0, 0.0)],
	[Vector2(0.0, 1.0), Vector2(1.0, 1.0)],
	[Vector2(0.0, 0.0), Vector2(0.0, 1.0)],
	[Vector2(1.0, 0.0), Vector2(1.0, 1.0)],
]
const CORNER_FRACTIONS := [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
const WALL_LIGHT_HEIGHTS := [0.3, 0.7]
const WALL_GUIDE_HEIGHTS := [0.1, 0.5, 0.9]
const PULSE_SPEED := 0.2
const PULSE_SPAN := 1.4
const PULSE_WIDTH := 5.0
const PULSE_BOOST_DECAY := 1.5
const RIB_DEPTH_CURVE := 1.8
const HAZARD_STRIPE_WIDTH := 26.0
const HAZARD_HEIGHT := 12.0
const PAD_POINT_COUNT := 48
const PAD_DASH_COUNT := 24
const PAD_DASH_SPIN := 0.4
const BRACKET_LENGTH := 28.0
const MOTE_SEED := 7

@export var opening_ratio := Vector2(0.55, 0.5)
@export var vanishing_height_ratio := 0.42
@export var parallax_shift := Vector2(46.0, 26.0)
@export var rib_count := 9
@export var lane_count := 14
@export var pad_offset_ratio := 0.2
@export var pad_radius_ratio := 0.26
@export var pad_squash := 0.26
@export var mote_count := 28

var focal_point := Vector2.ZERO
var parallax := Vector2.ZERO

var _elapsed_seconds := 0.0
var _pulse_boost := 0.0
var _outer_rect := Rect2()
var _inner_rect := Rect2()
var _mote_seeds : Array[Vector2] = []

#region Lifecycle
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var random_generator := RandomNumberGenerator.new()
	random_generator.seed = MOTE_SEED
	for mote_index in mote_count:
		_mote_seeds.append(Vector2(random_generator.randf(), random_generator.randf()))

func _process(delta: float) -> void:
	_elapsed_seconds += delta
	_pulse_boost = move_toward(_pulse_boost, 0.0, delta * PULSE_BOOST_DECAY)
	queue_redraw()

func trigger_pulse() -> void:
	_pulse_boost = 1.0
#endregion

#region Drawing
func _draw() -> void:
	_update_geometry()
	_draw_room_surfaces()
	_draw_depth_ribs()
	_draw_converging_lines()
	_draw_opening()
	_draw_hazard_strip()
	_draw_spotlight()
	_draw_landing_pad()
	_draw_motes()

func _update_geometry() -> void:
	var center_x := focal_point.x if focal_point != Vector2.ZERO else size.x * 0.5
	var vanishing_point := Vector2(center_x, size.y * vanishing_height_ratio) - parallax * parallax_shift
	var opening_size := size * opening_ratio
	_outer_rect = Rect2(Vector2.ZERO, size)
	_inner_rect = Rect2(vanishing_point - opening_size * 0.5, opening_size)

func _point_on(rect: Rect2, fraction: Vector2) -> Vector2:
	return rect.position + rect.size * fraction

func _rect_at_depth(depth: float) -> Rect2:
	return Rect2(_outer_rect.position.lerp(_inner_rect.position, depth), _outer_rect.size.lerp(_inner_rect.size, depth))

func _draw_room_surfaces() -> void:
	var outer_colors := MenuStyle.ROOM_OUTER_COLOR
	var inner_colors := MenuStyle.ROOM_INNER_COLOR
	for edge in SURFACE_EDGES:
		draw_polygon(
			PackedVector2Array([
				_point_on(_outer_rect, edge[0]),
				_point_on(_outer_rect, edge[1]),
				_point_on(_inner_rect, edge[1]),
				_point_on(_inner_rect, edge[0]),
			]),
			PackedColorArray([outer_colors, outer_colors, inner_colors, inner_colors])
		)

# Ribs bunch toward the opening to fake perspective; a light pulse travels along them into the bay.
func _draw_depth_ribs() -> void:
	var pulse_position := fposmod(_elapsed_seconds * PULSE_SPEED, PULSE_SPAN) - (PULSE_SPAN - 1.0) * 0.5
	for rib_index in rib_count:
		var rib_fraction := float(rib_index + 1) / float(rib_count + 1)
		var depth := 1.0 - pow(1.0 - rib_fraction, RIB_DEPTH_CURVE)
		var pulse := pow(maxf(0.0, 1.0 - absf(pulse_position - rib_fraction) * PULSE_WIDTH), 2.0)
		var brightness := 0.1 + pulse * 0.6 + _pulse_boost * 0.5 * (1.0 - rib_fraction)
		draw_rect(_rect_at_depth(depth), Color(MenuStyle.ACCENT, brightness), false, 1.5)

func _draw_converging_line(fraction: Vector2, color: Color, width: float) -> void:
	draw_line(_point_on(_outer_rect, fraction), _point_on(_inner_rect, fraction), color, width)

func _draw_converging_lines() -> void:
	var lane_color := Color(MenuStyle.ACCENT, 0.08)
	var guide_color := Color(MenuStyle.ACCENT, 0.12)
	var light_color := Color(MenuStyle.ACCENT, 0.55)

	for lane in range(1, lane_count):
		for edge_height in [0.0, 1.0]:
			_draw_converging_line(Vector2(float(lane) / lane_count, edge_height), lane_color, 1.0)

	for side in [0.0, 1.0]:
		for height in WALL_GUIDE_HEIGHTS:
			_draw_converging_line(Vector2(side, height), guide_color, 1.0)
		for height in WALL_LIGHT_HEIGHTS:
			_draw_converging_line(Vector2(side, height), light_color, 2.0)

func _draw_opening() -> void:
	var shimmer := 0.5 + 0.5 * sin(_elapsed_seconds * 2.0)
	draw_rect(_inner_rect, Color(MenuStyle.ACCENT, 0.25 + 0.15 * shimmer), false, 2.0)
	_draw_corner_brackets(_inner_rect, BRACKET_LENGTH, Color(MenuStyle.ACCENT, 0.9))

	var scan_y := _inner_rect.position.y + _inner_rect.size.y * fposmod(_elapsed_seconds * 0.12, 1.0)
	draw_line(Vector2(_inner_rect.position.x, scan_y), Vector2(_inner_rect.end.x, scan_y), Color(MenuStyle.ACCENT, 0.07), 2.0)

func _draw_corner_brackets(rect: Rect2, length: float, color: Color) -> void:
	for corner in CORNER_FRACTIONS:
		var origin := _point_on(rect, corner)
		draw_line(origin, origin + Vector2(1.0 - corner.x * 2.0, 0.0) * length, color, 3.0)
		draw_line(origin, origin + Vector2(0.0, 1.0 - corner.y * 2.0) * length, color, 3.0)

func _draw_hazard_strip() -> void:
	var stripe_top := _inner_rect.end.y
	var stripe_bottom := stripe_top + HAZARD_HEIGHT
	var stripe_count := ceili(_inner_rect.size.x / HAZARD_STRIPE_WIDTH)
	draw_rect(Rect2(_inner_rect.position.x, stripe_top, _inner_rect.size.x, HAZARD_HEIGHT), Color(0.02, 0.03, 0.05))
	for stripe_index in range(0, stripe_count, 2):
		var left := _inner_rect.position.x + stripe_index * HAZARD_STRIPE_WIDTH
		var right := minf(left + HAZARD_STRIPE_WIDTH, _inner_rect.end.x)
		draw_colored_polygon(PackedVector2Array([
			Vector2(left, stripe_top),
			Vector2(right, stripe_top),
			Vector2(right - 8.0, stripe_bottom),
			Vector2(left - 8.0, stripe_bottom),
		]), Color(MenuStyle.WARNING, 0.6))

func _get_pad_center() -> Vector2:
	return Vector2(focal_point.x, focal_point.y + size.y * pad_offset_ratio)

func _draw_spotlight() -> void:
	var pad_center := _get_pad_center()
	var beam_half_width := size.y * pad_radius_ratio * 0.75
	var top_color := Color(MenuStyle.ACCENT, 0.1)
	var bottom_color := Color(MenuStyle.ACCENT, 0.02)
	draw_polygon(
		PackedVector2Array([
			Vector2(pad_center.x - 30.0, 0.0),
			Vector2(pad_center.x + 30.0, 0.0),
			pad_center + Vector2(beam_half_width, 0.0),
			pad_center - Vector2(beam_half_width, 0.0),
		]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color])
	)

func _ellipse_points(center: Vector2, radius: float, point_count: int, start_angle: float = 0.0, sweep: float = TAU) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_index in point_count:
		var angle := start_angle + sweep * float(point_index) / float(point_count)
		points.append(center + Vector2(cos(angle), sin(angle) * pad_squash) * radius)
	return points

func _draw_landing_pad() -> void:
	var center := _get_pad_center()
	var radius := size.y * pad_radius_ratio
	var breathing := 0.5 + 0.5 * sin(_elapsed_seconds * 1.6)

	draw_colored_polygon(_ellipse_points(center, radius, PAD_POINT_COUNT), Color(MenuStyle.ACCENT, 0.05 + 0.04 * breathing))
	draw_polyline(MenuStyle.closed_outline(_ellipse_points(center, radius, PAD_POINT_COUNT)), Color(MenuStyle.ACCENT, 0.7), 3.0)
	draw_polyline(MenuStyle.closed_outline(_ellipse_points(center, radius * 0.66, PAD_POINT_COUNT)), Color(MenuStyle.ACCENT, 0.3), 1.5)

	var dash_step := TAU / PAD_DASH_COUNT
	var spin := _elapsed_seconds * PAD_DASH_SPIN
	for dash_index in range(0, PAD_DASH_COUNT, 2):
		var dash_start := spin + dash_index * dash_step
		draw_polyline(_ellipse_points(center, radius * 0.84, 5, dash_start, dash_step * 0.7), Color(MenuStyle.ACCENT, 0.55), 2.0)

func _draw_motes() -> void:
	for mote_seed in _mote_seeds:
		var drift_x := fposmod(mote_seed.x * size.x + _elapsed_seconds * (6.0 + mote_seed.x * 10.0), size.x)
		var drift_y := fposmod(mote_seed.y * size.y - _elapsed_seconds * (4.0 + mote_seed.y * 8.0), size.y)
		var twinkle := 0.5 + 0.5 * sin(_elapsed_seconds + mote_seed.x * 20.0)
		draw_rect(Rect2(drift_x, drift_y, 2.0, 2.0), Color(MenuStyle.TEXT, 0.05 + 0.2 * twinkle))
#endregion
