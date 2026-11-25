shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D skin_tex : source_color, filter_linear_mipmap;
uniform bool has_skin_tex = false;
uniform vec4 base_albedo : source_color = vec4(1.0);
uniform vec3 seed_world_pos = vec3(0.0);
uniform float swell_radius = 1.15;
uniform float swell_amount = 0.0;
uniform float charge_ratio : hint_range(0.0, 1.0) = 0.0;

varying float v_swell;

void vertex() {
	vec3 w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = distance(w_pos, seed_world_pos);
	float sphere_mask = smoothstep(swell_radius, 0.0, d);
	v_swell = sphere_mask;

	float pulse = 0.82 + 0.18 * sin(TIME * (10.0 + charge_ratio * 22.0));
	float model_scale = max(length(MODEL_MATRIX[0].xyz), 0.001);
	vec3 n_dir = length(NORMAL) > 0.0001 ? normalize(NORMAL) : vec3(0.0, 1.0, 0.0);
	VERTEX += n_dir * ((sphere_mask * swell_amount * pulse) / model_scale);
}

void fragment() {
	vec4 tex_col = has_skin_tex ? texture(skin_tex, UV) : vec4(1.0);
	vec3 skin_rgb = tex_col.rgb * base_albedo.rgb;

	float pulse_glow = 0.72 + 0.28 * sin(TIME * (12.0 + charge_ratio * 24.0));
	float local_heat = clamp(v_swell * (0.38 + 0.82 * charge_ratio), 0.0, 1.0);
	float body_fever = charge_ratio * charge_ratio * 0.26;
	float heat = clamp(max(local_heat, body_fever), 0.0, 1.0);

	vec3 magma_crimson = vec3(0.78, 0.09, 0.02);
	vec3 magma_orange = vec3(1.0, 0.40, 0.05);
	vec3 magma_gold = vec3(1.0, 0.90, 0.36);

	vec3 magma_tint = mix(magma_crimson, magma_orange, clamp(charge_ratio * 1.15, 0.0, 1.0));
	magma_tint = mix(magma_tint, magma_gold, pow(clamp(v_swell * charge_ratio, 0.0, 1.0), 1.8));

	ALBEDO = mix(skin_rgb, magma_tint, heat * 0.84);
	ROUGHNESS = mix(0.78, 0.34, heat);

	float emissive_power = (v_swell * (0.55 + 2.95 * charge_ratio * charge_ratio) + body_fever * 0.65) * pulse_glow;
	EMISSION = magma_tint * emissive_power;
}
