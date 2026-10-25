class_name DebrisShapes

const VARIANTS := 6
const PX := 2

const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

const PROFILES := {
	Debris.Tag.NULL: {sides = Vector2i(6, 7), radius = Vector2(14, 20), jitter = 0.2, jag = 0.0,
		aspect = Vector2(1.0, 1.2), color = Color(0.5, 0.5, 0.5), light = Color(1, 1, 1)},
	Debris.Tag.PLASTIC: {sides = Vector2i(9, 11), radius = Vector2(14, 22), jitter = 0.1, jag = 0.0,
		aspect = Vector2(1.0, 1.5), color = Color(0.25, 0.6, 0.9), light = Color(0.4, 0.8, 1.0)},
	Debris.Tag.METAL: {sides = Vector2i(6, 8), radius = Vector2(16, 26), jitter = 0.15, jag = 0.45,
		aspect = Vector2(1.5, 2.3), color = Color(0.6, 0.65, 0.7), light = Color(1.0, 0.7, 0.3)},
	Debris.Tag.CEMENT: {sides = Vector2i(5, 7), radius = Vector2(18, 26), jitter = 0.28, jag = 0.0,
		aspect = Vector2(1.0, 1.25), color = Color(0.55, 0.5, 0.42), light = Color(1.0, 0.4, 0.3)},
}

const SURFACES := {
	Debris.Tag.NULL: {noise = FastNoiseLite.TYPE_SIMPLEX, freq = 0.18, levels = 3, depth = 0.12},
	Debris.Tag.PLASTIC: {noise = FastNoiseLite.TYPE_SIMPLEX_SMOOTH, freq = 0.12, levels = 3, depth = 0.08},
	Debris.Tag.METAL: {noise = FastNoiseLite.TYPE_PERLIN, freq = 0.25, levels = 4, depth = 0.18},
	Debris.Tag.CEMENT: {noise = FastNoiseLite.TYPE_CELLULAR, freq = 0.22, levels = 3, depth = 0.22},
}

static var _cache := {}   # tag -> Array[Dictionary]

static func make(tag : int) -> Dictionary:
	var list : Array = _cache.get(tag, [])
	if list.size() < VARIANTS:
		list.append(_build(tag))
		_cache[tag] = list
		return list[list.size() - 1]
	return list[randi() % VARIANTS]


static func _solid(m : PackedByteArray, w : int, h : int, x : int, y : int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h and m[y * w + x] == 1


static func _build(tag : int) -> Dictionary:
	var p : Dictionary = PROFILES.get(tag, PROFILES[Debris.Tag.NULL])
	var s : Dictionary = SURFACES.get(tag, SURFACES[Debris.Tag.NULL])

	# --- outline polygon (screen px) ---
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
		var rr : float = r * (1.0 + randf_range(-p.jitter, p.jitter))
		if k % 2 == 1:
			rr *= 1.0 - p.jag * randf_range(0.6, 1.2)
		var q := Vector2(cos(a) * rr * asp, sin(a) * rr).rotated(rot)
		pts[k] = q
		mn = mn.min(q)
		mx = mx.max(q)
	var size := mx - mn
	var ctr := (mn + mx) * 0.5

	var w := ceili(size.x / PX) + 4
	var h := ceili(size.y / PX) + 4
	var half := Vector2(w, h) * 0.5
	var apoly := PackedVector2Array()
	var occ := PackedVector2Array()
	for q in pts:
		apoly.append((q - ctr) / PX + half)
		occ.append(q - ctr)

	var mask := PackedByteArray()
	mask.resize(w * h)
	for y in h:
		for x in w:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), apoly):
				mask[y * w + x] = 1

	var base : Color = p.color
	base.h = fposmod(base.h + randf_range(-0.05, 0.05), 1.0)
	base.s = clampf(base.s * randf_range(0.7, 1.2), 0.0, 1.0)
	base.v = clampf(base.v * randf_range(0.75, 1.2), 0.0, 1.0)
	var top : int = s.levels - 1
	var tones : Array[Color] = []
	for i in s.levels:
		tones.append(base.darkened(s.depth * 2.5 * (1.0 - float(i) / top)))
	var hi := base.lightened(0.35)
	var lo := tones[0].darkened(0.25)
	var line := base.darkened(0.8)

	var fn := FastNoiseLite.new()
	fn.noise_type = s.noise
	fn.frequency = s.freq
	fn.seed = randi()

	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			if mask[y * w + x] == 1:
				var col : Color
				if not _solid(mask, w, h, x - 1, y) or not _solid(mask, w, h, x, y - 1):
					col = hi
				elif not _solid(mask, w, h, x + 1, y) or not _solid(mask, w, h, x, y + 1):
					col = lo
				else:
					var nv := clampf(fn.get_noise_2d(x, y) * 0.5 + 0.5, 0.0, 1.0)
					var sc := nv * top
					var lv := floorf(sc)
					if sc - lv > (BAYER[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0:
						lv += 1.0
					col = tones[mini(int(lv), top)]
				img.set_pixel(x, y, col)
			elif _solid(mask, w, h, x - 1, y) or _solid(mask, w, h, x + 1, y) \
					or _solid(mask, w, h, x, y - 1) or _solid(mask, w, h, x, y + 1):
				img.set_pixel(x, y, line)

	return {tex = ImageTexture.create_from_image(img), poly = occ, size = size,
			color = base, light = p.light}