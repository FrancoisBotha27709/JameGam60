extends Node2D
class_name Main

@export var debris_amount : int = 10
@export var debris_scenes : Array[Debris]

@export_group("Lights")
@export var light_container : Node2D
@export var light_count : int = 40
@export var light_colors : Array[Color] = [
	Color(1.0, 0.55, 0.3),
	Color(1.0, 0.75, 0.4),
	Color(0.95, 0.45, 0.4),
]
@export_range(0.0, 0.2, 0.005) var light_hue_jitter : float = 0.03
@export_subgroup("Look")
@export var light_radius_min : float = 300.0
@export var light_radius_max : float = 700.0
@export var light_intensity_min : float = 0.5
@export var light_intensity_max : float = 1.0
@export var light_falloff_min : float = 1.5
@export var light_falloff_max : float = 2.5
@export_subgroup("Animation")
@export_range(0.0, 1.0, 0.01) var light_pulse_chance : float = 0.4
@export_range(0.0, 1.0, 0.01) var light_pulse_min : float = 0.1
@export_range(0.0, 1.0, 0.01) var light_pulse_max : float = 0.35
@export var light_pulse_speed_min : float = 0.1
@export var light_pulse_speed_max : float = 0.4
@export_range(0.0, 1.0, 0.01) var light_flicker_chance : float = 0.15
@export_range(0.0, 1.0, 0.01) var light_flicker_max : float = 0.2
@export_subgroup("Placement")
@export var light_edge_margin : float = 200.0
@export var light_min_spacing : float = 0.0
@export_group("Depots")
@export var depot_scene : PackedScene
@export var depot_count : int = 8
@export var depot_min_spacing : float = 1200.0
@export var depot_edge_margin : float = 400.0
@export var depot_placement_attempts : int = 100
@export_group("Particles")
@export var particle_pool : Array[PackedScene]
@export var particle_count : int = 300
@export_subgroup("Drift")
@export var particle_drift_min : float = 2.0
@export var particle_drift_max : float = 8.0
@export var particle_wander : float = 0.1

var _drifters : Array[Node2D] = []
var _drift_vel : PackedVector2Array = PackedVector2Array()
var _light_base_hue : float = 0.0

@export_group("World")
@export var world_size : Vector2 = Vector2(5000, 5000)
@export var player : Player
@export var cam : Cam
@export var minimap : Minimap
@export_group("Spawning")
@export var portal_entry : PortalEntry
@export var reveal : WreckReveal
@export var wrecks : Wrecks
@export var quota_margin : float = 1.5
@export_group("Asteroids")
@export var asteroid_scene : PackedScene
@export var field : AsteroidField
@export_group("Debris")
@export var debfield : DebrisField
@export_subgroup("Batching")
@export var debris_per_frame : int = 5
@export var particles_per_frame : int = 20
@export var start_banner : RunStartBanner

var world_rect : Rect2
var _sites : Array[WreckSite] = []

func _play_start_banner() -> void:
	if start_banner == null:
		return
	get_tree().paused = true
	start_banner.play(DataCollector.run_number, DataCollector.get_quota())
	await start_banner.sequence_finished
	get_tree().paused = false

func _ready() -> void:
	DataCollector.start_run(3)

	world_rect = Rect2(-world_size * 0.5, world_size)

	player.set_world_bounds(world_rect)
	cam.set_world_bounds(world_rect)
	minimap.set_world_bounds(world_rect)
	_hide_player()

	_rng.randomize()
	var rng := _rng

	_spawn_depots(rng)

	_spawn_lights(rng)
	await _spawn_asteroids(rng)
	_spawn_debris(rng)
	_spawn_particles(rng)

	await _play_start_banner()
	await _run_intro()

func _hide_player() -> void:
	player.visible = false

func _spawn_depots(rng : RandomNumberGenerator) -> void:
	if depot_scene == null:
		push_warning("Main: no depot_scene assigned")
		return

	var area := world_rect.grow(-depot_edge_margin)
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		area = world_rect

	var positions : Array[Vector2] = []

	for i in depot_count:
		var best_position := area.get_center()
		var best_distance := -1.0
		var found_position := false

		for attempt in depot_placement_attempts:
			var candidate := Vector2(
				rng.randf_range(area.position.x, area.end.x),
				rng.randf_range(area.position.y, area.end.y)
			)

			var nearest_distance := INF

			for existing in positions:
				nearest_distance = minf(
					nearest_distance,
					candidate.distance_to(existing)
				)

			if positions.is_empty() or nearest_distance >= depot_min_spacing:
				best_position = candidate
				found_position = true
				break

			if nearest_distance > best_distance:
				best_distance = nearest_distance
				best_position = candidate

		if not found_position and not positions.is_empty():
			if best_distance < depot_min_spacing:
				push_warning("Main: couldn't maintain minimum depot spacing")

		positions.append(best_position)

		var depot := depot_scene.instantiate() as Node2D
		depot.global_position = best_position
		depot.add_to_group("Depot")
		depot.name = "Depot_%02d" % i
		add_child(depot)

func _spawn_lights(rng : RandomNumberGenerator) -> void:
	if light_count <= 0:
		return

	var container : Node2D = light_container
	if container == null:
		container = Node2D.new()
		container.name = "SpaceLights"
		add_child(container)

	_light_base_hue = rng.randf()

	var area := world_rect.grow(-light_edge_margin)
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		area = world_rect

	var spacing := light_min_spacing
	if spacing <= 0.0:
		spacing = 0.7 * sqrt(area.get_area() / float(light_count))

	var points : Array[Vector2] = []
	for i in light_count:
		var p := _pick_light_point(rng, area, points, spacing)
		points.append(p)
		container.add_child(_make_light(rng, p))

func _pick_light_point(rng : RandomNumberGenerator, area : Rect2, points : Array[Vector2], spacing : float) -> Vector2:
	var best := area.get_center()
	var best_dist := -1.0
	for attempt in 30:
		var p := Vector2(
			rng.randf_range(area.position.x, area.end.x),
			rng.randf_range(area.position.y, area.end.y)
		)
		var nearest := INF
		for q in points:
			nearest = minf(nearest, p.distance_to(q))
		if nearest >= spacing:
			return p
		if nearest > best_dist:
			best_dist = nearest
			best = p
	return best

func _make_light(rng : RandomNumberGenerator, pos : Vector2) -> SpaceLight:
	var l := SpaceLight.new()
	l.position = pos
	l.color = _random_light_color(rng)
	l.intensity = rng.randf_range(light_intensity_min, light_intensity_max)
	l.radius = rng.randf_range(light_radius_min, light_radius_max)
	l.falloff = snappedf(rng.randf_range(light_falloff_min, light_falloff_max), 0.5)
	l.shape = LightPreset.Shape.POINT
	l.cast_shadows = false

	if rng.randf() < light_pulse_chance:
		l.pulse = rng.randf_range(light_pulse_min, light_pulse_max)
		l.pulse_speed = rng.randf_range(light_pulse_speed_min, light_pulse_speed_max)
	if rng.randf() < light_flicker_chance:
		l.flicker = rng.randf_range(0.05, maxf(light_flicker_max, 0.05))
		l.flicker_speed = rng.randf_range(4.0, 10.0)
	return l

func _random_light_color(rng : RandomNumberGenerator) -> Color:
	var c : Color
	if light_colors.is_empty():
		c = Color.from_hsv(_light_base_hue, 0.55, 1.0)
	else:
		c = light_colors[rng.randi_range(0, light_colors.size() - 1)]
	c.h = fposmod(c.h + rng.randf_range(-light_hue_jitter, light_hue_jitter), 1.0)
	c.s = clampf(c.s + rng.randf_range(-0.1, 0.1), 0.0, 1.0)
	return c

func _spawn_asteroids(rng : RandomNumberGenerator) -> void:
	if asteroid_scene == null:
		push_warning("Main: no asteroid_scene assigned")
		DataCollector.finish_spawn_job()
		return

	if field == null:
		field = AsteroidField.new()
		field.name = "AsteroidField"
		field.focus = player
		field.asteroid_scene = asteroid_scene
		add_child(field)

	var clear : Array[Vector2] = [player.global_position]
	for depot in get_tree().get_nodes_in_group("Depot"):
		if depot is Node2D:
			clear.append(depot.global_position)

	await field.build(world_rect, rng, clear)
	DataCollector.finish_spawn_job()

var _rng := RandomNumberGenerator.new()

func respawn_debris() -> void:
	DataCollector.start_run(1)
	player.reset_for_run()
	_hide_player()
	if debfield != null:
		debfield.clear()
	await _spawn_debris(_rng)
	await _run_intro()

func _spawn_debris(rng : RandomNumberGenerator) -> void:
	if debris_scenes.is_empty():
		DataCollector.finish_spawn_job()
		return
	if wrecks == null:
		wrecks = Wrecks.new()
	var amount := maxi(debris_amount, ceili(DataCollector.get_quota() * quota_margin))
	var player_position := player.global_position
	var sites := wrecks.plan(get_tree().get_nodes_in_group("Depot"), world_rect, amount, rng, player_position)
	if debfield == null:
		debfield = DebrisField.new()
		debfield.name = "DebrisField"
		debfield.focus = player
		add_child(debfield)
	await debfield.build(debris_scenes, amount, sites, wrecks.leash, world_rect, rng, player_position, wrecks.player_clear_radius, field)
	_sites = sites
	DataCollector.finish_spawn_job()

#region Intro

func _run_intro() -> void:
	if not DataCollector.is_world_ready:
		await DataCollector.world_ready
	var timer := DataCollector.global_timer
	if timer != null:
		timer.paused = true
	var was_skipped : bool = await _play_portal_entry()
	if not was_skipped and not _sites.is_empty():
		await show_wreck_sites(_sites)
	if timer != null:
		timer.paused = false
	player.visible = true
	player.set_physics_process(true)
	if debfield != null:
		debfield.start_streaming()

func _play_portal_entry() -> bool:
	if portal_entry == null:
		portal_entry = PortalEntry.new()
	return await portal_entry.play(self, player, cam)

func show_wreck_sites(sites : Array[WreckSite]) -> void:
	if reveal == null:
		reveal = WreckReveal.new()
	await reveal.play(self, sites, cam, player, debfield, _rng)

#endregion

func _spawn_particles(rng : RandomNumberGenerator) -> void:
	if particle_pool.is_empty():
		DataCollector.finish_spawn_job()
		return
	var holder := Node2D.new()
	holder.name = "WorldParticles"
	add_child(holder)
	DataCollector.add_spawn_total(particle_count)
	for i in particle_count:
		var fx := particle_pool[rng.randi_range(0, particle_pool.size() - 1)].instantiate() as Node2D
		fx.position = _random_point(rng)
		holder.add_child(fx)
		_drifters.append(fx)
		_drift_vel.append(Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(particle_drift_min, particle_drift_max))
		DataCollector.report_spawned()
		await DataCollector.spawn_checkpoint()

	DataCollector.finish_spawn_job()

func _process(delta: float) -> void:
	_drift_particles(delta)

func _random_point(rng : RandomNumberGenerator) -> Vector2:
	return Vector2(
		rng.randf_range(world_rect.position.x, world_rect.end.x),
		rng.randf_range(world_rect.position.y, world_rect.end.y)
	)

func _drift_particles(delta : float) -> void:
	for i in _drifters.size():
		var fx := _drifters[i]
		if not is_instance_valid(fx):
			continue
		var v := _drift_vel[i].rotated(randf_range(-1.0, 1.0) * particle_wander * delta)
		var p := fx.position + v * delta

		if p.x < world_rect.position.x:
			p.x = world_rect.position.x
			v.x = absf(v.x)
		elif p.x > world_rect.end.x:
			p.x = world_rect.end.x
			v.x = -absf(v.x)
		if p.y < world_rect.position.y:
			p.y = world_rect.position.y
			v.y = absf(v.y)
		elif p.y > world_rect.end.y:
			p.y = world_rect.end.y
			v.y = -absf(v.y)

		fx.position = p
		_drift_vel[i] = v