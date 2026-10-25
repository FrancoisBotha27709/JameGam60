class_name AsteroidShapes

const VARIANTS := 8
const TEXEL := 4.0
const BASE_SEED := 7741

const BAYER_BITS := 3
const BAYER_N := 1 << BAYER_BITS

const SURFACES := [
	{noise = FastNoiseLite.TYPE_SIMPLEX, freq = 0.28, levels = 4, depth = 0.45, detail = 0.30},
	{noise = FastNoiseLite.TYPE_SIMPLEX, freq = 0.20, levels = 5, depth = 0.55, detail = 0.35},
	{noise = FastNoiseLite.TYPE_CELLULAR, freq = 0.14, levels = 5, depth = 0.65, detail = 0.40},
]

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
const WARM_TOTAL := 3 * VARIANTS

static var _cache : Array = [[], [], []]
static var _bayer := PackedFloat32Array()

static var _warm_i := 0

static func warm_step() -> bool:
	if _warm_i < WARM_TOTAL:
		var s := _warm_i / VARIANTS
		_cache[s].append(_generate(s, _warm_i % VARIANTS))
		_warm_i += 1
	return _warm_i >= WARM_TOTAL


static func warm() -> void:
	while not warm_step():
		pass

static func variant(size : int, idx : int) -> Dictionary:
	if _cache[size].is_empty():
		warm()
	return _cache[size][idx % VARIANTS]

static func max_radius(size : int) -> float:
	var m := 0.0
	for i in VARIANTS:
		m = maxf(m, variant(size, i).radius)
	return m

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

static func _solid(m : PackedByteArray, w : int, h : int, x : int, y : int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h and m[y * w + x] == 1

static func _px(d : PackedByteArray, i : int, c : Color) -> void:
	i *= 4
	d[i] = c.r8
	d[i + 1] = c.g8
	d[i + 2] = c.b8
	d[i + 3] = 255

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
	var hull_shape := ConvexPolygonShape2D.new()
	hull_shape.points = hull

	var pieces : Array[ConvexPolygonShape2D] = []
	for part in Geometry2D.decompose_polygon_in_convex(pts):
		var cs := ConvexPolygonShape2D.new()
		cs.points = part
		pieces.append(cs)
	if pieces.is_empty():
		pieces.append(hull_shape)

	var occ := OccluderPolygon2D.new()
	occ.polygon = pts

	var col : Color = p.color
	col.h = fposmod(col.h + rng.randf_range(-0.04, 0.04), 1.0)
	col.s = clampf(col.s * rng.randf_range(0.7, 1.2), 0.0, 1.0)
	col.v = clampf(col.v * rng.randf_range(0.85, 1.15), 0.0, 1.0)

	var baked := _bake(pts, SURFACES[size], col, rng)

	return {poly = pts, shape = hull_shape, shapes = pieces, occluder = occ,
		radius = rmax, color = col, light = p.light,
		tex = baked.tex, tex_offset = baked.offset}

static func _bake(pts : PackedVector2Array, s : Dictionary, col : Color,
		rng : RandomNumberGenerator) -> Dictionary:
	var mn := Vector2(INF, INF)
	var mx := -mn
	for q in pts:
		mn = mn.min(q)
		mx = mx.max(q)
	var ctr := (mn + mx) * 0.5
	var w := ceili((mx.x - mn.x) / TEXEL) + 4   # 2px margin for the outline
	var h := ceili((mx.y - mn.y) / TEXEL) + 4
	var half := Vector2(w, h) * 0.5

	var gp := PackedVector2Array()
	for q in pts:
		gp.append((q - ctr) / TEXEL + half)

	var mask := _fill_mask(gp, w, h)

	var top : int = s.levels - 1
	var tones : Array[Color] = []
	for i in s.levels:
		var sh : float = 1.0 - s.depth * (1.0 - float(i) / top)
		tones.append(Color(col.r * sh, col.g * sh, col.b * sh))
	var hi := col.lightened(0.3)
	var lo := tones[0].darkened(0.25)
	var line := col.darkened(0.85)

	var f1 := FastNoiseLite.new()
	f1.noise_type = s.noise
	f1.frequency = s.freq
	f1.seed = rng.randi()
	var f2 := FastNoiseLite.new()
	f2.noise_type = FastNoiseLite.TYPE_SIMPLEX
	f2.frequency = s.freq * 3.0
	f2.seed = rng.randi()

	var detail : float = s.detail
	var bayer := _bayer_matrix()
	var rx := (mx.x - mn.x) / TEXEL * 0.5 + 1.0
	var ry := (mx.y - mn.y) / TEXEL * 0.5 + 1.0
	var light := Vector3(-0.5, -0.55, 0.65)

	var data := PackedByteArray()
	data.resize(w * h * 4)   # zero-filled = transparent
	for y in h:
		for x in w:
			var i := y * w + x
			if mask[i] == 1:
				if not _solid(mask, w, h, x - 1, y) or not _solid(mask, w, h, x, y - 1):
					_px(data, i, hi)
				elif not _solid(mask, w, h, x + 1, y) or not _solid(mask, w, h, x, y + 1):
					_px(data, i, lo)
				else:
					var nx := (x + 0.5 - half.x) / rx
					var ny := (y + 0.5 - half.y) / ry
					var nz := sqrt(maxf(1.0 - nx * nx - ny * ny, 0.0))
					var lam := clampf(light.x * nx + light.y * ny + light.z * nz, 0.0, 1.0)
					var nv := clampf(lerpf(f1.get_noise_2d(x, y), f2.get_noise_2d(x, y), detail) * 0.7 + 0.5, 0.0, 1.0)
					var sc := clampf((0.55 * nv + 0.45 * lam) * 1.15, 0.0, 1.0) * top
					var lv := floorf(sc)
					if sc - lv > bayer[(y % BAYER_N) * BAYER_N + (x % BAYER_N)]:
						lv += 1.0
					_px(data, i, tones[mini(int(lv), top)])
			elif _solid(mask, w, h, x - 1, y) or _solid(mask, w, h, x + 1, y) \
					or _solid(mask, w, h, x, y - 1) or _solid(mask, w, h, x, y + 1):
				_px(data, i, line)

	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	return {tex = ImageTexture.create_from_image(img), offset = ctr / TEXEL}

## Scanline polygon fill: far cheaper than is_point_in_polygon per pixel.
static func _fill_mask(gp : PackedVector2Array, w : int, h : int) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(w * h)
	var n := gp.size()
	var xs : Array[float] = []
	for y in h:
		var sy := y + 0.5
		xs.clear()
		for i in n:
			var a := gp[i]
			var b := gp[(i + 1) % n]
			if (a.y <= sy) != (b.y <= sy):
				xs.append(a.x + (sy - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		for k in range(0, xs.size() - 1, 2):
			var x0 := maxi(ceili(xs[k] - 0.5), 0)
			var x1 := mini(ceili(xs[k + 1] - 0.5) - 1, w - 1)
			for x in range(x0, x1 + 1):
				mask[y * w + x] = 1
	return mask