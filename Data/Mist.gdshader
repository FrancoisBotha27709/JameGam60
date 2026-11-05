shader_type canvas_item;

group_uniforms View;
uniform vec2 view_origin = vec2(0.0);
uniform vec2 view_size = vec2(1920.0, 1080.0);
uniform vec2 seed_offset = vec2(0.0);

group_uniforms Density;
uniform sampler2D density_texture : filter_linear, repeat_disable;
uniform vec2 density_origin = vec2(-8000.0, -8000.0);
uniform vec2 density_size = vec2(16000.0, 16000.0);
uniform float density_influence : hint_range(0.0, 1.0) = 1.0;

group_uniforms Disturbers;
const int MAX_DISTURBERS = 32;
uniform vec4 disturb_a[MAX_DISTURBERS];
uniform vec4 disturb_b[MAX_DISTURBERS];
uniform float clear_amount : hint_range(0.0, 1.0) = 0.25;

group_uniforms Look;
uniform float pixel_size : hint_range(1.0, 16.0, 1.0) = 4.0;
uniform float edge_pixel_size : hint_range(1.0, 8.0, 1.0) = 2.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.5;
uniform int levels : hint_range(1, 8) = 4;
uniform vec4 mist_color_a : source_color = vec4(0.40, 0.15, 0.30, 1.0);
uniform vec4 mist_color_b : source_color = vec4(0.55, 0.25, 0.15, 1.0);
uniform vec4 mist_highlight_color : source_color = vec4(1.0, 0.75, 0.35, 1.0);
uniform float highlight_amount : hint_range(0.0, 1.0) = 0.6;
uniform float shadow_tone : hint_range(0.0, 1.0) = 0.5;
uniform float light_strength : hint_range(0.0, 20.0) = 6.0;
uniform vec2 light_direction = vec2(-0.6, -0.8);

group_uniforms Clouds;
uniform float cloud_scale = 0.0011;
uniform int octaves : hint_range(1, 6) = 5;
uniform float threshold : hint_range(0.0, 1.0) = 0.58;
uniform float softness : hint_range(0.01, 1.0) = 0.22;
uniform float clump_strength : hint_range(0.0, 2.0) = 0.9;
uniform float warp_strength : hint_range(0.0, 4.0) = 0.8;

group_uniforms Evolution;
uniform float evolve_speed : hint_range(0.0, 1.0) = 0.12;
uniform float warp_travel : hint_range(0.0, 4.0) = 0.65;
uniform float shape_travel : hint_range(0.0, 2.0) = 0.45;
uniform float region_travel : hint_range(0.0, 3.0) = 0.7;
uniform vec2 drift = vec2(0.12, -0.08);

const float HASH_WRAP = 1024.0;
const vec2 HASH_SCALE = vec2(123.34, 456.21);
const float HASH_MIX_OFFSET = 45.32;
const mat2 ROT = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
const vec2 OCTAVE_SHIFT = vec2(17.3, 9.1);
const vec2 WARP_OFFSET = vec2(5.2, 1.3);
const vec2 REGION_OFFSET = vec2(31.7, 12.4);
const vec2 TINT_OFFSET = vec2(9.1, 3.7);
const float LIGHT_SAMPLE_OFFSET = 0.07;
const float PIXEL_CENTER = 0.5;

const int BAYER_SIZE = 4;
const float BAYER_MATRIX[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

float hash21(vec2 seed) {
	seed = fract(mod(seed, HASH_WRAP) * HASH_SCALE);
	seed += dot(seed, seed + HASH_MIX_OFFSET);
	return fract(seed.x * seed.y);
}

float value_noise(vec2 position) {
	vec2 lattice = floor(position);
	vec2 local = fract(position);
	vec2 eased = local * local * (3.0 - 2.0 * local);

	return mix(
		mix(
			hash21(lattice),
			hash21(lattice + vec2(1.0, 0.0)),
			eased.x
		),
		mix(
			hash21(lattice + vec2(0.0, 1.0)),
			hash21(lattice + vec2(1.0, 1.0)),
			eased.x
		),
		eased.y
	);
}

float fbm(vec2 position, int count) {
	float total = 0.0;
	float amplitude = 0.5;
	float amplitude_sum = 0.0;

	for (int i = 0; i < 6; i++) {
		if (i >= count) {
			break;
		}

		total += value_noise(position) * amplitude;
		amplitude_sum += amplitude;
		position = ROT * position * 2.03 + OCTAVE_SHIFT;
		amplitude *= 0.5;
	}

	return total / max(amplitude_sum, 0.0001);
}

float bayer_quantize(float value, vec2 cell, int level_count) {
	ivec2 m = ivec2(mod(cell, float(BAYER_SIZE)));
	float threshold_value =
		(BAYER_MATRIX[m.y * BAYER_SIZE + m.x] + PIXEL_CENTER) / 16.0;

	return floor(
		clamp(value, 0.0, 1.0) * float(level_count)
		+ threshold_value
	) / float(level_count);
}

float temporary_clear(vec2 world) {
	float clear = 0.0;

	for (int i = 0; i < MAX_DISTURBERS; i++) {
		vec4 a = disturb_a[i];

		if (a.w <= 0.0 || a.z <= 0.0) {
			continue;
		}

		float distance_to_object = length(world - a.xy);
		float radius_ratio = distance_to_object / a.z;
		float influence = 1.0 - smoothstep(0.0, 1.0, radius_ratio);

		clear = max(clear, influence * a.w);
	}

	return clear;
}

void fragment() {
	float edge_size = max(edge_pixel_size, 1.0);

	// Sample the cloud shape on a small screen-space grid.
	// This affects the silhouette without quantizing its alpha.
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 edge_cell = floor(FRAGCOORD.xy / edge_size);
	vec2 sample_screen = (edge_cell + vec2(0.5)) * edge_size;
	vec2 edge_uv = sample_screen / screen_size;

	// Keep shading and density evaluation at the original fragment UV.
	vec2 world = view_origin + SCREEN_UV * view_size;
	vec2 edge_world = view_origin + edge_uv * view_size;

	float t = TIME * evolve_speed;

	vec2 p = world * cloud_scale + seed_offset + drift * TIME;
	vec2 edge_p = edge_world * cloud_scale + seed_offset + drift * TIME;

	vec2 warp_flow = vec2(
		cos(t * 1.1),
		sin(t * 0.83)
	) * warp_travel;

	vec2 shape_flow = vec2(
		sin(t * 0.61),
		cos(t * 0.47)
	) * shape_travel;

	vec2 region_flow = vec2(
		cos(t * 0.37 + 1.0),
		sin(t * 0.29)
	) * region_travel;

	vec2 warp = vec2(
		fbm(edge_p + warp_flow, 3),
		fbm(edge_p + WARP_OFFSET - warp_flow.yx * 0.7, 3)
	);

	vec2 q = edge_p + (warp - 0.5) * warp_strength + shape_flow;

	float edge_raw = fbm(q, octaves);
	float edge_region = fbm(
		edge_p * 0.35 + REGION_OFFSET + region_flow,
		2
	);
	float edge_density = edge_raw + (edge_region - 0.5) * clump_strength;

	// Only the outer silhouette uses coarse samples.
	float body = smoothstep(
		threshold - softness * 0.25,
		threshold + softness,
		edge_density
	);

	// Evaluate persistent carving at the actual fragment position.
	vec2 field_uv = (world - density_origin) / density_size;
	float persistent_density = 1.0;

	if (
		field_uv.x >= 0.0 && field_uv.x <= 1.0 &&
		field_uv.y >= 0.0 && field_uv.y <= 1.0
	) {
		persistent_density = texture(density_texture, field_uv).r;
	}

	float density_mask = smoothstep(0.0, 0.8, persistent_density);
	float persistent_mask = mix(1.0, density_mask, density_influence);
	body *= persistent_mask;

	// Evaluate temporary cuts per fragment so they remain small and smooth.
	float temporary_mask = 1.0 - temporary_clear(world) * clear_amount;
	body *= temporary_mask;

	// Preserve continuous alpha for transparent, soft-looking mist.
	float alpha = clamp(body * opacity, 0.0, 1.0);

	if (alpha <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 light_dir = normalize(light_direction);

		float raw = fbm(p + (warp - 0.5) * warp_strength + shape_flow, octaves);

		float toward_light = fbm(
			p + (warp - 0.5) * warp_strength + shape_flow
				+ light_dir * LIGHT_SAMPLE_OFFSET,
			octaves
		);

		float rim = clamp(
			(raw - toward_light) * light_strength + 0.5,
			0.0,
			1.0
		);

		float tint_noise = fbm(
			p * 0.6 + TINT_OFFSET + region_flow * 0.5,
			2
		);

		vec2 shade_cell = floor(FRAGCOORD.xy / max(pixel_size, 1.0));

		float tint = bayer_quantize(
			smoothstep(0.35, 0.65, tint_noise),
			shade_cell,
			3
		);

		vec3 color = mix(
			mist_color_a.rgb,
			mist_color_b.rgb,
			tint
		);

		color = mix(color * shadow_tone, color, rim);

		float hot = smoothstep(0.55, 1.0, rim)
			* smoothstep(
				threshold + 0.1,
				threshold + softness + 0.25,
				raw
			);

		float highlight = bayer_quantize(
			hot * highlight_amount,
			shade_cell,
			3
		);

		color = mix(
			color,
			mist_highlight_color.rgb,
			highlight
		);

		COLOR = vec4(color, alpha);
	}
}