shader_type particles;

// =============================================================================
//  FX SIM SHADER  (pairs with fx_particles_draw.gdshader)
//  Every original uniform keeps its name and meaning, so existing JSON presets work.
//  New uniforms default to "off".
// =============================================================================

group_uniforms emission;
uniform vec2 emit_offset = vec2(0.0);
uniform vec2 emit_box = vec2(0.0);
uniform vec2 emit_ring = vec2(0.0);                       // (inner, outer) radius of a random point on a ring/disc
uniform float direction_deg = 90.0;
uniform float spread_deg : hint_range(0.0, 180.0) = 10.0;
uniform float spread_bias : hint_range(0.2, 4.0) = 1.0;
uniform float outward : hint_range(0.0, 1.0) = 0.0;       // 1 = fly away from the emitter centre
uniform vec2 speed = vec2(80.0, 160.0);
uniform float speed_bias : hint_range(0.2, 4.0) = 1.0;

group_uniforms bolt;                                      // NEW: lightning emitter
uniform float bolt_length = 0.0;                          // > 0 turns the emitter into a jagged bolt along direction_deg
uniform float bolt_amp = 16.0;
uniform float bolt_freq = 6.0;
uniform float bolt_width = 1.2;
uniform float bolt_branch : hint_range(0.0, 1.0) = 0.25;
uniform int bolt_branches : hint_range(0, 8) = 3;
uniform float bolt_branch_len : hint_range(0.0, 1.0) = 0.4;
uniform int bolt_seed = -1;                               // -1 = new shape each emission cycle
uniform float bolt_fps = 30.0;

group_uniforms forces;
uniform float drag = 1.0;
uniform vec2 accel = vec2(0.0);
uniform float propel = 0.0;
uniform float curl = 0.0;
uniform float curl_random : hint_range(0.0, 1.0) = 0.0;
uniform float turb_amp = 0.0;
uniform float turb_freq = 3.0;
uniform float turb_chaos : hint_range(0.0, 1.0) = 0.4;
uniform float attract = 0.0;                              // NEW: accel toward emitter centre (negative = push out)
uniform float swirl = 0.0;                                // NEW: tangential accel around emitter centre (true spiral)
uniform float orbit_k = 0.0;                              // NEW: spring that holds particles at orbit_radius
uniform float orbit_radius = 0.0;
uniform float flow_amp = 0.0;                             // NEW: world-space noise wind
uniform float flow_scale = 0.01;
uniform float flow_speed = 0.3;
uniform float jitter = 0.0;                               // NEW: random velocity kicks (crackle)
uniform float jitter_hz = 20.0;

group_uniforms size;
uniform float size_start = 0.6;
uniform float size_end = 0.0;
uniform float size_bulge = 0.0;
uniform float size_curve = 1.0;
uniform float size_random : hint_range(0.0, 1.0) = 0.3;
uniform float pulse_amp : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_freq = 4.0;
uniform float grow_in : hint_range(0.0, 1.0) = 0.0;       // NEW: fraction of life spent growing from 0

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

float rnd1(inout uint s) {
	s = pcg(s);
	return float(s) * INV_U;
}

float hash2(vec2 p) {
	ivec2 i = ivec2(floor(p));
	uint h = pcg(uint(i.x) * 1664525u + pcg(uint(i.y) + 1013904223u));
	return float(h) * INV_U;
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
			   mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}
// piece-wise linear noise: sharp kinks, which is what makes a bolt read as lightning
float lnoise(float x, float sd) {
	float i = floor(x);
	return mix(hash2(vec2(i, sd)), hash2(vec2(i + 1.0, sd)), fract(x));
}
vec2 bolt_main(float u, float sd) {
	float zig = (lnoise(u * bolt_freq, sd) - 0.5) * 2.0
			  + (lnoise(u * bolt_freq * 2.7 + 5.0, sd + 3.0) - 0.5) * 0.7;
	return vec2(u * bolt_length, zig * bolt_amp * sin(u * 3.14159265));
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
	vec2 pos = emit_box * (b.yz * 2.0 - 1.0) + disc;

	if (bolt_length > 0.0) {
		// all particles of one emission cycle share a seed -> they form ONE coherent bolt
		float sd = bolt_seed >= 0 ? float(bolt_seed % 4096) : float(pcg(uint(TIME * bolt_fps)) % 4096u);
		vec2 lp;
		if (a.z < bolt_branch && bolt_branches > 0) {
			float bi = floor(a.y * float(bolt_branches));
			float bs2 = sd + 17.0 * (bi + 1.0);
			float u0 = 0.12 + 0.76 * hash2(vec2(bi, bs2));
			float bside = hash2(vec2(bi + 31.0, bs2)) < 0.5 ? -1.0 : 1.0;
			float ba = bside * (0.35 + 0.7 * hash2(vec2(bi + 57.0, bs2)));
			float blen = bolt_length * bolt_branch_len * (0.5 + hash2(vec2(bi + 83.0, bs2)));
			vec2 bd = vec2(cos(ba), sin(ba));
			vec2 bn = vec2(-bd.y, bd.x);
			float jz = (lnoise(b.y * bolt_freq * 0.8, bs2) - 0.5) * 2.0;
			lp = bolt_main(u0, sd) + bd * (b.y * blen) + bn * jz * bolt_amp * 0.5 * b.y;
		} else {
			lp = bolt_main(b.y, sd);
		}
		lp.y += (b.z * 2.0 - 1.0) * bolt_width;
		float bh = radians(direction_deg);
		pos = mat2(vec2(cos(bh), sin(bh)), vec2(-sin(bh), cos(bh))) * lp;
		disc = pos;
	}

	vec2 d = mix(vec2(cos(ang), sin(ang)), disc * inversesqrt(dot(disc, disc) + 1e-6), outward);
	d *= inversesqrt(dot(d, d) + 1e-6);

	// Emitter rotation only (ignores node scale)
	mat2 basis = mat2(normalize(EMISSION_TRANSFORM[0].xy), normalize(EMISSION_TRANSFORM[1].xy));
	VELOCITY.xy = basis * d * mix(speed.x, speed.y, pow(b.x, speed_bias)) * power;

	TRANSFORM = EMISSION_TRANSFORM;
	TRANSFORM[3].xy += basis * (emit_offset + pos);

	CUSTOM = vec4(b.w, 0.0, c.x, 1.0 + life_random * c.y);
	COLOR = vec4(vec3(1.0 - tint_jitter * c.z), 1.0 - alpha_jitter * c.w);
}

void process() {
	float t0 = CUSTOM.y;
	float t = min(t0 + DELTA * CUSTOM.w / LIFETIME, 1.0);
	CUSTOM.y = t;

	vec2 v = VELOCITY.xy;
	float inv = inversesqrt(dot(v, v) + 1e-6);
	vec2 vd = v * inv;
	float f = t * turb_freq;
	float w = sin((f + CUSTOM.x) * TWO_PI) + turb_chaos * sin((f * 2.37 + CUSTOM.z) * TWO_PI);
	float cs = curl * mix(1.0, CUSTOM.x * 2.0 - 1.0, curl_random);
	v += (accel + vd * propel + vec2(-vd.y, vd.x) * (cs + w * turb_amp)) * DELTA;

	// ---- forces around the emitter centre (spirals, orbits) ----
	if (attract != 0.0 || swirl != 0.0 || orbit_k > 0.0) {
		mat2 basis = mat2(normalize(EMISSION_TRANSFORM[0].xy), normalize(EMISSION_TRANSFORM[1].xy));
		vec2 ctr = EMISSION_TRANSFORM[3].xy + basis * emit_offset;
		vec2 rel = TRANSFORM[3].xy - ctr;
		float dist = length(rel);
		vec2 out_dir = rel / max(dist, 1e-3);
		v += (-out_dir * attract + vec2(-out_dir.y, out_dir.x) * swirl) * DELTA;
		if (orbit_k > 0.0) {
			v -= out_dir * (dist - orbit_radius) * orbit_k * DELTA;
		}
	}

	// ---- world-space noise wind ----
	if (flow_amp > 0.0) {
		vec2 fp = TRANSFORM[3].xy * flow_scale + vec2(TIME * flow_speed, TIME * flow_speed * 0.7);
		vec2 fl = vec2(vnoise(fp), vnoise(fp + vec2(37.2, 11.7))) * 2.0 - 1.0;
		v += fl * flow_amp * DELTA;
	}

	// ---- random velocity kicks, stepped at jitter_hz ----
	if (jitter > 0.0) {
		float a0 = t0 * LIFETIME / CUSTOM.w;
		float a1 = t * LIFETIME / CUSTOM.w;
		float st1 = floor(a1 * jitter_hz);
		if (st1 != floor(a0 * jitter_hz)) {
			uint js = pcg(uint(st1) + pcg(uint(CUSTOM.x * 65535.0) + 17u));
			float ja = rnd1(js) * TWO_PI;
			v += vec2(cos(ja), sin(ja)) * jitter * (0.5 + 0.5 * rnd1(js));
		}
	}

	v *= exp(-drag * DELTA);                  // frame-rate independent, same as ShipFX
	VELOCITY.xy = v;
	float spd = length(v);

	// Quadratic bezier through start / bulge / end (bulge 0 = straight line)
	float tc = pow(t, size_curve);
	float u = 1.0 - tc;
	float sz = u * u * size_start + 2.0 * u * tc * (0.5 * (size_start + size_end) + size_bulge) + tc * tc * size_end;
	sz *= (1.0 + size_random * (CUSTOM.z * 2.0 - 1.0))
		* (1.0 + pulse_amp * sin((t * pulse_freq + CUSTOM.x) * TWO_PI)) * power;
	if (grow_in > 0.0) {
		sz *= smoothstep(0.0, grow_in, t);
	}

	float ang = rot_random * CUSTOM.z * TWO_PI + radians(spin_deg) * (CUSTOM.x * 2.0 - 1.0) * t * LIFETIME;
	// atan(0,0) is undefined and can produce NaN transforms on some GPUs -> only align when moving
	if (align_to_velocity > 0.0 && dot(v, v) > 1e-6) {
		ang = mix(ang, atan(v.y, v.x), align_to_velocity);
	}
	if (rot_steps > 0) {
		float q = TWO_PI / float(rot_steps);
		ang = floor(ang / q + 0.5) * q;
	}
	vec2 cr = vec2(cos(ang), sin(ang));
	TRANSFORM[0].xy = cr * sz * (1.0 + stretch * spd);
	TRANSFORM[1].xy = vec2(-cr.y, cr.x) * sz;
}
