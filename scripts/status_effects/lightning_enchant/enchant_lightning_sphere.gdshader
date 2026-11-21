shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec3 tint : source_color = vec3(0.18, 1.85, 3.2);

void fragment() {
	float ndv = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float pulse = 0.78 + 0.22 * sin(TIME * 18.0 + UV.x * 12.5 + UV.y * 9.0);
	float core = pow(ndv, 1.6) * pulse;
	ALBEDO = tint * (0.65 + core * 1.15);
	ALPHA = clamp(core * 0.92, 0.0, 1.0);
}
