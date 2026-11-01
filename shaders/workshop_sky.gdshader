shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

// Soft, wide strokes keep the window atmospheric behind the moving rain.
float soft_noise(vec2 p) {
	return sin(p.x * 1.1 + sin(p.y * 0.71)) * 0.45 + sin(p.x * 2.4 - p.y * 0.8) * 0.22;
}
void fragment() {
	vec2 uv = UV;
	vec3 horizon = vec3(0.48, 0.66, 0.67);
	vec3 upper = vec3(0.15, 0.32, 0.43);
	vec3 col = mix(upper, horizon, smoothstep(0.08, 0.87, uv.y));
	float drift = TIME * 0.002;
	float cloud = soft_noise(vec2(uv.x * 13.0 + drift, uv.y * 31.0));
	float strokes = smoothstep(0.34, 0.66, cloud) * smoothstep(0.0, 0.22, uv.y) * (1.0-smoothstep(0.63, 0.91, uv.y));
	col = mix(col, vec3(0.69,0.79,0.77), strokes * 0.38);
	ALBEDO = col;
}
