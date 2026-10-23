class_name AsteroidShapes

const VARIANTS := 8
const TEX_SIZE := 64
const TEXEL := 4.0   # world px per texture pixel; match your game's pixel size

const BAYER_BITS := 3                       # 8x8 matrix
const BAYER_N := 1 << BAYER_BITS

## depth = how dark the darkest tone gets (0..1), levels = number of tones,
## detail = how much of a second, finer noise layer is mixed in.
const SURFACES := [
	{noise = FastNoiseLite.TYPE_SIMPLEX, freq = 0.07, levels = 4, depth = 0.45, detail = 0.30},
	{noise = FastNoiseLite.TYPE_SIMPLEX, freq = 0.05, levels = 5, depth = 0.55, detail = 0.35},
	{noise = FastNoiseLite.TYPE_CELLULAR, freq = 0.035, levels = 5, depth = 0.65, detail = 0.40},
]
const BASE_SEED := 7741

const PROFILES := [
	{ # SMALL: fast-ish, dodge-able
		sides = Vector2i(12, 16),
		radius = Vector2(70, 110),
		aspect = Vector2(1.0, 1.35),
		lumps = 0.14,
		jitter = 0.06,
		craters = Vector2i(0, 1),
		crater_size = Vector2(0.25, 0.4),   # half-width in radians
		crater_depth = Vector2(0.10, 0.18),
		color = Color(0.46, 0.42, 0.39),
		light = Color(1.0, 0.75, 0.45)
	},
	{ # MEDIUM
		sides = Vector2i(16, 22),
		radius = Vector2(160, 240),
		aspect = Vector2(1.0, 1.35),
		lumps = 0.20,
		jitter = 0.05,
		craters = Vector2i(1, 3),
		crater_size = Vector2(0.2, 0.4),
		crater_depth = Vector2(0.10, 0.22),
		color = Color(0.40, 0.37, 0.35),
		light = Color(1.0, 0.7, 0.4)
	},
	{ # LARGE: slow walls you have to route around
		sides = Vector2i(24, 34),
		radius = Vector2(340, 520),
		aspect = Vector2(1.0, 1.25),
		lumps = 0.24,
		jitter = 0.04,
		craters = Vector2i(3, 6),
		crater_size = Vector2(0.15, 0.35),
		crater_depth = Vector2(0.08, 0.2),
		color = Color(0.34, 0.32, 0.33),
		light = Color(1.0, 0.65, 0.35)
	},
]

const BAYER := [
	0, 8, 2, 10,
	12, 4, 14, 6,
	3, 11, 1, 9,
	15, 7, 13, 5,
]

static var _cache : Array = [[], [], []]
static var _tex : Array = [null, null, null]

static func warm() -> void:
	for s in 3:
		if _cache[s].is_empty():
			for i in VARIANTS:
				_cache[s].append(_generate(s, i))

static func variant(size : int, idx : int) -> Dictionary:
	if _cache[size].is_empty():
		warm()
	return _cache[size][idx % VARIANTS]

static func max_radius(size : int) -> float:
	var m := 0.0
	for i in VARIANTS:
		m = maxf(m, variant(size, i).radius)
	return m

static var _bayer : PackedFloat32Array = PackedFloat32Array()

static func _bayer_matrix() -> PackedFloat32Array:
	if not _bayer.is_empty():
		return _bayer
	_bayer.resize(BAYER_N * BAYER_N)
	for y in BAYER_N:
		for x in BAYER_N:
			var v := 0
			for i in BAYER_BITS:
				var xb := (x >> i) & 1
				var yb := (y >> i) & 1
				v = (v << 2) | (((xb ^ yb) << 1) | yb)
			_bayer[y * BAYER_N + x] = (v + 0.5) / float(BAYER_N * BAYER_N)
	return _bayer

static func surface(size : int) -> Texture2D:
	if _tex[size] != null:
		return _tex[size]

	var s : Dictionary = SURFACES[size]
	var bayer := _bayer_matrix()

	var fn := FastNoiseLite.new()
	fn.noise_type = s.noise
	fn.frequency = s.freq
	fn.seed = BASE_SEED + size
	var base := fn.get_seamless_image(TEX_SIZE, TEX_SIZE)

	var fn2 := FastNoiseLite.new()
	fn2.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fn2.frequency = s.freq * 3.0
	fn2.seed = BASE_SEED + size + 100
	var fine := fn2.get_seamless_image(TEX_SIZE, TEX_SIZE)

	var vals := PackedFloat32Array()
	vals.resize(TEX_SIZE * TEX_SIZE)
	var lo := INF
	var hi := -INF
	var detail : float = s.detail
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var v := lerpf(base.get_pixel(x, y).r, fine.get_pixel(x, y).r, detail)
			vals[y * TEX_SIZE + x] = v
			lo = minf(lo, v)
			hi = maxf(hi, v)
	var span := maxf(hi - lo, 0.0001)

	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var top : int = s.levels - 1
	var depth : float = s.depth

	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var n := (vals[y * TEX_SIZE + x] - lo) / span
			var threshold := bayer[(y % BAYER_N) * BAYER_N + (x % BAYER_N)]
			var scaled := n * top
			var level := floorf(scaled)
			if scaled - level > threshold:
				level += 1.0
			var shade := 1.0 - depth * (1.0 - level / top)
			img.set_pixel(x, y, Color(shade, shade, shade, 1.0))

	_tex[size] = ImageTexture.create_from_image(img)
	return _tex[size]

static func _generate(size : int, idx : int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = BASE_SEED + size * 1000 + idx * 17

	var p : Dictionary = PROFILES[size]
	var n := rng.randi_range(p.sides.x, p.sides.y)
	var r := rng.randf_range(p.radius.x, p.radius.y)
	var asp := rng.randf_range(p.aspect.x, p.aspect.y)
	var rot := rng.randf() * TAU
	var lumps : float = p.lumps
	var jitter : float = p.jitter

	var harmonics : Array[Vector3] = []
	for k in range(2, 6):
		harmonics.append(Vector3(k, lumps / k * rng.randf_range(0.5, 1.0), rng.randf() * TAU))

	var craters : Array[Vector3] = []
	for _c in rng.randi_range(p.craters.x, p.craters.y):
		craters.append(Vector3(
			rng.randf() * TAU,
			rng.randf_range(p.crater_size.x, p.crater_size.y),
			rng.randf_range(p.crater_depth.x, p.crater_depth.y)))

	var pts := PackedVector2Array()
	pts.resize(n)
	var step := TAU / n
	var rmax := 0.0
	for k in n:
		var a := (k + rng.randf_range(-0.3, 0.3)) * step
		var rr := 1.0
		for h in harmonics:
			rr += h.y * sin(h.x * a + h.z)
		for cr in craters:
			var d := absf(angle_difference(a, cr.x))
			if d < cr.y:
				rr -= cr.z * 0.5 * (1.0 + cos(PI * d / cr.y))
		rr += rng.randf_range(-jitter, jitter)
		rr = maxf(rr, 0.45)
		var q := Vector2(cos(a) * rr * asp, sin(a) * rr).rotated(rot) * r
		pts[k] = q
		rmax = maxf(rmax, q.length())

	var hull := Geometry2D.convex_hull(pts)
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.remove_at(hull.size() - 1)
	var shape := ConvexPolygonShape2D.new()
	shape.points = hull

	var occ := OccluderPolygon2D.new()
	occ.polygon = pts

	var uv := PackedVector2Array()
	uv.resize(n)
	for k in n:
		uv[k] = pts[k] / TEXEL

	var col : Color = p.color
	col.h = fposmod(col.h + rng.randf_range(-0.04, 0.04), 1.0)
	col.s = clampf(col.s * rng.randf_range(0.7, 1.2), 0.0, 1.0)
	col.v = clampf(col.v * rng.randf_range(0.85, 1.15), 0.0, 1.0)

	var pieces : Array[ConvexPolygonShape2D] = []
	for part in Geometry2D.decompose_polygon_in_convex(pts):
		var cs := ConvexPolygonShape2D.new()
		cs.points = part
		pieces.append(cs)
	if pieces.is_empty():
		pieces.append(shape)   # convex hull fallback

	return {poly = pts, uv = uv, shape = shape, shapes = pieces, occluder = occ,
		radius = rmax, color = col, light = p.light}