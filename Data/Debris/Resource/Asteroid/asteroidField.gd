extends Node2D
class_name AsteroidField

signal asteroid_hit(asteroid : AsteroidObject, body : Node2D, point : Vector2, normal : Vector2)

@export var focus : Node2D
@export var asteroid_scene : PackedScene

@export_group("Density (rocks per 1,000,000 px²)")
@export var small_density : float = 0.5
@export var medium_density : float = 0.4
@export var large_density : float = 0.2

@export_group("Placement")
@export var gap : float = 250.0
@export var clear_radius : float = 900.0
@export var place_attempts : int = 40

@export_group("Depots")
@export var depot_soft_margin : float = 400.0
@export var depot_repel : float = 150.0

@export_group("Streaming")
@export var wake_distance : float = 3200.0
@export var sleep_margin : float = 600.0
@export var checks_per_frame : int = 12
@export var catchup_max : float = 20.0

@export_group("Rock vs Rock")
@export var rock_bounce : bool = true
@export_range(0.5, 1.0, 0.05) var rock_hull : float = 0.85
@export var max_speed : float = 140.0

var _rocks : Array[AsteroidObject] = []
var _awake : Array[AsteroidObject] = []
var _depots : Array[Depot] = []
var _cursor : int = 0
var _rect : Rect2

func _ready() -> void:
	add_to_group("AsteroidField")

func push_out(world_pos : Vector2, margin : float) -> Vector2:
	for a in _awake:
		var reach := a.radius + margin
		if world_pos.distance_squared_to(a.global_position) > reach * reach:
			continue
		var shift := a.push_out(world_pos, margin)
		if shift != Vector2.ZERO:
			return shift
	return Vector2.ZERO

func build(rect : Rect2, rng : RandomNumberGenerator, clear_points : Array[Vector2] = []) -> void:
	_rect = rect
	if asteroid_scene == null:
		push_error("AsteroidField: asteroid_scene is not assigned")
		return

	_depots.clear()
	for n in get_tree().get_nodes_in_group("Depot"):
		if n is Depot:
			_depots.append(n)

	AsteroidShapes.warm()

	var area_m := rect.get_area() / 1000000.0
	var density := [small_density, medium_density, large_density]
	var plan : Array[int] = []
	for s in [AsteroidObject.Size.LARGE, AsteroidObject.Size.MEDIUM, AsteroidObject.Size.SMALL]:
		for i in roundi(density[s] * area_m):
			plan.append(s)

	DataCollector.add_spawn_total(plan.size())

	var placed_pos := PackedVector2Array()
	var placed_rad := PackedFloat32Array()

	for s in plan:
		var v := rng.randi_range(0, AsteroidShapes.VARIANTS - 1)
		var r : float = AsteroidShapes.variant(s, v).radius
		var p := _find_spot(rng, r, placed_pos, placed_rad, clear_points)
		if p.x != INF:
			placed_pos.append(p)
			placed_rad.append(r)
			_spawn_rock(rng, s, v, p)
		DataCollector.report_spawned()
		await DataCollector.spawn_checkpoint()

	_stream_all()

func _find_spot(rng : RandomNumberGenerator, r : float, pos : PackedVector2Array,
		rad : PackedFloat32Array, clear_points : Array[Vector2]) -> Vector2:
	var area := _rect.grow(-r)
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return Vector2(INF, INF)
	for attempt in place_attempts:
		var p := Vector2(
			rng.randf_range(area.position.x, area.end.x),
			rng.randf_range(area.position.y, area.end.y))
		var ok := true
		for c in clear_points:
			if p.distance_to(c) < clear_radius + r:
				ok = false
				break
		if ok:
			for dep in _depots:
				if p.distance_to(dep.global_position) < dep.asteroid_clearance + depot_soft_margin + r:
					ok = false
					break
		if ok:
			for i in pos.size():
				if p.distance_to(pos[i]) < r + rad[i] + gap:
					ok = false
					break
		if ok:
			return p
	return Vector2(INF, INF)

func _spawn_rock(rng : RandomNumberGenerator, size : int, variant : int, p : Vector2) -> void:
	var a := asteroid_scene.instantiate() as AsteroidObject
	a.fx_parent = self
	a.setup(size, variant, _rect)
	a.position = p
	a.rotation = rng.randf() * TAU
	var spd_range : Vector2 = AsteroidObject.DRIFT_SPEED[size]
	a.velocity = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(spd_range.x, spd_range.y)
	a.field_idx = _rocks.size()
	a.field_slot = -1
	a.hit.connect(_on_hit.bind(a))
	_rocks.append(a)
	add_child(a)
	_wake(a)

func _on_hit(body : Node2D, point : Vector2, normal : Vector2, a : AsteroidObject) -> void:
	asteroid_hit.emit(a, body, point, normal)

func blocked(point : Vector2, margin : float = 0.0) -> bool:
	for a in _rocks:
		var r := a.radius * rock_hull + margin
		if point.distance_squared_to(a.position) < r * r:
			return true
	return false

func _process(_delta : float) -> void:
	if focus == null or _rocks.is_empty():
		return
	var fp := focus.global_position
	for i in mini(checks_per_frame, _rocks.size()):
		_cursor = (_cursor + 1) % _rocks.size()
		_update_rock(_rocks[_cursor], fp)

func _stream_all() -> void:
	if focus == null:
		return
	var fp := focus.global_position
	for a in _rocks:
		_update_rock(a, fp)

func _update_rock(a : AsteroidObject, fp : Vector2) -> void:
	var d := a.position.distance_to(fp) - a.radius
	if a.field_slot != -1:
		if d > wake_distance + sleep_margin:
			_sleep(a)
	elif d < wake_distance:
		_wake(a)

func _sleep(a : AsteroidObject) -> void:
	var last : AsteroidObject = _awake.pop_back()
	if last != a:
		_awake[a.field_slot] = last
		last.field_slot = a.field_slot
	a.field_slot = -1
	a.clear_contacts()
	a.visible = false
	a.process_mode = Node.PROCESS_MODE_DISABLED
	a.set_deferred("monitoring", false)
	a.set_meta("slept_at", Time.get_ticks_msec() / 1000.0)

func _wake(a : AsteroidObject) -> void:
	if a.field_slot != -1:
		return
	if a.has_meta("slept_at"):
		var dt := minf(Time.get_ticks_msec() / 1000.0 - float(a.get_meta("slept_at")), catchup_max)
		var pad := Vector2(a.radius, a.radius)
		a.position = (a.position + a.velocity * dt).clamp(_rect.position + pad, _rect.end - pad)
		_avoid_depots(a, 0.0)
	a.field_slot = _awake.size()
	_awake.append(a)
	a.visible = true
	a.process_mode = Node.PROCESS_MODE_INHERIT
	a.set_deferred("monitoring", true)


func _physics_process(delta : float) -> void:
	if rock_bounce:
		_collide_rocks()
	if not _depots.is_empty():
		for a in _awake:
			_avoid_depots(a, delta)

func _avoid_depots(a : AsteroidObject, delta : float) -> void:
	for dep in _depots:
		if not is_instance_valid(dep):
			continue
		var centre := to_local(dep.global_position)
		var off := a.position - centre
		var dist := off.length()
		var hard := dep.asteroid_clearance + a.radius
		var soft := hard + depot_soft_margin
		if dist >= soft:
			continue
		var n := off / dist if dist > 0.001 else Vector2.RIGHT
		if dist < hard:
			a.position = centre + n * hard
			var vn := a.velocity.dot(n)
			if vn < 0.0:
				a.velocity -= n * vn * 2.0
		else:
			var t := 1.0 - (dist - hard) / depot_soft_margin
			a.velocity += n * depot_repel * t * t * delta
		a.velocity = a.velocity.limit_length(max_speed)

func _collide_rocks() -> void:
	var n := _awake.size()
	for i in n:
		var a := _awake[i]
		var ra := a.radius * rock_hull
		for j in range(i + 1, n):
			var b := _awake[j]
			var rs := ra + b.radius * rock_hull
			var off := b.position - a.position
			var d2 := off.length_squared()
			if d2 >= rs * rs or d2 < 0.0001:
				continue
			var d := sqrt(d2)
			var nrm := off / d
			var ma := a.radius * a.radius
			var mb := b.radius * b.radius
			var tot := ma + mb
			var pen := rs - d
			a.position -= nrm * pen * (mb / tot)
			b.position += nrm * pen * (ma / tot)
			var rel := (b.velocity - a.velocity).dot(nrm)
			if rel < 0.0:
				var j_imp := -2.0 * rel / (1.0 / ma + 1.0 / mb)
				a.velocity = (a.velocity - nrm * (j_imp / ma)).limit_length(max_speed)
				b.velocity = (b.velocity + nrm * (j_imp / mb)).limit_length(max_speed)