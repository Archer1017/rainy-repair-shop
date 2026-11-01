shader_type spatial;
render_mode diffuse_burley;

uniform vec4 wood_color : source_color = vec4(0.27, 0.12, 0.055, 1.0);
uniform float grain_scale = 1.0;
varying vec3 local_position;

float hash(float n) { return fract(sin(n) * 43758.5453123); }
float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), f);
}

void vertex() { local_position = VERTEX; }

void fragment() {
	vec3 p = local_position * grain_scale;
	// Broad, quiet brush-like grain survives the wide camera without shimmer.
	float grain = p.x * 21.0 + sin(p.z * 0.9 + p.x * 2.0) * 1.2 + sin(p.z * 0.4) * 1.8;
	float fibres = noise(grain) * 0.10 + noise(grain * 2.2) * 0.025;
	float growth = smoothstep(0.83, 0.99, sin(grain * 0.48) * 0.5 + 0.5) * 0.035;
	float patina = noise(p.x * 3.0 + p.z * 0.7) * 0.045;
	ALBEDO = wood_color.rgb * (0.94 + fibres + patina - growth);
	ROUGHNESS = 0.79 + fibres * 0.12;
	SPECULAR = 0.22;
}
