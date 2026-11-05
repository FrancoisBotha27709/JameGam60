@tool
class_name FXPresets
extends RefCounted
## Library of layered effect presets for FXPlayer.
##
## A preset is an Array of layers. Each layer becomes one GPUParticles2D driven by
## ship_particles.gdshader (sim) + ship_particles_draw.gdshader (draw).
##
## Layer dictionary keys:
##   name, amount, lifetime            -> GPUParticles2D settings
##   sim   : { uniform: value }        -> ship_particles.gdshader parameters (only the ones that differ from defaults)
##   draw  : { uniform: value }        -> ship_particles_draw.gdshader parameters
##   one_shot, explosiveness, preprocess, local_coords, delay (s), vis (Rect2)
##
## Sizes: size_* uniforms are multiples of the 16 px quad, so  size = diameter_px / 16.
## Directional presets fire toward local "up" (-90 deg). Your thrust points down (+90).
## Add your own: write a _my_effect() returning an Array, and add it to names() + get_preset().

const QUAD := 16.0


static func names() -> PackedStringArray:
	return PackedStringArray([
		"thrust", "fire", "smoke", "ember", "spark", "gas", "mist", "wind", "snow",
		"lightning", "fire_blast", "ion_blast", "explosion", "shield", "shield_pulse", "portal",
	])


static func get_preset(preset_name: String) -> Dictionary:
	var layers : Array = []
	match preset_name:
		"thrust": layers = _thrust()
		"fire": layers = _fire()
		"smoke": layers = _smoke()
		"ember": layers = _ember()
		"spark": layers = _spark()
		"gas": layers = _gas()
		"mist": layers = _mist()
		"wind": layers = _wind()
		"snow": layers = _snow()
		"lightning": layers = _lightning()
		"fire_blast": layers = _fire_blast()
		"ion_blast": layers = _ion_blast()
		"explosion": layers = _explosion()
		"shield": layers = _shield()
		"shield_pulse": layers = _shield_pulse()
		"portal": layers = _portal()
		_: return {}
	return {"layers": layers}


# ----------------------------------------------------------------------------
# helpers
# ----------------------------------------------------------------------------

static func _p(core: Color, hot: Color, mid: Color, cool: Color) -> Dictionary:
	return {"col_core": core, "col_hot": hot, "col_mid": mid, "col_cool": cool}


static func palette(key: String) -> Dictionary:
	match key:
		"fire":  return _p(Color(1, 0.96, 0.75), Color(1, 0.75, 0.2), Color(0.95, 0.3, 0.1), Color(0.35, 0.12, 0.15))
		"ember": return _p(Color(1, 0.9, 0.5), Color(1, 0.6, 0.15), Color(0.9, 0.25, 0.08), Color(0.4, 0.08, 0.08))
		"spark": return _p(Color(1, 1, 0.9), Color(1, 0.85, 0.35), Color(1, 0.5, 0.12), Color(0.5, 0.15, 0.08))
		"smoke": return _p(Color(0.55, 0.55, 0.58), Color(0.38, 0.38, 0.42), Color(0.24, 0.24, 0.28), Color(0.12, 0.12, 0.15))
		"gas":   return _p(Color(0.85, 1, 0.5), Color(0.55, 0.85, 0.3), Color(0.28, 0.55, 0.25), Color(0.13, 0.28, 0.2))
		"mist":  return _p(Color(0.95, 0.98, 1), Color(0.8, 0.88, 0.95), Color(0.62, 0.74, 0.88), Color(0.45, 0.55, 0.72))
		"wind":  return _p(Color(1, 1, 1), Color(0.9, 0.95, 1), Color(0.75, 0.85, 0.95), Color(0.6, 0.7, 0.85))
		"snow":  return _p(Color(1, 1, 1), Color(0.92, 0.97, 1), Color(0.72, 0.85, 0.98), Color(0.55, 0.7, 0.9))
		"bolt":  return _p(Color(1, 1, 1), Color(0.75, 0.95, 1), Color(0.35, 0.65, 1), Color(0.2, 0.25, 0.8))
		"ion":   return _p(Color(0.85, 1, 1), Color(0.35, 0.9, 1), Color(0.15, 0.4, 1), Color(0.12, 0.08, 0.35))
		"flash": return _p(Color(1, 1, 0.95), Color(1, 0.9, 0.55), Color(1, 0.6, 0.25), Color(0.6, 0.25, 0.12))
		"shield":
			var d := _p(Color(0.8, 1, 1), Color(0.35, 0.85, 1), Color(0.15, 0.5, 0.95), Color(0.1, 0.2, 0.6))
			d["rim_color"] = Color(0.9, 1, 1)
			return d
		"portal":
			var d := _p(Color(1, 0.8, 1), Color(0.85, 0.35, 1), Color(0.45, 0.15, 0.85), Color(0.15, 0.05, 0.4))
			d["rim_color"] = Color(0.9, 0.6, 1)
			return d
		"void":
			var d := _p(Color(0.35, 0.1, 0.6), Color(0.2, 0.05, 0.4), Color(0.1, 0.02, 0.22), Color(0.04, 0.0, 0.1))
			d["rim_color"] = Color(0.9, 0.6, 1)
			return d
	return {}


static func _draw(pal: String, extra: Dictionary = {}) -> Dictionary:
	return palette(pal).merged(extra, true)


static func _layer(layer_name: String, amount: int, lifetime: float, sim: Dictionary, draw: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var d := {"name": layer_name, "amount": amount, "lifetime": lifetime, "sim": sim, "draw": draw}
	d.merge(extra, true)
	return d


static func _ember_layer(amount: int, life: float, box: Vector2, extra: Dictionary = {}) -> Dictionary:
	return _layer("embers", amount, life,
		{"emit_box": box, "direction_deg": -90.0, "spread_deg": 35.0, "spread_bias": 1.2,
		 "speed_min": 14.0, "speed_max": 38.0, "drag": 0.35, "accel": Vector2(0, -14),
		 "flow_amp": 40.0, "flow_scale": 0.018, "flow_speed": 0.6, "turb_amp": 24.0, "turb_freq": 1.4,
		 "size_start": 0.2, "size_end": 0.06, "size_random": 0.5, "life_random": 0.5},
		_draw("ember", {"shape": 1, "erode": 0.0, "heat_age": 1.2, "core_bias": 0.3, "fade_start": 0.55,
			"twinkle": 0.3, "twinkle_hz": 9.0, "additive": 0.6, "pixel_px": 1.0}),
		extra)


# ----------------------------------------------------------------------------
# presets
# ----------------------------------------------------------------------------

## Your original engine flame, unchanged (quad-relative pixel_res, point emitter pointing down).
static func _thrust() -> Array:
	return [_layer("flame", 40, 0.5,
		{"emit_box": Vector2(3, 0), "direction_deg": 90.0, "spread_deg": 8.0, "spread_bias": 1.8,
		 "speed_min": 90.0, "speed_max": 180.0, "drag": 2.0, "turb_amp": 25.0, "turb_freq": 3.0,
		 "size_start": 0.6, "size_end": 0.0, "align_to_velocity": true},
		_draw("fire", {"pixel_px": 0.0}),
		{"vis": Rect2(-200, -200, 400, 400)})]


static func _fire() -> Array:
	return [
		_layer("flame", 56, 0.9,
			{"emit_box": Vector2(9, 1), "direction_deg": -90.0, "spread_deg": 22.0, "spread_bias": 1.5,
			 "speed_min": 35.0, "speed_max": 85.0, "drag": 1.2, "accel": Vector2(0, -45),
			 "turb_amp": 45.0, "turb_freq": 2.2, "size_start": 0.85, "size_end": 0.0, "size_curve": 1.3,
			 "size_random": 0.4, "life_random": 0.4},
			_draw("fire", {"erode": 0.55, "core_bias": 0.7, "fade_start": 0.6})),
		_ember_layer(8, 1.6, Vector2(8, 1)),
	]


static func _smoke() -> Array:
	return [_layer("smoke", 24, 2.2,
		{"emit_box": Vector2(6, 1), "direction_deg": -90.0, "spread_deg": 15.0, "speed_min": 20.0, "speed_max": 50.0,
		 "drag": 0.9, "accel": Vector2(0, -22), "flow_amp": 18.0, "flow_scale": 0.012, "turb_amp": 14.0,
		 "size_start": 0.8, "size_end": 2.2, "size_curve": 0.8, "grow_in": 0.12, "size_random": 0.4},
		_draw("smoke", {"erode": 0.15, "heat_age": 0.4, "core_bias": 0.5, "noise_edge": 0.3, "noise_scale": 3.0,
			"noise_scroll": Vector2(0.2, 0.1), "opacity": 0.8, "fade_in": 0.12, "fade_start": 0.4, "pixel_px": 3.0}))]


static func _ember() -> Array:
	return [_ember_layer(22, 2.6, Vector2(22, 3), {"preprocess": 2.0})]


## One-shot impact sparks. Set play_mode = Loop for a welding / grinding look.
static func _spark() -> Array:
	return [_layer("sparks", 28, 0.55,
		{"direction_deg": -90.0, "spread_deg": 100.0, "spread_bias": 1.0, "speed_min": 90.0, "speed_max": 300.0,
		 "speed_pow": 0.8, "drag": 2.2, "accel": Vector2(0, 260), "size_start": 0.24, "size_end": 0.05,
		 "size_random": 0.4, "stretch": 0.01, "aspect": 0.45, "align_to_velocity": true},
		_draw("spark", {"shape": 2, "erode": 0.2, "heat_age": 1.0, "core_bias": 0.2, "fade_start": 0.55,
			"twinkle": 0.1, "additive": 0.6, "brightness": 1.15, "pixel_px": 1.5}),
		{"one_shot": true, "explosiveness": 0.95})]


static func _gas() -> Array:
	return [_layer("cloud", 22, 3.0,
		{"emit_shape": 1, "emit_radius": 14.0, "dir_mode": 1, "direction_deg": 0.0, "spread_deg": 0.0,
		 "speed_min": 8.0, "speed_max": 26.0, "drag": 0.8, "accel": Vector2(0, -6),
		 "flow_amp": 28.0, "flow_scale": 0.012, "flow_speed": 0.35, "turb_amp": 8.0, "turb_freq": 1.0,
		 "size_start": 2.2, "size_end": 3.6, "size_curve": 0.7, "size_random": 0.35, "life_random": 0.4, "grow_in": 0.2},
		_draw("gas", {"erode": 0.25, "heat_age": 0.5, "heat_noise": 0.35, "core_bias": 0.5, "noise_edge": 0.35,
			"noise_scale": 3.0, "noise_scroll": Vector2(0.25, 0.15), "noise_alpha": 0.6, "opacity": 0.7,
			"fade_in": 0.25, "fade_start": 0.45, "pixel_px": 3.0}),
		{"vis": Rect2(-400, -400, 800, 800)})]


static func _mist() -> Array:
	return [_layer("mist", 16, 5.0,
		{"emit_box": Vector2(80, 10), "direction_deg": 0.0, "spread_deg": 20.0, "speed_min": 4.0, "speed_max": 14.0,
		 "drag": 0.4, "flow_amp": 14.0, "flow_scale": 0.008, "flow_speed": 0.15, "turb_amp": 4.0,
		 "size_start": 3.5, "size_end": 5.0, "size_curve": 0.8, "size_random": 0.35, "life_random": 0.4, "grow_in": 0.25},
		_draw("mist", {"erode": 0.1, "heat_age": 0.3, "core_bias": 0.4, "noise_edge": 0.5, "noise_scale": 2.2,
			"noise_scroll": Vector2(0.1, 0.05), "noise_alpha": 0.8, "opacity": 0.38, "fade_in": 0.3,
			"fade_start": 0.5, "pixel_px": 4.0}),
		{"preprocess": 4.0, "vis": Rect2(-500, -400, 1000, 800)})]


static func _wind() -> Array:
	return [_layer("streaks", 26, 1.0,
		{"emit_box": Vector2(6, 70), "direction_deg": 0.0, "spread_deg": 3.0, "speed_min": 200.0, "speed_max": 340.0,
		 "drag": 0.25, "flow_amp": 90.0, "flow_scale": 0.012, "flow_speed": 0.5, "turb_amp": 40.0, "turb_freq": 1.0,
		 "size_start": 0.5, "size_end": 0.35, "size_random": 0.5, "life_random": 0.5,
		 "align_to_velocity": true, "stretch": 0.014, "aspect": 0.2},
		_draw("wind", {"shape": 2, "erode": 0.0, "heat_age": 0.2, "core_bias": 0.3, "opacity": 0.55,
			"fade_in": 0.25, "fade_start": 0.55, "pixel_px": 1.5}),
		{"preprocess": 1.0, "vis": Rect2(-300, -300, 1000, 600)})]


static func _snow() -> Array:
	return [_layer("flakes", 70, 6.0,
		{"emit_offset": Vector2(0, -110), "emit_box": Vector2(260, 4), "direction_deg": 90.0, "spread_deg": 10.0,
		 "speed_min": 22.0, "speed_max": 48.0, "drag": 0.15, "flow_amp": 30.0, "flow_scale": 0.008, "flow_speed": 0.4,
		 "turb_amp": 18.0, "turb_freq": 1.3, "size_start": 0.38, "size_end": 0.38, "size_random": 0.6, "life_random": 0.3,
		 "spin_deg": 140.0, "rot_steps": 8},
		_draw("snow", {"shape": 4, "shape_param": 0.34, "erode": 0.0, "heat_age": 0.0, "core_bias": 0.6,
			"fade_in": 0.08, "fade_start": 0.85, "pixel_px": 1.5}),
		{"preprocess": 6.0, "vis": Rect2(-600, -400, 1200, 800)})]


static func _lightning() -> Array:
	var bolt_sim := {"emit_shape": 2, "direction_deg": -90.0, "bolt_length": 110.0, "bolt_amp": 18.0, "bolt_freq": 6.0,
		"bolt_width": 1.2, "bolt_branch": 0.3, "bolt_branches": 3, "bolt_branch_len": 0.4,
		"spread_deg": 180.0, "speed_min": 0.0, "speed_max": 14.0, "drag": 4.0, "turb_amp": 0.0,
		"size_random": 0.3, "life_random": 0.1}
	return [
		_layer("bolt", 90, 0.22,
			bolt_sim.merged({"size_start": 0.26, "size_end": 0.12}, true),
			_draw("bolt", {"shape": 2, "erode": 0.3, "heat_age": 0.8, "core_bias": 0.4, "fade_start": 0.35,
				"twinkle": 0.12, "twinkle_hz": 30.0, "additive": 0.7, "brightness": 1.1, "pixel_px": 1.5}),
			{"explosiveness": 1.0, "vis": Rect2(-300, -300, 600, 600)}),
		# soft halo, follows the same bolt shape because it shares the seed timing
		_layer("glow", 60, 0.22,
			bolt_sim.merged({"size_start": 0.7, "size_end": 0.5}, true),
			_draw("bolt", {"shape": 0, "erode": 0.2, "heat_age": 0.3, "core_bias": 0.0, "heat_offset": -0.2,
				"opacity": 0.28, "fade_start": 0.2, "additive": 1.0, "pixel_px": 2.0}),
			{"explosiveness": 1.0, "vis": Rect2(-300, -300, 600, 600)}),
	]


static func _fire_blast() -> Array:
	return [
		_layer("flame", 70, 0.55,
			{"emit_box": Vector2(4, 0), "direction_deg": -90.0, "spread_deg": 18.0, "spread_bias": 1.4,
			 "speed_min": 220.0, "speed_max": 420.0, "drag": 3.4, "accel": Vector2(0, -40),
			 "turb_amp": 55.0, "turb_freq": 2.5, "size_start": 0.45, "size_end": 1.3, "size_curve": 0.6},
			_draw("fire", {"erode": 0.7, "core_bias": 0.7, "fade_start": 0.55}),
			{"one_shot": true, "explosiveness": 0.35}),
		_layer("sparks", 18, 0.7,
			{"direction_deg": -90.0, "spread_deg": 30.0, "speed_min": 180.0, "speed_max": 420.0, "drag": 2.4,
			 "accel": Vector2(0, 200), "size_start": 0.2, "size_end": 0.04, "stretch": 0.01, "aspect": 0.5, "align_to_velocity": true},
			_draw("spark", {"shape": 2, "erode": 0.2, "heat_age": 1.0, "core_bias": 0.2, "fade_start": 0.55,
				"additive": 0.6, "pixel_px": 1.5}),
			{"one_shot": true, "explosiveness": 0.6}),
		_layer("smoke", 14, 1.2,
			{"direction_deg": -90.0, "spread_deg": 22.0, "speed_min": 60.0, "speed_max": 150.0, "drag": 2.2,
			 "accel": Vector2(0, -30), "size_start": 0.8, "size_end": 2.0, "grow_in": 0.15},
			_draw("smoke", {"erode": 0.1, "heat_age": 0.3, "noise_edge": 0.3, "opacity": 0.8, "fade_in": 0.12,
				"fade_start": 0.4, "pixel_px": 3.0}),
			{"one_shot": true, "explosiveness": 0.5, "delay": 0.08}),
	]


## Radial EMP-style burst: flash + expanding ring + electric sparks.
static func _ion_blast() -> Array:
	return [
		_layer("flash", 1, 0.22, {"speed_min": 0.0, "speed_max": 0.0, "size_start": 4.5, "size_end": 1.0, "size_curve": 0.5, "size_random": 0.0, "life_random": 0.0},
			_draw("ion", {"erode": 0.8, "heat_age": 0.4, "core_bias": 0.3, "fade_start": 0.1, "additive": 1.0, "brightness": 1.2, "pixel_px": 2.0}),
			{"one_shot": true, "explosiveness": 1.0}),
		_layer("ring", 1, 0.5, {"speed_min": 0.0, "speed_max": 0.0, "size_start": 0.3, "size_end": 9.0, "size_curve": 0.45, "size_random": 0.0, "life_random": 0.0},
			_draw("ion", {"ring_width": 0.16, "ring_taper": 0.75, "rim_width": 0.06, "rim_color": Color(1, 1, 1), "erode": 0.0,
				"heat_age": 1.0, "core_bias": 0.0, "noise_edge": 0.12, "noise_scale": 5.0, "fade_start": 0.35,
				"additive": 0.5, "pixel_px": 2.0}),
			{"one_shot": true, "explosiveness": 1.0, "vis": Rect2(-300, -300, 600, 600)}),
		_layer("sparks", 34, 0.6,
			{"dir_mode": 1, "direction_deg": 0.0, "spread_deg": 0.0, "speed_min": 90.0, "speed_max": 330.0, "speed_pow": 0.7,
			 "drag": 3.2, "size_start": 0.22, "size_end": 0.05, "stretch": 0.012, "aspect": 0.5, "align_to_velocity": true,
			 "jitter": 60.0, "jitter_hz": 24.0},
			_draw("ion", {"shape": 1, "erode": 0.2, "heat_age": 1.2, "core_bias": 0.2, "twinkle": 0.1, "additive": 0.7, "pixel_px": 1.5}),
			{"one_shot": true, "explosiveness": 1.0}),
	]


static func _explosion() -> Array:
	var burst := {"one_shot": true, "explosiveness": 1.0, "vis": Rect2(-400, -400, 800, 800)}
	return [
		_layer("flash", 1, 0.16, {"speed_min": 0.0, "speed_max": 0.0, "size_start": 5.0, "size_end": 3.0, "size_random": 0.0, "life_random": 0.0},
			_draw("flash", {"erode": 0.5, "heat_age": 0.3, "core_bias": 0.2, "fade_start": 0.3, "additive": 1.0, "pixel_px": 2.0}), burst),
		_layer("fireball", 46, 0.75,
			{"emit_shape": 1, "emit_radius": 6.0, "dir_mode": 1, "direction_deg": 0.0, "spread_deg": 0.0,
			 "speed_min": 20.0, "speed_max": 230.0, "speed_pow": 0.8, "drag": 4.2, "accel": Vector2(0, -25),
			 "turb_amp": 35.0, "size_start": 1.5, "size_end": 0.35, "size_random": 0.5, "life_random": 0.5},
			_draw("fire", {"erode": 0.65, "core_bias": 0.8, "fade_start": 0.5}), burst),
		_layer("shock", 1, 0.4, {"speed_min": 0.0, "speed_max": 0.0, "size_start": 0.5, "size_end": 9.5, "size_curve": 0.4, "size_random": 0.0, "life_random": 0.0},
			_draw("flash", {"ring_width": 0.1, "ring_taper": 0.7, "erode": 0.0, "heat_age": 1.0, "core_bias": 0.0,
				"fade_start": 0.3, "additive": 0.4, "pixel_px": 2.0}), burst),
		_layer("sparks", 36, 0.9,
			{"dir_mode": 1, "direction_deg": 0.0, "spread_deg": 0.0, "speed_min": 100.0, "speed_max": 380.0, "speed_pow": 0.8,
			 "drag": 2.2, "accel": Vector2(0, 200), "size_start": 0.22, "size_end": 0.05, "stretch": 0.01, "aspect": 0.5, "align_to_velocity": true},
			_draw("spark", {"shape": 2, "erode": 0.2, "heat_age": 1.0, "core_bias": 0.2, "fade_start": 0.55, "additive": 0.6, "pixel_px": 1.5}), burst),
		_layer("smoke", 20, 1.8,
			{"emit_shape": 1, "emit_radius": 10.0, "dir_mode": 1, "direction_deg": 0.0, "spread_deg": 0.0,
			 "speed_min": 10.0, "speed_max": 70.0, "drag": 2.5, "accel": Vector2(0, -18),
			 "size_start": 1.2, "size_end": 2.6, "grow_in": 0.2, "size_random": 0.4},
			_draw("smoke", {"erode": 0.1, "heat_age": 0.3, "noise_edge": 0.3, "opacity": 0.85, "fade_in": 0.15,
				"fade_start": 0.35, "pixel_px": 3.0}),
			burst.merged({"delay": 0.1}, true)),
		_layer("embers", 14, 1.6,
			{"dir_mode": 1, "direction_deg": 0.0, "spread_deg": 0.0, "speed_min": 20.0, "speed_max": 120.0, "drag": 1.5,
			 "accel": Vector2(0, -20), "flow_amp": 30.0, "size_start": 0.18, "size_end": 0.05},
			_draw("ember", {"shape": 1, "erode": 0.0, "heat_age": 1.2, "fade_start": 0.55, "twinkle": 0.3, "additive": 0.6, "pixel_px": 1.0}),
			burst.merged({"delay": 0.1}, true)),
	]


## Follows the node (local_coords) so it stays glued to the ship.
static func _shield() -> Array:
	return [
		_layer("bubble", 2, 2.6,
			{"speed_min": 0.0, "speed_max": 0.0, "size_start": 7.6, "size_end": 7.9, "size_random": 0.0, "life_random": 0.0,
			 "pulse_amp": 0.025, "pulse_hz": 0.8},
			_draw("shield", {"erode": 0.0, "rim_width": 0.07, "core_alpha": 0.16, "heat_age": 0.0, "heat_offset": -0.05,
				"core_bias": 0.5, "noise_scale": 4.0, "noise_scroll": Vector2(0.3, 0.2), "noise_alpha": 0.8, "noise_edge": 0.05,
				"opacity": 0.9, "fade_in": 0.2, "fade_start": 0.8, "flicker": 0.08, "flicker_hz": 0.8,
				"additive": 0.35, "pixel_px": 2.0}),
			{"local_coords": true, "vis": Rect2(-160, -160, 320, 320)}),
		_layer("orbit", 14, 1.8,
			{"emit_shape": 1, "emit_radius": 58.0, "emit_radius_inner": 58.0, "dir_mode": 2, "direction_deg": 0.0, "spread_deg": 0.0,
			 "speed_min": 55.0, "speed_max": 55.0, "drag": 0.1, "attract": 52.0, "orbit_k": 2.0, "orbit_radius": 58.0,
			 "turb_amp": 0.0, "size_start": 0.22, "size_end": 0.1},
			_draw("shield", {"shape": 1, "erode": 0.0, "heat_age": 1.0, "core_bias": 0.2, "fade_in": 0.1,
				"twinkle": 0.2, "additive": 0.7, "pixel_px": 1.5}),
			{"local_coords": true, "vis": Rect2(-160, -160, 320, 320)}),
	]


## Hit / activation ripple. Set play_mode = Loop for periodic idle pulses.
static func _shield_pulse() -> Array:
	var o := {"one_shot": true, "explosiveness": 1.0, "local_coords": true, "vis": Rect2(-300, -300, 600, 600)}
	return [
		_layer("wave", 1, 0.55,
			{"speed_min": 0.0, "speed_max": 0.0, "size_start": 5.0, "size_end": 9.0, "size_curve": 0.5, "size_random": 0.0, "life_random": 0.0},
			_draw("shield", {"ring_width": 0.2, "ring_taper": 0.8, "rim_width": 0.08, "core_alpha": 0.3, "noise_edge": 0.18,
				"noise_scale": 6.0, "erode": 0.0, "heat_age": 1.0, "core_bias": 0.0, "fade_start": 0.3,
				"additive": 0.5, "pixel_px": 2.0}), o),
		_layer("flare", 1, 0.25,
			{"speed_min": 0.0, "speed_max": 0.0, "size_start": 7.5, "size_end": 7.5, "size_random": 0.0, "life_random": 0.0},
			_draw("shield", {"erode": 0.0, "heat_age": 0.5, "core_bias": 0.3, "opacity": 0.4, "fade_start": 0.0,
				"additive": 1.0, "pixel_px": 2.0}), o),
		_layer("sparks", 18, 0.5,
			{"emit_shape": 1, "emit_radius": 58.0, "emit_radius_inner": 58.0, "dir_mode": 1, "direction_deg": 0.0, "spread_deg": 0.0,
			 "speed_min": 30.0, "speed_max": 110.0, "drag": 3.0, "size_start": 0.2, "size_end": 0.04},
			_draw("shield", {"shape": 1, "erode": 0.0, "heat_age": 1.0, "twinkle": 0.2, "additive": 0.7, "pixel_px": 1.5}), o),
	]


static func _portal() -> Array:
	var loc := {"local_coords": true, "vis": Rect2(-200, -200, 400, 400)}
	return [
		_layer("core", 2, 3.0,
			{"speed_min": 0.0, "speed_max": 0.0, "size_start": 5.5, "size_end": 5.8, "size_random": 0.0, "life_random": 0.0,
			 "pulse_amp": 0.03, "pulse_hz": 0.6},
			_draw("void", {"erode": 0.0, "rim_width": 0.09, "heat_age": 0.0, "core_bias": 0.8, "noise_edge": 0.14,
				"noise_scale": 4.0, "noise_scroll": Vector2(0.4, -0.3), "flicker": 0.1, "flicker_hz": 1.5,
				"opacity": 0.95, "fade_in": 0.2, "fade_start": 0.8, "pixel_px": 2.0}),
			loc),
		_layer("swirl", 80, 1.3,
			{"emit_shape": 1, "emit_radius": 70.0, "emit_radius_inner": 52.0, "dir_mode": 2, "direction_deg": 0.0, "spread_deg": 0.0,
			 "speed_min": 40.0, "speed_max": 60.0, "drag": 1.2, "attract": 130.0, "swirl": 60.0, "turb_amp": 0.0,
			 "size_start": 0.4, "size_end": 0.1, "size_random": 0.5, "align_to_velocity": true, "stretch": 0.008, "aspect": 0.4},
			_draw("portal", {"shape": 2, "erode": 0.0, "heat_age": 1.0, "core_bias": 0.0, "twinkle": 0.05,
				"fade_in": 0.1, "fade_start": 0.6, "additive": 0.8, "pixel_px": 1.5}),
			loc),
		_layer("wisps", 14, 1.6,
			{"emit_shape": 1, "emit_radius": 52.0, "emit_radius_inner": 48.0, "dir_mode": 1, "direction_deg": 0.0, "spread_deg": 0.0,
			 "speed_min": 10.0, "speed_max": 30.0, "drag": 0.5, "swirl": 20.0, "size_start": 0.2, "size_end": 0.05},
			_draw("portal", {"shape": 1, "erode": 0.0, "heat_age": 1.2, "twinkle": 0.25, "additive": 0.8, "pixel_px": 1.0}),
			loc),
	]