extends Node

@export var max_shadow_lights := 6
@export var cull_margin := 64.0
@export var cull_interval := 0.1
@export var auto_background_layers := true

var ambient_color := Color(0.04, 0.05, 0.09):
	set(v):
		ambient_color = v
		for m in _modulates:
			if is_instance_valid(m):
				m.color = v

var _modulates : Array = []
var _sun: DirectionalLight2D
var _timer := 0.0
var _tween: Tween

func _ready() -> void:
	var m := CanvasModulate.new()
	m.color = ambient_color
	add_child(m)
	_modulates.append(m)
	if auto_background_layers:
		get_tree().node_added.connect(_on_node_added)

func set_ambient(color: Color, duration := 0.0) -> void:
	if _tween:
		_tween.kill()
	if duration <= 0.0:
		ambient_color = color
		return
	_tween = create_tween()
	_tween.tween_property(self, "ambient_color", color, duration)

func light_layer(layer: CanvasLayer) -> void:
	if layer.has_meta(&"lm_lit"):
		return
	layer.set_meta(&"lm_lit", true)
	var m := CanvasModulate.new()
	m.color = ambient_color
	_modulates.append(m)
	layer.add_child.call_deferred(m)

func spawn(preset: LightPreset, pos := Vector2.ZERO, parent: Node = null) -> SpaceLight:
	var light := SpaceLight.new()
	(parent if parent else get_tree().current_scene).add_child(light)
	light.apply_preset(preset)
	if parent:
		light.position = pos
	else:
		light.global_position = pos
	return light

func flash(pos: Vector2, color := Color(1, 0.7, 0.3), radius := 300.0,
		duration := 0.4, energy := 2.5) -> SpaceLight:
	var p := LightPreset.explosion()
	p.color = color; p.radius = radius; p.energy = energy
	p.lifetime = duration; p.fade_out = duration * 0.9
	return spawn(p, pos)

func set_sun(angle_deg: float, color := Color(1, 0.95, 0.8), energy := 0.6,
		shadows := true, shadow_distance := 0.0) -> DirectionalLight2D:
	if not _sun:
		_sun = DirectionalLight2D.new()
		_sun.range_layer_min = -128
		_sun.range_layer_max = 128
		_sun.range_z_min = -4096
		_sun.range_z_max = 4096
		add_child(_sun)
	_sun.rotation_degrees = angle_deg
	_sun.color = color
	_sun.energy = energy
	_sun.shadow_enabled = shadows
	# Occluders farther than this from the camera centre cast no sun shadow.
	_sun.max_distance = shadow_distance if shadow_distance > 0.0 else 10000.0
	return _sun

func remove_sun() -> void:
	if _sun:
		_sun.queue_free()
		_sun = null

func _on_node_added(n: Node) -> void:
	if n is CanvasLayer and (n as CanvasLayer).layer < 0:
		light_layer(n)

func _process(delta: float) -> void:
	_timer += delta
	if _timer < cull_interval:
		return
	_timer = 0.0
	_update_lights()

func _update_lights() -> void:
	var vp := get_viewport()
	var view: Rect2 = vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	var center := view.get_center()
	var shadow_candidates: Array[SpaceLight] = []

	for node in get_tree().get_nodes_in_group(&"space_lights"):
		var l := node as SpaceLight
		if not l:
			continue
		if l.cullable:
			var r := l.radius + cull_margin
			var box := Rect2(l.global_position - Vector2(r, r), Vector2(r, r) * 2.0)
			l.enabled = view.intersects(box)
		else:
			l.enabled = true
		if l.enabled and l.cast_shadows:
			shadow_candidates.append(l)

	# Only the closest N shadow-casters actually render shadows.
	shadow_candidates.sort_custom(func(a: SpaceLight, b: SpaceLight) -> bool:
		return a.global_position.distance_squared_to(center) \
			< b.global_position.distance_squared_to(center))
	for i in shadow_candidates.size():
		shadow_candidates[i].shadow_enabled = i < max_shadow_lights