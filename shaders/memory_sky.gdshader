shader_type sky;

// A painted blue-hour sky. The slow cloud banks leave a quiet, readable horizon.
uniform vec3 zenith_color : source_color = vec3(0.10, 0.23, 0.35);
uniform vec3 horizon_color : source_color = vec3(0.39, 0.61, 0.65);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), f.x), mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}
void sky() {
	float h = max(EYEDIR.y, 0.0);
	vec3 color = mix(horizon_color, zenith_color, smoothstep(0.0, 0.75, h));
	vec2 p = EYEDIR.xz / (0.32 + h) * 3.2;
	float field = noise(p + vec2(TIME * 0.0015, 0.0)) * 0.70 + noise(p * 2.1) * 0.30;
	float cloud = smoothstep(0.46, 0.78, field) * smoothstep(0.0, 0.12, h);
	vec3 cloud_color = mix(vec3(0.20, 0.33, 0.41), vec3(0.47, 0.65, 0.68), smoothstep(0.45, 0.80, field));
	color = mix(color, cloud_color, cloud * 0.55);
	vec3 moon_direction = normalize(vec3(-0.32, 0.38, -0.86));
	float moon_distance = distance(EYEDIR, moon_direction);
	float halo = exp(-moon_distance * 18.0) * 0.13;
	float moon = 1.0 - smoothstep(0.022, 0.026, moon_distance);
	color += vec3(0.69, 0.84, 0.85) * halo;
	color = mix(color, vec3(0.84, 0.92, 0.87) * 1.3, moon);
	COLOR = color;
}
