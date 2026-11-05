extends CanvasLayer
class_name MistField

const MAX_DISTURBERS := 32
const TRAIL_SLOTS := 12
const OBJECT_SLOTS := MAX_DISTURBERS - TRAIL_SLOTS - 1
const OBJECT_GROUPS: Array[StringName] = [&"Debris", &"Asteroid"]
const MIN_STRENGTH_RATIO := 0.3
const FALLBACK_MAX_SPEED := 600.0
const DEFAULT_SHIP_RADIUS := 100.0
const MIN_TRAIL_SPACING := 40.0

const PALETTE_MIST_A: Array[Color] = [
	Color(0.25, 0.10, 0.50), Color(0.05, 0.30, 0.30),
	Color(0.45, 0.07, 0.10), Color(0.03, 0.15, 0.40),
	Color(0.40, 0.15, 0.30), Color(0.14, 0.15, 0.20)
]
const PALETTE_MIST_B: Array[Color] = [
	Color(0.06, 0.30, 0.55), Color(0.12, 0.20, 0.50),
	Color(0.35, 0.12, 0.30), Color(0.02, 0.35, 0.45),
	Color(0.55, 0.25, 0.15), Color(0.20, 0.22, 0.28)
]
const PALETTE_MIST_HIGHLIGHT: Array[Color] = [
	Color(0.95, 0.42, 0.62), Color(0.60, 1.00, 0.65),
	Color(1.00, 0.55, 0.20), Color(0.50, 0.95, 0.95),
	Color(1.00, 0.75, 0.35), Color(0.62, 0.66, 0.75)
]

@export_group("Shader")
@export var mist_material: ShaderMaterial
@export var focus: Node2D
@export var palette_source_material: ShaderMaterial
@export var sync_palette_and_look := true
@export_range(0.0, 3.0, 0.05) var mist_motion_multiplier := 0.5
@export_range(0.0, 3.0, 0.05) var warp_motion_multiplier := 0.5

@export_group("Density Field")
@export var density_origin := Vector2(-8000.0, -8000.0)
@export var density_size := Vector2(16000.0, 16000.0)
@export_range(64, 512, 16) var density_resolution := 256
@export_range(0.0, 1.0, 0.01) var refill_rate := 0.18
@export_range(0.0, 1.0, 0.05) var carve_strength := 0.35
@export_range(0.1, 4.0, 0.1) var ship_radius_scale := 0.8
@export var ship_radius_padding := 10.0
@export_range(1.0, 100.0, 1.0) var carve_spacing := 8.0
@export_range(0.0, 2.0, 0.05) var speed_radius_bonus := 0.1
@export_range(0.01, 0.2, 0.01) var density_update_interval := 0.05

@export_group("Ship")
@export var fallback_ship_radius := DEFAULT_SHIP_RADIUS

@export_group("Temporary Disturbances")
@export var debris_radius := 90.0
@export var asteroid_radius_scale := 1.4
@export_range(0.0, 1.0, 0.05) var object_strength := 0.2
@export_range(0.01, 0.5, 0.01) var scan_interval := 0.05
@export var scan_margin := 400.0
@export var drag_time := 0.15
@export var max_drag := 80.0

@export_group("Wake")
@export var trail_life := 5.0
@export var trail_strength := 0.12
@export var trail_radius_scale := 0.5

var _material: ShaderMaterial
var _density_image: Image
var _density_texture: ImageTexture
var _a := PackedVector4Array()
var _b := PackedVector4Array()
var _trail_pos := PackedVector2Array()
var _trail_drag := PackedVector2Array()
var _trail_power := PackedFloat32Array()
var _trail_age := PackedFloat32Array()
var _trail_head := 0
var _trail_timer := 0.0
var _last_trail_pos := Vector2.INF
var _objects: Array[Node2D] = []
var _scan_timer := 0.0
var _density_timer := 0.0
var _style_timer := 0.0
var _motion_paused := false
var _max_speed := FALLBACK_MAX_SPEED
var _last_ship_position := Vector2.INF

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a.resize(MAX_DISTURBERS)
	_b.resize(MAX_DISTURBERS)
	_trail_pos.resize(TRAIL_SLOTS)
	_trail_drag.resize(TRAIL_SLOTS)
	_trail_power.resize(TRAIL_SLOTS)
	_trail_age.resize(TRAIL_SLOTS)
	_trail_age.fill(INF)

	_create_density_field()
	_create_shader_layer()

	if _material:
		_sync_style_from_source()
		reseed()

func _create_density_field() -> void:
	var resolution := maxi(density_resolution, 64)
	_density_image = Image.create(resolution, resolution, false, Image.FORMAT_R8)
	_density_image.fill(Color.WHITE)
	_density_texture = ImageTexture.create_from_image(_density_image)

func _create_shader_layer() -> void:
	if mist_material == null:
		push_error("MistField: No ShaderMaterial assigned.")
		return

	if mist_material.shader == null:
		push_error("MistField: The assigned ShaderMaterial has no shader.")
		return

	_material = mist_material.duplicate() as ShaderMaterial

	if _material == null:
		push_error("MistField: Failed to duplicate the assigned ShaderMaterial.")
		return

	_material.set_shader_parameter("density_texture", _density_texture)
	_material.set_shader_parameter("density_origin", density_origin)
	_material.set_shader_parameter("density_size", density_size)

	var rect := ColorRect.new()
	rect.name = "MistRenderer"
	rect.material = _material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rect)

func _get_source_value(parameter: StringName, fallback: Variant) -> Variant:
	if palette_source_material == null:
		return fallback

	var value: Variant = palette_source_material.get_shader_parameter(parameter)
	return fallback if value == null else value

func _sync_style_from_source() -> void:
	if _material == null or palette_source_material == null:
		return

	var palette := int(_get_source_value(&"palette", 0))

	if palette == 0:
		_material.set_shader_parameter("mist_color_a", _get_source_value(&"mist_color_a", PALETTE_MIST_A[0]))
		_material.set_shader_parameter("mist_color_b", _get_source_value(&"mist_color_b", PALETTE_MIST_B[0]))
		_material.set_shader_parameter("mist_highlight_color", _get_source_value(&"mist_highlight_color", PALETTE_MIST_HIGHLIGHT[0]))
	else:
		var index := clampi(palette - 1, 0, PALETTE_MIST_A.size() - 1)
		_material.set_shader_parameter("mist_color_a", PALETTE_MIST_A[index])
		_material.set_shader_parameter("mist_color_b", PALETTE_MIST_B[index])
		_material.set_shader_parameter("mist_highlight_color", PALETTE_MIST_HIGHLIGHT[index])

	_material.set_shader_parameter("pixel_size", float(_get_source_value(&"pixel_size", 4.0)))
	_material.set_shader_parameter("levels", int(_get_source_value(&"mist_levels", 5)))
	_material.set_shader_parameter("octaves", int(_get_source_value(&"mist_octaves", 5)))
	_material.set_shader_parameter("threshold", float(_get_source_value(&"mist_threshold", 0.42)))
	_material.set_shader_parameter("softness", float(_get_source_value(&"mist_softness", 0.32)))
	_material.set_shader_parameter("warp_strength", float(_get_source_value(&"mist_warp_strength", 1.6)))
	_material.set_shader_parameter("highlight_amount", float(_get_source_value(&"mist_highlight_amount", 0.7)))

	var far_intensity := float(_get_source_value(&"far_mist_intensity", 0.55))
	var near_intensity := float(_get_source_value(&"near_mist_intensity", 0.30))
	_material.set_shader_parameter("opacity", clampf((far_intensity + near_intensity) * 0.5, 0.15, 0.75))

func _set_shader_motion(drift: Vector2, evolve: float, warp: float, shape: float, region: float) -> void:
	if _material == null:
		return

	_material.set_shader_parameter("drift", drift)
	_material.set_shader_parameter("evolve_speed", evolve)
	_material.set_shader_parameter("warp_travel", warp)
	_material.set_shader_parameter("shape_travel", shape)
	_material.set_shader_parameter("region_travel", region)

func _update_motion_parameters() -> void:
	var motion := maxf(mist_motion_multiplier, 0.0)

	_set_shader_motion(
		Vector2(0.12, -0.08) * motion,
		0.12 * motion,
		0.65 * maxf(warp_motion_multiplier, 0.0),
		0.45 * motion,
		0.7 * motion
	)

func reseed() -> void:
	if _material == null:
		return

	_material.set_shader_parameter(
		"seed_offset",
		Vector2(randf_range(0.0, 400.0), randf_range(0.0, 400.0))
	)

	_trail_age.fill(INF)
	_last_trail_pos = Vector2.INF
	_last_ship_position = Vector2.INF
	_trail_timer = 0.0

func _process(delta: float) -> void:
	if _material == null:
		return

	if get_tree().paused:
		if not _motion_paused:
			_motion_paused = true
			_set_shader_motion(Vector2.ZERO, 0.0, 0.0, 0.0, 0.0)
		return

	_motion_paused = false

	if sync_palette_and_look:
		_style_timer -= delta
		if _style_timer <= 0.0:
			_style_timer = 0.2
			_sync_style_from_source()

	_update_motion_parameters()
	_update_view_parameters()

	_update_max_speed()

	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = scan_interval
		_gather_objects()

	_update_density(delta)
	_update_trail(delta)
	_pack_disturbers()

	_material.set_shader_parameter("disturb_a", _a)
	_material.set_shader_parameter("disturb_b", _b)

func _update_view_parameters() -> void:
	var viewport := get_viewport()
	var world_rect: Rect2 = viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()

	_material.set_shader_parameter("view_origin", world_rect.position)
	_material.set_shader_parameter("view_size", world_rect.size)

func _update_max_speed() -> void:
	_max_speed = FALLBACK_MAX_SPEED

	if is_instance_valid(focus) and focus.has_method("stat_f"):
		_max_speed = maxf(float(focus.call("stat_f", &"max_speed")), 1.0)

func _gather_objects() -> void:
	var viewport := get_viewport()
	var world_rect: Rect2 = viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()
	var center := world_rect.get_center()
	var reach_squared := pow(world_rect.size.length() * 0.5 + scan_margin, 2.0)
	var found: Array[Node2D] = []

	for group in OBJECT_GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			var candidate := node as Node2D

			if candidate == null or not candidate.is_visible_in_tree():
				continue

			if candidate.global_position.distance_squared_to(center) < reach_squared:
				found.append(candidate)

	found.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center)
	)

	_objects = found.slice(0, OBJECT_SLOTS)

func _ship_velocity() -> Vector2:
	if not is_instance_valid(focus):
		return Vector2.ZERO

	var value: Variant = focus.get("velocity")
	return value if value is Vector2 else Vector2.ZERO

func _strength_ratio(speed: float) -> float:
	return clampf(speed / _max_speed, MIN_STRENGTH_RATIO, 1.0)

func _ship_radius() -> float:
	if not is_instance_valid(focus):
		return fallback_ship_radius

	var result := fallback_ship_radius
	var shape_node := focus.get("collision_shape") as CollisionShape2D

	if shape_node and shape_node.shape:
		var shape := shape_node.shape
		var scale := shape_node.global_scale.abs()

		if shape is CircleShape2D:
			result = (shape as CircleShape2D).radius * maxf(scale.x, scale.y)
		elif shape is RectangleShape2D:
			var rectangle := shape as RectangleShape2D
			result = maxf(rectangle.size.x * scale.x, rectangle.size.y * scale.y) * 0.5
		elif shape is CapsuleShape2D:
			var capsule := shape as CapsuleShape2D
			result = maxf(capsule.radius * scale.x, capsule.height * scale.y * 0.5)

	return maxf(result, 1.0)

func _update_density(delta: float) -> void:
	_density_timer += delta

	if _density_timer < density_update_interval:
		return

	var step := _density_timer
	_density_timer = 0.0
	_refill_density(step)

	if is_instance_valid(focus):
		var position := focus.global_position
		var velocity := _ship_velocity()
		var radius := _ship_radius() * ship_radius_scale + ship_radius_padding
		radius += velocity.length() / _max_speed * radius * speed_radius_bonus

		if _last_ship_position == Vector2.INF:
			_carve_circle(position, radius, carve_strength)
		else:
			_carve_segment(_last_ship_position, position, radius, carve_strength)

		_last_ship_position = position

	_density_texture.update(_density_image)

func _refill_density(delta: float) -> void:
	if refill_rate <= 0.0:
		return

	var data := _density_image.get_data()
	var increment := roundi(clampf(refill_rate * delta, 0.0, 1.0) * 255.0)

	if increment <= 0:
		return

	for i in range(data.size()):
		data[i] = mini(255, int(data[i]) + increment)

	_density_image.set_data(
		_density_image.get_width(),
		_density_image.get_height(),
		false,
		Image.FORMAT_R8,
		data
	)

func _world_to_field(position: Vector2) -> Vector2:
	var uv := (position - density_origin) / density_size

	return Vector2(
		uv.x * _density_image.get_width(),
		uv.y * _density_image.get_height()
	)

func _world_radius_to_pixels(radius: float) -> float:
	var px_x := float(_density_image.get_width()) / maxf(density_size.x, 1.0)
	var px_y := float(_density_image.get_height()) / maxf(density_size.y, 1.0)

	return radius * maxf(px_x, px_y)

func _carve_circle(position: Vector2, radius: float, strength: float) -> void:
	var center := _world_to_field(position)
	var pixel_radius := _world_radius_to_pixels(radius)

	if pixel_radius > 0.0:
		_carve_pixel_circle(center, pixel_radius, strength)

func _carve_segment(from_world: Vector2, to_world: Vector2, radius: float, strength: float) -> void:
	var distance := from_world.distance_to(to_world)
	var steps := maxi(1, ceili(distance / maxf(carve_spacing, 1.0)))

	for i in range(steps + 1):
		_carve_circle(
			from_world.lerp(to_world, float(i) / steps),
			radius,
			strength
		)

func _carve_pixel_circle(center: Vector2, radius: float, strength: float) -> void:
	var width := _density_image.get_width()
	var height := _density_image.get_height()
	var min_x := maxi(0, floori(center.x - radius))
	var max_x := mini(width - 1, ceili(center.x + radius))
	var min_y := maxi(0, floori(center.y - radius))
	var max_y := mini(height - 1, ceili(center.y + radius))

	if min_x > max_x or min_y > max_y:
		return

	var safe_radius := maxf(radius, 0.001)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var offset := Vector2(x + 0.5, y + 0.5) - center
			var ratio := offset.length() / safe_radius

			if ratio >= 1.0:
				continue

			var edge := 1.0 - smoothstep(0.35, 1.0, ratio)
			var amount := clampf(strength * edge, 0.0, 1.0)
			var old_value := _density_image.get_pixel(x, y).r
			var value := lerpf(old_value, 0.0, amount)

			_density_image.set_pixel(x, y, Color(value, value, value, 1.0))

func _drag_for(velocity: Vector2) -> Vector2:
	return (velocity * drag_time).limit_length(max_drag)

func _update_trail(delta: float) -> void:
	for i in range(TRAIL_SLOTS):
		_trail_age[i] += delta

	if not is_instance_valid(focus):
		return

	var spacing := maxf(MIN_TRAIL_SPACING, _ship_radius() * 0.25)
	_trail_timer -= delta

	if _trail_timer > 0.0:
		return

	if _last_trail_pos != Vector2.INF and focus.global_position.distance_to(_last_trail_pos) < spacing:
		return

	_trail_timer = trail_life / float(TRAIL_SLOTS) * 0.5

	var velocity := _ship_velocity()
	_trail_pos[_trail_head] = focus.global_position
	_trail_drag[_trail_head] = _drag_for(velocity)
	_trail_power[_trail_head] = _strength_ratio(velocity.length())
	_trail_age[_trail_head] = 0.0
	_trail_head = (_trail_head + 1) % TRAIL_SLOTS
	_last_trail_pos = focus.global_position

func _pack_disturbers() -> void:
	for i in range(MAX_DISTURBERS):
		_a[i] = Vector4.ZERO
		_b[i] = Vector4.ZERO

	var slot := 0

	if is_instance_valid(focus):
		var velocity := _ship_velocity()
		var radius := _ship_radius() * ship_radius_scale + ship_radius_padding
		_a[slot] = Vector4(focus.global_position.x, focus.global_position.y, radius, 0.0)

		var drag := _drag_for(velocity)
		_b[slot] = Vector4(drag.x, drag.y, 0.0, 0.0)

	slot += 1

	for i in range(TRAIL_SLOTS):
		if slot >= MAX_DISTURBERS:
			break

		var age_ratio := _trail_age[i] / maxf(trail_life, 0.001)

		if age_ratio >= 1.0:
			slot += 1
			continue

		var fade := pow(1.0 - age_ratio, 1.5)
		var radius := _ship_radius() * trail_radius_scale

		_a[slot] = Vector4(
			_trail_pos[i].x,
			_trail_pos[i].y,
			radius,
			trail_strength * fade * _trail_power[i]
		)

		_b[slot] = Vector4(_trail_drag[i].x, _trail_drag[i].y, 0.0, 0.0)
		slot += 1

	for node in _objects:
		if slot >= MAX_DISTURBERS:
			break

		if not is_instance_valid(node):
			continue

		var velocity := Vector2.ZERO
		var radius := debris_radius

		if node is AsteroidObject:
			var asteroid := node as AsteroidObject
			velocity = asteroid.velocity
			radius = maxf(asteroid.radius * asteroid_radius_scale, debris_radius)
		elif node is DebrisObject:
			velocity = (node as DebrisObject).drift_velocity

		var drag := _drag_for(velocity)

		_a[slot] = Vector4(
			node.global_position.x,
			node.global_position.y,
			radius,
			object_strength * _strength_ratio(velocity.length())
		)

		_b[slot] = Vector4(drag.x, drag.y, 0.0, 0.0)
		slot += 1