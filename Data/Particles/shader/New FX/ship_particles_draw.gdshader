shader_type canvas_item;
// Premultiplied output lets one uniform (`additive`) fade between normal and additive blending.
// With additive = 0 this is mathematically identical to blend_mix.
render_mode blend_premul_alpha;

// =============================================================================
//  DRAW SHADER  (pairs with ship_particles.gdshader)
//  Style is unchanged: pixel-snapped distance-field shape, hard-banded heat ramp,
//  Bayer-dithered fade, shape erosion over life. New uniforms default to "off".
// =============================================================================

group_uniforms palette;
uniform vec4 col_core : source_color = vec4(1.0, 0.96, 0.75, 1.0);
uniform vec4 col_hot : source_color = vec4(1.0, 0.75, 0.2, 1.0);
uniform vec4 col_mid : source_color = vec4(0.95, 0.3, 0.1, 1.0);
uniform vec4 col_cool : source_color = vec4(0.35, 0.12, 0.15, 1.0);
uniform vec3 thresholds = vec3(0.2, 0.45, 0.75);
uniform float core_bias : hint_range(0.0, 2.0) = 0.6;     // how much the centre is hotter than the edge
uniform float heat_age : hint_range(0.0, 3.0) = 1.0;      // how fast particles cool over life (0 = static colour)
uniform float heat_offset : hint_range(-1.0, 1.0) = 0.0;  // shifts every band (static colour choice)
uniform float heat_rand : hint_range(0.0, 1.0) = 0.0;     // per-particle colour variation
uniform float heat_noise : hint_range(0.0, 1.0) = 0.0;    // in-particle colour mottling (needs noise_scale)
uniform float flicker : hint_range(0.0, 1.0) = 0.0;       // colour shimmer over time
uniform float flicker_hz = 6.0;
uniform vec4 rim_color : source_color = vec4(1.0);
uniform float rim_width : hint_range(0.0, 1.0) = 0.0;     // bright outline band at the shape edge (0 = off)
uniform float brightness : hint_range(0.0, 3.0) = 1.0;

group_uniforms look;
uniform int shape : hint_range(0, 4) = 0;                 // 0 circle | 1 diamond | 2 square | 3 star | 4 plus
uniform float shape_param : hint_range(0.05, 1.0) = 0.34; // plus: arm thickness
uniform float pixel_res = 4.0;                            // chunks per quad (quad-relative, original behaviour)
uniform float pixel_px = 0.0;                             // >0: chunk size in SCREEN pixels instead (constant grain at any size)
uniform float softness : hint_range(0.0, 1.0) = 0.0;
uniform float erode : hint_range(0.0, 1.0) = 0.4;
uniform float ring_width : hint_range(0.0, 1.0) = 1.0;    // <1 hollows the shape into a ring of this thickness
uniform float ring_taper : hint_range(0.0, 1.0) = 0.0;    // ring gets thinner over life
uniform float core_alpha : hint_range(0.0, 1.0) = 1.0;    // opacity of everything inside the rim (needs rim_width)
uniform float noise_edge : hint_range(0.0, 1.0) = 0.0;    // ragged / blotchy outline
uniform float noise_alpha : hint_range(0.0, 1.0) = 0.0;   // mottled opacity (gas, mist, shields)
uniform float noise_scale = 3.0;
uniform vec2 noise_scroll = vec2(0.0);

group_uniforms fade;
uniform float fade_start : hint_range(0.0, 1.0) = 0.5;
uniform float fade_in : hint_range(0.0, 1.0) = 0.0;       // fraction of life spent fading in
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float dither : hint_range(0.0, 1.0) = 1.0;
uniform float twinkle : hint_range(0.0, 1.0) = 0.0;       // chance a particle blinks out each step
uniform float twinkle_hz = 12.0;
uniform float additive : hint_range(0.0, 1.0) = 0.0;      // 0 = normal blend, 1 = additive glow
group_uniforms;

varying vec4 v_data;
varying vec4 v_tint;

uint pcg(uint v) {
	uint s = v * 747796405u + 2891336453u;
	uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
	return (w >> 22u) ^ w;
}
float hash2(vec2 p) {
	ivec2 i = ivec2(floor(p));
	uint h = pcg(uint(i.x) * 1664525u + pcg(uint(i.y) + 1013904223u));
	return float(h) * (1.0 / 4294967295.0);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
			   mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

float bayer2(vec2 a) { a = floor(a); return fract(a.x * 0.5 + a.y * a.y * 0.75); }
float bayer4(vec2 a) { return bayer2(a * 0.5) * 0.25 + bayer2(a); }
// ~step(e, x) when s = 0, smooth ramp otherwise
float gte(float x, float e, float s) { return clamp((x - e) / max(s, 1e-4) * 0.5 + 0.5, 0.0, 1.0); }

void vertex() {
	v_data = INSTANCE_CUSTOM;
	v_tint = COLOR;
}

void fragment() {
	float t = v_data.y;
	float r0 = v_data.x;
	float r1 = v_data.z;

	// ---- pixel grid ----
	vec2 res = vec2(pixel_res);
	if (pixel_px > 0.0) {
		vec2 qpx = vec2(1.0 / max(length(vec2(dFdx(UV.x), dFdy(UV.x))), 1e-6),
						1.0 / max(length(vec2(dFdx(UV.y), dFdy(UV.y))), 1e-6));
		res = max(floor(qpx / pixel_px + 0.5), vec2(1.0));
	}
	vec2 uv = UV;
	if (pixel_px > 0.0 || pixel_res > 0.0) {
		uv = (floor(UV * res) + 0.5) / res;
	}
	vec2 dcell = pixel_px > 0.0 ? floor(UV * res) : floor(UV * max(pixel_res, 4.0));

	// ---- shape distance ----
	vec2 p = uv * 2.0 - 1.0;
	vec2 q = abs(p);
	float d;
	if (shape == 0) {
		d = length(p);
	} else if (shape == 1) {
		d = q.x + q.y;
	} else if (shape == 2) {
		d = max(q.x, q.y);
	} else if (shape == 3) {
		float sr = sqrt(q.x) + sqrt(q.y);
		d = sr * sr;
	} else {
		d = max(max(q.x, q.y), min(q.x, q.y) / max(shape_param, 1e-3));
	}

	// ---- pixel noise (outline, opacity, colour) ----
	float n = 0.5;
	if (noise_edge > 0.0 || noise_alpha > 0.0 || heat_noise > 0.0) {
		vec2 np = uv * noise_scale + vec2(r0 * 41.0, r1 * 27.0) + noise_scroll * TIME;
		n = vnoise(np) * 0.65 + vnoise(np * 2.3 + 9.1) * 0.35;
	}
	float dn = d - (n - 0.5) * noise_edge * 2.0;

	// ---- body, ring, rim ----
	float edge = 1.0 - t * erode;
	float body = gte(edge, dn, softness);
	if (ring_width < 1.0) {
		float rw = ring_width * (1.0 - ring_taper * t);
		body *= gte(dn, edge - rw, softness);
	}
	float rimv = 1.0;
	if (rim_width > 0.0) {
		rimv = gte(dn, edge - rim_width, softness);
		body *= mix(core_alpha, 1.0, rimv);
	}

	// ---- banded heat ramp ----
	float heat = heat_offset + 1.0 - heat_age * t - core_bias * 0.5 * d
		+ heat_rand * (r0 - 0.5) + heat_noise * (n - 0.5) * 2.0;
	if (flicker > 0.0) {
		heat += flicker * sin(TIME * flicker_hz * 6.2831853 + r0 * 6.2831853);
	}
	vec3 c = col_cool.rgb;
	c = mix(c, col_mid.rgb, gte(heat, thresholds.x, softness));
	c = mix(c, col_hot.rgb, gte(heat, thresholds.y, softness));
	c = mix(c, col_core.rgb, gte(heat, thresholds.z, softness));
	if (rim_width > 0.0) {
		c = mix(c, rim_color.rgb, rimv);
	}

	// ---- fade + dither ----
	float f_out = 1.0 - clamp((t - fade_start) / max(1.0 - fade_start, 1e-4), 0.0, 1.0);
	float f_in = fade_in > 0.0 ? clamp(t / fade_in, 0.0, 1.0) : 1.0;
	float f = min(f_out, f_in) * opacity;
	if (noise_alpha > 0.0) {
		f *= mix(1.0, clamp((n - 0.5) * 2.0 + 0.5, 0.0, 1.0), noise_alpha);
	}
	if (twinkle > 0.0) {
		uint tk = pcg(uint(floor(TIME * twinkle_hz + r1 * 13.0)) + uint(r0 * 65535.0) * 2654435761u);
		if (float(tk) * (1.0 / 4294967295.0) < twinkle) {
			discard;
		}
	}
	float thr = bayer4(dcell + floor(r0 * 8.0) * 3.0);
	float a = body * mix(f, step(thr + 1e-4, f), dither);
	if (a <= 0.001) discard;

	vec4 col = vec4(c * brightness, a) * v_tint;
	COLOR = vec4(col.rgb * col.a, col.a * (1.0 - additive));
}
