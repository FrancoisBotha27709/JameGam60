shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0, 0.2, 0.2, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pixel_size = 4.0;

float bayer8(ivec2 p) {
	int x = p.x & 7;
	int y = p.y & 7;
	int xr = x ^ y;
	int v = 0;
	for (int i = 0; i < 3; i++) {
		v |= ((((xr >> i) & 1) << 1) | ((y >> i) & 1)) << (2 * (2 - i));
	}
	return (float(v) + 0.5) / 64.0;
}

void fragment() {
	ivec2 cell = ivec2(floor(FRAGCOORD.xy / pixel_size));
	vec2 uv = (vec2(cell) * pixel_size) / (vec2(1.0) / SCREEN_PIXEL_SIZE);
	float d = distance(uv, vec2(0.5));
	float vig = smoothstep(0.2, 0.8, d);
	float cover = vig * vig * intensity * 0.6;
	float b = bayer8(cell);
	float on = step(b, cover);
	float bright = step(b, cover * cover);
	vec3 col = mix(tint.rgb * 0.35, tint.rgb, bright);
	COLOR = vec4(col, on);
}
