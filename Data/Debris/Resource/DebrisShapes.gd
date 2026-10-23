class_name DebrisShapes

const VARIANTS := 6

const PROFILES := {
	Debris.Tag.NULL:
		{
			sides = Vector2i(6, 7),
			radius = Vector2(14, 20),
			jitter = 0.2,
			jag = 0.0,
			aspect = Vector2(1.0, 1.2),
			color = Color(0.5, 0.5, 0.5),
			light = Color(1, 1, 1)
		},
	Debris.Tag.PLASTIC:
		{
			sides = Vector2i(9, 11),
			radius = Vector2(14, 22),
			jitter = 0.1,
			jag = 0.0,
			aspect = Vector2(1.0, 1.5),
			color = Color(0.25, 0.6, 0.9),
			light = Color(0.4, 0.8, 1.0)
		},
	Debris.Tag.METAL:
		{
			sides = Vector2i(6, 8),
			radius = Vector2(16, 26),
			jitter = 0.15,
			jag = 0.45,
			aspect = Vector2(1.5, 2.3),
			color = Color(0.6, 0.65, 0.7),
			light = Color(1.0, 0.7, 0.3)
		},
	Debris.Tag.CEMENT:
		{
			sides = Vector2i(5, 7),
			radius = Vector2(18, 26),
			jitter = 0.28, jag = 0.0,
			aspect = Vector2(1.0, 1.25),
			color = Color(0.55, 0.5, 0.42),
			light = Color(1.0, 0.4, 0.3)
		},
}

const TEX_SIZE := 32   # must be a multiple of 4 so the Bayer pattern tiles cleanly

const BAYER := [
	0, 8, 2, 10,
	12, 4, 14, 6,
	3, 11, 1, 9,
	15, 7, 13, 5,
]

# levels = number of tones, depth = how dark the darkest tone gets (0..1)
const SURFACES := {
	Debris.Tag.NULL:
		{noise = FastNoiseLite.TYPE_SIMPLEX,
		freq = 0.06,
		levels = 3,
		depth = 0.12
	},
	Debris.Tag.PLASTIC:
		{noise = FastNoiseLite.TYPE_SIMPLEX_SMOOTH,
		freq = 0.04,
		levels = 3,
		depth = 0.08
	},
	Debris.Tag.METAL:
		{noise = FastNoiseLite.TYPE_PERLIN,
		freq = 0.10,
		levels = 4,
		depth = 0.18
	},
	Debris.Tag.CEMENT:
		{noise = FastNoiseLite.TYPE_CELLULAR,
		freq = 0.09,
		levels = 3,
		depth = 0.22
	},
}

static var _tex := {}

static func surface(tag : int) -> Texture2D:
	if _tex.has(tag):
		return _tex[tag]

	var s : Dictionary = SURFACES.get(tag, SURFACES[Debris.Tag.NULL])
	var fn := FastNoiseLite.new()
	fn.noise_type = s.noise
	fn.frequency = s.freq
	fn.seed = randi()   # randomized once per tag, then cached

	var src := fn.get_seamless_image(TEX_SIZE, TEX_SIZE)
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var top : int = s.levels - 1

	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var n := src.get_pixel(x, y).r                  # 0..1
			var threshold = (BAYER[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0
			var scaled := n * top
			var level := floorf(scaled)
			if scaled - level > threshold:
				level += 1.0
			var shade = 1.0 - s.depth * (1.0 - level / top)
			img.set_pixel(x, y, Color(shade, shade, shade, 1.0))

	_tex[tag] = ImageTexture.create_from_image(img)
	return _tex[tag]

static func make(tag : int) -> Dictionary:
	var p : Dictionary = PROFILES.get(tag, PROFILES[Debris.Tag.NULL])
	var n := randi_range(p.sides.x, p.sides.y)
	var r := randf_range(p.radius.x, p.radius.y)
	var asp := randf_range(p.aspect.x, p.aspect.y)
	var rot := randf() * TAU
	var off := randf() * TAU
	var pts := PackedVector2Array()
	pts.resize(n)
	var mn := Vector2(INF, INF)
	var mx := -mn
	for k in n:
		var a := off + (k + randf_range(-0.3, 0.3)) * TAU / n
		var rr := r * (1.0 + randf_range(-p.jitter, p.jitter))
		if k % 2 == 1:
			rr *= 1.0 - p.jag * randf_range(0.6, 1.2)
		var q := Vector2(cos(a) * rr * asp, sin(a) * rr).rotated(rot)
		pts[k] = q
		mn = mn.min(q)
		mx = mx.max(q)
	var c : Color = p.color
	c.h = fposmod(c.h + randf_range(-0.05, 0.05), 1.0)
	c.s = clampf(c.s * randf_range(0.7, 1.2), 0.0, 1.0)
	c.v = clampf(c.v * randf_range(0.75, 1.2), 0.0, 1.0)
	return {poly = pts, size = mx - mn, center = (mn + mx) * 0.5, color = c, light = p.light}