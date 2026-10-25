extends Area2D
class_name AsteroidObject

enum Size {
	SMALL,
	MEDIUM,
	LARGE
}

signal hit(body : Node2D, point : Vector2, normal : Vector2)
signal destroyed

const DRIFT_SPEED := [Vector2(40.0, 90.0), Vector2(18.0, 45.0), Vector2(6.0, 20.0)]
const SPIN_SCALE := [1.0, 0.5, 0.2]
const HEALTH_MULT := [0.2, 0.5, 1.0]

@export var node_collision : CollisionShape2D
@export var node_sprite : Sprite2D
@export var node_occluder : LightOccluder2D
@export var node_light_rig : LightRig
@export var weight : float
@export var spin_speed : float
@export var size : Size = Size.MEDIUM
@export var hit_particle : PackedScene
@export_range(0.0, 1000.0) var max_health : float
@export var shadow_cast : bool = true
@export var small_casts_shadow : bool = false
@export_group("Bounce")
@export var ship_radius : float = 30.0
@export var hit_cooldown : float = 0.15

var current_health : float
var velocity := Vector2.ZERO
var variant : int = 0
var radius : float = 0.0
var fx_parent : Node

var field_idx : int = -1
var field_slot : int = -1

var _poly := PackedVector2Array()
var _spin : float = 0.0
var _bounded : bool = false
var _wmin := Vector2.ZERO
var _wmax := Vector2.ZERO
var _extra_cols : Array[CollisionShape2D] = []
var _touching : Node2D
var _hit_cd : float = 0.0

func _ready() -> void:
	add_to_group("Asteroid")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func setup(p_size : int, p_variant : int, bounds : Rect2 = Rect2()) -> void:
	size = p_size as Size
	variant = p_variant
	var v := AsteroidShapes.variant(size, variant)

	_poly = v.poly
	radius = v.radius

	node_sprite.texture = v.tex
	node_sprite.offset = v.tex_offset
	node_sprite.scale = Vector2(AsteroidShapes.TEXEL, AsteroidShapes.TEXEL)
	node_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_apply_collision(v.shapes)

	if node_occluder:
		var cast := shadow_cast and (size != Size.SMALL or small_casts_shadow)
		node_occluder.visible = cast
		if cast:
			node_occluder.occluder = v.occluder

	current_health = max_health * HEALTH_MULT[size]
	_spin = randf_range(-1.0, 1.0) * spin_speed * SPIN_SCALE[size]
	velocity = Vector2.ZERO
	_touching = null

	_bounded = bounds.has_area()
	if _bounded:
		var pad := Vector2(radius, radius)
		_wmin = bounds.position + pad
		_wmax = (bounds.end - pad).max(_wmin)

func _apply_collision(shapes : Array) -> void:
	node_collision.shape = shapes[0]
	node_collision.disabled = false
	for i in range(1, shapes.size()):
		var cs : CollisionShape2D
		if i - 1 < _extra_cols.size():
			cs = _extra_cols[i - 1]
		else:
			cs = CollisionShape2D.new()
			add_child(cs)
			_extra_cols.append(cs)
		cs.shape = shapes[i]
		cs.disabled = false
	for i in range(shapes.size() - 1, _extra_cols.size()):
		_extra_cols[i].disabled = true

func _physics_process(delta : float) -> void:
	position += velocity * delta
	rotation += _spin * delta
	if _bounded:
		_bounce_off_world()
	_hit_cd = maxf(_hit_cd - delta, 0.0)
	if _touching != null:
		_resolve_player()

func clear_contacts() -> void:
	_touching = null

func get_weight() -> float:
	return weight

func take_damage(amount : float, point : Vector2) -> void:
	if current_health <= 0.0:
		return
	current_health -= amount
	_spawn_hit_fx(point)
	if current_health <= 0.0:
		destroyed.emit()


func surface_point(world_pos : Vector2) -> Vector2:
	var lp := to_local(world_pos)
	var best := Vector2.ZERO
	var best_d := INF
	var n := _poly.size()
	for i in n:
		var q := Geometry2D.get_closest_point_to_segment(lp, _poly[i], _poly[(i + 1) % n])
		var d := lp.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best = q
	return to_global(best)


## Returns the shift that moves world_pos out of the rock plus `margin`, or ZERO.
func push_out(world_pos : Vector2, margin : float) -> Vector2:
	var pt := surface_point(world_pos)
	var inside := Geometry2D.is_point_in_polygon(to_local(world_pos), _poly)
	var d := world_pos.distance_to(pt)
	if not inside and d >= margin:
		return Vector2.ZERO
	var n : Vector2   # points out of the rock
	if d > 0.001:
		n = ((pt - world_pos) if inside else (world_pos - pt)) / d
	else:
		n = (world_pos - global_position).normalized()
	return pt + n * margin - world_pos


func _bounce_off_world() -> void:
	var p := position
	if p.x >= _wmin.x and p.x <= _wmax.x and p.y >= _wmin.y and p.y <= _wmax.y:
		return
	if p.x < _wmin.x:
		p.x = _wmin.x
		velocity.x = absf(velocity.x)
	elif p.x > _wmax.x:
		p.x = _wmax.x
		velocity.x = -absf(velocity.x)
	if p.y < _wmin.y:
		p.y = _wmin.y
		velocity.y = absf(velocity.y)
	elif p.y > _wmax.y:
		p.y = _wmax.y
		velocity.y = -absf(velocity.y)
	position = p


func _on_body_entered(body : Node2D) -> void:
	if body.is_in_group("Player"):
		_touching = body


func _on_body_exited(body : Node2D) -> void:
	if body == _touching:
		_touching = null


func _resolve_player() -> void:
	var bp := _touching.global_position
	var pt := surface_point(bp)
	var inside := Geometry2D.is_point_in_polygon(to_local(bp), _poly)
	var d := bp.distance_to(pt)
	if not inside and d >= ship_radius:
		return

	var normal : Vector2
	if d > 0.001:
		normal = ((pt - bp) if inside else (bp - pt)) / d
	else:
		normal = (bp - global_position).normalized()

	var bounced : bool = _touching.bounce_off(normal, pt + normal * ship_radius, velocity)
	if bounced and _hit_cd <= 0.0:
		_hit_cd = hit_cooldown
		_spawn_hit_fx(pt)
		hit.emit(_touching, pt, normal)


func _spawn_hit_fx(point : Vector2) -> void:
	if hit_particle == null:
		return
	var parent : Node = fx_parent if is_instance_valid(fx_parent) else get_parent()
	if parent == null:
		return
	var fx := hit_particle.instantiate() as FXEmitter
	fx.finished.connect(fx.queue_free)
	parent.add_child(fx)
	fx.global_position = point
	fx.play()