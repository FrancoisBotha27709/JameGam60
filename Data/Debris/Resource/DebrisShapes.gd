class_name DebrisShapes

const VARIANTS := 6
const PX := 2
const HALF := 0.5
const EDGE_PADDING := 4   # extra texture pixels around the outline
const ANGLE_JITTER := 0.3
const JAG_RANGE := Vector2(0.6, 1.2)
const JAG_VERTEX_INTERVAL := 2   # every second vertex is pulled inward on jagged shapes
const HUE_JITTER := 0.05
const SATURATION_RANGE := Vector2(0.7, 1.2)
const VALUE_RANGE := Vector2(0.75, 1.2)
const TONE_DEPTH_SCALE := 2.5
const HIGHLIGHT_LIGHTEN := 0.35
const SHADOW_DARKEN := 0.25
const OUTLINE_DARKEN := 0.8
const BAYER_SIZE := 4
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

# Outline (sides/radius/jitter/jag/aspect), colors, and surface noise (noise/freq/levels/depth) per tag.
const PROFILES := {
	Debris.Tag.NULL: {sides = Vector2i(6, 7), radius = Vector2(14, 20), jitter = 0.2, jag = 0.0, aspect = Vector2(1.0, 1.2),
		color = Color(0.5, 0.5, 0.5), light = Color(1, 1, 1),
		noise = FastNoiseLite.TYPE_SIMPLEX, freq = 0.18, levels = 3, depth = 0.12},
	Debris.Tag.PLASTIC: {sides = Vector2i(9, 11), radius = Vector2(14, 22), jitter = 0.1, jag = 0.0, aspect = Vector2(1.0, 1.5),
		color = Color(0.25, 0.6, 0.9), light = Color(0.4, 0.8, 1.0),
		noise = FastNoiseLite.TYPE_SIMPLEX_SMOOTH, freq = 0.12, levels = 3, depth = 0.08},
	Debris.Tag.METAL: {sides = Vector2i(6, 8), radius = Vector2(16, 26), jitter = 0.15, jag = 0.45, aspect = Vector2(1.5, 2.3),
		color = Color(0.6, 0.65, 0.7), light = Color(1.0, 0.7, 0.3),
		noise = FastNoiseLite.TYPE_PERLIN, freq = 0.25, levels = 4, depth = 0.18},
	Debris.Tag.CEMENT: {sides = Vector2i(5, 7), radius = Vector2(18, 26), jitter = 0.28, jag = 0.0, aspect = Vector2(1.0, 1.25),
		color = Color(0.55, 0.5, 0.42), light = Color(1.0, 0.4, 0.3),
		noise = FastNoiseLite.TYPE_CELLULAR, freq = 0.22, levels = 3, depth = 0.22},
}
const NEIGHBOR_OFFSETS : Array[Vector2i] = [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]

static var _cache := {}   # tag -> Array[Dictionary]


# Returns a cached shape for the tag, building new variants until VARIANTS exist.
static func make(tag : int) -> Dictionary:
	if not _cache.has(tag):
		_cache[tag] = []
	var variants : Array = _cache[tag]
	if variants.size() < VARIANTS:
		variants.append(_build(tag))
		return variants.back()
	return variants.pick_random()

static func random_in(value_range : Vector2) -> float:
	return randf_range(value_range.x, value_range.y)

static func shift_hue(color : Color, amount : float) -> Color:
	color.h = fposmod(color.h + amount, 1.0)
	return color

# Builds one variant: jittered polygon outline, rasterized mask, dithered pixel texture.
static func _build(tag : int) -> Dictionary:
	var profile : Dictionary = PROFILES.get(tag, PROFILES[Debris.Tag.NULL])
	var outline := _build_outline(profile)
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for vertex in outline:
		bounds = bounds.expand(vertex)
	var grid_size := Vector2i((bounds.size / PX).ceil()) + Vector2i.ONE * EDGE_PADDING
	var occluder := PackedVector2Array()
	var texture_polygon := PackedVector2Array()
	for vertex in outline:
		occluder.append(vertex - bounds.get_center())
		texture_polygon.append(occluder[-1] / PX + Vector2(grid_size) * HALF)
	var base_color := _randomize_color(profile.color)
	var image := _paint(_rasterize(grid_size, texture_polygon), grid_size, base_color, profile)
	return {tex = ImageTexture.create_from_image(image), poly = occluder, size = bounds.size,
			color = base_color, light = profile.light}

# A rotated, stretched, jittered polygon; jagged profiles pull alternate vertices inward.
static func _build_outline(profile : Dictionary) -> PackedVector2Array:
	var side_count := randi_range(profile.sides.x, profile.sides.y)
	var radius := random_in(profile.radius)
	var aspect := random_in(profile.aspect)
	var tilt := randf() * TAU
	var start_angle := randf() * TAU
	var outline := PackedVector2Array()
	for side_index in side_count:
		var angle := start_angle + (side_index + randf_range(-ANGLE_JITTER, ANGLE_JITTER)) * TAU / side_count
		var vertex_radius : float = radius * (1.0 + randf_range(-profile.jitter, profile.jitter))
		if side_index % JAG_VERTEX_INTERVAL == 1:
			vertex_radius *= 1.0 - profile.jag * random_in(JAG_RANGE)
		outline.append(Vector2(cos(angle) * vertex_radius * aspect, sin(angle) * vertex_radius).rotated(tilt))
	return outline

# Flat byte mask: 1 where a pixel center lies inside the polygon.
static func _rasterize(grid_size : Vector2i, polygon : PackedVector2Array) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(grid_size.x * grid_size.y)
	for row in grid_size.y:
		for column in grid_size.x:
			if Geometry2D.is_point_in_polygon(Vector2(column + HALF, row + HALF), polygon):
				mask[row * grid_size.x + column] = 1
	return mask

static func _is_solid(mask : PackedByteArray, grid_size : Vector2i, cell : Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, grid_size).has_point(cell) and mask[cell.y * grid_size.x + cell.x] == 1

static func _randomize_color(color : Color) -> Color:
	color = shift_hue(color, randf_range(-HUE_JITTER, HUE_JITTER))
	color.s = clampf(color.s * random_in(SATURATION_RANGE), 0.0, 1.0)
	color.v = clampf(color.v * random_in(VALUE_RANGE), 0.0, 1.0)
	return color

# Darkest-to-lightest tones used by the noise dither.
static func _make_tones(base_color : Color, profile : Dictionary) -> Array[Color]:
	var tones : Array[Color] = []
	for level in profile.levels:
		var depth_ratio = 1.0 - float(level) / (profile.levels - 1)
		tones.append(base_color.darkened(profile.depth * TONE_DEPTH_SCALE * depth_ratio))
	return tones

# Noise remapped to 0..1 and ordered-dithered (Bayer) between the nearest two tones.
static func _dithered_tone(noise : FastNoiseLite, cell : Vector2i, tones : Array[Color]) -> Color:
	var top_level := tones.size() - 1
	var scaled := clampf(noise.get_noise_2d(cell.x, cell.y) * HALF + HALF, 0.0, 1.0) * top_level
	var level := floorf(scaled)
	var threshold = (BAYER[(cell.y % BAYER_SIZE) * BAYER_SIZE + cell.x % BAYER_SIZE] + HALF) / BAYER.size()
	return tones[mini(int(level) + int(scaled - level > threshold), top_level)]

# Paints highlight on top/left edges, shadow on bottom/right, dithered noise inside, and a dark outline.
static func _paint(mask : PackedByteArray, grid_size : Vector2i, base_color : Color, profile : Dictionary) -> Image:
	var tones := _make_tones(base_color, profile)
	var highlight := base_color.lightened(HIGHLIGHT_LIGHTEN)
	var shadow := tones[0].darkened(SHADOW_DARKEN)
	var outline_color := base_color.darkened(OUTLINE_DARKEN)
	var noise := FastNoiseLite.new()
	noise.noise_type = profile.noise
	noise.frequency = profile.freq
	noise.seed = randi()
	var image := Image.create(grid_size.x, grid_size.y, false, Image.FORMAT_RGBA8)
	for row in grid_size.y:
		for column in grid_size.x:
			var cell := Vector2i(column, row)
			var solid_neighbors := NEIGHBOR_OFFSETS.map(func(offset : Vector2i) -> bool: return _is_solid(mask, grid_size, cell + offset))
			if not _is_solid(mask, grid_size, cell):
				if solid_neighbors.has(true):
					image.set_pixelv(cell, outline_color)
			elif not (solid_neighbors[0] and solid_neighbors[1]):
				image.set_pixelv(cell, highlight)
			elif not (solid_neighbors[2] and solid_neighbors[3]):
				image.set_pixelv(cell, shadow)
			else:
				image.set_pixelv(cell, _dithered_tone(noise, cell, tones))
	return image