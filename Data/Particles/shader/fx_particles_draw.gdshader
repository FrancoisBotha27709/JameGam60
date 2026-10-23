shader_type canvas_item;
render_mode blend_premul_alpha;

group_uniforms palette;
uniform vec4 col_core : source_color = vec4(1.0, 0.96, 0.75, 1.0);
uniform vec4 col_hot : source_color = vec4(1.0, 0.75, 0.2, 1.0);
uniform vec4 col_mid : source_color = vec4(0.95, 0.3, 0.1, 1.0);
uniform vec4 col_cool : source_color = vec4(0.35, 0.12, 0.15, 1.0);
uniform vec4 col_outline : source_color = vec4(0.12, 0.03, 0.05, 1.0);
uniform vec3 thresholds = vec3(0.2, 0.45, 0.75);
uniform float core_bias : hint_range(0.0, 2.0) = 0.6;
uniform float life_heat : hint_range(0.0, 2.0) = 1.0;
uniform float heat_jitter : hint_range(0.0, 1.0) = 0.2;
uniform float hue_shift = 0.0;
uniform float additive : hint_range(0.0, 1.0) = 0.0;
uniform float glow = 1.0;

group_uniforms form;
uniform float shape : hint_range(0.0, 3.0) = 0.0;
uniform vec2 aspect = vec2(1.0);
uniform float thickness : hint_range(0.05, 1.0) = 0.3;
uniform float ring : hint_range(0.0, 1.0) = 0.0;
uniform float pixel_res = 4.0;
uniform float softness : hint_range(0.0, 1.0) = 0.0;
uniform float erode : hint_range(0.0, 1.0) = 0.4;
uniform float outline : hint_range(0.0, 0.5) = 0.0;
uniform float edge_noise : hint_range(0.0, 1.0) = 0.0;
uniform float grain : hint_range(0.0, 1.0) = 0.0;

group_uniforms fade;
uniform float fade_in : hint_range(0.0, 1.0) = 0.0;
uniform float fade_start : hint_range(0.0, 1.0) = 0.5;
uniform float dither : hint_range(0.0, 1.0) = 1.0;
uniform float flicker : hint_range(0.0, 1.0) = 0.0;
uniform float flicker_freq = 12.0;
group_uniforms;

varying vec4 v_data;
varying vec4 v_tint;

const float TWO_PI = 6.2831853;

float bayer2(vec2 a) { a = floor(a); return fract(a.x * 0.5 + a.y * a.y * 0.75); }
float bayer4(vec2 a) { return bayer2(a * 0.5) * 0.25 + bayer2(a); }
// ~step(e, x) when s = 0, smooth ramp otherwise
float gte(float x, float e, float s) { return clamp((x - e) / max(s, 1e-4) * 0.5 + 0.5, 0.0, 1.0); }
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
vec3 hue_rot(vec3 c, float a) {
	vec3 k = vec3(0.57735);
	float s = sin(a);
	float co = cos(a);
	return c * co + cross(k, c) * s + k * dot(k, c) * (1.0 - co);
}

void vertex() {
	v_data = INSTANCE_CUSTOM;
	v_tint = COLOR;
}

void fragment() {
	float t = v_data.y;
	float res = max(pixel_res, 1.0);
	vec2 cell = floor(UV * res);
	vec2 uv = mix(UV, (cell + 0.5) / res, step(0.5, pixel_res));
	vec2 p = (uv * 2.0 - 1.0) / aspect;
	vec2 q = abs(p);
	float h = hash12(cell + floor(v_data.x * 64.0) * 17.0);

	// All four distance fields blended by weight, no branching
	float dsq = max(q.x, q.y);
	vec4 w = max(1.0 - abs(vec4(shape) - vec4(0.0, 1.0, 2.0, 3.0)), 0.0);
	float d = dot(w, vec4(length(p), q.x + q.y, dsq, max(dsq, min(q.x, q.y) / thickness)));

	float k = 1.0 / (1.0 + outline);
	float rad = k * (1.0 - t * erode - edge_noise * h * 0.5);
	float on = step(0.001, ring);
	float outer = gte(rad + outline * k, d, softness) * (1.0 - gte(rad * (1.0 - ring) - outline * k, d, softness) * on);
	float body = gte(rad, d, softness) * (1.0 - gte(rad * (1.0 - ring), d, softness) * on);

	float heat = 1.0 - t * life_heat - core_bias * 0.5 * d + (v_data.z - 0.5) * heat_jitter - grain * h;
	vec3 c = col_cool.rgb;
	c = mix(c, col_mid.rgb, gte(heat, thresholds.x, softness));
	c = mix(c, col_hot.rgb, gte(heat, thresholds.y, softness));
	c = mix(c, col_core.rgb, gte(heat, thresholds.z, softness));
	c = hue_rot(c, hue_shift * t * TWO_PI);
	c = mix(c, col_outline.rgb, clamp(outer - body, 0.0, 1.0));

	float f = (1.0 - clamp((t - fade_start) / max(1.0 - fade_start, 1e-4), 0.0, 1.0))
		* clamp(t / max(fade_in, 1e-4), 0.0, 1.0)
		* (1.0 - flicker * (0.5 + 0.5 * sin((t * flicker_freq + v_data.x) * TWO_PI)));
	float thr = bayer4(cell + floor(v_data.x * 8.0) * 3.0);
	float a = outer * mix(f, step(thr + 1e-4, f), dither);

	vec4 o = vec4(c * glow, a) * v_tint;
	COLOR = vec4(o.rgb * o.a, o.a * (1.0 - additive));
}
