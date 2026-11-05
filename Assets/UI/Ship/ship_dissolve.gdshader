shader_type canvas_item;

// 0 = normal sprite, 1 = fully dissolved
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Largest pixel block (in texture pixels) the sprite pixelates down to
uniform float max_pixel_size = 24.0;
// Size of the blocks that randomly vanish (in texture pixels)
uniform float dissolve_block = 6.0;
uniform vec4 edge_color : source_color = vec4(0.4, 0.9, 1.0, 1.0);
uniform float edge_width = 0.12;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 px = UV * tex_size;

	// Pixelate: snap sampling to the centre of a growing cell
	float cell = max(1.0, floor(mix(1.0, max_pixel_size, progress)));
	vec2 snapped = (floor(px / cell) + 0.5) * cell;
	vec4 col = texture(TEXTURE, snapped / tex_size);

	// Dissolve: each block has a random threshold, gone once progress passes it
	float r = hash(floor(px / dissolve_block));
	float keep = step(progress, r);

	// Glow on blocks that are about to disappear
	float glow = 1.0 - smoothstep(0.0, edge_width, r - progress);
	glow *= smoothstep(0.0, 0.05, progress); // no glow at rest
	col.rgb = mix(col.rgb, edge_color.rgb, glow * col.a);

	col.a *= keep;
	COLOR = col;
}