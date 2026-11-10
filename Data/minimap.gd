extends Control
class_name Minimap

const EDGE_PAIRS := [[], [3, 0], [0, 1], [3, 1], [1, 2], [3, 0, 1, 2], [0, 2], [3, 2], [2, 3], [0, 2], [0, 1, 2, 3], [1, 2], [3, 1], [0, 1], [3, 0], []]
const STATE_SLEEPING := 1

@export var player : Player

@export var world_rect : Rect2 = Rect2()

@export_group("View")
@export var follow_player : bool = false
@export var view_range : float = 3000.0
@export var padding : float = 6.0

@export_group("Style")
@export var background_color : Color = Color(0.03, 0.05, 0.08, 0.7)
@export var asteroid_color : Color = Color(0.75, 0.65, 0.55, 0.9)
@export var debris_color : Color = Color(0.45, 0.8, 1.0, 0.85)
@export var depot_color : Color = Color(0.4, 1.0, 0.6, 1.0)
@export var player_color : Color = Color(1.0, 1.0, 1.0, 1.0)
@export var line_px : float = 1.5
@export var depot_px : float = 5.0
@export var player_px : float = 5.0

@export_group("Debris Blobs")
@export var show_debris : bool = true
@export var debris_blob_px : float = 7.0
@export var debris_cell_px : float = 3.0
@export_range(0.05, 0.95, 0.05) var debris_threshold : float = 0.35
@export var debris_refresh : float = 0.05
@export var debris_smoothing : float = 14.0
@export var debris_scan_per_frame : int = 4000

var _scale : float = 1.0
var _origin : Vector2 = Vector2.ZERO
var _debris_field : DebrisField
var _target_timer : float = 0.0
var _sleep_pos := PackedVector2Array()
var _sleep_idx := PackedInt32Array()
var _pend_pos := PackedVector2Array()
var _pend_idx := PackedInt32Array()
var _scan_cursor : int = 0
var _scan_view := Rect2()
var _gx0 : int = 0
var _gy0 : int = 0
var _gw : int = 0
var _gh : int = 0
var _cw : float = 0.0
var _target := PackedFloat32Array()
var _display := PackedFloat32Array()

#region Lifecycle

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_world_bounds(rect : Rect2) -> void:
	world_rect = rect

func _process(delta : float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("Player") as Player
	_update_view()
	if show_debris and _find_field():
		_scan_sleeping()
		_target_timer += delta
		if _target_timer >= debris_refresh or _display.is_empty():
			_target_timer = 0.0
			_rebuild_target()
		var k := 1.0 - exp(-delta * debris_smoothing)
		for i in _display.size():
			_display[i] += (_target[i] - _display[i]) * k
	queue_redraw()

func _find_field() -> bool:
	if not is_instance_valid(_debris_field):
		_debris_field = get_tree().get_first_node_in_group("DebrisField") as DebrisField
	return _debris_field != null

#endregion

#region View

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

func _to_world(map : Vector2) -> Vector2:
	return (map - size * 0.5) / _scale + _origin

func _view_world() -> Rect2:
	return Rect2(_to_world(Vector2.ZERO), size / _scale)

#endregion

#region Debris Field

func _scan_sleeping() -> void:
	var states = _debris_field.get_states()
	var positions = _debris_field.get_positions()
	var n = states.size()
	if _scan_cursor == 0:
		var v := _view_world()
		_scan_view = v.grow(maxf(v.size.x, v.size.y) * 0.5)
	var end := mini(_scan_cursor + debris_scan_per_frame, n)
	var xf := _debris_field.global_transform
	for i in range(_scan_cursor, end):
		if states[i] == STATE_SLEEPING:
			var p : Vector2 = xf * positions[i]
			if _scan_view.has_point(p):
				_pend_pos.append(p)
				_pend_idx.append(i)
	_scan_cursor = end
	if end >= n:
		_sleep_pos = _pend_pos
		_sleep_idx = _pend_idx
		_pend_pos = PackedVector2Array()
		_pend_idx = PackedInt32Array()
		_scan_cursor = 0

func _rebuild_target() -> void:
	var cell := debris_cell_px
	var rc := debris_blob_px / cell
	var cw := cell / _scale
	var view := _view_world()
	var m := ceili(maxf(size.x, size.y) * 0.25 / cell) + ceili(rc) + 1
	var ngx := floori(view.position.x / cw) - m
	var ngy := floori(view.position.y / cw) - m
	var ngw := ceili(size.x / cell) + m * 2 + 1
	var ngh := ceili(size.y / cell) + m * 2 + 1
	var reset := _display.is_empty() or ngw != _gw or ngh != _gh or absf(cw - _cw) > 0.000001
	if reset:
		_gw = ngw
		_gh = ngh
		_cw = cw
		_gx0 = ngx
		_gy0 = ngy
		_display.resize(_gw * _gh)
		_target.resize(_gw * _gh)
	elif ngx != _gx0 or ngy != _gy0:
		var dx := ngx - _gx0
		var dy := ngy - _gy0
		var nd := PackedFloat32Array()
		nd.resize(_gw * _gh)
		var i0 := maxi(0, -dx)
		var i1 := mini(_gw, _gw - dx)
		for j in _gh:
			var oj := j + dy
			if oj < 0 or oj >= _gh:
				continue
			for i in range(i0, i1):
				nd[j * _gw + i] = _display[oj * _gw + i + dx]
		_display = nd
		_gx0 = ngx
		_gy0 = ngy
	_target.fill(0.0)
	var r2 := rc * rc
	var states = _debris_field.get_states()
	for k in _sleep_idx.size():
		if states[_sleep_idx[k]] == STATE_SLEEPING:
			_splat(_sleep_pos[k], rc, r2)
	for node in _debris_field.get_active_nodes():
		if node.anchor == null:
			_splat(node.global_position, rc, r2)
	if reset:
		_display = _target.duplicate()

func _splat(p : Vector2, rc : float, r2 : float) -> void:
	var fx := p.x / _cw - _gx0
	var fy := p.y / _cw - _gy0
	var i0 := maxi(ceili(fx - rc), 0)
	var i1 := mini(floori(fx + rc), _gw - 1)
	var j0 := maxi(ceili(fy - rc), 0)
	var j1 := mini(floori(fy + rc), _gh - 1)
	for j in range(j0, j1 + 1):
		var dy := j - fy
		var row := j * _gw
		for i in range(i0, i1 + 1):
			var dx := i - fx
			var d2 := dx * dx + dy * dy
			if d2 < r2:
				var w := 1.0 - d2 / r2
				_target[row + i] += w * w

func _contour_lines() -> PackedVector2Array:
	var lines := PackedVector2Array()
	if _display.is_empty():
		return lines
	var thr := debris_threshold
	var o := _to_map(Vector2(_gx0, _gy0) * _cw)
	for j in _gh - 1:
		for i in _gw - 1:
			var a := _display[j * _gw + i]
			var b := _display[j * _gw + i + 1]
			var c := _display[(j + 1) * _gw + i + 1]
			var d := _display[(j + 1) * _gw + i]
			var id := int(a > thr) | (int(b > thr) << 1) | (int(c > thr) << 2) | (int(d > thr) << 3)
			if id == 0 or id == 15:
				continue
			var pairs : Array = EDGE_PAIRS[id]
			for k in pairs.size():
				lines.append(_edge(o, i, j, pairs[k], a, b, c, d, thr))
	return lines

func _edge(o : Vector2, i : int, j : int, e : int, a : float, b : float, c : float, d : float, thr : float) -> Vector2:
	var p0 := Vector2(i, j)
	var p1 := Vector2(i + 1, j)
	var v0 := a
	var v1 := b
	match e:
		1:
			p0 = Vector2(i + 1, j)
			p1 = Vector2(i + 1, j + 1)
			v0 = b
			v1 = c
		2:
			p0 = Vector2(i, j + 1)
			p1 = Vector2(i + 1, j + 1)
			v0 = d
			v1 = c
		3:
			p1 = Vector2(i, j + 1)
			v1 = d
	var t := clampf((thr - v0) / (v1 - v0), 0.0, 1.0) if v1 != v0 else 0.5
	return o + p0.lerp(p1, t) * debris_cell_px

#endregion

#region Drawing

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)

	if world_rect.size.x > 0.0 and world_rect.size.y > 0.0:
		var r := world_rect
		var border := PackedVector2Array([
			_to_map(r.position), _to_map(Vector2(r.end.x, r.position.y)),
			_to_map(r.end), _to_map(Vector2(r.position.x, r.end.y)),
			_to_map(r.position)])
		draw_polyline(border, asteroid_color.darkened(0.4), line_px)

	if show_debris:
		var lines := _contour_lines()
		if not lines.is_empty():
			draw_multiline(lines, debris_color, line_px)

	var view := Rect2(Vector2.ZERO, size).grow(32.0)
	for a in get_tree().get_nodes_in_group("Asteroid"):
		var rock := a as AsteroidObject
		if rock == null:
			continue
		var centre := _to_map(rock.global_position)
		var reach := rock.radius * _scale
		if not view.grow(reach).has_point(centre):
			continue
		var poly = AsteroidShapes.variant(rock.size, rock.variant).poly
		var xf := rock.global_transform
		var pts := PackedVector2Array()
		pts.resize(poly.size() + 1)
		for i in poly.size():
			pts[i] = _to_map(xf * poly[i])
		pts[poly.size()] = pts[0]
		draw_polyline(pts, asteroid_color, line_px)

	for d in get_tree().get_nodes_in_group("Depot"):
		if d is Node2D:
			draw_arc(_to_map(d.global_position), depot_px, 0.0, TAU, 20, depot_color, line_px * 1.5)

	if is_instance_valid(player):
		var s := player_px
		var shape := PackedVector2Array([
			Vector2(0, -s), Vector2(s * 0.7, s * 0.7), Vector2(0, s * 0.3), Vector2(-s * 0.7, s * 0.7)])
		var pxf := Transform2D(player.global_rotation, _to_map(player.global_position))
		for i in shape.size():
			shape[i] = pxf * shape[i]
		draw_colored_polygon(shape, player_color)

#endregion
