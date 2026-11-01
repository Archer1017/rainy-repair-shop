shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 rain_color : source_color = vec4(0.42, 0.71, 0.76, 0.4);
uniform float rain_speed = 0.65;

float hash(float p) { return fract(sin(p * 127.1) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	float rain = 0.0;
	for (int i = 0; i < 2; i++) {
		float layer = float(i);
		float columns = 61.0 + layer * 31.0;
		float column = floor(uv.x * columns);
		float seed = hash(column + layer * 79.0);
		float x = fract(uv.x * columns) - 0.35 - 0.22 * sin(uv.y * 5.0 + seed * 9.0);
		float trail = fract(uv.y * (2.5 + seed * 2.0) - TIME * rain_speed * (0.38 + seed * 0.65) + seed * 11.0);
		float line = (1.0 - smoothstep(0.012, 0.040, abs(x))) * smoothstep(0.20, 0.72, trail) * (1.0 - smoothstep(0.91, 1.0, trail));
		rain += line * (0.2 + 0.8 * seed);
	}
	float haze = 0.038 + 0.035 * pow(1.0 - uv.y, 2.0);
	ALBEDO = rain_color.rgb;
	ALPHA = haze + rain * rain_color.a;
}
