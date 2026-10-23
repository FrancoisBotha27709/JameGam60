class_name LightPreset
extends Resource

enum Shape { POINT, CONE }

@export var color := Color.WHITE
@export_range(0.0, 8.0, 0.01) var energy := 1.0
@export_range(8.0, 4000.0, 1.0, "suffix:px") var radius := 200.0
@export_range(0.25, 6.0, 0.05) var falloff := 2.0
@export var shape := Shape.POINT
@export_range(5.0, 180.0, 1.0, "suffix:°") var cone_angle := 60.0
@export var cast_shadows := false

@export_group("Shadow Range")
@export_range(0.0, 4000.0, 1.0, "suffix:px") var shadow_range := 0.0
@export_range(0.0, 1.0, 0.01) var shadow_fade := 0.5
@export_range(0.0, 1.0, 0.01) var shadow_dither := 0.0
@export_group("Animation")
@export_range(0.0, 1.0, 0.01) var flicker := 0.0
@export_range(0.1, 30.0, 0.1) var flicker_speed := 8.0
@export_range(0.0, 1.0, 0.01) var pulse := 0.0
@export_range(0.05, 10.0, 0.05, "suffix:Hz") var pulse_speed := 1.0

@export_group("Lifetime (0 = forever)")
@export_range(0.0, 60.0, 0.05, "suffix:s") var lifetime := 0.0
@export_range(0.0, 10.0, 0.01, "suffix:s") var fade_in := 0.0
@export_range(0.0, 10.0, 0.01, "suffix:s") var fade_out := 0.0

static func _make(c: Color, e: float, r: float, f: float = 2.0) -> LightPreset:
	var p := LightPreset.new()
	p.color = c; p.energy = e; p.radius = r; p.falloff = f
	return p

static func _anim(p: LightPreset, flick: float, flick_speed: float,
		pul: float, pul_speed: float) -> LightPreset:
	p.flicker = flick; p.flicker_speed = flick_speed
	p.pulse = pul; p.pulse_speed = pul_speed
	return p

static func library() -> Dictionary:
	return {
		"engine_glow": engine_glow, "engine_ion": engine_ion,
		"engine_fire": engine_fire, "engine_plasma": engine_plasma,
		"cockpit": cockpit, "headlight": headlight, "nav_red": nav_red,
		"nav_green": nav_green, "warning_strobe": warning_strobe,
		"beacon": beacon, "radioactive": radioactive, "sparking": sparking,
		"ember": ember, "crystal": crystal, "lamp": lamp,
		"star": star, "depot_glow": depot_glow,
		"explosion": explosion, "pickup_flash": pickup_flash,
		"debris_plastic": debris_plastic, "debris_metal": debris_metal,
		"debris_cement": debris_cement,
	}

static func engine_glow() -> LightPreset:
	return _anim(_make(Color(0.3, 0.7, 1.0), 1.3, 120.0, 2.5), 0.25, 14.0, 0.0, 1.0)

static func engine_ion() -> LightPreset:
	return _anim(_make(Color(0.45, 0.95, 1.0), 1.1, 100.0, 2.8), 0.1, 20.0, 0.0, 1.0)

static func engine_fire() -> LightPreset:
	return _anim(_make(Color(1.0, 0.5, 0.15), 1.5, 140.0, 2.0), 0.45, 18.0, 0.0, 1.0)

static func engine_plasma() -> LightPreset:
	return _anim(_make(Color(0.8, 0.4, 1.0), 1.4, 130.0, 2.2), 0.15, 12.0, 0.2, 3.0)

static func cockpit() -> LightPreset:
	return _make(Color(0.7, 0.85, 1.0), 0.6, 70.0, 1.5)

static func headlight() -> LightPreset:
	var p := _make(Color(0.9, 0.95, 1.0), 1.4, 420.0, 1.3)
	p.shape = Shape.CONE; p.cone_angle = 50.0; p.cast_shadows = true
	p.shadow_range = 300.0; p.shadow_fade = 0.5
	return p

static func nav_red() -> LightPreset:
	return _anim(_make(Color(1.0, 0.15, 0.1), 1.2, 60.0, 2.0), 0.0, 8.0, 1.0, 0.7)

static func nav_green() -> LightPreset:
	return _anim(_make(Color(0.15, 1.0, 0.3), 1.2, 60.0, 2.0), 0.0, 8.0, 1.0, 0.7)

static func warning_strobe() -> LightPreset:
	return _anim(_make(Color(1.0, 0.35, 0.1), 2.0, 200.0, 1.5), 0.0, 8.0, 1.0, 3.0)

static func beacon() -> LightPreset:
	return _anim(_make(Color(1.0, 0.25, 0.2), 1.5, 220.0, 1.5), 0.0, 8.0, 0.9, 0.8)

static func radioactive() -> LightPreset:
	return _anim(_make(Color(0.4, 1.0, 0.3), 1.0, 130.0, 1.8), 0.0, 8.0, 0.4, 0.4)

static func sparking() -> LightPreset:
	return _anim(_make(Color(0.6, 0.85, 1.0), 1.6, 90.0, 2.5), 0.9, 22.0, 0.0, 1.0)

static func ember() -> LightPreset:
	return _anim(_make(Color(1.0, 0.45, 0.2), 0.8, 100.0, 2.0), 0.4, 6.0, 0.0, 1.0)

static func crystal() -> LightPreset:
	return _anim(_make(Color(0.75, 0.45, 1.0), 1.0, 150.0, 1.6), 0.0, 8.0, 0.35, 0.3)

static func lamp() -> LightPreset:
	return _make(Color(1.0, 0.85, 0.5), 0.9, 120.0, 1.5)

static func star() -> LightPreset:
	var p := _make(Color(1.0, 0.9, 0.7), 1.2, 900.0, 1.2)
	p.cast_shadows = true; p.shadow_range = 650.0; p.shadow_fade = 0.6
	return p

static func depot_glow() -> LightPreset:
	return _anim(_make(Color(1.0, 0.8, 0.5), 0.9, 450.0, 1.3), 0.0, 8.0, 0.15, 0.3)

static func explosion() -> LightPreset:
	var p := _anim(_make(Color(1.0, 0.6, 0.2), 3.0, 350.0, 2.0), 0.3, 8.0, 0.0, 1.0)
	p.lifetime = 0.6; p.fade_in = 0.02; p.fade_out = 0.5
	return p

static func pickup_flash() -> LightPreset:
	var p := _make(Color(1.0, 0.95, 0.6), 2.0, 200.0, 1.8)
	p.lifetime = 0.5; p.fade_in = 0.03; p.fade_out = 0.45
	return p

static func debris_plastic() -> LightPreset:
	# Soft, slightly tinted sheen with a slow tumble.
	return _anim(_make(Color(0.8, 0.95, 0.9), 0.5, 60.0, 1.8), 0.0, 8.0, 0.25, 0.5)

static func debris_metal() -> LightPreset:
	# Sharp, cold glints as the surface rotates through the sunlight.
	return _anim(_make(Color(0.75, 0.85, 1.0), 1.1, 80.0, 2.2), 0.05, 16.0, 0.7, 1.6)

static func debris_cement() -> LightPreset:
	# Dull, warm-grey and matte: barely there, with a very slow drift.
	return _anim(_make(Color(0.65, 0.62, 0.58), 0.35, 50.0, 1.5), 0.0, 8.0, 0.1, 0.25)