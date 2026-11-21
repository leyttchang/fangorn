shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Shader de pierre ancienne sculptée style Porte de la Moria (LOTR) :
// - Albedo sRGB + Normal map linéaire OpenGL + Roughness linéaire
// - Patine minérale gris-argenté usée par le temps sur les reliefs de gravures (Runes, Couronne de Durin, Arbres)
//   modulée par une usure irrégulière pour un rendu authentique "gravure ancienne érodée" (jamais néon)
// - Mousse forestière sombre au pied des maçonneries

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_tex : filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 stone_tint : source_color = vec4(1.22, 1.26, 1.32, 1.0);
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);
uniform float normal_strength : hint_range(0.0, 3.0) = 1.65;
uniform float roughness_mult : hint_range(0.3, 1.5) = 1.0;
uniform float specular_val : hint_range(0.0, 1.0) = 0.30;

// Accentuation de la gravure calcaire/argent terni (usée par endroits)
uniform float engraving_contrast : hint_range(0.0, 1.5) = 0.68;
uniform vec4 engraving_patina_color : source_color = vec4(0.68, 0.73, 0.79, 1.0);

// Mousse d'ancrage au ras du sol
uniform float ground_moss_height : hint_range(0.0, 4.0) = 1.55;
uniform float ground_moss_strength : hint_range(0.0, 1.0) = 0.48;
uniform vec4 ground_moss_color : source_color = vec4(0.11, 0.16, 0.09, 1.0);

// Très sobre reflet lunaire d'ithildin terni sur les gravures
uniform float ithildin_sheen : hint_range(0.0, 0.25) = 0.075;
uniform vec4 ithildin_color : source_color = vec4(0.70, 0.78, 0.88, 1.0);

varying float v_local_y;
varying vec3 v_local_pos;
varying float v_cam_dist;

void vertex() {
	v_local_y = VERTEX.y;
	v_local_pos = VERTEX;
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_cam_dist = length(CAMERA_POSITION_WORLD - world_pos);
}

void fragment() {
	vec2 uv = UV * uv_scale + uv_offset;
	vec3 raw_tex = texture(albedo_tex, uv).rgb;
	vec3 base_col = raw_tex * stone_tint.rgb;
	vec3 n_sample = texture(normal_tex, uv).rgb;
	float r_sample = texture(roughness_tex, uv).r;

	// Détection multi-échelle des arêtes et traits gravés (comparaison avec un mip plus flou)
	vec3 coarse_tex = textureLod(albedo_tex, uv, 3.2).rgb;
	float lum_fine = dot(raw_tex, vec3(0.299, 0.587, 0.114));
	float lum_coarse = dot(coarse_tex, vec3(0.299, 0.587, 0.114));
	float local_relief = clamp((lum_fine - lum_coarse) * 3.8 + smoothstep(0.30, 0.54, lum_fine) * 0.65, 0.0, 1.0);

	// Usure irrégulière séculaire : certaines zones de la gravure sont partiellement effacées par l'érosion
	float wear_wave = 0.55 + 0.45 * sin(v_local_pos.x * 1.35 + sin(v_local_pos.y * 1.9) * 1.4) * cos(v_local_pos.y * 1.15 - 0.6);
	float worn_engraving = clamp(local_relief * mix(0.42, 1.0, wear_wave) * engraving_contrast, 0.0, 0.82);

	vec3 carved_stone = mix(base_col, engraving_patina_color.rgb, worn_engraving);

	// Ancrage moussu naturel vers la base
	float moss_grad = 1.0 - smoothstep(-0.2, max(ground_moss_height, 0.05), v_local_y);
	float crevice_factor = clamp((0.50 - lum_fine) * 2.4, 0.0, 1.0);
	float moss_mix = clamp(moss_grad * (0.42 + 0.58 * crevice_factor) * ground_moss_strength, 0.0, 0.85);
	vec3 final_albedo = mix(carved_stone, ground_moss_color.rgb, moss_mix);

	float glyph_mask = worn_engraving * (1.0 - moss_mix);
	float prox = 1.0 - smoothstep(6.0, 28.0, v_cam_dist);

	ALBEDO = final_albedo;
	ROUGHNESS = clamp(mix(r_sample * roughness_mult - glyph_mask * 0.12, 0.95, moss_mix), 0.38, 0.99);
	METALLIC = glyph_mask * 0.18;
	SPECULAR = specular_val;
	NORMAL_MAP = n_sample;
	NORMAL_MAP_DEPTH = normal_strength;
	EMISSION = ithildin_color.rgb * (glyph_mask * ithildin_sheen * (0.55 + 0.45 * prox));
}
