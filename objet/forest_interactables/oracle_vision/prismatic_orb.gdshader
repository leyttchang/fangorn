shader_type spatial;
render_mode unshaded, cull_back, blend_mix;

uniform float pulse_speed : hint_range(0.5, 8.0) = 2.8;
uniform float brightness : hint_range(0.5, 6.0) = 2.6;
uniform float alpha_base : hint_range(0.2, 1.0) = 0.94;

varying vec3 v_local_pos;
varying vec3 v_world_nrm;
varying vec3 v_view_dir;

vec3 spectral_palette(float t) {
	// Palette prismatique vive en cosinus (cyan -> magenta -> or -> émeraude -> violet)
	vec3 a = vec3(0.58, 0.52, 0.65);
	vec3 b = vec3(0.52, 0.48, 0.45);
	vec3 c = vec3(1.0, 1.0, 1.0);
	vec3 d = vec3(0.00, 0.33, 0.67);
	return max(vec3(0.02), a + b * cos(6.2831853 * (c * t + d)));
}

void vertex() {
	float t = TIME * pulse_speed;
	// Ondulation organique liquide à la surface de la sphère
	float w1 = sin(VERTEX.x * 7.5 + t * 1.7) * cos(VERTEX.y * 6.8 - t * 1.3);
	float w2 = sin(VERTEX.z * 8.2 + t * 2.1 + VERTEX.y * 4.0);
	float disp = (w1 * 0.6 + w2 * 0.4) * 0.055;
	VERTEX += NORMAL * disp;

	v_local_pos = VERTEX;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 cam_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	v_view_dir = normalize(cam_pos - world_pos);
}

void fragment() {
	float t = TIME * pulse_speed;
	float ndotv = clamp(abs(dot(normalize(v_world_nrm), normalize(v_view_dir))), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, 2.1);

	// Tourbillons chromatiques 3D multi-échelles
	vec3 p = v_local_pos * 3.4;
	float swirl = sin(p.x * 2.2 + t * 1.1) + cos(p.y * 2.7 - t * 1.4) + sin(p.z * 2.5 + t * 0.9);
	float swirl2 = cos((p.x - p.z) * 3.8 + t * 2.2 + swirl * 0.85);
	float hue_t = swirl * 0.22 + swirl2 * 0.18 + fresnel * 0.48 - t * 0.24;

	vec3 irid_a = spectral_palette(hue_t);
	vec3 irid_b = spectral_palette(hue_t + 0.37);
	vec3 core_white = vec3(1.25, 1.18, 1.35);

	float core_glow = pow(ndotv, 2.4);
	vec3 col = mix(irid_a, irid_b, 0.5 + 0.5 * sin(swirl2 * 2.4 + t));
	col = mix(col, core_white, core_glow * 0.45);
	col += spectral_palette(hue_t + 0.62) * fresnel * 1.35;

	float breath = 0.88 + 0.18 * sin(t * 2.3);
	ALBEDO = col * brightness * breath;
	ALPHA = clamp(alpha_base * mix(0.82, 1.0, fresnel), 0.0, 1.0);
}
