shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

// --- Couleurs & PBR de la glace ---
uniform vec4 ice_shallow_color : source_color = vec4(0.40, 0.79, 0.96, 1.0);
uniform vec4 ice_deep_color : source_color = vec4(0.10, 0.34, 0.60, 1.0);
uniform vec4 crack_frost_color : source_color = vec4(0.86, 0.97, 1.00, 1.0);
uniform vec4 iridescence_color : source_color = vec4(0.72, 0.84, 1.00, 1.0);
uniform vec4 wave_crest_color : source_color = vec4(0.88, 0.98, 1.00, 1.0);

uniform float base_alpha : hint_range(0.1, 0.95) = 0.62;
uniform float ice_roughness : hint_range(0.02, 0.5) = 0.09;
uniform float ice_specular : hint_range(0.0, 1.0) = 0.88;
uniform float ice_metallic : hint_range(0.0, 1.0) = 0.12;

// --- Fissures & Givre ---
uniform sampler2D cracks_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float use_cracks_texture : hint_range(0.0, 1.0) = 1.0;
uniform float cracks_tex_strength : hint_range(0.0, 1.0) = 0.55;
uniform float macro_voronoi_scale : hint_range(0.03, 0.5) = 0.15;
uniform float micro_voronoi_scale : hint_range(0.1, 1.5) = 0.48;

// --- Onde de gel progressive & Fonte (Phase 2 -> Mort du Boss) ---
uniform vec3 freeze_origin_world = vec3(0.0, 0.0, 0.0);
uniform float current_freeze_radius = 0.0;
uniform float wave_crest_width : hint_range(0.5, 8.0) = 2.8;
uniform float wave_crest_emission : hint_range(0.0, 6.0) = 2.35;
uniform float thaw_alpha : hint_range(0.0, 1.0) = 1.0;

varying vec3 v_world_pos;

// Hash 2D purement arithmétique (sans sin, stable quelle que soit la position monde de l'arène)
vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float frost_fbm(vec2 p) {
	float v = 0.0;
	v += 0.62 * value_noise(p);
	p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p;
	v += 0.38 * value_noise(p);
	return v;
}

// Retourne vec2(distance_fissure, id_cellule) pour dessiner plaques cristallines & veines
vec2 voronoi_ice(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	float d1_sq = 8.0;
	float d2_sq = 8.0;
	float cell_id = 0.0;

	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 h = hash22(n + g);
			vec2 r = g + (0.15 + 0.70 * h) - f;
			float d_sq = dot(r, r);
			if (d_sq < d1_sq) {
				d2_sq = d1_sq;
				d1_sq = d_sq;
				cell_id = h.x;
			} else if (d_sq < d2_sq) {
				d2_sq = d_sq;
			}
		}
	}
	float edge_dist = sqrt(d2_sq) - sqrt(d1_sq);
	return vec2(edge_dist, cell_id);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (current_freeze_radius <= 0.005 || thaw_alpha <= 0.002) {
		discard;
	}

	// Coordonnées locales centrées sur l'origine du cri pour une précision maximale
	vec2 rel_xz = v_world_pos.xz - freeze_origin_world.xz;
	float raw_dist = length(rel_xz);

	// Légère dentelure cristalline du front d'expansion de la glace
	float rim_noise = frost_fbm(rel_xz * 0.32) - 0.5;
	float jagged_dist = raw_dist + rim_noise * 1.35;

	// Rejet rapide des pixels situés au-delà du front de gel
	if (jagged_dist > current_freeze_radius + 0.35) {
		discard;
	}

	// Couverture de l'onde de gel (1.0 dans la zone gelée, fondu doux sur le bord avant)
	float wave_fill = 1.0 - smoothstep(current_freeze_radius - 0.45, current_freeze_radius + 0.30, jagged_dist);

	// Crête blanche givrée lumineuse sur le front d'expansion circulaire
	float dist_behind_front = current_freeze_radius - jagged_dist;
	float crest_band = smoothstep(wave_crest_width, 0.0, dist_behind_front) * smoothstep(-0.30, 0.12, dist_behind_front);

	// Proximité du bord du polygone (encodée dans COLOR.r par BossIceArena)
	float arena_border_fade = smoothstep(0.0, 1.0, COLOR.r);

	// Réseau procédural de plaques et fissures cristallines (2 échelles)
	vec2 v_macro = voronoi_ice(rel_xz * macro_voronoi_scale);
	vec2 v_micro = voronoi_ice(rel_xz * micro_voronoi_scale + vec2(17.3, -9.1));

	float macro_crack = 1.0 - smoothstep(0.0, 0.065, v_macro.x);
	float micro_crack = (1.0 - smoothstep(0.0, 0.055, v_micro.x)) * 0.55;
	float frost_cloud = frost_fbm(rel_xz * 0.22 + vec2(4.2, -7.8));

	// Échantillonnage optionnel de la texture de fissures (coordonnées monde bi-échelles sans répétition visible)
	float tex_crack = 0.0;
	if (use_cracks_texture > 0.5) {
		vec4 tc1 = texture(cracks_texture, rel_xz * 0.075);
		vec4 tc2 = texture(cracks_texture, rel_xz * 0.19 + vec2(0.37, 0.61));
		float s1 = max(tc1.a * max(tc1.r, 0.65), tc1.r * tc1.a);
		float s2 = max(tc2.a * max(tc2.r, 0.65), tc2.r * tc2.a);
		tex_crack = clamp(s1 * 0.68 + s2 * 0.42, 0.0, 1.0) * cracks_tex_strength;
	}

	float total_cracks = clamp(macro_crack * 0.85 + micro_crack + tex_crack, 0.0, 1.0);
	float frost_veins = clamp(total_cracks + smoothstep(0.58, 0.92, frost_cloud) * 0.32, 0.0, 1.0);

	// Fonte organique à la mort du boss (les bords et zones fines fondent légèrement en premier)
	float organic_thaw = smoothstep(1.0 - thaw_alpha, 1.0 - thaw_alpha + 0.35, 0.28 + 0.52 * frost_cloud + 0.20 * arena_border_fade);
	float effective_thaw = mix(thaw_alpha, thaw_alpha * organic_thaw, 0.65);

	float alpha_raw = base_alpha + frost_veins * 0.18 + crest_band * 0.28;
	float final_alpha = clamp(alpha_raw, 0.0, 0.92) * wave_fill * arena_border_fade * effective_thaw;

	if (final_alpha <= 0.003) {
		discard;
	}

	// Perturbation subtile de la normale monde pour capter les reflets sur les facettes de glace
	float facet_tilt_x = (v_macro.y - 0.5) * 0.06 + (macro_crack - micro_crack) * 0.09;
	float facet_tilt_z = (v_micro.y - 0.5) * 0.06 - (frost_cloud - 0.5) * 0.07;
	vec3 world_normal = normalize(vec3(facet_tilt_x, 1.0, facet_tilt_z));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	// Reflets irisés subtils selon l'angle rasant (Fresnel)
	float ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, 3.0);
	float irid_wave = 0.5 + 0.5 * cos(ndotv * 9.0 + v_macro.y * 5.2);

	// Composition couleur : glace profonde -> cyan glacé -> irisation -> veines blanches & crête d'onde
	vec3 base_ice = mix(ice_deep_color.rgb, ice_shallow_color.rgb, 0.38 + 0.45 * frost_cloud + 0.17 * v_macro.y);
	base_ice = mix(base_ice, iridescence_color.rgb, fresnel * (0.28 + 0.26 * irid_wave));
	vec3 cracked_ice = mix(base_ice, crack_frost_color.rgb, frost_veins * 0.72);
	vec3 final_rgb = mix(cracked_ice, wave_crest_color.rgb, crest_band * 0.88);

	// Atténuation douce du spéculaire sur les bords transparents pour éviter tout reflet fantôme
	float spec_vis = smoothstep(0.0, 0.35, final_alpha);

	ALBEDO = final_rgb;
	ALPHA = final_alpha;
	ROUGHNESS = mix(0.65, clamp(ice_roughness + frost_veins * 0.14, 0.04, 0.45), spec_vis);
	SPECULAR = ice_specular * spec_vis;
	METALLIC = ice_metallic * spec_vis;
	EMISSION = wave_crest_color.rgb * (crest_band * wave_crest_emission * arena_border_fade * effective_thaw)
		+ crack_frost_color.rgb * (total_cracks * 0.14 * final_alpha);
}
