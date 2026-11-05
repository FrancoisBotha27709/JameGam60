shader_type canvas_item;

// Procedural parallax starfield with twinkling stars and randomly glowing constellations,
// rendered as pixel art with 4x4 Bayer dithering. Lit constellations connect their stars with
// faint lines. Motion is smooth (sub-pixel) while the image stays pixelated.
//
// Extras on top of the base starfield:
//   - Two layers of domain-warped nebula mist (far and near) with a 3-color palette
//   - A diagonal galactic dust band with a soft haze and thousands of one-pixel stars
//   - Diffraction flares on the biggest stars
//   - Occasional shooting stars
//   - Soft horizon glow and vignette
//   - A palette dropdown with premade color schemes (or "Custom" to use the color uniforms)
// Everything is dithered, so it keeps the same pixel-art look.
// Apply to a full-screen ColorRect. For a gameplay background, put that ColorRect in a CanvasLayer
// behind the game and attach starfield_background.gd so the sky scrolls with the camera.

group_uniforms Palette;
// Pick a premade color scheme, or choose "Custom" to use the individual color uniforms below.
uniform float sky_brightness : hint_range(0.0, 3.0) = 1.0; // final output multiplier; 1.0 = as authored
uniform int palette : hint_enum("Custom (use colors below)", "Violet Nebula", "Emerald Aurora", "Crimson Ember", "Deep Ocean", "Golden Dusk", "Monochrome") = 0;

group_uniforms Game_background;
// Feed these from a script (see starfield_background.gd) to use the shader as a gameplay background.
// With the defaults the shader behaves exactly like the self-animating main-menu version.
uniform vec2 camera_position = vec2(0.0);                              // world position of the camera, in pixels
uniform float view_height_world = 1080.0;                              // visible world height in pixels (viewport height / zoom)
uniform float camera_influence : hint_range(0.0, 2.0) = 0.6;           // how far the nearest star layer slides per world pixel (1 = same speed as the world)
uniform float ambient_motion : hint_range(0.0, 1.0) = 1.0;             // idle drift and sway; set to 0 in gameplay so only the camera moves the sky

group_uniforms Base_sky_and_stars;
uniform vec4 background_color : source_color = vec4(0.01, 0.01, 0.05, 1.0);
uniform vec4 cool_star_color : source_color = vec4(0.7, 0.8, 1.0, 1.0);
uniform vec4 warm_star_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform vec4 line_color : source_color = vec4(0.6, 0.75, 1.0, 1.0);

uniform float pixel_size : hint_range(1.0, 16.0, 1.0) = 4.0;
uniform int star_levels : hint_range(1, 8) = 4;

uniform int layer_count : hint_range(1, 6) = 4;
uniform float far_cell_count : hint_range(5.0, 80.0) = 30.0;
uniform float near_cell_count : hint_range(2.0, 40.0) = 8.0;
uniform float far_drift_scale : hint_range(0.0, 1.0) = 0.2;
uniform vec2 drift_velocity = vec2(0.015, 0.006);
uniform float sway_amplitude : hint_range(0.0, 0.2) = 0.03;
uniform float sway_speed : hint_range(0.0, 2.0) = 0.15;

uniform float star_density : hint_range(0.0, 1.0) = 0.45;
uniform float min_star_radius : hint_range(0.01, 0.25) = 0.03;
uniform float max_star_radius : hint_range(0.01, 0.25) = 0.12;
uniform float star_wobble_amount : hint_range(0.0, 0.1) = 0.05;
uniform float star_wobble_speed : hint_range(0.0, 5.0) = 0.6;

uniform float twinkle_speed : hint_range(0.0, 10.0) = 2.5;
uniform float twinkle_speed_variation : hint_range(0.0, 1.0) = 0.6;
uniform float twinkle_depth : hint_range(0.0, 1.0) = 0.5;

uniform float constellation_period : hint_range(1.0, 30.0) = 8.0;
uniform float constellation_chance : hint_range(0.0, 1.0) = 0.35;
uniform float constellation_glow_strength : hint_range(0.0, 2.0) = 0.7;
uniform float line_brightness : hint_range(0.0, 1.0) = 0.5;
uniform float line_half_width_pixels : hint_range(0.1, 2.0) = 0.5;
uniform float max_line_length : hint_range(0.5, 6.0) = 2.0;

group_uniforms Star_flares; // diffraction spikes on the largest stars
uniform float flare_strength : hint_range(0.0, 2.0) = 0.9;
uniform float flare_size_threshold : hint_range(0.0, 1.0) = 0.8;

group_uniforms Nebula_mist;
uniform vec4 mist_color_a : source_color = vec4(0.25, 0.10, 0.50, 1.0);        // deep violet
uniform vec4 mist_color_b : source_color = vec4(0.06, 0.30, 0.55, 1.0);        // cold teal-blue
uniform vec4 mist_highlight_color : source_color = vec4(0.95, 0.42, 0.62, 1.0); // hot pink glow
uniform float mist_highlight_amount : hint_range(0.0, 1.0) = 0.7;

uniform int mist_octaves : hint_range(1, 6) = 5;
uniform float mist_threshold : hint_range(0.0, 1.0) = 0.42;
uniform float mist_softness : hint_range(0.01, 1.0) = 0.32;
uniform float mist_warp_strength : hint_range(0.0, 4.0) = 1.6;
uniform float mist_flow_speed : hint_range(0.0, 0.5) = 0.025;
uniform float mist_breathing : hint_range(0.0, 0.5) = 0.15;
uniform int mist_levels : hint_range(1, 8) = 5;

uniform float far_mist_scale : hint_range(0.5, 10.0) = 2.2;
uniform float far_mist_parallax : hint_range(0.0, 1.0) = 0.06;
uniform float far_mist_intensity : hint_range(0.0, 2.0) = 0.55;

uniform float near_mist_scale : hint_range(0.5, 10.0) = 3.4;
uniform float near_mist_parallax : hint_range(0.0, 1.0) = 0.35;
uniform float near_mist_intensity : hint_range(0.0, 2.0) = 0.30;

group_uniforms Galactic_dust_band;
uniform vec4 dust_color : source_color = vec4(0.55, 0.45, 0.75, 1.0);
uniform float dust_strength : hint_range(0.0, 1.0) = 1.0;
uniform float dust_haze_strength : hint_range(0.0, 1.0) = 0.35;
uniform float dust_star_density : hint_range(0.0, 0.5) = 0.16;
uniform float band_angle : hint_range(-3.1416, 3.1416) = 0.5;
uniform vec2 band_center = vec2(0.9, 0.5);
uniform float band_width : hint_range(0.05, 1.0) = 0.22;
uniform float band_ripple : hint_range(0.0, 1.0) = 0.3;
uniform float dust_parallax : hint_range(0.0, 1.0) = 0.1;
uniform float band_repeat_distance : hint_range(1.5, 20.0) = 3.0; // spacing between repeated bands, so one is always reachable in-game

group_uniforms Shooting_stars;
uniform vec4 shooting_star_color : source_color = vec4(0.85, 0.93, 1.0, 1.0);
uniform int shooting_star_slots : hint_range(0, 4) = 2;
uniform float shooting_star_period : hint_range(2.0, 60.0) = 10.0;
uniform float shooting_star_duration : hint_range(0.3, 4.0) = 1.4;
uniform float shooting_star_chance : hint_range(0.0, 1.0) = 0.8;
uniform float shooting_star_travel : hint_range(0.1, 1.5) = 0.6;
uniform float shooting_star_trail_length : hint_range(0.02, 0.5) = 0.15;

group_uniforms Atmosphere;
uniform vec4 horizon_color : source_color = vec4(0.10, 0.06, 0.24, 1.0);
uniform float horizon_strength : hint_range(0.0, 1.0) = 0.5;
uniform float horizon_falloff : hint_range(1.0, 6.0) = 2.8;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.6;
uniform float vignette_inner_radius : hint_range(0.0, 1.0) = 0.3;
uniform float vignette_outer_radius : hint_range(0.0, 1.5) = 0.85;

// Constants
const int BAYER_SIZE = 4;
const int BAYER_ENTRY_COUNT = 16;
const float BAYER_MATRIX[BAYER_ENTRY_COUNT] = float[BAYER_ENTRY_COUNT](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

const vec2 HASH_SCALE = vec2(123.34, 456.21);
// Seeds wrap at this value so hashing stays precise (and stars stay stable) far from the origin.
const float HASH_WRAP = 1024.0;
const float HASH_MIX_OFFSET = 45.32;
const vec2 HASH_SECOND_CHANNEL_OFFSET = vec2(37.17, 91.53);
const vec2 PRESENCE_SEED_OFFSET = vec2(11.3, 5.7);
const vec2 SIZE_SEED_OFFSET = vec2(23.1, 47.9);
const vec2 COLOR_SEED_OFFSET = vec2(71.9, 13.3);
const float STAR_EDGE_MARGIN = 0.25;
const float MAX_HALO_RADIUS = STAR_EDGE_MARGIN;
const float LAYER_SEED_STRIDE = 17.0;
const float CYCLE_SEED_STRIDE = 3.7;
const int CONSTELLATION_SIDE = 4;
const float PIXEL_CENTER = 0.5;
const float MIN_CORE_RADIUS_PIXELS = 1.0;
const float SEGMENT_EPSILON = 0.000001;
const float SWAY_AXIS_RATIO = 0.7;

// Flares must stay inside the star's own grid cell, so they can never be longer than the margin.
const float MAX_FLARE_LENGTH = STAR_EDGE_MARGIN * 0.96;
const float MIN_FLARE_LENGTH_RATIO = 0.55;
const float FLARE_HALF_WIDTH_PIXELS = 0.5;

// Nebula noise
const int MAX_MIST_OCTAVES = 6;
const int WARP_OCTAVES = 3;
const float MIST_LACUNARITY = 2.03;
const float MIST_GAIN = 0.5;
const mat2 MIST_ROTATION = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
const vec2 MIST_OCTAVE_SHIFT = vec2(17.3, 9.1);
const vec2 MIST_WARP_OFFSET = vec2(5.2, 1.3);
const vec2 MIST_TINT_OFFSET = vec2(9.1, 3.7);
const float MIST_TINT_SCALE = 0.6;
const float MIST_TINT_LEVELS = 3.0;
const float MIST_BREATHING_SPEED = 0.2;
const float FAR_MIST_SEED = 0.0;
const float NEAR_MIST_SEED = 31.7;

// Dust band
const float DUST_RIPPLE_SCALE = 3.0;
const float DUST_CLOUD_SCALE = 6.0;
const vec2 DUST_CLOUD_OFFSET = vec2(41.3, 7.9);
const vec2 DUST_CELL_SCALE = vec2(0.37, 0.53);
const vec2 DUST_VARIATION_OFFSET = vec2(13.7, 29.1);
const float DUST_MIN_BRIGHTNESS = 0.4;
const float DUST_TWINKLE_SPEED = 3.0;
const float DUST_TWINKLE_DEPTH = 0.3;

// Shooting stars
const float SLOT_SEED_STRIDE = 13.7;
const float SHOOTING_CYCLE_WRAP = 128.0;
const float SHOOTING_MAX_HEIGHT = 0.5;
const float SHOOTING_MIN_SLOPE = 0.25;
const float SHOOTING_MAX_SLOPE = 0.7;
const float SHOOTING_HEAD_RADIUS_PIXELS = 2.0;
const float SHOOTING_LINE_HALF_WIDTH_PIXELS = 0.7;

// Atmosphere
const int HORIZON_LEVELS = 6;

// ---------------------------------------------------------------------------------------------
// Color palettes
// Preset i (1-based, matching the palette dropdown) lives at index i - 1 in every array below.
// Palette 0 ("Custom") ignores these and uses the individual color uniforms instead.
// ---------------------------------------------------------------------------------------------
const int PRESET_COUNT = 6;

const vec3 PALETTE_BACKGROUND[PRESET_COUNT] = vec3[PRESET_COUNT](
	vec3(0.01, 0.01, 0.05),  // Violet Nebula
	vec3(0.01, 0.03, 0.04),  // Emerald Aurora
	vec3(0.04, 0.01, 0.02),  // Crimson Ember
	vec3(0.00, 0.02, 0.06),  // Deep Ocean
	vec3(0.04, 0.02, 0.04),  // Golden Dusk
	vec3(0.01, 0.01, 0.01)  // Monochrome
);
const vec3 PALETTE_COOL_STAR[PRESET_COUNT] = vec3[PRESET_COUNT](
	vec3(0.70, 0.80, 1.00),  // Violet Nebula
	vec3(0.70, 1.00, 0.90),  // Emerald Aurora
	vec3(1.00, 0.85, 0.80),  // Crimson Ember
	vec3(0.70, 0.90, 1.00),  // Deep Ocean
	vec3(1.00, 0.90, 0.80),  // Golden Dusk
	vec3(0.85, 0.88, 0.95)  // Monochrome
);
const vec3 PALETTE_WARM_STAR[PRESET_COUNT] = vec3[PRESET_COUNT](
	vec3(1.00, 0.90, 0.70),  // Violet Nebula
	vec3(1.00, 0.95, 0.70),  // Emerald Aurora
	vec3(1.00, 0.75, 0.45),  // Crimson Ember
	vec3(0.95, 0.95, 0.85),  // Deep Ocean
	vec3(1.00, 0.85, 0.50),  // Golden Dusk
	vec3(0.95, 0.95, 0.90)  // Monochrome
);
const vec3 PALETTE_LINE[PRESET_COUNT] = vec3[PRESET_COUNT](
	vec3(0.60, 0.75, 1.00),  // Violet Nebula
	vec3(0.55, 1.00, 0.80),  // Emerald Aurora
	vec3(1.00, 0.60, 0.50),  // Crimson Ember
	vec3(0.50, 0.85, 1.00),  // Deep Ocean
	vec3(1.00, 0.80, 0.55),  // Golden Dusk
	vec3(0.70, 0.75, 0.85)  // Monochrome
);
const vec3 PALETTE_MIST_A[PRESET_COUNT] = vec3[PRESET_COUNT](
	vec3(0.25, 0.10, 0.50),  // Violet Nebula
	vec3(0.05, 0.30, 0.30),  // Emerald Aurora
	vec3(0.45, 0.07, 0.10),  // Crimson Ember
	vec3(0.03, 0.15, 0.40),  // Deep Ocean
	vec3(0.40, 0.15, 0.30),  // Golden Dusk
	vec3(0.14, 0.15, 0.20)  // Monochrome
);
const vec3 PALETTE_MIST_B[PRESET_COUNT] = vec3[PRESET_COUNT](
	vec3(0.06, 0.30, 0.55),  // Violet Nebula
	vec3(0.12, 0.20, 0.50),  // Emerald Aurora
	vec3(0.35, 0.12, 0.30),  // Crimson Ember
	vec3(0.02, 0.35, 0.45),  // Deep Ocean
	vec3(0.55, 0.25, 0.15),  // Golden Dusk
	vec3(0.20, 0.22, 0.28)  // Monochrome
);
const vec3 PALETTE_MIST_HIGHLIGHT[PRESET_COUNT] = vec3[PRESET_COUNT](
	vec3(0.95, 0.42, 0.62),  // Violet Nebula
	vec3(0.60, 1.00, 0.65),  // Emerald Aurora
	vec3(1.00, 0.55, 0.20),  // Crimson Ember
	vec3(0.50, 0.95, 0.95),  // Deep Ocean
	vec3(1.00, 0.75, 0.35),  // Golden Dusk
	vec3(0.62, 0.66, 0.75)  // Monochrome
);
const vec3 PALETTE_DUST[PRESET_COUNT] = vec3[PRESET_COUNT](
	vec3(0.55, 0.45, 0.75),  // Violet Nebula
	vec3(0.40, 0.80, 0.70),  // Emerald Aurora
	vec3(0.80, 0.40, 0.35),  // Crimson Ember
	vec3(0.40, 0.65, 0.85),  // Deep Ocean
	vec3(0.85, 0.60, 0.50),  // Golden Dusk
	vec3(0.50, 0.52, 0.60)  // Monochrome
);
const vec3 PALETTE_SHOOTING_STAR[PRESET_COUNT] = vec3[PRESET_COUNT](
	vec3(0.85, 0.93, 1.00),  // Violet Nebula
	vec3(0.85, 1.00, 0.90),  // Emerald Aurora
	vec3(1.00, 0.90, 0.75),  // Crimson Ember
	vec3(0.80, 0.97, 1.00),  // Deep Ocean
	vec3(1.00, 0.95, 0.80),  // Golden Dusk
	vec3(0.95, 0.97, 1.00)  // Monochrome
);
const vec3 PALETTE_HORIZON[PRESET_COUNT] = vec3[PRESET_COUNT](
	vec3(0.10, 0.06, 0.24),  // Violet Nebula
	vec3(0.03, 0.16, 0.16),  // Emerald Aurora
	vec3(0.22, 0.05, 0.07),  // Crimson Ember
	vec3(0.02, 0.10, 0.22),  // Deep Ocean
	vec3(0.26, 0.10, 0.14),  // Golden Dusk
	vec3(0.07, 0.08, 0.11)  // Monochrome
);

int preset_index() {
	return clamp(palette - 1, 0, PRESET_COUNT - 1);
}

vec3 palette_background() {
	return palette == 0 ? background_color.rgb : PALETTE_BACKGROUND[preset_index()];
}

vec3 palette_cool_star() {
	return palette == 0 ? cool_star_color.rgb : PALETTE_COOL_STAR[preset_index()];
}

vec3 palette_warm_star() {
	return palette == 0 ? warm_star_color.rgb : PALETTE_WARM_STAR[preset_index()];
}

vec3 palette_line() {
	return palette == 0 ? line_color.rgb : PALETTE_LINE[preset_index()];
}

vec3 palette_mist_a() {
	return palette == 0 ? mist_color_a.rgb : PALETTE_MIST_A[preset_index()];
}

vec3 palette_mist_b() {
	return palette == 0 ? mist_color_b.rgb : PALETTE_MIST_B[preset_index()];
}

vec3 palette_mist_highlight() {
	return palette == 0 ? mist_highlight_color.rgb : PALETTE_MIST_HIGHLIGHT[preset_index()];
}

vec3 palette_dust() {
	return palette == 0 ? dust_color.rgb : PALETTE_DUST[preset_index()];
}

vec3 palette_shooting_star() {
	return palette == 0 ? shooting_star_color.rgb : PALETTE_SHOOTING_STAR[preset_index()];
}

vec3 palette_horizon() {
	return palette == 0 ? horizon_color.rgb : PALETTE_HORIZON[preset_index()];
}

// ---------------------------------------------------------------------------------------------
// Hashing, noise and dithering
// ---------------------------------------------------------------------------------------------

// Pseudo-random value in [0, 1) from a 2D seed.
float hash21(vec2 seed) {
	seed = fract(mod(seed, HASH_WRAP) * HASH_SCALE);
	seed += dot(seed, seed + HASH_MIX_OFFSET);
	return fract(seed.x * seed.y);
}

// Two independent pseudo-random values in [0, 1) from a 2D seed.
vec2 hash22(vec2 seed) {
	return vec2(hash21(seed), hash21(seed + HASH_SECOND_CHANNEL_OFFSET));
}

// Smooth 2D value noise in [0, 1).
float value_noise(vec2 position) {
	vec2 lattice = floor(position);
	vec2 local = fract(position);
	vec2 eased = local * local * (3.0 - 2.0 * local);
	float bottom_left = hash21(lattice);
	float bottom_right = hash21(lattice + vec2(1.0, 0.0));
	float top_left = hash21(lattice + vec2(0.0, 1.0));
	float top_right = hash21(lattice + vec2(1.0, 1.0));
	return mix(mix(bottom_left, bottom_right, eased.x), mix(top_left, top_right, eased.x), eased.y);
}

// Layered noise (fractal Brownian motion), normalised to roughly [0, 1]. Each octave is rotated
// so the grid axes of the underlying noise never show through.
float fbm(vec2 position, int octaves) {
	float total = 0.0;
	float amplitude = 0.5;
	float amplitude_sum = 0.0;
	for (int octave = 0; octave < MAX_MIST_OCTAVES; octave++) {
		if (octave >= octaves) {
			break;
		}
		total += value_noise(position) * amplitude;
		amplitude_sum += amplitude;
		position = MIST_ROTATION * position * MIST_LACUNARITY + MIST_OCTAVE_SHIFT;
		amplitude *= MIST_GAIN;
	}
	return total / amplitude_sum;
}

// 4x4 ordered-dither threshold in (0, 1) for a given pixel.
float bayer_threshold(vec2 screen_pixel) {
	ivec2 matrix_cell = ivec2(mod(screen_pixel, float(BAYER_SIZE)));
	return (BAYER_MATRIX[matrix_cell.y * BAYER_SIZE + matrix_cell.x] + PIXEL_CENTER) / float(BAYER_ENTRY_COUNT);
}

// Snaps a 0..1 value to a limited number of levels, using Bayer dithering to hide the banding.
float bayer_quantize(float value, vec2 screen_pixel, int levels) {
	float level_count = float(levels);
	return floor(clamp(value, 0.0, 1.0) * level_count + bayer_threshold(screen_pixel)) / level_count;
}

// ---------------------------------------------------------------------------------------------
// Stars and constellations
// ---------------------------------------------------------------------------------------------

// Per-star brightness multiplier that dips and recovers at a star-specific speed and phase.
float twinkle_factor(float star_seed) {
	float speed = twinkle_speed * mix(1.0 - twinkle_speed_variation, 1.0 + twinkle_speed_variation, star_seed);
	float wave = sin(TIME * speed + star_seed * TAU) * 0.5 + 0.5;
	return 1.0 - twinkle_depth * wave;
}

// Grid coordinate of the constellation block that a star cell belongs to.
vec2 constellation_region(vec2 cell_id) {
	return floor(cell_id / float(CONSTELLATION_SIDE));
}

// Smooth 0..1 pulse for a constellation region; each cycle it randomly lights up or stays dark.
float constellation_glow(vec2 region_id, float layer_seed) {
	float region_seed = hash21(region_id + layer_seed);
	float cycle_progress = TIME / constellation_period + region_seed;
	float cycle_seed = floor(cycle_progress) * CYCLE_SEED_STRIDE;
	float is_lit = step(hash21(region_id + layer_seed + cycle_seed), constellation_chance);
	float envelope = sin(fract(cycle_progress) * PI);
	return is_lit * envelope * envelope;
}

// Slowly wandering star center in layer space (xy) and whether the cell holds a star (z).
vec3 star_anchor(vec2 cell_id, float layer_seed) {
	vec2 cell_seed = cell_id + layer_seed;
	if (hash21(cell_seed + PRESENCE_SEED_OFFSET) > star_density) {
		return vec3(0.0);
	}
	vec2 position_roll = hash22(cell_seed);
	vec2 wobble_phase = position_roll.yx * TAU;
	vec2 wobble = vec2(sin(TIME * star_wobble_speed + wobble_phase.x), cos(TIME * star_wobble_speed + wobble_phase.y));
	vec2 center_in_cell = mix(vec2(STAR_EDGE_MARGIN), vec2(1.0 - STAR_EDGE_MARGIN), position_roll);
	return vec3(cell_id + center_in_cell + wobble * star_wobble_amount, 1.0);
}

// Shortest distance from a point to the line segment between two stars.
float segment_distance(vec2 point, vec2 segment_start, vec2 segment_end) {
	vec2 segment = segment_end - segment_start;
	float along = dot(point - segment_start, segment) / max(dot(segment, segment), SEGMENT_EPSILON);
	return distance(point, segment_start + segment * clamp(along, 0.0, 1.0));
}

// Thin four-armed cross that fades along its length. offset is the pixel's position relative to the
// star in cell units, and half_width is the arm half-thickness in the same units.
float star_flare(vec2 offset, float flare_length, float half_width) {
	vec2 distance_from_star = abs(offset);
	float horizontal_arm = (1.0 - smoothstep(0.0, flare_length, distance_from_star.x)) * step(distance_from_star.y, half_width);
	float vertical_arm = (1.0 - smoothstep(0.0, flare_length, distance_from_star.y)) * step(distance_from_star.x, half_width);
	float arms = max(horizontal_arm, vertical_arm);
	return arms * arms;
}

// Dithered color of the single star (if any) in this grid cell; pixel_grid is one screen pixel in cell units.
vec3 star_in_cell(vec2 layer_position, vec2 screen_pixel, float pixel_grid, float layer_seed) {
	vec2 cell_id = floor(layer_position);
	vec3 anchor = star_anchor(cell_id, layer_seed);
	if (anchor.z == 0.0) {
		return vec3(0.0);
	}

	vec2 cell_seed = cell_id + layer_seed;
	vec2 offset = layer_position - anchor.xy;
	float star_distance = length(offset);
	float size_roll = hash21(cell_seed + SIZE_SEED_OFFSET);
	float core_radius = max(mix(min_star_radius, max_star_radius, size_roll * size_roll), pixel_grid * MIN_CORE_RADIUS_PIXELS);
	float glow = constellation_glow(constellation_region(cell_id), layer_seed);
	float twinkle = twinkle_factor(hash22(cell_seed).x);
	float glow_boost = 1.0 + glow * constellation_glow_strength;

	float core = smoothstep(core_radius, 0.0, star_distance);
	float halo = smoothstep(MAX_HALO_RADIUS, 0.0, star_distance);
	float brightness = core * twinkle * glow_boost;
	brightness += halo * halo * glow * constellation_glow_strength;

	// Only the biggest stars get a flare; it grows with size and flickers with the star.
	if (size_roll > flare_size_threshold) {
		float size_ratio = smoothstep(flare_size_threshold, 1.0, size_roll);
		float flare_length = MAX_FLARE_LENGTH * mix(MIN_FLARE_LENGTH_RATIO, 1.0, size_ratio);
		float flare = star_flare(offset, flare_length, pixel_grid * FLARE_HALF_WIDTH_PIXELS);
		brightness += flare * flare_strength * twinkle * glow_boost;
	}

	vec3 star_color = mix(palette_cool_star(), palette_warm_star(), hash21(cell_seed + COLOR_SEED_OFFSET));
	return star_color * bayer_quantize(brightness, screen_pixel, star_levels);
}

// Dithered lines linking a lit constellation's stars in a snaking chain, fading with the glow pulse.
vec3 constellation_lines(vec2 layer_position, vec2 screen_pixel, float pixel_grid, float layer_seed) {
	vec2 region_id = constellation_region(floor(layer_position));
	float glow = constellation_glow(region_id, layer_seed);
	if (glow <= 0.0) {
		return vec3(0.0);
	}

	float half_width = line_half_width_pixels * pixel_grid;
	float last_column = float(CONSTELLATION_SIDE - 1);
	float coverage = 0.0;
	bool has_previous_star = false;
	vec2 previous_center = vec2(0.0);

	for (int chain_index = 0; chain_index < CONSTELLATION_SIDE * CONSTELLATION_SIDE; chain_index++) {
		float row = float(chain_index / CONSTELLATION_SIDE);
		float column = float(chain_index % CONSTELLATION_SIDE);
		float snaked_column = mix(column, last_column - column, mod(row, 2.0));
		vec3 anchor = star_anchor(region_id * float(CONSTELLATION_SIDE) + vec2(snaked_column, row), layer_seed);
		if (anchor.z == 0.0) {
			continue;
		}
		if (has_previous_star && distance(previous_center, anchor.xy) <= max_line_length) {
			coverage = max(coverage, step(segment_distance(layer_position, previous_center, anchor.xy), half_width));
		}
		previous_center = anchor.xy;
		has_previous_star = true;
	}

	return palette_line() * bayer_quantize(coverage * glow * line_brightness, screen_pixel, star_levels);
}

// ---------------------------------------------------------------------------------------------
// Nebula mist
// ---------------------------------------------------------------------------------------------

// Cloud density in [0, 1]: noise whose sample position is bent by two slowly flowing noise fields,
// which gives the curling, wispy shapes of a real nebula.
float mist_density(vec2 position) {
	vec2 flow = vec2(TIME, -TIME * SWAY_AXIS_RATIO) * mist_flow_speed;
	vec2 warp = vec2(
		fbm(position + flow, WARP_OCTAVES),
		fbm(position + MIST_WARP_OFFSET - flow * SWAY_AXIS_RATIO, WARP_OCTAVES)
	);
	return fbm(position + (warp - 0.5) * mist_warp_strength, mist_octaves);
}

// One dithered layer of colored mist. Color steps (violet <-> teal, then a hot highlight in the
// densest parts) are dithered too, so the clouds look like hand-placed pixels rather than gradients.
vec3 mist_layer(vec2 sky_position, vec2 screen_pixel, vec2 drift, float parallax, float scale, float seed, float intensity, float vignette) {
	if (intensity <= 0.0) {
		return vec3(0.0);
	}

	vec2 position = (sky_position + drift * parallax) * scale + vec2(seed, seed * 0.57);
	float density = mist_density(position);
	float body = smoothstep(mist_threshold, mist_threshold + mist_softness, density);
	float breathing = 1.0 + mist_breathing * sin(TIME * MIST_BREATHING_SPEED + seed);
	float lit = bayer_quantize(body * intensity * breathing * vignette, screen_pixel, mist_levels);
	if (lit <= 0.0) {
		return vec3(0.0);
	}

	float tint_noise = fbm(position * MIST_TINT_SCALE + MIST_TINT_OFFSET, 2);
	float tint = bayer_quantize(smoothstep(0.35, 0.65, tint_noise), screen_pixel, int(MIST_TINT_LEVELS));
	float hot_core = smoothstep(mist_threshold + 0.15, mist_threshold + mist_softness + 0.25, density);
	float highlight = bayer_quantize(hot_core * mist_highlight_amount, screen_pixel, int(MIST_TINT_LEVELS));

	vec3 color = mix(palette_mist_a(), palette_mist_b(), tint);
	color = mix(color, palette_mist_highlight(), highlight);
	return color * lit;
}

// ---------------------------------------------------------------------------------------------
// Galactic dust band
// ---------------------------------------------------------------------------------------------

// A diagonal river of faint haze and one-pixel stars, like the Milky Way seen from inside.
vec3 galactic_dust(vec2 sky_position, vec2 screen_pixel, vec2 drift, float pixel_unit, float vignette) {
	if (dust_strength <= 0.0) {
		return vec3(0.0);
	}

	vec2 position = sky_position + drift * dust_parallax;
	vec2 band_direction = vec2(cos(band_angle), sin(band_angle));
	vec2 band_normal = vec2(-band_direction.y, band_direction.x);
	float ripple = (fbm(position * DUST_RIPPLE_SCALE, 3) - 0.5) * band_ripple;
	float across = dot(position - band_center, band_normal) + ripple;
	across = mod(across + band_repeat_distance * 0.5, band_repeat_distance) - band_repeat_distance * 0.5;
	float band_mask = exp(-(across * across) / (band_width * band_width));

	float cloudiness = fbm(position * DUST_CLOUD_SCALE + DUST_CLOUD_OFFSET, 4);
	float haze = bayer_quantize(band_mask * cloudiness * dust_haze_strength * vignette, screen_pixel, star_levels);

	// One-pixel stars: each screen-sized cell inside the band has a small chance to hold one.
	vec2 dust_cell = floor(position / pixel_unit);
	float dust_roll = hash21(dust_cell * DUST_CELL_SCALE);
	float presence_threshold = 1.0 - band_mask * dust_star_density * (0.4 + cloudiness);
	float is_present = step(presence_threshold, dust_roll);
	float variation = hash21(dust_cell + DUST_VARIATION_OFFSET);
	float twinkle = 1.0 - DUST_TWINKLE_DEPTH * (sin(TIME * DUST_TWINKLE_SPEED + variation * TAU) * 0.5 + 0.5);
	float sparkle = bayer_quantize(mix(DUST_MIN_BRIGHTNESS, 1.0, variation) * twinkle, screen_pixel, star_levels);
	vec3 sparkle_color = mix(palette_cool_star(), palette_warm_star(), variation);

	return (palette_dust() * haze + sparkle_color * sparkle * is_present) * dust_strength;
}

// ---------------------------------------------------------------------------------------------
// Shooting stars
// ---------------------------------------------------------------------------------------------

// A few meteors that streak across the sky at random times, with a bright head and a tapering tail.
vec3 shooting_stars(vec2 sky_position, vec2 screen_pixel, float pixel_unit, float aspect) {
	float intensity = 0.0;

	for (int slot = 0; slot < shooting_star_slots; slot++) {
		float slot_seed = float(slot) * SLOT_SEED_STRIDE + 1.0;
		float slot_period = shooting_star_period * mix(0.7, 1.3, hash21(vec2(slot_seed, 1.0)));
		float slot_progress = TIME / slot_period + hash21(vec2(slot_seed, 2.0));
		float flight = fract(slot_progress) * slot_period / shooting_star_duration;
		if (flight >= 1.0) {
			continue;
		}

		float cycle_seed = mod(floor(slot_progress), SHOOTING_CYCLE_WRAP);
		vec2 roll_a = hash22(vec2(slot_seed, cycle_seed));
		vec2 roll_b = hash22(vec2(cycle_seed + 7.3, slot_seed + 3.1));
		if (roll_b.y > shooting_star_chance) {
			continue;
		}

		// Streaks start in the upper half and fall diagonally toward the opposite side of the screen.
		float side = roll_a.x > 0.5 ? -1.0 : 1.0;
		vec2 direction = normalize(vec2(side, mix(SHOOTING_MIN_SLOPE, SHOOTING_MAX_SLOPE, roll_b.x)));
		vec2 start = vec2(roll_a.x * aspect, roll_a.y * SHOOTING_MAX_HEIGHT);
		vec2 head = start + direction * flight * shooting_star_travel;

		vec2 relative = sky_position - head;
		float behind_head = -dot(relative, direction);
		float across = abs(dot(relative, vec2(-direction.y, direction.x)));
		if (behind_head < 0.0 || behind_head > shooting_star_trail_length) {
			// Still allow the round head to show in front of the tail's start.
			float head_only = smoothstep(pixel_unit * SHOOTING_HEAD_RADIUS_PIXELS, 0.0, length(relative));
			intensity = max(intensity, head_only * sin(flight * PI));
			continue;
		}

		float taper = 1.0 - behind_head / shooting_star_trail_length;
		float half_width = pixel_unit * SHOOTING_LINE_HALF_WIDTH_PIXELS * mix(0.5, 1.0, taper);
		float tail = step(across, half_width) * taper * taper;
		float head_glow = smoothstep(pixel_unit * SHOOTING_HEAD_RADIUS_PIXELS, 0.0, length(relative));
		intensity = max(intensity, (tail + head_glow) * sin(flight * PI));
	}

	return palette_shooting_star() * bayer_quantize(intensity, screen_pixel, star_levels);
}

// ---------------------------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------------------------

void fragment() {
	float pixel_unit = pixel_size * SCREEN_PIXEL_SIZE.y;
	vec2 screen_pixel = floor(FRAGCOORD.xy / pixel_size);
	vec2 sky_position = (screen_pixel + PIXEL_CENTER) * pixel_unit;
	vec2 sway = vec2(sin(TIME * sway_speed), sin(TIME * sway_speed * SWAY_AXIS_RATIO)) * sway_amplitude;
	vec2 camera_offset = camera_position / max(view_height_world, 1.0) * camera_influence;
	vec2 base_drift = (drift_velocity * TIME + sway) * ambient_motion + camera_offset;
	float vignette = 1.0 - vignette_strength * smoothstep(vignette_inner_radius, vignette_outer_radius, distance(UV, vec2(0.5)));

	vec3 sky_color = palette_background();

	// Soft glow rising from the bottom edge, dithered so it never bands.
	float horizon = bayer_quantize(pow(UV.y, horizon_falloff) * horizon_strength, screen_pixel, HORIZON_LEVELS);
	sky_color += palette_horizon() * horizon;

	// Behind the stars: distant mist and the dust band.
	sky_color += mist_layer(sky_position, screen_pixel, base_drift, far_mist_parallax, far_mist_scale, FAR_MIST_SEED, far_mist_intensity, vignette);
	sky_color += galactic_dust(sky_position, screen_pixel, base_drift, pixel_unit, vignette);

	for (int layer_index = 0; layer_index < layer_count; layer_index++) {
		float depth = float(layer_index) / max(float(layer_count - 1), 1.0);
		float cell_count = mix(far_cell_count, near_cell_count, depth);
		float parallax = mix(far_drift_scale, 1.0, depth);
		float layer_seed = float(layer_index) * LAYER_SEED_STRIDE;
		float pixel_grid = pixel_unit * cell_count;
		vec2 drift_offset = base_drift * parallax;
		vec2 layer_position = (sky_position + drift_offset) * cell_count;
		sky_color += constellation_lines(layer_position, screen_pixel, pixel_grid, layer_seed);
		sky_color += star_in_cell(layer_position, screen_pixel, pixel_grid, layer_seed);
	}

	// In front of the stars: wispy near mist and meteors.
	sky_color += mist_layer(sky_position, screen_pixel, base_drift, near_mist_parallax, near_mist_scale, NEAR_MIST_SEED, near_mist_intensity, vignette);
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	sky_color += shooting_stars(sky_position, screen_pixel, pixel_unit, aspect);

	COLOR = vec4(sky_color * sky_brightness, 1.0);
}
