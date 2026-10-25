extends Area2D
class_name DebrisObject

signal delivered
signal quantum_expired

@export var fx_pickup : FXEmitter
@export var quantum_container : Node2D
@export var quantum_particle_scene : PackedScene
@export var blast_damping : float = 2.5   # higher = the shove fades faster
@export var quantum_tint : Color = Color(0.55, 0.9, 1.0)
@export var flash_rate_start : float = 3.0
@export var flash_rate_end : float = 18.0
@export var teleport_min : float = 500.0
@export var teleport_max : float = 900.0
@export var sprite : Sprite2D
var _base_color := Color.WHITE

const ROPE_PTS := 9
@export var rope_slack : float = 1.08
@export var rope_stiffness : float = 0.12
@export var rope_damping : float = 4.0
@export var rope_max_pull_speed : float = 600.0
@export var rope_pull_accel : float = 1500.0
var _pull_speed := 0.0
@export_range(0.0, 0.5, 0.01) var rope_length_variation : float = 0.2   # ±20%
var _rope_len := 80.0
@export var asteroid_margin : float = 16.0   # roughly the debris half-size
var _asteroids : AsteroidField
var _rp := PackedVector2Array()
var _rpp := PackedVector2Array()

var data : Debris
var anchor : Node2D
var rope : Line2D
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

var _q_focus : Node2D
var _q_time_left : float = 0.0
var _q_armed : bool = false
var _q_phase : float = 0.0
var _q_radius_sq : float = 0.0

var _min_speed : float = 0.0
var _max_speed : float = 0.0
var _turn : float = 0.0
var _attached_factor : float = 1.0
var _bounded : bool = false
var _wmin := Vector2.ZERO
var _wmax := Vector2.ZERO

func setup(debris : Debris, home_pos : Vector2 = Vector2.ZERO, leash_radius : float = 0.0, bounds : Rect2 = Rect2()) -> void:
	data = debris
	home = home_pos
	leash = leash_radius
	_clear_quantum()

	_bounded = bounds.has_area()
	if _bounded:
		world_rect = bounds
		_wmin = bounds.position
		_wmax = bounds.end

	speed_scale = DataCollector.get_chaos_scale()
	_min_speed = data.drift_speed_min * speed_scale
	_max_speed = data.drift_speed_max * speed_scale
	_turn = data.drift_turn_rate
	_attached_factor = data.drift_attached_factor

	drift_velocity = Vector2.from_angle(randf() * TAU) * randf_range(data.drift_speed_min, data.drift_speed_max)
	spin = randf_range(-data.drift_spin_max, data.drift_spin_max)
	blast_velocity = Vector2.ZERO   # recycled nodes shouldn't inherit an old shove
	_rope_len = data.rope_length * randf_range(1.0 - rope_length_variation, 1.0 + rope_length_variation)
	var rig := get_node_or_null("LightRig") as LightRig
	if rig:
		if data.light_preset != null:
			rig.preset = data.light_preset   # resource wins; else the rig's own preset is the fallback
		rig.chance = data.light_chance
		rig.shadow_cast = data.shadow_cast
	_apply_shape()

func _ready() -> void:
	if data == null:
		push_error("DebrisObject: setup() was not called with a Debris resource")
		set_physics_process(false)
		return
	add_to_group("Debris")
	body_entered.connect(_on_body_entered)
	var rig := LightRig.new()
	rig.preset = data.light_preset
	rig.chance = data.light_chance
	rig.shadow_cast = data.shadow_cast
	add_child(rig)
	_asteroids = get_tree().get_first_node_in_group("AsteroidField") as AsteroidField

func has_tag(tag : String) -> bool:
	return tag in data.data_tags or tag in runtime_tags

func get_weight() -> float:
	return data.stat_weight

func get_value() -> int:
	var v := float(data.stat_value)
	if is_quantum and quantum_caught:
		v *= data.quantum_multiplier
	return roundi(v)

func set_quantum(on : bool, focus : Node2D) -> void:
	_clear_quantum()
	if not on:
		return
	is_quantum = true
	runtime_tags.append("quantum")
	_q_focus = focus
	_q_time_left = data.quantum_lifetime
	_q_radius_sq = data.quantum_trigger_radius * data.quantum_trigger_radius
	modulate = quantum_tint
	for i in 4:
		var fx := quantum_particle_scene.instantiate() as FXEmitter
		fx.finished.connect(fx.queue_free)
		quantum_container.add_child(fx)

func _clear_quantum() -> void:
	is_quantum = false
	quantum_caught = false
	_q_armed = false
	_q_phase = 0.0
	_q_focus = null
	runtime_tags.erase("quantum")
	modulate = Color.WHITE
	if quantum_container:
		quantum_container.top_level = false
		quantum_container.position = Vector2.ZERO
		for c in quantum_container.get_children():
			c.queue_free()

func quantum_spent() -> bool:
	return is_quantum and (quantum_caught or _q_armed)

func _quantum_tick(delta : float) -> void:
	if quantum_caught:
		return
	if not _q_armed:
		if not is_instance_valid(_q_focus):
			return
		if global_position.distance_squared_to(_q_focus.global_position) > _q_radius_sq:
			return
		_q_armed = true

	_q_time_left -= delta
	if _q_time_left <= 0.0:
		_expire_quantum()
		return

	var t := 1.0 - _q_time_left / data.quantum_lifetime
	_q_phase += TAU * lerpf(flash_rate_start, flash_rate_end, t) * delta
	var a := 0.5 + 0.5 * sin(_q_phase)
	modulate = Color(quantum_tint.r, quantum_tint.g, quantum_tint.b, lerpf(0.15, 1.0, a))

func _expire_quantum() -> void:
	is_quantum = false   # double expire guard
	runtime_tags.erase("quantum")
	modulate = Color.WHITE

	# burst stays where it expired
	quantum_container.top_level = true
	quantum_container.global_position = global_position
	for c in quantum_container.get_children():
		(c as FXEmitter).play()

	# jump opposite to the heading
	var p := position - drift_velocity.normalized() * randf_range(teleport_min, teleport_max)
	position = p.clamp(_wmin, _wmax) if _bounded else p
	quantum_expired.emit()

func _on_body_entered(body : Node2D) -> void:
	if anchor == null and body.is_in_group("Player"):
		body.attach(self)

func attach_to(target : Node2D) -> void:
	anchor = target
	set_deferred("monitoring", false)

	rope = Line2D.new()
	rope.top_level = true
	rope.width = data.rope_width
	rope.joint_mode = Line2D.LINE_JOINT_ROUND
	rope.begin_cap_mode = Line2D.LINE_CAP_ROUND
	rope.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	_rp.resize(ROPE_PTS)
	for i in ROPE_PTS:
		_rp[i] = global_position.lerp(target.global_position, float(i) / (ROPE_PTS - 1))
	_rpp = _rp.duplicate()
	_pull_speed = 0.0
	rope.points = _rp
	add_child(rope)
	if is_quantum and not quantum_caught:
		quantum_caught = true
		modulate = quantum_tint

	var base := _base_color
	var hs := randf_range(-0.04, 0.04)
	var c0 := base.darkened(randf_range(0.3, 0.5))
	var c1 := base.lightened(randf_range(0.3, 0.5))
	c0.a = 0.45
	c0.h = fposmod(c0.h + hs, 1.0)
	c1.h = fposmod(c1.h + hs, 1.0)
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	rope.gradient = g

func _free_rope() -> void:
	if rope != null:
		rope.queue_free()
		rope = null

func detach() -> void:
	_free_rope()
	anchor = null
	set_deferred("monitoring", true)

func detach_to(target : Node2D) -> void:
	_free_rope()
	attach_to(target)
	delivered.emit()

func apply_blast(origin : Vector2, radius : float, force : float) -> void:
	var offset := global_position - origin
	var dist := offset.length()
	if dist > radius:
		return
	var dir := offset / dist if dist > 0.001 else Vector2.from_angle(randf() * TAU)
	var falloff := 1.0 - dist / radius
	blast_velocity += dir * force * falloff
	spin += randf_range(-4.0, 4.0) * falloff   # a bit of tumble

func _physics_process(delta : float) -> void:
	var v := drift_velocity.rotated(randf_range(-1.0, 1.0) * _turn * delta)
	var speed := v.length()
	if speed < 0.001:
		v = Vector2.from_angle(randf() * TAU) * _min_speed
	else:
		var target := clampf(speed, _min_speed, _max_speed)
		v *= lerpf(speed, target, minf(2.0 * delta, 1.0)) / speed
	drift_velocity = v

	var step := v if anchor == null else v * _attached_factor
	if blast_velocity.length_squared() > 1.0:
		step += blast_velocity
		blast_velocity *= maxf(1.0 - blast_damping * delta, 0.0)
	else:
		blast_velocity = Vector2.ZERO
	position += step * delta
	rotation += spin * delta

	if is_quantum:
		_quantum_tick(delta)
	if anchor != null:
		_pull_rope(delta)
	if _asteroids != null:
		_collide_asteroids()
	if _bounded:
		_bounce_off_world()

func _collide_asteroids() -> void:
	var shift := _asteroids.push_out(global_position, asteroid_margin)
	if shift == Vector2.ZERO:
		return
	global_position += shift
	var n := shift.normalized()
	if drift_velocity.dot(n) < 0.0:
		drift_velocity = drift_velocity.bounce(n)
	if blast_velocity.dot(n) < 0.0:
		blast_velocity = blast_velocity.bounce(n)

func _pull_rope(delta : float) -> void:
	var a := anchor.global_position
	var to_anchor := a - global_position
	var dist := to_anchor.length()
	if dist > data.rope_length:
		_pull_speed = minf(_pull_speed + rope_pull_accel * delta, rope_max_pull_speed)
		var excess := dist - data.rope_length
		var move := minf(excess * minf(data.rope_pull_strength * delta, 1.0), _pull_speed * delta)
		global_position += to_anchor / dist * move
	else:
		_pull_speed = 0.0

	var last := ROPE_PTS - 1
	var seg := data.rope_length * rope_slack / last
	var damp := maxf(1.0 - rope_damping * delta, 0.0)

	for i in range(1, last):
		var p := _rp[i]
		_rp[i] = p + (p - _rpp[i]) * damp
		_rpp[i] = p
	for i in range(1, last):
		_rp[i] = _rp[i].lerp((_rp[i - 1] + _rp[i + 1]) * 0.5, rope_stiffness)
	_rp[0] = global_position
	_rp[last] = a

	for it in 4:
		for i in last:
			var d := _rp[i + 1] - _rp[i]
			var l := d.length()
			if l <= seg:
				continue
			var shift := d * ((l - seg) / l)
			if i == 0:
				_rp[1] -= shift
			elif i == last - 1:
				_rp[i] += shift
			else:
				_rp[i] += shift * 0.5
				_rp[i + 1] -= shift * 0.5
	rope.points = _rp

func _bounce_off_world() -> void:
	var p := position
	if p.x >= _wmin.x and p.x <= _wmax.x and p.y >= _wmin.y and p.y <= _wmax.y:
		return   # the common case: nothing to do
	if p.x < _wmin.x:
		p.x = _wmin.x
		drift_velocity.x = absf(drift_velocity.x)    # force it to point inward
	elif p.x > _wmax.x:
		p.x = _wmax.x
		drift_velocity.x = -absf(drift_velocity.x)
	if p.y < _wmin.y:
		p.y = _wmin.y
		drift_velocity.y = absf(drift_velocity.y)
	elif p.y > _wmax.y:
		p.y = _wmax.y
		drift_velocity.y = -absf(drift_velocity.y)
	position = p

func _apply_shape() -> void:
	var v := DebrisShapes.make(data.tag)
	var poly : PackedVector2Array = v.poly
	_base_color = v.color

	sprite.texture = v.tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(DebrisShapes.PX, DebrisShapes.PX)
	var f := randf_range(0.9, 1.1)
	sprite.self_modulate = Color(f, f, f)   # self_modulate so quantum's node modulate still works
	rotation = randf() * TAU

	var col := $CollisionShape2D as CollisionShape2D
	(col.shape as RectangleShape2D).size = v.size
	col.position = Vector2.ZERO

	var occ := $LightOccluder2D as LightOccluder2D
	occ.visible = data.shadow_cast
	if data.shadow_cast:
		occ.occluder.polygon = poly

	var light := get_node_or_null("SpaceLight3") as PointLight2D
	if light:
		light.visible = randf() < data.light_chance
		light.position = poly[randi() % poly.size()]
		var lc : Color = v.light
		light.color = lc.lightened(randf_range(-0.15, 0.15))
		light.set("pulse_speed", randf_range(0.4, 1.4))
		light.set("intensity", randf_range(0.8, 1.4))
		light.height = 0.5
