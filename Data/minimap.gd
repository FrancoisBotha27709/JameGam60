extends Control
class_name Minimap

## Draws a scaled-down view of the whole map. Creates no child nodes.
## Needs groups: "Asteroid", "Depot", "Player".

@export var player : Player

## World area to show. Leave at zero size to auto-fit to everything found,
## or call set_world_bounds(rect) from your level script.
@export var world_rect : Rect2 = Rect2()

@export_group("View")
@export var follow_player : bool = false
@export var view_range : float = 3000.0 ## world units across the minimap width when following
@export var padding : float = 6.0

@export_group("Style")
@export var background_color : Color = Color(0.03, 0.05, 0.08, 0.7)
@export var asteroid_color : Color = Color(0.75, 0.65, 0.55, 0.9)
@export var depot_color : Color = Color(0.4, 1.0, 0.6, 1.0)
@export var player_color : Color = Color(1.0, 1.0, 1.0, 1.0)
@export var line_px : float = 1.5
@export var depot_px : float = 5.0
@export var player_px : float = 5.0

var _scale : float = 1.0
var _origin : Vector2 = Vector2.ZERO # world point shown at the minimap center


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_world_bounds(rect : Rect2) -> void:
	world_rect = rect


func _process(_delta : float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("Player") as Player
	queue_redraw()


func _update_view() -> void:
	var inner := size - Vector2(padding, padding) * 2.0
	if follow_player and is_instance_valid(player):
		_scale = inner.x / view_range
		_origin = player.global_position
		return

	var rect := world_rect
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		rect = _auto_bounds()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		_scale = 1.0
		_origin = Vector2.ZERO
		return
	_scale = minf(inner.x / rect.size.x, inner.y / rect.size.y)
	_origin = rect.get_center()


func _auto_bounds() -> Rect2:
	var found := false
	var r := Rect2()
	for group in ["Asteroid", "Depot", "Player"]:
		for n in get_tree().get_nodes_in_group(group):
			if n is Node2D:
				var p : Vector2 = n.global_position
				if not found:
					r = Rect2(p, Vector2.ZERO)
					found = true
				else:
					r = r.expand(p)
	return r.grow(200.0) if found else r


func _to_map(world : Vector2) -> Vector2:
	return (world - _origin) * _scale + size * 0.5


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	_update_view()

	# World border (only when a rect is set)
	if world_rect.size.x > 0.0 and world_rect.size.y > 0.0:
		var r := world_rect
		var pts := PackedVector2Array([
			_to_map(r.position), _to_map(Vector2(r.end.x, r.position.y)),
			_to_map(r.end), _to_map(Vector2(r.position.x, r.end.y)),
			_to_map(r.position)])
		draw_polyline(pts, asteroid_color.darkened(0.4), line_px)

	# Asteroids
	for a in get_tree().get_nodes_in_group("Asteroid"):
		var poly : Polygon2D = a.get("node_polygon")
		if poly == null or poly.polygon.is_empty():
			continue
		var xf : Transform2D = poly.global_transform
		var pts := PackedVector2Array()
		for p in poly.polygon:
			pts.append(_to_map(xf * p))
		pts.append(pts[0])
		draw_polyline(pts, asteroid_color, line_px)

	# Depots
	for d in get_tree().get_nodes_in_group("Depot"):
		if d is Node2D:
			draw_arc(_to_map(d.global_position), depot_px, 0.0, TAU, 20, depot_color, line_px * 1.5)

	# Player
	if is_instance_valid(player):
		var s := player_px
		var shape := PackedVector2Array([
			Vector2(0, -s), Vector2(s * 0.7, s * 0.7), Vector2(0, s * 0.3), Vector2(-s * 0.7, s * 0.7)])
		var xf := Transform2D(player.global_rotation, _to_map(player.global_position))
		for i in shape.size():
			shape[i] = xf * shape[i]
		draw_colored_polygon(shape, player_color)