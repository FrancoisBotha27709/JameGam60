extends Node2D
class_name Main

@export var background_sprite_container : Node2D
@export var mist_container : Node2D
@export var stars_container : Node2D
@export var galaxy_container : Node2D
@export var planets_container : Node2D
@export var debris_amount : int = 10
@export var debris_scenes : Array[Debris]
@export_group("Background")
@export_dir var background_folder : String = "res://Assets/UI/SpaceBackground/*/background/"
@export var background_tile_size : int = 1024
@export_enum("Crimson", "Deep_Blue") var space_name : String = "Crimson"

@export_subgroup("Mist")
@export_dir var mist_folder : String = "res://Assets/UI/SpaceBackground/*/mist/"
@export var mist_staggered : bool = true
@export var mist_movement_amount : float = 15.0
@export var mist_movement_duration : float = 4.0

var _mist_tween : Tween
var _mist_origin : Vector2
@export_subgroup("Galaxy")
@export_dir var galaxy_folder : String = "res://Assets/UI/SpaceBackground/*/galaxies/"
@export var galaxy_staggered : bool = true
@export_subgroup("Planet")
@export_dir var planet_folder : String = "res://Assets/UI/SpaceBackground/*/planets/"
@export var planet_staggered : bool = true
@export_subgroup("Stars")
@export_dir var stars_folder : String = "res://Assets/UI/SpaceBackground/*/stars/"
@export var stars_staggered : bool = true

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
@export var quota_margin : float = 1.5
@export var spawn_min_distance : float = 800.0
@export var spawn_max_distance : float = 1600.0
@export var spawn_growth_per_upgrade : float = 0.5
@export var leash_factor : float = 1.25
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

	_rng.randomize()
	var rng := _rng

	_spawn_background(rng)
	_spawn_mist(rng)
	_spawn_galaxies(rng)
	_spawn_planets(rng)
	_spawn_stars(rng)
	_spawn_lights(rng)
	_spawn_asteroids(rng)
	_spawn_debris(rng)
	_spawn_particles(rng)

	if mist_container != null:
		_mist_origin = mist_container.position
		_animate_mist(rng)
	_play_start_banner()

func _animate_mist(rng : RandomNumberGenerator) -> void:
	var target := _mist_origin + Vector2(
		rng.randf_range(-mist_movement_amount, mist_movement_amount),
		rng.randf_range(-mist_movement_amount, mist_movement_amount))

	_mist_tween = create_tween()
	_mist_tween.tween_property(mist_container, "position", target, mist_movement_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_mist_tween.tween_callback(_animate_mist.bind(rng))

func _spawn_background(rng : RandomNumberGenerator) -> void:
	var path : String = background_folder.replace("*", str(space_name).to_lower())
	var textures := _load_tile_textures(path)
	if textures.is_empty():
		push_warning("Main: no background tiles found in '%s'" % background_folder)
		return

	var container : Node2D = background_sprite_container
	if container == null:
		container = Node2D.new()
		container.name = "Background"
		add_child(container)
		move_child(container, 0)

	_fill_world_with_tiles(container, textures, rng, false)

func _spawn_mist(rng : RandomNumberGenerator) -> void:
	if mist_folder.is_empty():
		return # no mist folder chosen, skip quietly
	var path : String = mist_folder.replace("*", str(space_name).to_lower())
	var textures := _load_tile_textures(path)
	if textures.is_empty():
		push_warning("Main: no mist tiles found in '%s'" % mist_folder)
		return

	var container : Node2D = mist_container
	if container == null:
		container = Node2D.new()
		container.name = "Mist"
		add_child(container)

	_fill_world_with_tiles(container, textures, rng, mist_staggered)

func _spawn_galaxies(rng : RandomNumberGenerator) -> void:
	if galaxy_folder.is_empty():
		return # no mist folder chosen, skip quietly
	var path : String = galaxy_folder.replace("*", str(space_name).to_lower())
	var textures := _load_tile_textures(path)
	if textures.is_empty():
		push_warning("Main: no mist tiles found in '%s'" % galaxy_folder)
		return

	var container : Node2D = galaxy_container
	if container == null:
		container = Node2D.new()
		container.name = "Galaxy"
		add_child(container)

	_fill_world_with_tiles(container, textures, rng, galaxy_staggered)

func _spawn_planets(rng : RandomNumberGenerator) -> void:
	if planet_folder.is_empty():
		return # no mist folder chosen, skip quietly
	var path : String = planet_folder.replace("*", str(space_name).to_lower())
	var textures := _load_tile_textures(path)
	if textures.is_empty():
		push_warning("Main: no mist tiles found in '%s'" % planet_folder)
		return

	var container : Node2D = planets_container
	if container == null:
		container = Node2D.new()
		container.name = "Planet"
		add_child(container)

	_fill_world_with_tiles(container, textures, rng, planet_staggered)

func _spawn_stars(rng : RandomNumberGenerator) -> void:
	if stars_folder.is_empty():
		return # no mist folder chosen, skip quietly
	var path : String = stars_folder.replace("*", str(space_name).to_lower())
	var textures := _load_tile_textures(path)
	if textures.is_empty():
		push_warning("Main: no mist tiles found in '%s'" % stars_folder)
		return

	var container : Node2D = stars_container
	if container == null:
		container = Node2D.new()
		container.name = "Stars"
		add_child(container)

	_fill_world_with_tiles(container, textures, rng, stars_staggered)

func _fill_world_with_tiles(container : Node2D, textures : Array[Texture2D], rng : RandomNumberGenerator, stagger : bool) -> void:
	var step := float(background_tile_size)
	var cols := ceili(world_rect.size.x / step)
	var rows := ceili(world_rect.size.y / step)
	var origin := world_rect.get_center() - Vector2(cols, rows) * step * 0.5

	if stagger:
		cols += 1
		rows += 1
		origin -= Vector2(step, step) * 0.5

	var grid := PackedInt32Array()
	grid.resize(cols * rows)
	grid.fill(-1)

	for row in rows:
		for col in cols:
			var left := grid[row * cols + col - 1] if col > 0 else -1
			var up := grid[(row - 1) * cols + col] if row > 0 else -1
			var idx := _pick_tile(rng, textures.size(), left, up)
			grid[row * cols + col] = idx

			var tex := textures[idx]
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = Vector2(step / tex.get_width(), step / tex.get_height())
			sprite.position = origin + Vector2(col, row) * step
			container.add_child(sprite)

func _pick_tile(rng : RandomNumberGenerator, count : int, left : int, up : int) -> int:
	if count == 1:
		return 0
	for attempt in 12:
		var idx := rng.randi_range(0, count - 1)
		if idx != left and idx != up:
			return idx
	return rng.randi_range(0, count - 1)

func _load_tile_textures(folder : String) -> Array[Texture2D]:
	var result : Array[Texture2D] = []
	var dir := DirAccess.open(folder)
	if dir == null:
		push_error("Main: cannot open tile folder '%s'" % folder)
		return result

	var names : Array[String] = []
	for file in dir.get_files():
		var f := file.trim_suffix(".import")
		if f.get_extension().to_lower() != "png":
			continue
		if not names.has(f):
			names.append(f)
	names.sort()

	for f in names:
		var tex := load(folder.path_join(f)) as Texture2D
		if tex != null:
			result.append(tex)
	return result

func _spawn_lights(rng : RandomNumberGenerator) -> void:
	if light_count <= 0:
		return

	var container : Node2D = light_container
	if container == null:
		container = Node2D.new()
		container.name = "SpaceLights"
		add_child(container)

	_light_base_hue = rng.randf() # only used when light_colors is empty

	var area := world_rect.grow(-light_edge_margin)
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		area = world_rect

	# minimum spacing so the lights spread over the whole map instead of clumping
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
		if nearest > best_dist: # remember the least crowded try in case none is good enough
			best_dist = nearest
			best = p
	return best

func _make_light(rng : RandomNumberGenerator, pos : Vector2) -> SpaceLight:
	var l := SpaceLight.new()
	l.position = pos
	l.color = _random_light_color(rng)
	l.intensity = rng.randf_range(light_intensity_min, light_intensity_max)
	l.radius = rng.randf_range(light_radius_min, light_radius_max)
	# snapped so lights share a few cached textures instead of generating a new one each
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
	var depot := get_node_or_null("Depot") as Node2D
	if depot != null:
		clear.append(depot.global_position)

	await field.build(world_rect, rng, clear)
	DataCollector.finish_spawn_job()

var _rng := RandomNumberGenerator.new()

func respawn_debris() -> void:
	DataCollector.start_run(1)
	player.reset_for_run()
	if debfield != null:
		debfield.clear()
	await _spawn_debris(_rng)

func _spawn_debris(rng : RandomNumberGenerator) -> void:
	if debris_scenes.is_empty():
		push_error("Main: No Debris resources assigned")
		DataCollector.finish_spawn_job()
		return

	var spread := 1.0 + spawn_growth_per_upgrade * DataCollector.upgrades_taken
	var amount := maxi(debris_amount, ceili(DataCollector.get_quota() * quota_margin))

	var depot := get_node_or_null("Depot") as Node2D
	var center := depot.global_position if depot != null else Vector2.ZERO
	var leash := spawn_max_distance * spread * leash_factor
	if debfield == null:
		debfield = DebrisField.new()

		debfield.name = "DebrisField"
		debfield.focus = player
		add_child(debfield)
	
	await debfield.build(debris_scenes, amount, center, spawn_min_distance,
		spawn_max_distance, spread, leash, world_rect, rng)
	DataCollector.finish_spawn_job()

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