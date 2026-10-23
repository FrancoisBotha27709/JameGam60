@tool
class_name SpaceLight
extends PointLight2D

enum Dither {
	NONE,
	BAYER_2X2,
	BAYER_4X4,
	BAYER_8X8,
	CHECKER,
	INTERLEAVED_GRADIENT,
	NOISE,
}

const TEX_SIZE := 128
static var _img_cache := {}

@export_range(0.0, 8.0, 0.01) var intensity := 1.0:
	set(v):
		intensity = v
		if is_node_ready() and not _batch:
			energy = v
@export_range(8.0, 4000.0, 1.0, "suffix:px") var radius := 200.0:
	set(v): radius = v; _rebuild()
@export_range(0.25, 6.0, 0.05) var falloff := 2.0:
	set(v): falloff = v; _rebuild()
@export var shape := LightPreset.Shape.POINT:
	set(v): shape = v; _rebuild()
@export_range(5.0, 180.0, 1.0, "suffix:°") var cone_angle := 60.0:
	set(v): cone_angle = v; _rebuild()
@export var cast_shadows := false:
	set(v):
		cast_shadows = v
		shadow_enabled = v
		_rebuild()
@export var affect_background := true:
	set(v): affect_background = v; _apply_range()
@export var preset : LightPreset:
	set(v):
		preset = v
		if v != null and is_node_ready():
			apply_preset(v)

@export_group("Pixel Look")
@export var dither : Dither = Dither.BAYER_4X4:
	set(v): dither = v; _rebuild()
@export_range(2, 16, 1) var dither_levels := 4:
	set(v): dither_levels = v; _rebuild()
@export_range(1, 8, 1) var pixel_size := 1:
	set(v): pixel_size = v; _rebuild()
@export_range(0.0, 1.0, 0.01) var shadow_dither := 0.0:
	set(v): shadow_dither = v; _rebuild()
@export_group("Shadow Range")
@export_range(0.0, 4000.0, 1.0, "suffix:px") var shadow_range := 0.0:
	set(v): shadow_range = v; _rebuild()
@export_range(0.0, 1.0, 0.01) var shadow_fade := 0.5:
	set(v): shadow_fade = v; _rebuild()

@export_group("Animation")
@export_range(0.0, 1.0, 0.01) var flicker := 0.0:
	set(v): flicker = v; _refresh_processing()
@export_range(0.1, 30.0, 0.1) var flicker_speed := 8.0
@export_range(0.0, 1.0, 0.01) var pulse := 0.0:
	set(v): pulse = v; _refresh_processing()
@export_range(0.05, 10.0, 0.05, "suffix:Hz") var pulse_speed := 1.0

@export_group("Lifetime (0 = forever)")
@export_range(0.0, 60.0, 0.05, "suffix:s") var lifetime := 0.0:
	set(v): lifetime = v; _refresh_processing()
@export_range(0.0, 10.0, 0.01, "suffix:s") var fade_in := 0.0
@export_range(0.0, 10.0, 0.01, "suffix:s") var fade_out := 0.0

@export_group("Culling")
@export var cullable := true

var _age := 0.0
var _offset := 0.0
var _batch := false
var _rebuild_queued := false
var _fill : PointLight2D
var _tex_main : ImageTexture
var _tex_fill : ImageTexture

func _validate_property(property: Dictionary) -> void:
	if property.name == "texture":
		property.usage = PROPERTY_USAGE_NONE

func _enter_tree() -> void:
	add_to_group(&"space_lights")

func _ready() -> void:
	_offset = randf() * 100.0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # no bilinear blur
	shadow_enabled = cast_shadows
	_apply_range()
	_rebuild()
	_refresh_processing()
	if not Engine.is_editor_hint():
		_animate(0.0)

func apply_preset(p: LightPreset) -> void:
	_batch = true
	color = p.color
	intensity = p.energy
	radius = p.radius
	falloff = p.falloff
	shape = p.shape
	cone_angle = p.cone_angle
	cast_shadows = p.cast_shadows
	shadow_range = p.shadow_range
	shadow_fade = p.shadow_fade
	shadow_dither = p.shadow_dither
	flicker = p.flicker; flicker_speed = p.flicker_speed
	pulse = p.pulse; pulse_speed = p.pulse_speed
	lifetime = p.lifetime; fade_in = p.fade_in; fade_out = p.fade_out
	_batch = false
	_rebuild()

func _apply_range() -> void:
	var layers := 128 if affect_background else 0
	range_layer_min = -layers
	range_layer_max = layers
	var z := 4096 if affect_background else 1024
	range_z_min = -z
	range_z_max = z
	_sync_fill(true)

func _rebuild() -> void:
	if _batch or not is_node_ready() or _rebuild_queued:
		return
	_rebuild_queued = true
	_do_rebuild.call_deferred()

func _do_rebuild() -> void:
	_rebuild_queued = false
	if not is_inside_tree():
		return
	var limited := cast_shadows and shadow_range > 0.0 and shadow_range < radius
	var split := cast_shadows and (limited or shadow_dither > 0.0)
	var a := 0.0
	var b := 0.0
	if limited:
		b = shadow_range / radius
		a = b * (1.0 - shadow_fade)
	_set_main_image(_get_image(shape, falloff, cone_angle, a, b, 1 if split else 0, shadow_dither, dither, dither_levels, pixel_size))
	texture_scale = radius / (TEX_SIZE * 0.5)
	energy = intensity
	if split:
		if _fill == null:
			_fill = PointLight2D.new()
			_fill.shadow_enabled = false
			_fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_fill, false, Node.INTERNAL_MODE_BACK)
			_tex_fill = null
		_set_fill_image(_get_image(shape, falloff, cone_angle, a, b, 2, shadow_dither, dither, dither_levels, pixel_size))
	elif _fill != null:
		_fill.queue_free()
		_fill = null
		_tex_fill = null
	_refresh_processing()
	_sync_fill(true)

func _set_main_image(img: Image) -> void:
	if _tex_main == null:
		_tex_main = ImageTexture.create_from_image(img)
		texture = _tex_main
	else:
		_tex_main.update(img)

func _set_fill_image(img: Image) -> void:
	if _tex_fill == null:
		_tex_fill = ImageTexture.create_from_image(img)
		_fill.texture = _tex_fill
	else:
		_tex_fill.update(img)

func _sync_fill(full := false) -> void:
	if _fill == null:
		return
	_fill.color = color
	_fill.energy = energy
	_fill.enabled = enabled
	if full:
		_fill.blend_mode = blend_mode
		_fill.offset = offset
		_fill.texture_scale = texture_scale
		_fill.range_item_cull_mask = range_item_cull_mask
		_fill.range_layer_min = range_layer_min
		_fill.range_layer_max = range_layer_max
		_fill.range_z_min = range_z_min
		_fill.range_z_max = range_z_max

func _refresh_processing() -> void:
	set_process(flicker > 0.0 or pulse > 0.0 or lifetime > 0.0 or _fill != null)

func _process(delta: float) -> void:
	_age += delta
	_animate(delta)
	_sync_fill()

func _animate(_delta: float) -> void:
	var m := 1.0
	var t := _age + _offset
	if pulse > 0.0:
		m *= 1.0 - pulse * 0.5 * (1.0 + sin(t * pulse_speed * TAU))
	if flicker > 0.0:
		var n := (sin(t * flicker_speed) + sin(t * flicker_speed * 2.3 + 1.7) \
				+ sin(t * flicker_speed * 4.1 + 4.2)) / 3.0
		m *= 1.0 - flicker * (0.5 + 0.5 * n)
	if lifetime > 0.0 and not Engine.is_editor_hint():
		if fade_in > 0.0 and _age < fade_in:
			m *= _age / fade_in
		var remaining := lifetime - _age
		if fade_out > 0.0 and remaining < fade_out:
			m *= maxf(remaining / fade_out, 0.0)
		if remaining <= 0.0:
			queue_free()
			return
	if enabled:  # skip work while culled
		energy = intensity * m

static func _get_image(shp: int, fall: float, cone: float, a: float, b: float, mask: int, leak: float,
		dither_type: int, levels: int, cell: int) -> Image:
	if mask == 0:
		a = 0.0
		b = 0.0
		leak = 0.0
	cell = maxi(cell, 1)
	levels = maxi(levels, 2)
	var cone_i := roundi(cone) if shp == LightPreset.Shape.CONE else 0
	var key := "%d|%d|%d|%d|%d|%d|%d|%d|%d|%d" % [shp, roundi(fall * 20.0), cone_i,
			roundi(a * 100.0), roundi(b * 100.0), mask, roundi(leak * 100.0), dither_type, levels, cell]
	if _img_cache.has(key):
		return _img_cache[key]
	var bb := maxf(b, a + 0.001)
	var sd := dither_type if dither_type != Dither.NONE else Dither.BAYER_4X4
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var c := (TEX_SIZE - 1) * 0.5
	var half := deg_to_rad(cone) * 0.5
	for y in TEX_SIZE:
		var cy := floori(float(y) / cell)
		var sy := (cy + 0.5) * cell - 0.5
		for x in TEX_SIZE:
			var cx := floori(float(x) / cell)
			var sx := (cx + 0.5) * cell - 0.5
			var d := Vector2(sx - c, sy - c)
			var t := d.length() / c
			var v := pow(clampf(1.0 - t, 0.0, 1.0), fall)
			if shp == LightPreset.Shape.CONE:
				v *= 1.0 - smoothstep(half * 0.6, half, absf(d.angle()))  # points along +X
			if mask != 0:
				var s := smoothstep(a, bb, t) if b > 0.0 else 0.0
				if _threshold(sd, cx + 2, cy + 1) < leak:   # shifted to decorrelate from value dither
					s = 1.0
				v *= (1.0 - s) if mask == 1 else s
			if dither_type != Dither.NONE:
				v = _dither_value(v, cx, cy, dither_type, levels)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	_img_cache[key] = img
	return img

static func _dither_value(v: float, x: int, y: int, type: int, levels: int) -> float:
	var steps := float(levels - 1)
	var scaled := clampf(v, 0.0, 1.0) * steps
	var lo := floorf(scaled)
	var frac := scaled - lo
	if frac > _threshold(type, x, y):
		lo += 1.0
	return clampf(lo / steps, 0.0, 1.0)

static func _threshold(type: int, x: int, y: int) -> float:
	match type:
		Dither.BAYER_2X2:
			return (_bayer(x & 1, y & 1, 1) + 0.5) / 4.0
		Dither.BAYER_4X4:
			return (_bayer(x & 3, y & 3, 2) + 0.5) / 16.0
		Dither.BAYER_8X8:
			return (_bayer(x & 7, y & 7, 3) + 0.5) / 64.0
		Dither.CHECKER:
			return 0.75 if ((x + y) & 1) == 1 else 0.25
		Dither.INTERLEAVED_GRADIENT:
			var inner := fmod(0.06711056 * x + 0.00583715 * y, 1.0)
			return fmod(52.9829189 * inner, 1.0)
		Dither.NOISE:
			return _hash01(x, y)
	return 0.5

static func _bayer(x: int, y: int, bits: int) -> int:
	var v := 0
	for i in bits:
		var xb := (x >> i) & 1
		var yb := (y >> i) & 1
		v = (v << 2) | (((xb ^ yb) << 1) | yb)
	return v

static func _hash01(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65536.0