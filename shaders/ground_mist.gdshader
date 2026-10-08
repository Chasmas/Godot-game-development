shader_type canvas_item;
render_mode unshaded;
uniform vec4 mist_color : source_color = vec4(0.48, 0.53, 0.60, 0.13);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
 vec2 p=UV*vec2(10.0,5.0)+vec2(TIME*0.025,-TIME*0.012);
 float banks=noise(p)*0.65+noise(p*2.1+vec2(-TIME*0.015,0))*0.35;
 float edges=smoothstep(0.0,0.08,UV.x)*smoothstep(0.0,0.08,1.0-UV.x)*smoothstep(0.0,0.09,UV.y)*smoothstep(0.0,0.09,1.0-UV.y);
 COLOR=vec4(mist_color.rgb,mist_color.a*smoothstep(0.3,0.78,banks)*edges);
}
