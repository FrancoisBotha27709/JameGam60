shader_type canvas_item;

uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform float pixel_size = 4.0;
uniform vec4 tint_color : source_color = vec4(1.0);
uniform float tint_mix : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / pixel_size);
	float h = hash(cell) * 0.7;
	COLOR.rgb = mix(COLOR.rgb, tint_color.rgb, tint_mix);
	COLOR.a *= smoothstep(h, h + 0.3, reveal);
}
