shader_type canvas_item;
uniform sampler2D grain_source : repeat_enable, filter_linear;
uniform float strength = 0.35;
void fragment() {
	vec2 uv=UV;
	float tick=floor(TIME*12.0);
	vec3 a=texture(grain_source,uv*3.0+vec2(tick*.137,tick*.071)).rgb;
	vec3 b=texture(grain_source,uv.yx*7.0+vec2(tick*.031,-tick*.119)).rgb;
	float grain=fract(dot(a,vec3(13.7,17.1,9.2))+dot(b,vec3(11.0,3.0,7.0)));
	float scan=.7+.3*sin(uv.y*120.0);
	float band=.75+.25*sin(uv.y*6.283-TIME*1.8);
	COLOR=vec4(vec3(.20,.42,.48)*(grain*.65+.25)*scan*band*strength,1.0);
}
