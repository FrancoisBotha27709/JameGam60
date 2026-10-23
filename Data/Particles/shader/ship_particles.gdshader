shader_type particles;

group_uniforms emission;
uniform vec2 emit_offset = vec2(0.0);
uniform vec2 emit_box = vec2(3.0, 0.0);
uniform float direction_deg = 90.0;
uniform float spread_deg : hint_range(0.0, 180.0) = 8.0;
uniform float spread_bias : hint_range(0.2, 4.0) = 1.8;
uniform float speed_min = 90.0;
uniform float speed_max = 180.0;

group_uniforms motion;
uniform float drag = 2.0;
uniform vec2 accel = vec2(0.0);
uniform float turb_amp = 25.0;
uniform float turb_freq = 3.0;

group_uniforms look;
uniform float size_start = 0.6;
uniform float size_end = 0.0;
uniform float size_curve = 1.0;
uniform float size_random : hint_range(0.0, 1.0) = 0.3;
uniform float life_random : hint_range(0.0, 1.0) = 0.3;
uniform bool align_to_velocity = false;
uniform float stretch = 0.0;
uniform float spin_deg = 0.0;
uniform float rot_random : hint_range(0.0, 1.0) = 0.0;
uniform int rot_steps = 0;

group_uniforms control;
uniform float power : hint_range(0.0, 2.0) = 1.0;

uint pcg(uint v) {
	uint s = v * 747796405u + 2891336453u;
	uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
	return (w >> 22u) ^ w;
}
float rnd(inout uint s) {
	s = pcg(s);
	return float(s) * (1.0 / 4294967295.0);
}

void start() {
	uint s = pcg(NUMBER + pcg(RANDOM_SEED));
	float r1 = rnd(s);
	float r2 = rnd(s);
	float r3 = rnd(s);
	float r4 = rnd(s);
	float r5 = rnd(s);
	float r6 = rnd(s);
	float r7 = rnd(s);

	float k = r1 * 2.0 - 1.0;
	k = sign(k) * pow(abs(k), spread_bias);
	float ang = radians(direction_deg + k * spread_deg);

	// Emitter rotation only (ignores node scale)
	mat2 basis = mat2(normalize(EMISSION_TRANSFORM[0].xy), normalize(EMISSION_TRANSFORM[1].xy));
	VELOCITY.xy = basis * vec2(cos(ang), sin(ang)) * mix(speed_min, speed_max, r2) * power;

	TRANSFORM = EMISSION_TRANSFORM;
	TRANSFORM[3].xy += basis * (emit_offset + emit_box * vec2(r3 * 2.0 - 1.0, r4 * 2.0 - 1.0));

	CUSTOM = vec4(r5, 0.0, r6, 1.0 + life_random * r7);
}

void process() {
	float t = min(CUSTOM.y + DELTA * CUSTOM.w / LIFETIME, 1.0);
	CUSTOM.y = t;

	vec2 v = VELOCITY.xy * exp(-drag * DELTA) + accel * DELTA;
	float inv = inversesqrt(dot(v, v) + 1e-6);
	v += vec2(-v.y, v.x) * inv * sin((t * turb_freq + CUSTOM.x) * 6.2831853) * turb_amp * DELTA;
	VELOCITY.xy = v;

	float sz = mix(size_start, size_end, pow(t, size_curve))
		* (1.0 + size_random * (CUSTOM.z * 2.0 - 1.0)) * power;

	float ang = align_to_velocity
		? atan(v.y, v.x)
		: rot_random * CUSTOM.z * 6.2831853 + radians(spin_deg) * (CUSTOM.x * 2.0 - 1.0) * t * LIFETIME;
	if (rot_steps > 0) {
		float q = 6.2831853 / float(rot_steps);
		ang = floor(ang / q + 0.5) * q;
	}
	vec2 c = vec2(cos(ang), sin(ang));
	TRANSFORM[0].xy = c * sz * (1.0 + stretch * length(v));
	TRANSFORM[1].xy = vec2(-c.y, c.x) * sz;
}
