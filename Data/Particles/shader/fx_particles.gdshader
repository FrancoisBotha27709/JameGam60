shader_type particles;

group_uniforms emission;
uniform vec2 emit_offset = vec2(0.0);
uniform vec2 emit_box = vec2(0.0);
uniform vec2 emit_ring = vec2(0.0);
uniform float direction_deg = 90.0;
uniform float spread_deg : hint_range(0.0, 180.0) = 10.0;
uniform float spread_bias : hint_range(0.2, 4.0) = 1.0;
uniform float outward : hint_range(0.0, 1.0) = 0.0;
uniform vec2 speed = vec2(80.0, 160.0);
uniform float speed_bias : hint_range(0.2, 4.0) = 1.0;

group_uniforms forces;
uniform float drag = 1.0;
uniform vec2 accel = vec2(0.0);
uniform float propel = 0.0;
uniform float curl = 0.0;
uniform float curl_random : hint_range(0.0, 1.0) = 0.0;
uniform float turb_amp = 0.0;
uniform float turb_freq = 3.0;
uniform float turb_chaos : hint_range(0.0, 1.0) = 0.4;

group_uniforms size;
uniform float size_start = 0.6;
uniform float size_end = 0.0;
uniform float size_bulge = 0.0;
uniform float size_curve = 1.0;
uniform float size_random : hint_range(0.0, 1.0) = 0.3;
uniform float pulse_amp : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_freq = 4.0;

group_uniforms rotation;
uniform float align_to_velocity : hint_range(0.0, 1.0) = 0.0;
uniform float stretch = 0.0;
uniform float spin_deg = 0.0;
uniform float rot_random : hint_range(0.0, 1.0) = 0.0;
uniform int rot_steps = 0;

group_uniforms life;
uniform float life_random : hint_range(0.0, 1.0) = 0.3;
uniform float tint_jitter : hint_range(0.0, 1.0) = 0.0;
uniform float alpha_jitter : hint_range(0.0, 1.0) = 0.0;
uniform float power : hint_range(0.0, 2.0) = 1.0;
group_uniforms;

const float TWO_PI = 6.2831853;
const float INV_U = 1.0 / 4294967295.0;

uint pcg(uint v) {
	uint s = v * 747796405u + 2891336453u;
	uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
	return (w >> 22u) ^ w;
}

vec4 rnd4(inout uint s) {
	vec4 r;
	s = pcg(s);
	r.x = float(s) * INV_U;
	s = pcg(s);
	r.y = float(s) * INV_U;
	s = pcg(s);
	r.z = float(s) * INV_U;
	s = pcg(s);
	r.w = float(s) * INV_U;
	return r;
}

void start() {
	uint s = pcg(NUMBER + pcg(RANDOM_SEED));
	vec4 a = rnd4(s);
	vec4 b = rnd4(s);
	vec4 c = rnd4(s);

	float k = a.x * 2.0 - 1.0;
	k = sign(k) * pow(abs(k), spread_bias);
	float ang = radians(direction_deg + k * spread_deg);

	float rr = mix(emit_ring.x, emit_ring.y, sqrt(a.y));
	float ra = a.z * TWO_PI;
	vec2 disc = rr * vec2(cos(ra), sin(ra));

	vec2 d = mix(vec2(cos(ang), sin(ang)), disc * inversesqrt(dot(disc, disc) + 1e-6), outward);
	d *= inversesqrt(dot(d, d) + 1e-6);

	// Emitter rotation only (ignores node scale)
	mat2 basis = mat2(normalize(EMISSION_TRANSFORM[0].xy), normalize(EMISSION_TRANSFORM[1].xy));
	VELOCITY.xy = basis * d * mix(speed.x, speed.y, pow(b.x, speed_bias)) * power;

	TRANSFORM = EMISSION_TRANSFORM;
	TRANSFORM[3].xy += basis * (emit_offset + emit_box * (b.yz * 2.0 - 1.0) + disc);

	CUSTOM = vec4(b.w, 0.0, c.x, 1.0 + life_random * c.y);
	COLOR = vec4(vec3(1.0 - tint_jitter * c.z), 1.0 - alpha_jitter * c.w);
}

void process() {
	float t = min(CUSTOM.y + DELTA * CUSTOM.w / LIFETIME, 1.0);
	CUSTOM.y = t;

	vec2 v = VELOCITY.xy;
	float inv = inversesqrt(dot(v, v) + 1e-6);
	vec2 vd = v * inv;
	float f = t * turb_freq;
	float w = sin((f + CUSTOM.x) * TWO_PI) + turb_chaos * sin((f * 2.37 + CUSTOM.z) * TWO_PI);
	float cs = curl * mix(1.0, CUSTOM.x * 2.0 - 1.0, curl_random);
	v += (accel + vd * propel + vec2(-vd.y, vd.x) * (cs + w * turb_amp)) * DELTA;
	float spd = dot(v, v) * inv;                           // ~|v|, no sqrt
	v /= 1.0 + drag * DELTA;
	VELOCITY.xy = v;

	// Quadratic bezier through start / bulge / end (bulge 0 = straight line)
	float tc = pow(t, size_curve);
	float u = 1.0 - tc;
	float sz = u * u * size_start + 2.0 * u * tc * (0.5 * (size_start + size_end) + size_bulge) + tc * tc * size_end;
	sz *= (1.0 + size_random * (CUSTOM.z * 2.0 - 1.0))
		* (1.0 + pulse_amp * sin((t * pulse_freq + CUSTOM.x) * TWO_PI)) * power;

	float angR = rot_random * CUSTOM.z * TWO_PI + radians(spin_deg) * (CUSTOM.x * 2.0 - 1.0) * t * LIFETIME;
	float ang = mix(angR, atan(v.y, v.x), align_to_velocity);
	float q = TWO_PI / max(float(rot_steps), 1.0);
	ang = mix(ang, floor(ang / q + 0.5) * q, step(0.5, float(rot_steps)));
	vec2 cr = vec2(cos(ang), sin(ang));
	TRANSFORM[0].xy = cr * sz * (1.0 + stretch * spd);
	TRANSFORM[1].xy = vec2(-cr.y, cr.x) * sz;
}
