
extends Node2D
class_name ShipInfo

@export var node_line: Line2D
@export var node_panel: Control

@export var panel_width: float = 220.0:
	set(value):
		panel_width = maxf(value, 0.0)
		_layout_panel()

@export var panel_height: float = 120.0:
	set(value):
		panel_height = maxf(value, 0.0)
		_layout_panel()

@export_group("Animation")
@export var line_duration: float = 0.35
@export var quick_line_duration: float = 0.12
@export var text_delay: float = 0.0

var _title: String = ""
var _data: Dictionary = {}
var _place_right: bool = true
var _straight_length: float = 50.0
var _diagonal_length: float = 60.0

var _path := PackedVector2Array()
var _line_progress: float = 0.0
var _line_tween: Tween
var _shown: bool = false
var _quick: bool = false
var _setup_called: bool = false
var _refresh_queued: bool = false

var _external_layout := false
var _external_panel_rect := Rect2()


func _ready() -> void:
	_resolve_nodes()

	if node_line != null:
		node_line.clear_points()

	if node_panel != null:
		node_panel.visible = false

	if _setup_called:
		_queue_refresh()


func setup(
	title: String,
	data: Dictionary,
	place_right: bool,
	straight_length: float = 50.0,
	diagonal_length: float = 60.0,
	quick: bool = false
) -> void:
	_title = title
	_data = data.duplicate(true)
	_place_right = place_right
	_straight_length = maxf(straight_length, 0.0)
	_diagonal_length = maxf(diagonal_length, 0.0)
	_quick = quick
	_setup_called = true

	_queue_refresh()


func is_placed_right() -> bool:
	return _place_right


func get_panel_size() -> Vector2:
	_resolve_nodes()

	var result := Vector2(panel_width, panel_height)

	if node_panel != null:
		var minimum_size := node_panel.get_combined_minimum_size()
		result.x = maxf(result.x, minimum_size.x)
		result.y = maxf(result.y, minimum_size.y)

	return result

func set_panel_rect(parent_rect: Rect2) -> void:
	_external_layout = true
	_external_panel_rect = parent_rect

	panel_width = maxf(parent_rect.size.x, 0.0)
	panel_height = maxf(parent_rect.size.y, 0.0)

	_resolve_nodes()

	if node_panel != null:
		node_panel.size = parent_rect.size
		node_panel.position = parent_rect.position - position

	_queue_refresh()


func get_title() -> String:
	return _title


func set_title(value: String) -> void:
	_title = value
	_send_content(true)


func get_data() -> Dictionary:
	return _data.duplicate(true)


func set_data(value: Dictionary) -> void:
	_data = value.duplicate(true)
	_send_content(true)


func set_side(place_right: bool) -> void:
	_place_right = place_right
	_external_layout = false
	_queue_refresh()


func set_line_lengths(straight_length: float, diagonal_length: float) -> void:
	_straight_length = maxf(straight_length, 0.0)
	_diagonal_length = maxf(diagonal_length, 0.0)
	_queue_refresh()


func _resolve_nodes() -> void:
	if node_line == null:
		node_line = get_node_or_null("Line2D") as Line2D

	if node_panel == null:
		node_panel = get_node_or_null("InfoPanel") as Control


func _queue_refresh() -> void:
	if _refresh_queued:
		return

	_refresh_queued = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false

	if not is_inside_tree():
		return

	_resolve_nodes()

	if node_line == null or node_panel == null:
		return

	_layout_panel()

	var new_path := _compute_path()

	if _shown and _paths_equal(new_path, _path):
		if node_panel.visible:
			_send_content(true)
		return

	_path = new_path
	_play_line(_quick or _shown)


func _play_line(quick: bool) -> void:
	if _line_tween != null and _line_tween.is_valid():
		_line_tween.kill()

	_shown = true
	node_panel.visible = false
	_set_line_progress(0.0)

	_line_tween = create_tween()
	_line_tween.tween_method(
		_set_line_progress,
		0.0,
		1.0,
		maxf(quick_line_duration if quick else line_duration, 0.001)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_line_tween.tween_callback(_on_line_finished.bind(quick))


func _on_line_finished(quick: bool) -> void:
	if not is_instance_valid(node_panel):
		return

	node_panel.visible = true
	_send_content(quick, 0.0 if quick else text_delay)


func _set_line_progress(value: float) -> void:
	_line_progress = clampf(value, 0.0, 1.0)
	_draw_line()


func _draw_line() -> void:
	if node_line == null or _path.size() < 2:
		return

	node_line.clear_points()

	if _line_progress >= 1.0:
		for point in _path:
			node_line.add_point(point)
		return

	var remaining := _path_length() * _line_progress
	node_line.add_point(_path[0])

	for i in range(1, _path.size()):
		var segment := _path[i] - _path[i - 1]
		var segment_length := segment.length()

		if remaining >= segment_length:
			node_line.add_point(_path[i])
			remaining -= segment_length
		else:
			node_line.add_point(
				_path[i - 1] + segment.normalized() * remaining
			)
			break


func _path_length() -> float:
	var total := 0.0
	for i in range(1, _path.size()):
		total += _path[i].distance_to(_path[i - 1])
	return total


func _compute_path() -> PackedVector2Array:
	var start := Vector2.ZERO

	if not _external_layout:
		var side := 1.0 if _place_right else -1.0
		var vertical_direction := -1.0 if position.y >= 0.0 else 1.0

		return PackedVector2Array([
			start,
			Vector2(side * _straight_length, 0.0),
			Vector2(
				side * (_straight_length + _diagonal_length),
				vertical_direction * _diagonal_length
			)
		])

	var panel_pos := node_panel.position
	var panel_size := node_panel.size

	var end_x := panel_pos.x if _place_right else panel_pos.x + panel_size.x
	var end_y := panel_pos.y + panel_size.y * 0.5
	var endpoint := Vector2(end_x, end_y)

	var direction := 1.0 if _place_right else -1.0
	var straight_end := Vector2(
		direction * minf(_straight_length, absf(endpoint.x)),
		0.0
	)

	# If the target is too close to the marker, connect directly.
	if absf(endpoint.x) <= _straight_length:
		return PackedVector2Array([start, endpoint])

	# The first segment extends horizontally, and the second reaches the
	# actual panel edge. The panel layout controls the final endpoint.
	return PackedVector2Array([
		start,
		straight_end,
		endpoint
	])


func _paths_equal(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() != b.size():
		return false

	for i in a.size():
		if not a[i].is_equal_approx(b[i]):
			return false

	return true


func _layout_panel() -> void:
	if not is_inside_tree():
		return

	_resolve_nodes()

	if node_panel == null:
		return

	if _external_layout:
		node_panel.size = Vector2(panel_width, panel_height)
		node_panel.position = _external_panel_rect.position - position
		return

	var path := _compute_path()
	if path.size() < 2:
		return

	var endpoint := path[path.size() - 1]

	node_panel.size = Vector2(panel_width, panel_height)
	node_panel.position.x = endpoint.x if _place_right else endpoint.x - panel_width
	node_panel.position.y = endpoint.y - panel_height * 0.5


func _send_content(replace: bool, delay: float = 0.0) -> void:
	if not is_instance_valid(node_panel):
		return

	var info_panel := node_panel as ShipInfoPanel
	if info_panel != null:
		info_panel.setup(_title, _data, true, replace, delay)
	else:
		push_warning("ShipInfo: InfoPanel must have ShipInfoPanel.gd attached.")
