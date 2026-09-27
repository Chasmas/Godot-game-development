shader_type canvas_item;
// Brings a painted story frame to life. The painting is one flat image, so
// the motion comes from zones laid over it (normalised rects in the frame):
//   0 sway     palm fronds, hair, papers: sideways wave, strongest at the top
//   1 ripple   water, wet asphalt, reflections
//   2 flicker  neon, lamps, firelight: irregular brightness
//   3 pulse    slow glow in and out
//   4 tv       a CRT: scanlines, rolling bar, jittery brightness
//   5 heat     haze rising off fire
//   6 blink    an LED or tally light, on and off
//   7 breathe  a person: the chest rises and falls (stretch from the bottom)
//   8 siren    police lights washing red, then blue
//   9 drift    smoke / clouds / fog sliding sideways
// zp = (amount, speed, phase, extra). Every zone fades out at its edges so
// nothing tears. On top: the emissive mask (neon, screens, fire) breathes
// with a slow per-area flicker, and a fine grain keeps the paint alive.

uniform sampler2D glow_mask : filter_linear, hint_default_black;
uniform float glow_amount = 0.35;
uniform float grain = 0.035;
uniform float time_offset = 0.0;
uniform int zn = 0;
uniform int zt[16];
uniform vec4 zr[16];
uniform vec4 zp[16];

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(vec2(i, 0.0)), hash(vec2(i + 1.0, 0.0)), f * f * (3.0 - 2.0 * f));
}
float feather(vec2 uv, vec4 r) {
	vec2 lo = (uv - r.xy) / max(r.zw, vec2(0.001));
	vec2 e = smoothstep(vec2(0.0), vec2(0.18), lo) * smoothstep(vec2(0.0), vec2(0.18), 1.0 - lo);
	return e.x * e.y;
}

void fragment() {
	float t = TIME + time_offset;
	vec2 uv = UV;
	vec2 off = vec2(0.0);
	// geometric zones first (they move the lookup)
	for (int i = 0; i < 16; i++) {
		if (i >= zn) break;
		int ty = zt[i];
		vec4 r = zr[i];
		vec4 p = zp[i];
		float w = feather(UV, r);
		if (w <= 0.0) continue;
		float ly = clamp((UV.y - r.y) / max(r.w, 0.001), 0.0, 1.0);
		if (ty == 0) {
			off.x += sin(t * p.y + UV.y * 40.0 + p.z) * p.x * 0.004 * (1.0 - ly) * w;
		} else if (ty == 1) {
			off += vec2(sin(UV.y * 260.0 + t * p.y * 3.0 + p.z), cos(UV.x * 180.0 + t * p.y * 2.0)) * p.x * 0.0012 * w;
		} else if (ty == 5) {
			off.x += sin(UV.y * 140.0 - t * 7.0 * p.y + p.z) * p.x * 0.0022 * w;
			off.y += cos(UV.x * 110.0 - t * 5.0 * p.y) * p.x * 0.0016 * w;
		} else if (ty == 7) {
			float bottom = r.y + r.w;
			off.y += (UV.y - bottom) * sin(t * p.y * 1.6 + p.z) * p.x * 0.012 * w;
		} else if (ty == 9) {
			off.x += (noise1(UV.y * 8.0 + t * 0.3 * p.y) - 0.5) * p.x * 0.01 * w;
		}
	}
	vec4 col = texture(TEXTURE, uv + off);
	// light zones (they change the colour)
	for (int i = 0; i < 16; i++) {
		if (i >= zn) break;
		int ty = zt[i];
		vec4 r = zr[i];
		vec4 p = zp[i];
		float w = feather(UV, r);
		if (w <= 0.0) continue;
		if (ty == 2) {
			float n = noise1(t * p.y * 6.0 + p.z) * 0.7 + noise1(t * p.y * 17.0 + p.z * 3.0) * 0.3;
			float drop = step(0.93, noise1(t * p.y * 2.3 + p.z * 7.0)) * 0.5;
			col.rgb *= 1.0 + (n - 0.5) * p.x * w - drop * p.x * w;
		} else if (ty == 3) {
			col.rgb *= 1.0 + sin(t * p.y + p.z) * p.x * 0.5 * w;
		} else if (ty == 4) {
			float lines = 0.92 + 0.08 * sin(UV.y * 900.0);
			float roll = smoothstep(0.0, 0.04, abs(fract(UV.y * 0.8 - t * 0.12 * p.y) - 0.5) - 0.44);
			float jit = 0.95 + 0.05 * noise1(t * 40.0 + p.z);
			vec3 tv = col.rgb * mix(1.0, lines * jit, p.x) + vec3(0.06, 0.08, 0.1) * (1.0 - roll) * p.x;
			col.rgb = mix(col.rgb, tv, w);
		} else if (ty == 6) {
			float on = step(0.5, fract(t * p.y / 2.0 + p.z));
			col.rgb += vec3(1.0, 0.2, 0.15) * on * p.x * w * max(col.r, 0.3);
		} else if (ty == 8) {
			float s = sin(t * p.y * 4.0 + p.z);
			vec3 tint = s > 0.0 ? vec3(1.0, 0.1, 0.12) : vec3(0.15, 0.3, 1.0);
			col.rgb += tint * abs(s) * p.x * 0.35 * w;
		}
	}
	// emissive areas breathe, each part of the frame on its own rhythm
	float m = texture(glow_mask, UV).r;
	if (m > 0.0) {
		float area = noise1(t * 1.3 + floor(UV.x * 6.0) * 7.0 + floor(UV.y * 4.0) * 13.0);
		float spark = step(0.965, noise1(t * 9.0 + floor(UV.x * 5.0) * 3.0)) * 0.6;
		col.rgb += col.rgb * m * glow_amount * (area - 0.35 - spark);
	}
	col.rgb += (hash(UV * 900.0 + fract(t * 23.0)) - 0.5) * grain;
	COLOR = col * COLOR;
}
