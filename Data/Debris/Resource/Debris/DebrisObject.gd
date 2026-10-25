extends Area2D
class_name DebrisObject

signal delivered
signal quantum_expired

@export var fx_pickup : FXEmitter
@export var quantum_container : Node2D
@export var quantum_particle_scene : PackedScene
@export var sprite : Sprite2D
@export var blast_damping : float = 2.5   # higher = the shove fades faster
@export var quantum_tint : Color = Color(0.55, 0.9, 1.0)
@export var flash_rate_start : float = 3.0
@export var flash_rate_end : float = 18.0
@export var teleport_min : float = 500.0
@export var teleport_max : float = 900.0
@export var rope_slack : float = 1.08
@export var rope_stiffness : float = 0.12
@export var rope_damping : float = 4.0
@export var rope_max_pull_speed : float = 600.0
@export var rope_pull_accel : float = 1500.0
@export_range(0.0, 0.5, 0.01) var rope_length_variation : float = 0.2   # ±20%
@export var asteroid_margin : float = 16.0   # roughly the debris half-size

const SPEED_EASE_RATE := 2.0
const MIN_HEADING_SPEED := 0.001
const BLAST_CUTOFF_SQUARED := 1.0
const BLAST_TUMBLE := 4.0
const TURN_JITTER := 1.0
const SHADE_RANGE := Vector2(0.9, 1.1)
const LIGHT_PULSE_RANGE := Vector2(0.4, 1.4)
const LIGHT_INTENSITY_RANGE := Vector2(0.8, 1.4)
const LIGHT_TINT_RANGE := Vector2(-0.15, 0.15)
const LIGHT_HEIGHT := 0.5

var data : Debris
var anchor : Node2D
var rope : Line2D
var base_color := Color.WHITE
var drift_velocity : Vector2
var spin : float
var world_rect : Rect2
var home : Vector2
var leash : float = 0.0
var speed_scale : float = 1.0
var blast_velocity := Vector2.ZERO
var field_idx : int = -1
var field_slot : int = -1
var runtime_tags : Array[String] = []
var is_quantum : bool = false
var quantum_caught : bool = false

var rope_system : DebrisRope
var quantum_system : DebrisQuantum
var _rope_len := 80.0
var _rig : LightRig
var _asteroids : AsteroidField
var _min_speed := 0.0
var _max_speed := 0.0
var _bounded := false
var _world_min := Vector2.ZERO
var _world_max := Vector2.ZERO


func _init() -> void:
	rope_system = DebrisRope.new(self)
	quantum_system = DebrisQuantum.new(self)
	quantum_system.expired.connect(_on_quantum_expired)

# Prepares a (possibly recycled) node for a new debris definition and world.
func setup(debris : Debris, home_pos : Vector2 = Vector2.ZERO, leash_radius : float = 0.0, bounds : Rect2 = Rect2()) -> void:
	data = debris
	home = home_pos
	leash = leash_radius
	quantum_system.reset()
	_bounded = bounds.has_area()
	if _bounded:
		world_rect = bounds
		_world_min = bounds.position
		_world_max = bounds.end
	speed_scale = DataCollector.get_chaos_scale()
	_min_speed = data.drift_speed_min * speed_scale
	_max_speed = data.drift_speed_max * speed_scale
	drift_velocity = _random_heading() * randf_range(data.drift_speed_min, data.drift_speed_max)
	spin = randf_range(-data.drift_spin_max, data.drift_spin_max)
	blast_velocity = Vector2.ZERO   # recycled nodes shouldn't inherit an old shove
	_rope_len = data.rope_length * randf_range(1.0 - rope_length_variation, 1.0 + rope_length_variation)
	_rig = _rig if _rig else get_node_or_null("LightRig") as LightRig
	_apply_rig()
	_apply_shape()

func _ready() -> void:
	if data == null:
		push_error("DebrisObject: setup() was not called with a Debris resource")
		set_physics_process(false)
		return
	add_to_group("Debris")
	body_entered.connect(_on_body_entered)
	if _rig == null:
		_rig = LightRig.new()
		_apply_rig()
		add_child(_rig)
	_asteroids = get_tree().get_first_node_in_group("AsteroidField") as AsteroidField

func _random_heading() -> Vector2:
	return Vector2.from_angle(randf() * TAU)

# The resource's preset wins; otherwise the rig keeps its own preset.
func _apply_rig() -> void:
	if _rig == null:
		return
	if data.light_preset != null:
		_rig.preset = data.light_preset
	_rig.chance = data.light_chance
	_rig.shadow_cast = data.shadow_cast

func has_tag(tag : String) -> bool:
	return tag in data.data_tags or tag in runtime_tags

func get_weight() -> float:
	return data.stat_weight

func get_value() -> int:
	return roundi(data.stat_value * (data.quantum_multiplier if is_quantum and quantum_caught else 1.0))

func _on_body_entered(body : Node2D) -> void:
	if anchor == null and body.is_in_group("Player"):
		body.attach(self)

func set_quantum(enabled : bool, focus : Node2D) -> void:
	quantum_system.reset()
	if enabled:
		quantum_system.begin(focus)

func quantum_spent() -> bool:
	return quantum_system.is_spent()

# After a quantum expiry the debris jumps opposite to its heading, then listeners are told.
func _on_quantum_expired() -> void:
	var destination := position - drift_velocity.normalized() * randf_range(teleport_min, teleport_max)
	position = destination.clamp(_world_min, _world_max) if _bounded else destination
	quantum_expired.emit()


# ---------------------------------------------------------------- rope
func attach_to(target : Node2D) -> void:
	anchor = target
	set_deferred("monitoring", false)
	rope_system.create(target)
	if is_quantum and not quantum_caught:
		quantum_caught = true
		modulate = quantum_tint

func detach() -> void:
	rope_system.release()
	anchor = null
	set_deferred("monitoring", true)

func detach_to(target : Node2D) -> void:
	rope_system.release()
	attach_to(target)
	delivered.emit()


# ---------------------------------------------------------------- motion
func apply_blast(origin : Vector2, radius : float, force : float) -> void:
	var offset := global_position - origin
	var distance := offset.length()
	if distance > radius:
		return
	var falloff := 1.0 - distance / radius
	var direction := offset / distance if distance > MIN_HEADING_SPEED else _random_heading()
	blast_velocity += direction * force * falloff
	spin += randf_range(-BLAST_TUMBLE, BLAST_TUMBLE) * falloff   # a bit of tumble

func _physics_process(delta : float) -> void:
	drift_velocity = _next_drift_velocity(delta)
	var attach_factor := 1.0 if anchor == null else data.drift_attached_factor
	position += (drift_velocity * attach_factor + _consume_blast(delta)) * delta
	rotation += spin * delta
	if is_quantum:
		quantum_system.tick(delta)
	if anchor:
		rope_system.update(delta)
	if _asteroids:
		_collide_asteroids()
	if _bounded:
		_bounce_off_world()

# Wanders the heading and eases the speed back into the allowed range.
func _next_drift_velocity(delta : float) -> Vector2:
	var turned := drift_velocity.rotated(randf_range(-TURN_JITTER, TURN_JITTER) * data.drift_turn_rate * delta)
	var speed := turned.length()
	if speed < MIN_HEADING_SPEED:
		return _random_heading() * _min_speed
	var eased_speed := lerpf(speed, clampf(speed, _min_speed, _max_speed), minf(SPEED_EASE_RATE * delta, 1.0))
	return turned * eased_speed / speed

# Returns the current shove and damps it; tiny shoves are cut to zero.
func _consume_blast(delta : float) -> Vector2:
	var current_blast := blast_velocity
	var is_active := blast_velocity.length_squared() > BLAST_CUTOFF_SQUARED
	blast_velocity = blast_velocity * maxf(1.0 - blast_damping * delta, 0.0) if is_active else Vector2.ZERO
	return current_blast if is_active else Vector2.ZERO

func _reflect_if_approaching(velocity_value : Vector2, surface_normal : Vector2) -> Vector2:
	return velocity_value.bounce(surface_normal) if velocity_value.dot(surface_normal) < 0.0 else velocity_value

func _collide_asteroids() -> void:
	var shift := _asteroids.push_out(global_position, asteroid_margin)
	if shift == Vector2.ZERO:
		return
	global_position += shift
	drift_velocity = _reflect_if_approaching(drift_velocity, shift.normalized())
	blast_velocity = _reflect_if_approaching(blast_velocity, shift.normalized())

# Points an axis's speed back inward when the debris crossed that edge.
func _point_inward(speed : float, overshoot : float) -> float:
	return absf(speed) * signf(overshoot) if overshoot != 0.0 else speed

func _bounce_off_world() -> void:
	var clamped_position := position.clamp(_world_min, _world_max)
	var overshoot := clamped_position - position
	drift_velocity = Vector2(_point_inward(drift_velocity.x, overshoot.x), _point_inward(drift_velocity.y, overshoot.y))
	position = clamped_position

# Applies a cached procedural shape: texture, collision box, occluder, and a random point light.
func _apply_shape() -> void:
	var shape := DebrisShapes.make(data.tag)
	var outline : PackedVector2Array = shape.poly
	base_color = shape.color
	sprite.texture = shape.tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * DebrisShapes.PX
	var shade := DebrisShapes.random_in(SHADE_RANGE)
	sprite.self_modulate = Color(shade, shade, shade)   # self_modulate so quantum's node modulate still works
	rotation = randf() * TAU
	var collision := $CollisionShape2D as CollisionShape2D
	(collision.shape as RectangleShape2D).size = shape.size
	collision.position = Vector2.ZERO
	var occluder := $LightOccluder2D as LightOccluder2D
	occluder.visible = data.shadow_cast
	if data.shadow_cast:
		occluder.occluder.polygon = outline
	var light := get_node_or_null("SpaceLight3") as PointLight2D
	if light:
		light.visible = randf() < data.light_chance
		light.position = outline[randi() % outline.size()]
		light.color = (shape.light as Color).lightened(DebrisShapes.random_in(LIGHT_TINT_RANGE))
		light.set("pulse_speed", DebrisShapes.random_in(LIGHT_PULSE_RANGE))
		light.set("intensity", DebrisShapes.random_in(LIGHT_INTENSITY_RANGE))
		light.height = LIGHT_HEIGHT