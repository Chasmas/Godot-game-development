// Chrome-sunset gradient for the HOTSHOT logotype.
shader_type canvas_item;

uniform float height = 120.0;
uniform vec4 top_color : source_color = vec4(1.0, 0.86, 0.3, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.24, 0.5, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.42, 0.11, 1.0, 1.0);
uniform float shine = 1.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {

	float t = clamp(local_pos.y / height, 0.0, 1.0);
	vec3 c = t < 0.52 ? mix(top_color.rgb, mid_color.rgb, t / 0.52) : mix(mid_color.rgb, bottom_color.rgb, (t - 0.52) / 0.48);
	// horizon line + chrome glints
	c = mix(c, vec3(1.0), smoothstep(0.012, 0.0, abs(t - 0.52)) * 0.9);
	float glint = (1.0 - smoothstep(0.0, 0.035, abs(fract(local_pos.x * 0.0025 + local_pos.y * 0.004 - TIME * 0.15) - 0.5))) * shine;
	c += glint * 0.6;
	// retro stripes in the lower half
	float stripe = step(0.6, t) * step(0.5, fract(t * 18.0));
	c = mix(c, c * 0.55, stripe * 0.6);
	COLOR = vec4(c, COLOR.a);
}
