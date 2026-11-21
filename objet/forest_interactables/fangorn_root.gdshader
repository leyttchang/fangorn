shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Équivalent GLSL fidèle de root_shader.tres (mêmes paramètres fin / debut / smoth_step /
// smoth_step_sommet / force_pincement_ / root_texture / normal_text / arm_text / ColorParameter),
// SANS le x100 forcé sur UV.x qui répétait l'écorce 100 fois par racine, et avec pincement conique
// exact refermant totalement l'extrémité de la racine lors de sa croissance ou rétraction.

uniform float fin : hint_range(0.0, 1.0) = 0.0;
uniform float debut : hint_range(0.0, 1.0) = 1.0;
uniform float smoth_step : hint_range(0.0, 0.2) = 0.008;
uniform float smoth_step_sommet : hint_range(0.005, 0.4) = 0.14;
uniform float force_pincement_ : hint_range(0.0, 2.0) = 0.12;

uniform sampler2D root_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_text : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arm_text : filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 ColorParameter : source_color = vec4(0.60, 0.52, 0.38, 1.0);
uniform float normal_strength : hint_range(0.0, 3.0) = 1.2;
uniform vec2 uv_scale = vec2(1.0, 2.5);
uniform float align_bark_uv : hint_range(0.0, 1.0) = 1.0;

// Reproduction analytique fidèle de Curve_radius_profile de root_shader.tres
float eval_radius_profile(float u) {
	if (u <= 0.05) {
		return mix(0.0, 0.28, clamp(u / 0.05, 0.0, 1.0));
	} else if (u <= 0.10) {
		return mix(0.28, 0.82, (u - 0.05) / 0.05);
	} else if (u <= 0.18) {
		return mix(0.82, 0.96, (u - 0.10) / 0.08);
	} else if (u <= 0.30) {
		return mix(0.96, 1.00, (u - 0.18) / 0.12);
	} else if (u <= 0.75) {
		return mix(1.00, 0.90, (u - 0.30) / 0.45);
	} else if (u <= 0.88) {
		return mix(0.90, 0.75, (u - 0.75) / 0.13);
	} else if (u <= 0.95) {
		return mix(0.75, 0.36, (u - 0.88) / 0.07);
	} else {
		return mix(0.36, 0.0, clamp((u - 0.95) / 0.05, 0.0, 1.0));
	}
}

// Reproduction fidèle de Curve_l5ag3 de root_shader.tres : 1.0 à la pointe coupée -> 0.0 dans le corps
float eval_pinch_curve(float v) {
	float x = clamp(v, 0.0, 1.0);
	return pow(1.0 - x, 1.55);
}

void vertex() {
	float u = UV.x;
	float w_sommet = max(smoth_step_sommet, 0.005);
	float s_start = smoothstep(fin, fin + w_sommet, u);
	float s_end = 1.0 - smoothstep(debut - w_sommet, debut, u);
	float body_mask = clamp(s_start * s_end, 0.0, 1.0);

	float pinch = eval_pinch_curve(body_mask) * force_pincement_ * eval_radius_profile(u);
	VERTEX -= NORMAL * pinch;
}

void fragment() {
	float u = UV.x;
	float w_alpha = max(smoth_step, 0.003);
	float a_start = smoothstep(fin, fin + w_alpha, u);
	float a_end = 1.0 - smoothstep(debut - w_alpha, debut, u);
	float alpha_vis = clamp(a_start * a_end, 0.0, 1.0);
	if (alpha_vis <= 0.02) {
		discard;
	}

	vec2 base_uv = mix(UV, vec2(UV.y, UV.x), align_bark_uv);
	vec2 tex_uv = base_uv * uv_scale;

	vec3 bark_col = texture(root_texture, tex_uv).rgb * ColorParameter.rgb;
	vec3 arm = texture(arm_text, tex_uv).rgb;
	vec3 n_map = texture(normal_text, tex_uv).rgb;

	ALBEDO = bark_col;
	ROUGHNESS = clamp(arm.g > 0.01 ? arm.g : arm.r, 0.45, 0.98);
	SPECULAR = 0.22;
	NORMAL_MAP = n_map;
	NORMAL_MAP_DEPTH = normal_strength;
}
