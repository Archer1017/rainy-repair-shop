shader_type spatial;
uniform vec4 stone_color : source_color = vec4(0.24, 0.29, 0.28, 1.0);
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_position.xz * vec2(1.25, 2.1);
	p.x += mod(floor(p.y), 2.0) * 0.5;
	vec2 cell = fract(p);
	vec2 edge = min(cell, 1.0 - cell);
	float grout = smoothstep(0.014, 0.048, min(edge.x, edge.y));
	float variation = hash(floor(p));
	float cloud = sin(world_position.x * 0.6 + sin(world_position.z * 0.4)) * 0.035;
	ALBEDO = stone_color.rgb * (0.90 + variation * 0.18 + cloud) * mix(0.69, 1.0, grout);
	ROUGHNESS = 0.59 + variation * 0.16;
	SPECULAR = 0.28;
}
