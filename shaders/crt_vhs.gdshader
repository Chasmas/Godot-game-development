// HOTSHOT CALIFORNIA - VHS / CRT post process.
// Subtle by design: gameplay readability first.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform bool crt_enabled = true;
uniform float chroma = 1.0;          // chromatic aberration strength (0 = off)
uniform float scanline_strength = 0.18;
uniform float curvature = 0.035;
uniform float vignette = 0.35;
uniform float grain = 0.045;
uniform float tracking = 0.0;        // 0..1 burst of VHS tracking noise
uniform float brightness = 1.0;
uniform float saturation = 1.08;
uniform int colorblind = 0;          // 0 off, 1 protan, 2 deutan, 3 tritan (daltonize)
uniform vec4 flash_color = vec4(1.0, 0.1, 0.3, 0.0);
uniform float desaturate = 0.0;      // used for death / slow-mo
uniform vec4 tint = vec4(1.0, 1.0, 1.0, 0.0);
uniform float bloom = 0.45;          // neon glow strength (0 = off)
uniform float cel = 0.0;             // 0..1 colour banding for a cel-shaded finish

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

vec3 daltonize(vec3 c, int mode) {
	// LMS-based error redistribution (Fidaner et al.)
	mat3 rgb2lms = mat3(vec3(17.8824, 3.45565, 0.0299566), vec3(43.5161, 27.1554, 0.184309), vec3(4.11935, 3.86714, 1.46709));
	mat3 lms2rgb = inverse(rgb2lms);
	vec3 lms = rgb2lms * c;
	vec3 sim = lms;
	if (mode == 1) sim = vec3(2.02344 * lms.y - 2.52581 * lms.z, lms.y, lms.z);
	else if (mode == 2) sim = vec3(lms.x, 0.494207 * lms.x + 1.24827 * lms.z, lms.z);
	else sim = vec3(lms.x, lms.y, -0.395913 * lms.x + 0.801109 * lms.y);
	vec3 err = c - lms2rgb * sim;
	vec3 corr = vec3(0.0, err.r * 0.7 + err.g, err.r * 0.7 + err.b);
	return clamp(c + corr, 0.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (crt_enabled) {
		vec2 cc = uv - 0.5;
		float d = dot(cc, cc);
		uv = uv + cc * d * curvature;
	}
	// tracking wobble
	float line = floor(uv.y * 180.0);
	float wob = tracking * (hash(vec2(line, floor(TIME * 24.0))) - 0.5) * 0.02;
	wob += tracking * 0.004 * sin(uv.y * 40.0 + TIME * 30.0);
	uv.x += wob;

	vec3 col;
	float ca = chroma * 0.0016 * (crt_enabled ? 1.0 : 0.5);
	vec2 off = (uv - 0.5) * ca * 2.0 + vec2(ca * 0.5, 0.0);
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;

	if (bloom > 0.0) {
		// cheap 12-tap glow on bright pixels: neon, muzzle flashes, lamps
		vec2 px = 1.0 / vec2(textureSize(screen_tex, 0));
		vec3 acc = vec3(0.0);
		for (int i = 0; i < 12; i++) {
			float a = float(i) * 0.5236;
			for (int r = 1; r <= 2; r++) {
				vec2 o = vec2(cos(a), sin(a)) * px * float(r) * 3.5;
				vec3 s = texture(screen_tex, uv + o).rgb;
				acc += max(s - vec3(0.72), vec3(0.0)) / float(r);
			}
		}
		col += acc / 12.0 * bloom * 1.6;
	}
	if (cel > 0.0) {
		vec3 q = floor(col * 10.0 + 0.5) / 10.0;
		col = mix(col, q, cel * 0.5);
	}
	if (crt_enabled) {
		float sl = sin(SCREEN_UV.y * 540.0 * 3.14159) * 0.5 + 0.5;
		col *= 1.0 - scanline_strength * sl;
		col += (hash(uv * 800.0 + TIME) - 0.5) * grain;
		vec2 v = SCREEN_UV - 0.5;
		col *= 1.0 - vignette * dot(v, v) * 2.2;
		// tracking noise band
		float band = smoothstep(0.03, 0.0, abs(fract(SCREEN_UV.y * 0.5 - TIME * 0.07) - 0.5)) * tracking;
		col = mix(col, vec3(hash(uv * 900.0 + TIME)), band * 0.5);
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) col = vec3(0.0);
	}
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation * (1.0 - desaturate));
	col = mix(col, col * tint.rgb, tint.a);
	col *= brightness;
	if (colorblind > 0) col = daltonize(col, colorblind);
	col = mix(col, flash_color.rgb, flash_color.a);
	COLOR = vec4(col, 1.0);
}
