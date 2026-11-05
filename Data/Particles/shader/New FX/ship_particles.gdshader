shader_type particles;

// =============================================================================
//  SIM SHADER  (pairs with ship_particles_draw.gdshader)
//  Every uniform added on top of the original fire shader defaults to "off", so
//  an existing material renders exactly as before.
//
//  Particle data layout (unchanged):  CUSTOM = (rand_a, life 0..1, rand_b, life_mult)
// =============================================================================

group_uniforms emission;
uniform vec2 emit_offset = vec2(0.0);
uniform vec2 emit_box = vec2(3.0, 0.0);                      // emit_shape 0: random point inside this half-size box
uniform int emit_shape : hint_range(0, 2) = 0;               // 0 box | 1 ring/disc/arc | 2 lightning bolt
uniform float emit_radius = 24.0;                            // shape 1: outer radius (px)
uniform float emit_radius_inner = 0.0;                       // shape 1: inner radius (== outer -> thin circle)
uniform float emit_arc_deg : hint_range(0.0, 360.0) = 360.0; // shape 1: arc span
uniform float emit_arc_center_deg = 0.0;                     // shape 1: arc centre direction
uniform int dir_mode : hint_range(0, 2) = 0;                 // 0 fixed | 1 radial (away from centre) | 2 tangent (swirl)
uniform float direction_deg = 90.0;                          // mode 0: heading. mode 1/2: offset added to radial/tangent. shape 2: bolt heading
uniform float spread_deg : hint_range(0.0, 180.0) = 8.0;
uniform float spread_bias : hint_range(0.2, 4.0) = 1.8;
uniform float speed_min = 90.0;
uniform float speed_max = 180.0;
uniform float speed_pow : hint_range(0.1, 4.0) = 1.0;       // >1 favours slow particles, <1 favours fast ones

group_uniforms bolt;                                         // only used by emit_shape 2
uniform float bolt_length = 120.0;
uniform float bolt_amp = 16.0;                               // zig-zag size (px)
uniform float bolt_freq = 6.0;                               // zig-zag segments along the bolt
uniform float bolt_width = 1.2;                              // random scatter across the bolt (px)
uniform float bolt_branch : hint_range(0.0, 1.0) = 0.25;     // share of particles that sit on side branches
uniform int bolt_branches : hint_range(0, 8) = 3;
uniform float bolt_branch_len : hint_range(0.0, 1.0) = 0.4;
uniform int bolt_seed = -1;                                  // -1 = new bolt shape every emission cycle
uniform float bolt_fps = 30.0;

group_uniforms motion;
uniform float drag = 2.0;
uniform vec2 accel = vec2(0.0);
uniform float turb_amp = 25.0;
uniform float turb_freq = 3.0;
uniform float attract = 0.0;                                 // accel toward emitter centre (negative = push out)
uniform float swirl = 0.0;                                   // tangential accel around emitter centre
uniform float orbit_k = 0.0;                                 // spring that holds particles at orbit_radius
uniform float orbit_radius = 0.0;
uniform float flow_amp = 0.0;                                // world-space noise wind (gusts, drifting gas)
uniform float flow_scale = 0.01;                             // 1 / noise wavelength in px
uniform float flow_speed = 0.3;
uniform float jitter = 0.0;                                  // random velocity kicks (sparks, crackle)
uniform float jitter_hz = 20.0;

group_uniforms look;
uniform float size_start = 0.6;
uniform float size_end = 0.0;
uniform float size_curve = 1.0;
uniform float size_random : hint_range(0.0, 1.0) = 0.3;
uniform float life_random : hint_range(0.0, 1.0) = 0.3;
uniform float grow_in : hint_range(0.0, 1.0) = 0.0;          // fraction of life spent growing from 0 (soft pop-in)
uniform float pulse_amp = 0.0;                               // size breathing
uniform float pulse_hz = 1.0;
uniform float aspect = 1.0;                                  // thickness multiplier (streaks, wind, sparks)
uniform bool align_to_velocity = false;
uniform float stretch = 0.0;
uniform float spin_deg = 0.0;
uniform float rot_random : hint_range(0.0, 1.0) = 0.0;
uniform int rot_steps = 0;

group_uniforms control;
uniform float power : hint_range(0.0, 2.0) = 1.0;

const float K_TAU = 6.2831853;

uint pcg(uint v) {
	uint s = v * 747796405u + 2891336453u;
	uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
	return (w >> 22u) ^ w;
}
float rnd(inout uint s) {
	s = pcg(s);
	return float(s) * (1.0 / 4294967295.0);
}

// Stateless 2D lattice hash + value noise (world-space wind, bolt shapes)
float hash2(vec2 p) {
	ivec2 i = ivec2(floor(p));
	uint h = pcg(uint(i.x) * 1664525u + pcg(uint(i.y) + 1013904223u));
	return float(h) * (1.0 / 4294967295.0);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
			   mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}
// Piece-wise linear noise -> sharp kinks, which is what makes a bolt look like lightning
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
	float r1 = rnd(s);
	float r2 = rnd(s);
	float r3 = rnd(s);
	float r4 = rnd(s);
	float r5 = rnd(s);
	float r6 = rnd(s);
	float r7 = rnd(s);
	float r8 = rnd(s);
	float r9 = rnd(s);
	float r10 = rnd(s);
	float r11 = rnd(s);

	float k = r1 * 2.0 - 1.0;
	k = sign(k) * pow(abs(k), spread_bias);

	// ---- spawn position (local to the emitter, before rotation) ----
	vec2 off = emit_box * vec2(r3 * 2.0 - 1.0, r4 * 2.0 - 1.0);
	if (emit_shape == 1) {
		float a = radians(emit_arc_center_deg + (r8 - 0.5) * emit_arc_deg);
		float rr = sqrt(mix(emit_radius_inner * emit_radius_inner, emit_radius * emit_radius, r9));
		off = vec2(cos(a), sin(a)) * rr;
	} else if (emit_shape == 2) {
		// All particles of one emission cycle share the same seed -> they form ONE coherent bolt.
		float sd = bolt_seed >= 0 ? float(bolt_seed % 4096) : float(pcg(uint(TIME * bolt_fps)) % 4096u);
		vec2 lp;
		if (r8 < bolt_branch && bolt_branches > 0) {
			float bi = floor(r9 * float(bolt_branches));
			float bs2 = sd + 17.0 * (bi + 1.0);
			float u0 = 0.12 + 0.76 * hash2(vec2(bi, bs2));
			float bside = hash2(vec2(bi + 31.0, bs2)) < 0.5 ? -1.0 : 1.0;
			float ba = bside * (0.35 + 0.7 * hash2(vec2(bi + 57.0, bs2)));
			float blen = bolt_length * bolt_branch_len * (0.5 + hash2(vec2(bi + 83.0, bs2)));
			vec2 bd = vec2(cos(ba), sin(ba));
			vec2 bn = vec2(-bd.y, bd.x);
			float jz = (lnoise(r3 * bolt_freq * 0.8, bs2) - 0.5) * 2.0;
			lp = bolt_main(u0, sd) + bd * (r3 * blen) + bn * jz * bolt_amp * 0.5 * r3;
		} else {
			lp = bolt_main(r3, sd);
		}
		lp.y += (r10 * 2.0 - 1.0) * bolt_width;
		float ba0 = radians(direction_deg);
		off = mat2(vec2(cos(ba0), sin(ba0)), vec2(-sin(ba0), cos(ba0))) * lp;
	}

	// ---- heading ----
	float base = 0.0;
	if (dir_mode != 0) {
		if (dot(off, off) < 1e-4) {
			base = r11 * K_TAU;               // point emitter: random direction
		} else {
			base = atan(off.y, off.x);
		}
		if (dir_mode == 2) {
			base += 1.5707963;
		}
	}
	float ang = base + radians(direction_deg + k * spread_deg);

	// Emitter rotation only (ignores node scale)
	mat2 basis = mat2(normalize(EMISSION_TRANSFORM[0].xy), normalize(EMISSION_TRANSFORM[1].xy));
	VELOCITY.xy = basis * vec2(cos(ang), sin(ang)) * mix(speed_min, speed_max, pow(r2, speed_pow)) * power;

	TRANSFORM = EMISSION_TRANSFORM;
	TRANSFORM[3].xy += basis * (emit_offset + off);

	CUSTOM = vec4(r5, 0.0, r6, 1.0 + life_random * r7);
}

void process() {
	float t0 = CUSTOM.y;
	float t = min(t0 + DELTA * CUSTOM.w / LIFETIME, 1.0);
	CUSTOM.y = t;

	vec2 v = VELOCITY.xy * exp(-drag * DELTA) + accel * DELTA;
	float inv = inversesqrt(dot(v, v) + 1e-6);
	v += vec2(-v.y, v.x) * inv * sin((t * turb_freq + CUSTOM.x) * 6.2831853) * turb_amp * DELTA;

	// ---- forces around the emitter centre ----
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
			float ja = rnd(js) * K_TAU;
			v += vec2(cos(ja), sin(ja)) * jitter * (0.5 + 0.5 * rnd(js));
		}
	}
	VELOCITY.xy = v;

	float sz = mix(size_start, size_end, pow(t, size_curve))
		* (1.0 + size_random * (CUSTOM.z * 2.0 - 1.0)) * power;
	if (grow_in > 0.0) {
		sz *= smoothstep(0.0, grow_in, t);
	}
	if (pulse_amp != 0.0) {
		sz *= 1.0 + pulse_amp * sin(TIME * pulse_hz * K_TAU + CUSTOM.x * K_TAU);
	}

	float ang = align_to_velocity
		? atan(v.y, v.x)
		: rot_random * CUSTOM.z * 6.2831853 + radians(spin_deg) * (CUSTOM.x * 2.0 - 1.0) * t * LIFETIME;
	if (rot_steps > 0) {
		float q = 6.2831853 / float(rot_steps);
		ang = floor(ang / q + 0.5) * q;
	}
	vec2 c = vec2(cos(ang), sin(ang));
	TRANSFORM[0].xy = c * sz * (1.0 + stretch * length(v));
	TRANSFORM[1].xy = vec2(-c.y, c.x) * sz * aspect;
}
