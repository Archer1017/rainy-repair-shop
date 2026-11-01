shader_type spatial;
uniform vec4 wall_color : source_color = vec4(0.19, 0.24, 0.22, 1.0);
varying vec3 position_world;
float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898,78.233, 37.719))) * 43758.5453); }
float soft_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y), mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() { position_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float mottling = soft_noise(position_world * 1.8);
	float brush = soft_noise(position_world * vec3(6.0, 14.0, 6.0));
	ALBEDO = wall_color.rgb * (0.96 + mottling * 0.08 + brush * 0.025);
	ROUGHNESS = 0.95;
	SPECULAR = 0.18;
}
