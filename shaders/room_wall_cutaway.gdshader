shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform bool has_texture = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness = 0.9;
uniform float visible_height = 0.45;
varying float world_height;
void vertex() {
	world_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}
void fragment() {
	if (world_height > visible_height) discard;
	ALBEDO = albedo_color.rgb;
	if (has_texture) ALBEDO *= texture(albedo_texture, UV).rgb;
	ROUGHNESS = roughness;
}
