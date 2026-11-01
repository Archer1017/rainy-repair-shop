shader_type spatial;
render_mode diffuse_burley;
uniform vec4 water_color : source_color = vec4(0.12, 0.31, 0.38, 1.0);
varying vec3 world_position;
void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(p.x * 0.65 + TIME * 0.52) * 0.034 + sin(p.z * 0.9 - TIME * 0.63) * 0.023;
	world_position = p;
}
void fragment() {
	vec2 p = world_position.xz;
	float swell = sin(p.x * 0.22 + p.y * 0.37 + TIME * 0.25);
	float wave = sin(p.y * 2.7 + sin(p.x * 0.65 + TIME * 0.19) * 1.8 - TIME * 0.5);
	float crest = smoothstep(0.91, 1.0, wave) * (0.5 + 0.5 * sin(p.x * 0.9 + p.y * 0.25));
	float glimmer = exp(-pow((p.x + 4.0 + sin(p.y * 0.3) * 1.5) / 9.0, 2.0));
	glimmer *= (1.0 - smoothstep(-32.0, -4.0, p.y)) * crest;
	ALBEDO = water_color.rgb * (0.90 + swell * 0.08) + vec3(0.20, 0.36, 0.36) * crest * 0.10;
	METALLIC = 0.20;
	ROUGHNESS = 0.38;
	SPECULAR = 0.34;
	NORMAL_MAP = vec3(0.5 + sin(p.y * 2.7 + TIME * 0.5) * 0.025, 0.5 + sin(p.x * 1.7 - TIME * 0.6) * 0.018, 1.0);
	EMISSION = water_color.rgb * 0.13 + vec3(0.29, 0.51, 0.55) * glimmer * 0.18;
}
