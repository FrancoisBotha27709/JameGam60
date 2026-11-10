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
const PLAYER_DAMAGE_SCALE := [0.6, 1.0, 1.6]
const MIN_RELATIVE_SPEED := 0.001
const MIN_NORMAL_LENGTH := 0.001
const DAMAGED_TINT := Color(1.0, 0.55, 0.45)

@export var node_collision : CollisionShape2D
@export var node_sprite : Sprite2D
@export var node_occluder : LightOccluder2D
@export var node_light_rig : LightRig
@export var weight : float
@export var spin_speed : float
@export var size : Size = Size.MEDIUM
@export var hit_particle : PackedScene
@export_range(0.0, 1000.0) var max_health : float = 150.0
@export var shadow_cast : bool = true
@export var small_casts_shadow : bool = false
@export_group("Bounce")
@export var ship_radius : float = 30.0
@export var hit_cooldown : float = 0.15
@export_group("Ramming")
@export var ram_damage : float = 60.0
@export var ram_speed_reference : float = 400.0
@export var ram_max_speed_factor : float = 2.5

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
var _is_dead : bool = false

func _ready() -> void:
	add_to_group("Asteroid")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func setup(p_size : int, p_variant : int, bounds : Rect2 = Rect2()) -> void:
	size = p_size as Size
	variant = p_variant
	var shape_data := AsteroidShapes.variant(size, variant)

	_poly = shape_data.poly
	radius = shape_data.radius

	node_sprite.texture = shape_data.tex
	node_sprite.offset = shape_data.tex_offset
	node_sprite.scale = Vector2(AsteroidShapes.TEXEL, AsteroidShapes.TEXEL)
	node_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node_sprite.self_modulate = Color.WHITE

	_apply_collision(shape_data.shapes)

	if node_occluder:
		var cast := shadow_cast and (size != Size.SMALL or small_casts_shadow)
		node_occluder.visible = cast
		if cast:
			node_occluder.occluder = shape_data.occluder

	current_health = health_capacity()
	_is_dead = false
	_spin = randf_range(-1.0, 1.0) * spin_speed * SPIN_SCALE[size]
	velocity = Vector2.ZERO
	_touching = null

	_bounded = bounds.has_area()
	if _bounded:
		var pad := Vector2(radius, radius)
		_wmin = bounds.position + pad
		_wmax = (bounds.end - pad).max(_wmin)

func health_capacity() -> float:
	return max_health * HEALTH_MULT[size]

func _apply_collision(shapes : Array) -> void:
	node_collision.shape = shapes[0]
	node_collision.disabled = false
	for i in range(1, shapes.size()):
		var extra_collision : CollisionShape2D
		if i - 1 < _extra_cols.size():
			extra_collision = _extra_cols[i - 1]
		else:
			extra_collision = CollisionShape2D.new()
			add_child(extra_collision)
			_extra_cols.append(extra_collision)
		extra_collision.shape = shapes[i]
		extra_collision.disabled = false
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
	if _is_dead or amount <= 0.0:
		return
	current_health -= amount
	_spawn_hit_fx(point)
	var capacity := health_capacity()
	node_sprite.self_modulate = Color.WHITE.lerp(DAMAGED_TINT, 1.0 - clampf(current_health / maxf(capacity, MIN_RELATIVE_SPEED), 0.0, 1.0))
	if current_health <= 0.0:
		_is_dead = true
		destroyed.emit()

func surface_point(world_pos : Vector2) -> Vector2:
	var local_point := to_local(world_pos)
	var best := Vector2.ZERO
	var best_distance := INF
	var point_count := _poly.size()
	for i in point_count:
		var closest := Geometry2D.get_closest_point_to_segment(local_point, _poly[i], _poly[(i + 1) % point_count])
		var distance := local_point.distance_squared_to(closest)
		if distance < best_distance:
			best_distance = distance
			best = closest
	return to_global(best)

func push_out(world_pos : Vector2, margin : float) -> Vector2:
	var surface := surface_point(world_pos)
	var inside := Geometry2D.is_point_in_polygon(to_local(world_pos), _poly)
	var distance := world_pos.distance_to(surface)
	if not inside and distance >= margin:
		return Vector2.ZERO
	var outward : Vector2
	if distance > MIN_NORMAL_LENGTH:
		outward = ((surface - world_pos) if inside else (world_pos - surface)) / distance
	else:
		outward = (world_pos - global_position).normalized()
	return surface + outward * margin - world_pos

func _bounce_off_world() -> void:
	var clamped := position
	if clamped.x >= _wmin.x and clamped.x <= _wmax.x and clamped.y >= _wmin.y and clamped.y <= _wmax.y:
		return
	if clamped.x < _wmin.x:
		clamped.x = _wmin.x
		velocity.x = absf(velocity.x)
	elif clamped.x > _wmax.x:
		clamped.x = _wmax.x
		velocity.x = -absf(velocity.x)
	if clamped.y < _wmin.y:
		clamped.y = _wmin.y
		velocity.y = absf(velocity.y)
	elif clamped.y > _wmax.y:
		clamped.y = _wmax.y
		velocity.y = -absf(velocity.y)
	position = clamped

func _on_body_entered(body : Node2D) -> void:
	if body.is_in_group("Player"):
		_touching = body

func _on_body_exited(body : Node2D) -> void:
	if body == _touching:
		_touching = null

func _resolve_player() -> void:
	var body_position := _touching.global_position
	var surface := surface_point(body_position)
	var inside := Geometry2D.is_point_in_polygon(to_local(body_position), _poly)
	var distance := body_position.distance_to(surface)
	if not inside and distance >= ship_radius:
		return

	var normal : Vector2
	if distance > MIN_NORMAL_LENGTH:
		normal = ((surface - body_position) if inside else (body_position - surface)) / distance
	else:
		normal = (body_position - global_position).normalized()

	var relative_velocity : Vector2 = _touching.velocity - velocity
	var approach_speed := -relative_velocity.dot(normal)
	var directness := clampf(approach_speed / maxf(relative_velocity.length(), MIN_RELATIVE_SPEED), 0.0, 1.0)
	var ram_multiplier : float = _touching.get_ram_multiplier()

	var bounced : bool = _touching.bounce_off(normal, surface + normal * ship_radius, velocity, PLAYER_DAMAGE_SCALE[size])
	if bounced and _hit_cd <= 0.0:
		_hit_cd = hit_cooldown
		_spawn_hit_fx(surface)
		hit.emit(_touching, surface, normal)
		var speed_factor := clampf(approach_speed / ram_speed_reference, 0.0, ram_max_speed_factor)
		take_damage(ram_damage * speed_factor * directness * ram_multiplier, surface)

func random_point_inside() -> Vector2:
	for attempt in 64:
		var local_point := Vector2(
			randf_range(-radius, radius),
			randf_range(-radius, radius)
		)
		if Geometry2D.is_point_in_polygon(local_point, _poly):
			return to_global(local_point)

	return global_position

func _spawn_hit_fx(point : Vector2) -> void:
	if hit_particle == null:
		return
	var parent : Node = fx_parent if is_instance_valid(fx_parent) else get_parent()
	if parent == null:
		return
	var effect := hit_particle.instantiate() as FXEmitter
	effect.finished.connect(effect.queue_free)
	parent.add_child(effect)
	effect.global_position = point
	effect.play()