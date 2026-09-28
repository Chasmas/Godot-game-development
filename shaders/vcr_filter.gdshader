shader_type canvas_item;
// A tape playing on an old deck: the picture holds still, the tape doesn't.
// Scanlines, a slight colour split, a soft tracking bar rolling up the
// frame (lines inside it slip sideways), fine noise, a little line jitter,
// and now and then a thin flash of head-switching at the bottom.

uniform float strength = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	// the tracking bar: a band rolling slowly upward
	float bar_y = 1.0 - fract(t * 0.07);
	float in_bar = smoothstep(0.08, 0.0, abs(uv.y - bar_y));
	uv.x += in_bar * 0.006 * sin(uv.y * 400.0 + t * 20.0) * strength;
	// line jitter, very small
	uv.x += (hash(vec2(floor(uv.y * 270.0), floor(t * 24.0))) - 0.5) * 0.0012 * strength;
	// head-switching noise at the very bottom
	float hs = step(0.975, uv.y);
	uv.x += hs * (hash(vec2(floor(uv.y * 540.0), floor(t * 30.0))) - 0.5) * 0.02 * strength;
	// chroma split
	float sp = 0.0018 * strength;
	vec4 c;
	c.r = texture(TEXTURE, uv + vec2(sp, 0.0)).r;
	c.g = texture(TEXTURE, uv).g;
	c.b = texture(TEXTURE, uv - vec2(sp, 0.0)).b;
	c.a = texture(TEXTURE, uv).a;
	// scanlines and noise
	float scan = 0.92 + 0.08 * sin(uv.y * 1080.0);
	float n = (hash(uv * vec2(960.0, 540.0) + t) - 0.5) * 0.05 * strength;
	c.rgb = c.rgb * scan + n;
	// the bar is a touch brighter and washed
	c.rgb += in_bar * 0.05 * strength;
	// soft vignette
	vec2 d = UV - 0.5;
	c.rgb *= 1.0 - dot(d, d) * 0.6;
	COLOR = c * COLOR;
}
