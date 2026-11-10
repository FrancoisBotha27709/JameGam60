extends Node2D
class_name AsteroidField

signal asteroid_hit(asteroid : AsteroidObject, body : Node2D, point : Vector2, normal : Vector2)
signal asteroid_destroyed(origin : Vector2, size : int)

const CLEAR_PASSES := 4
const NO_SLOT := -1
const FX_PIXEL_SCALE := 2.0
const MIN_DISTANCE := 0.001

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

@export_group("Breaking")
@export var chunk_debris : Debris
@export var chunk_counts : Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 4), Vector2i(4, 7)]
@export var value_per_radius : float = 0.05
@export var value_jitter : Vector2 = Vector2(0.6, 1.4)
@export var weight_jitter : Vector2 = Vector2(0.6, 1.4)
@export var chunk_scatter : float = 0.5
@export var chunk_blast_force : float = 500.0
@export var chunk_blast_jitter : Vector2 = Vector2(0.6, 1.2)
@export var delivered_lifetime : Vector2 = Vector2(0.6, 1.6)
@export_subgroup("Destruction Effects")
@export var destroy_fx_preset : String = "explosion"
@export var destroy_fx_power : Array[float] = [0.8, 1.2, 1.8]
@export var destroy_shake : Array[float] = [8.0, 14.0, 24.0]
@export var destroy_shake_time : float = 0.3
@export var destroy_fx_counts : Array[int] = [2, 3, 5]
@export var destroy_fx_stagger : Vector2 = Vector2(0.06, 0.14)
@export var destroy_fx_radius : float = 0.85

var _rocks : Array[AsteroidObject] = []
var _awake : Array[AsteroidObject] = []
var _depots : Array[Depot] = []
var _cursor : int = 0
var _rect : Rect2
var _chunk_rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("AsteroidField")
	_chunk_rng.randomize()

#region Queries

func push_out(world_pos : Vector2, margin : float) -> Vector2:
	for rock in _awake:
		var reach := rock.radius + margin
		if world_pos.distance_squared_to(rock.global_position) > reach * reach:
			continue
		var shift := rock.push_out(world_pos, margin)
		if shift != Vector2.ZERO:
			return shift
	return Vector2.ZERO

func resolve_point(world_pos : Vector2, margin : float) -> Vector2:
	var point := world_pos
	for pass_index in CLEAR_PASSES:
		var moved := false
		for rock in _rocks:
			var reach := rock.radius + margin
			if point.distance_squared_to(rock.global_position) > reach * reach:
				continue
			var shift := rock.push_out(point, margin)
			if shift != Vector2.ZERO:
				point += shift
				moved = true
		if not moved:
			break
	return point

func blocked(point : Vector2, margin : float = 0.0) -> bool:
	for rock in _rocks:
		var reach := rock.radius * rock_hull + margin
		if point.distance_squared_to(rock.position) < reach * reach:
			return true
	return false

#endregion

#region Building

func build(rect : Rect2, rng : RandomNumberGenerator, clear_points : Array[Vector2] = []) -> void:
	_rect = rect
	if asteroid_scene == null:
		return

	_depots.clear()
	for node in get_tree().get_nodes_in_group("Depot"):
		if node is Depot:
			_depots.append(node)

	AsteroidShapes.warm()

	var area_millions := rect.get_area() / 1000000.0
	var density := [small_density, medium_density, large_density]
	var plan : Array[int] = []
	for rock_size in [AsteroidObject.Size.LARGE, AsteroidObject.Size.MEDIUM, AsteroidObject.Size.SMALL]:
		for i in roundi(density[rock_size] * area_millions):
			plan.append(rock_size)

	DataCollector.add_spawn_total(plan.size())

	var placed_positions := PackedVector2Array()
	var placed_radii := PackedFloat32Array()

	for rock_size in plan:
		var shape_variant := rng.randi_range(0, AsteroidShapes.VARIANTS - 1)
		var rock_radius : float = AsteroidShapes.variant(rock_size, shape_variant).radius
		var spot := _find_spot(rng, rock_radius, placed_positions, placed_radii, clear_points)
		if spot.x != INF:
			placed_positions.append(spot)
			placed_radii.append(rock_radius)
			_spawn_rock(rng, rock_size, shape_variant, spot)
		DataCollector.report_spawned()
		await DataCollector.spawn_checkpoint()

	_stream_all()

func _find_spot(rng : RandomNumberGenerator, rock_radius : float, positions : PackedVector2Array,
		radii : PackedFloat32Array, clear_points : Array[Vector2]) -> Vector2:
	var area := _rect.grow(-rock_radius)
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return Vector2(INF, INF)
	for attempt in place_attempts:
		var candidate := Vector2(
			rng.randf_range(area.position.x, area.end.x),
			rng.randf_range(area.position.y, area.end.y))
		var accepted := true
		for clear_point in clear_points:
			if candidate.distance_to(clear_point) < clear_radius + rock_radius:
				accepted = false
				break
		if accepted:
			for depot in _depots:
				if candidate.distance_to(depot.global_position) < depot.asteroid_clearance + depot_soft_margin + rock_radius:
					accepted = false
					break
		if accepted:
			for i in positions.size():
				if candidate.distance_to(positions[i]) < rock_radius + radii[i] + gap:
					accepted = false
					break
		if accepted:
			return candidate
	return Vector2(INF, INF)

func _spawn_rock(rng : RandomNumberGenerator, rock_size : int, shape_variant : int, spot : Vector2) -> void:
	var rock := asteroid_scene.instantiate() as AsteroidObject
	rock.fx_parent = self
	rock.setup(rock_size, shape_variant, _rect)
	rock.position = spot
	rock.rotation = rng.randf() * TAU
	var speed_range : Vector2 = AsteroidObject.DRIFT_SPEED[rock_size]
	rock.velocity = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(speed_range.x, speed_range.y)
	rock.field_idx = _rocks.size()
	rock.field_slot = NO_SLOT
	rock.hit.connect(_on_hit.bind(rock))
	rock.destroyed.connect(_on_destroyed.bind(rock))
	_rocks.append(rock)
	add_child(rock)
	_wake(rock)

func _on_hit(body : Node2D, point : Vector2, normal : Vector2, rock : AsteroidObject) -> void:
	asteroid_hit.emit(rock, body, point, normal)

#endregion

#region Breaking


func _on_destroyed(rock : AsteroidObject) -> void:
	var origin := rock.global_position
	var rock_size : int = rock.size
	var rock_radius := rock.radius
	var rock_weight := rock.get_weight()

	var explosion_positions := _get_explosion_positions(rock)

	_retire_rock(rock)
	_spawn_destroy_effects(explosion_positions, rock_size)
	_spawn_chunks(origin, rock_size, rock_radius, rock_weight, explosion_positions)

	asteroid_destroyed.emit(origin, rock_size)


func _get_explosion_positions(rock : AsteroidObject) -> Array[Vector2]:
	var positions : Array[Vector2] = []
	var count := destroy_fx_counts[rock.size]

	for explosion_index in count:
		positions.append(rock.random_point_inside())

	return positions


func _retire_rock(rock : AsteroidObject) -> void:
	if rock.field_slot != NO_SLOT:
		var last_awake : AsteroidObject = _awake.pop_back()
		if last_awake != rock:
			_awake[rock.field_slot] = last_awake
			last_awake.field_slot = rock.field_slot
		rock.field_slot = NO_SLOT

	var last_rock : AsteroidObject = _rocks.pop_back()
	if last_rock != rock:
		_rocks[rock.field_idx] = last_rock
		last_rock.field_idx = rock.field_idx

	rock.field_idx = NO_SLOT
	rock.clear_contacts()
	rock.remove_from_group("Asteroid")
	rock.visible = false
	rock.process_mode = Node.PROCESS_MODE_DISABLED
	rock.set_deferred("monitoring", false)
	rock.queue_free()


func _spawn_destroy_effects(positions : Array[Vector2], rock_size : int) -> void:
	for explosion_index in positions.size():
		var delay := 0.0

		for previous_explosion in explosion_index:
			delay += _random_in(destroy_fx_stagger)

		_spawn_delayed_destroy_effect(positions[explosion_index], rock_size, delay)

	var camera := get_viewport().get_camera_2d() as Cam
	if camera != null:
		camera.impact(destroy_shake[rock_size], destroy_shake_time, 0.0, 0.0)


func _spawn_delayed_destroy_effect(point : Vector2, rock_size : int, delay : float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout

	if not is_inside_tree():
		return

	var effect := FXPlayer.new()
	effect.preset = destroy_fx_preset
	effect.pixel_scale = FX_PIXEL_SCALE
	effect.power = destroy_fx_power[rock_size]
	effect.play_mode = FXPlayer.PlayMode.ONCE
	effect.free_on_finish = true
	effect.position = to_local(point)
	effect.rotation = _chunk_rng.randf_range(0.0, TAU)

	add_child(effect)
	effect.play()


func _spawn_chunks(origin : Vector2, rock_size : int, rock_radius : float,
		rock_weight : float, explosion_positions : Array[Vector2]) -> void:

	if chunk_debris == null:
		push_warning("AsteroidField: chunk_debris is not assigned")
		return

	if chunk_debris.scene == null:
		push_warning("AsteroidField: chunk_debris has no scene assigned")
		return

	var count_range : Vector2i = chunk_counts[rock_size]
	var count := _chunk_rng.randi_range(count_range.x, count_range.y)
	var total_value := rock_radius * value_per_radius
	var base_weight := maxf(rock_weight, chunk_debris.stat_weight * count) / float(count)

	for chunk_index in count:
		var data := chunk_debris.duplicate() as Debris
		data.tag = Debris.Tag.ASTEROID
		data.stat_value = maxi(1, roundi(total_value / float(count) * _random_in(value_jitter)))
		data.stat_weight = base_weight * _random_in(weight_jitter)

		var chunk := data.scene.instantiate() as DebrisObject
		if chunk == null:
			push_warning("AsteroidField: failed to instantiate asteroid debris scene")
			continue

		chunk.delivered.connect(_on_chunk_delivered.bind(chunk))
		chunk.setup(data, Vector2.ZERO, 0.0, _rect, DebrisShapes.RANDOM_VARIANT)

		var offset := Vector2.from_angle(_chunk_rng.randf() * TAU) * rock_radius * chunk_scatter * _chunk_rng.randf()
		chunk.position = to_local(origin + offset)

		add_child(chunk)

		# Each explosion pushes the debris outwards from its own position.
		var blast_force := chunk_blast_force * _random_in(chunk_blast_jitter)
		var force_per_explosion := blast_force / float(maxi(explosion_positions.size(), 1))

		if explosion_positions.is_empty():
			chunk.apply_blast(origin, INF, blast_force)
		else:
			for explosion_position in explosion_positions:
				chunk.apply_blast(explosion_position, rock_radius * 2.5, force_per_explosion)


func _random_in(value_range : Vector2) -> float:
	return _chunk_rng.randf_range(value_range.x, value_range.y)


func _on_chunk_delivered(chunk : DebrisObject) -> void:
	get_tree().create_timer(_random_in(delivered_lifetime)).timeout.connect(func() -> void:
		if is_instance_valid(chunk):
			chunk.queue_free())


#endregion

#region Streaming

func _process(_delta : float) -> void:
	if focus == null or _rocks.is_empty():
		return
	var focus_position := focus.global_position
	for i in mini(checks_per_frame, _rocks.size()):
		_cursor = (_cursor + 1) % _rocks.size()
		_update_rock(_rocks[_cursor], focus_position)

func _stream_all() -> void:
	if focus == null:
		return
	var focus_position := focus.global_position
	for rock in _rocks:
		_update_rock(rock, focus_position)

func _update_rock(rock : AsteroidObject, focus_position : Vector2) -> void:
	var distance := rock.position.distance_to(focus_position) - rock.radius
	if rock.field_slot != NO_SLOT:
		if distance > wake_distance + sleep_margin:
			_sleep(rock)
	elif distance < wake_distance:
		_wake(rock)

func _sleep(rock : AsteroidObject) -> void:
	var last : AsteroidObject = _awake.pop_back()
	if last != rock:
		_awake[rock.field_slot] = last
		last.field_slot = rock.field_slot
	rock.field_slot = NO_SLOT
	rock.clear_contacts()
	rock.visible = false
	rock.process_mode = Node.PROCESS_MODE_DISABLED
	rock.set_deferred("monitoring", false)
	rock.set_meta("slept_at", Time.get_ticks_msec() / 1000.0)

func _wake(rock : AsteroidObject) -> void:
	if rock.field_slot != NO_SLOT:
		return
	if rock.has_meta("slept_at"):
		var elapsed := minf(Time.get_ticks_msec() / 1000.0 - float(rock.get_meta("slept_at")), catchup_max)
		var pad := Vector2(rock.radius, rock.radius)
		rock.position = (rock.position + rock.velocity * elapsed).clamp(_rect.position + pad, _rect.end - pad)
		_avoid_depots(rock, 0.0)
	rock.field_slot = _awake.size()
	_awake.append(rock)
	rock.visible = true
	rock.process_mode = Node.PROCESS_MODE_INHERIT
	rock.set_deferred("monitoring", true)

#endregion

#region Physics

func _physics_process(delta : float) -> void:
	if rock_bounce:
		_collide_rocks()
	if not _depots.is_empty():
		for rock in _awake:
			_avoid_depots(rock, delta)

func _avoid_depots(rock : AsteroidObject, delta : float) -> void:
	for depot in _depots:
		if not is_instance_valid(depot):
			continue
		var centre := to_local(depot.global_position)
		var offset := rock.position - centre
		var distance := offset.length()
		var hard := depot.asteroid_clearance + rock.radius
		var soft := hard + depot_soft_margin
		if distance >= soft:
			continue
		var direction := offset / distance if distance > MIN_DISTANCE else Vector2.RIGHT
		if distance < hard:
			rock.position = centre + direction * hard
			var normal_speed := rock.velocity.dot(direction)
			if normal_speed < 0.0:
				rock.velocity -= direction * normal_speed * 2.0
		else:
			var falloff := 1.0 - (distance - hard) / depot_soft_margin
			rock.velocity += direction * depot_repel * falloff * falloff * delta
		rock.velocity = rock.velocity.limit_length(max_speed)

func _collide_rocks() -> void:
	var rock_count := _awake.size()
	for i in rock_count:
		var first := _awake[i]
		var first_reach := first.radius * rock_hull
		for j in range(i + 1, rock_count):
			var second := _awake[j]
			var combined := first_reach + second.radius * rock_hull
			var offset := second.position - first.position
			var distance_squared := offset.length_squared()
			if distance_squared >= combined * combined or distance_squared < 0.0001:
				continue
			var distance := sqrt(distance_squared)
			var normal := offset / distance
			var first_mass := first.radius * first.radius
			var second_mass := second.radius * second.radius
			var total_mass := first_mass + second_mass
			var penetration := combined - distance
			first.position -= normal * penetration * (second_mass / total_mass)
			second.position += normal * penetration * (first_mass / total_mass)
			var relative_speed := (second.velocity - first.velocity).dot(normal)
			if relative_speed < 0.0:
				var impulse := -2.0 * relative_speed / (1.0 / first_mass + 1.0 / second_mass)
				first.velocity = (first.velocity - normal * (impulse / first_mass)).limit_length(max_speed)
				second.velocity = (second.velocity + normal * (impulse / second_mass)).limit_length(max_speed)

#endregion
