shader_type canvas_item;
render_mode blend_mix;

group_uniforms palette;
uniform vec4 col_core : source_color = vec4(1.0, 0.96, 0.75, 1.0);
uniform vec4 col_hot : source_color = vec4(1.0, 0.75, 0.2, 1.0);
uniform vec4 col_mid : source_color = vec4(0.95, 0.3, 0.1, 1.0);
uniform vec4 col_cool : source_color = vec4(0.35, 0.12, 0.15, 1.0);
uniform vec3 thresholds = vec3(0.2, 0.45, 0.75);
uniform float core_bias : hint_range(0.0, 2.0) = 0.6;

group_uniforms look;
uniform int shape : hint_range(0, 2) = 0;
uniform float pixel_res = 4.0;
uniform float softness : hint_range(0.0, 1.0) = 0.0;
uniform float erode : hint_range(0.0, 1.0) = 0.4;

group_uniforms fade;
uniform float fade_start : hint_range(0.0, 1.0) = 0.5;
uniform float dither : hint_range(0.0, 1.0) = 1.0;
group_uniforms;

varying vec4 v_data;
varying vec4 v_tint;

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
	vec2 uv = pixel_res > 0.0 ? (floor(UV * pixel_res) + 0.5) / pixel_res : UV;
	vec2 p = uv * 2.0 - 1.0;
	vec2 q = abs(p);
	float d = shape == 0 ? length(p) : (shape == 1 ? q.x + q.y : max(q.x, q.y));
	float body = gte(1.0 - t * erode, d, softness);

	float heat = 1.0 - t - core_bias * 0.5 * d;
	vec3 c = col_cool.rgb;
	c = mix(c, col_mid.rgb, gte(heat, thresholds.x, softness));
	c = mix(c, col_hot.rgb, gte(heat, thresholds.y, softness));
	c = mix(c, col_core.rgb, gte(heat, thresholds.z, softness));

	float f = 1.0 - clamp((t - fade_start) / max(1.0 - fade_start, 1e-4), 0.0, 1.0);
	float thr = bayer4(floor(UV * max(pixel_res, 4.0)) + floor(v_data.x * 8.0) * 3.0);
	float a = body * mix(f, step(thr + 1e-4, f), dither);
	if (a <= 0.001) discard;

	COLOR = vec4(c, a) * v_tint;
}
