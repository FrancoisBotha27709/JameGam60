class_name LightRig
extends Node

@export var preset : LightPreset
@export var engine_preset : LightPreset
## Chance that `preset` lights spawn (engine lights always spawn).
@export_range(0.0, 1.0, 0.01) var chance := 1.0
## Off = removes all occluders under the parent.
@export var shadow_cast := true

@export_group("Engine")
@export var boost_color := Color(0.5, 0.8, 1.0)
@export var boost_radius_mult := 1.4
@export var boost_intensity_mult := 1.5
## Radius multiplier when throttle is almost 0 (grows to 1.0 at full throttle).
@export_range(0.0, 1.0, 0.01) var idle_radius_mult := 0.5

var lights : Array[SpaceLight] = []
var engine_lights : Array[SpaceLight] = []

var _base := {}   # SpaceLight -> { color, intensity, radius }
var _built := false
var _boosting := false
var _tint := Color.WHITE
var _tint_amt := 0.0

func _ready() -> void:
	build()

func build() -> void:
	if _built:
		return
	_built = true
	var root := get_parent()
	if root == null:
		return
	_build_shadows(root)
	if randf() <= chance:
		_spawn_lights(root, "light_marker_*", preset, lights)
	_spawn_lights(root, "engine_marker_*", engine_preset, engine_lights)

func set_engine(level: float, boosting := false) -> void:
	_boosting = boosting
	for l in engine_lights:
		if not is_instance_valid(l):
			continue
		var b : Dictionary = _base[l]
		l.visible = level > 0.02
		if not l.visible:
			continue
		var boost_i := boost_intensity_mult if boosting else 1.0
		var boost_r := boost_radius_mult if boosting else 1.0
		l.intensity = b.intensity * level * boost_i
		var r : float = b.radius * lerpf(idle_radius_mult, 1.0, level) * boost_r
		if absf(l.radius - r) > 1.0:
			l.radius = r
		l.color = _final_color(l, boosting)

func set_tint(c: Color, amount: float) -> void:
	_tint = c
	_tint_amt = clampf(amount, 0.0, 1.0)
	for l in lights:
		if is_instance_valid(l):
			l.color = _final_color(l, false)
	for l in engine_lights:
		if is_instance_valid(l):
			l.color = _final_color(l, _boosting)

func set_lights_visible(on: bool) -> void:
	for l in lights + engine_lights:
		if is_instance_valid(l):
			l.visible = on

func _final_color(l: SpaceLight, boosted: bool) -> Color:
	var col : Color = _base[l].color
	if boosted:
		col = col.lerp(boost_color, 0.6)
	return col.lerp(_tint, _tint_amt)

func _spawn_lights(root: Node, pattern: String, p: LightPreset, out: Array[SpaceLight]) -> void:
	if p == null:
		return
	for marker in root.find_children(pattern, "Marker2D", true, false):
		if not (marker as Marker2D).visible:
			continue   # lets inherited scenes switch a marker off (they can't delete it)
		var l := LightManager.spawn(p, Vector2.ZERO, marker)
		l.cast_shadows = false   # the light sits inside its own object
		if marker.has_meta("color"):     l.color = marker.get_meta("color")
		if marker.has_meta("radius"):    l.radius = marker.get_meta("radius")
		if marker.has_meta("intensity"): l.intensity = marker.get_meta("intensity")
		_base[l] = {"color": l.color, "intensity": l.intensity, "radius": l.radius}
		out.append(l)

func _build_shadows(root: Node) -> void:
	if not shadow_cast:
		for o in root.find_children("*", "LightOccluder2D", true, false):
			o.queue_free()
		return
	for n in root.find_children("shadow_polygon*", "Polygon2D", true, false):
		var poly := n as Polygon2D
		var pts := poly.polygon
		if poly.offset != Vector2.ZERO:
			for i in pts.size():
				pts[i] += poly.offset
		var occ := LightOccluder2D.new()
		occ.occluder = OccluderPolygon2D.new()
		occ.occluder.polygon = pts
		occ.transform = poly.transform
		poly.get_parent().add_child(occ)
		poly.visible = false