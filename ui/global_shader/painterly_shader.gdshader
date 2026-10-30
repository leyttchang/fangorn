shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled, blend_mix;

// Buffers requis
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

// --- 1. Kuwahara Généralisé à 8 Secteurs (Aplats de peinture organiques) ---
group_uniforms Kuwahara_Paint;
uniform bool enable_kuwahara = true;
uniform float paint_radius : hint_range(0.0, 5.0, 0.1) = 2.5;
group_uniforms;

// --- 2. Rim Light Chaud & Silhouettes (Style No Rest for the Wicked) ---
group_uniforms RimLight_And_Silhouettes;
uniform bool enable_dry_brush = true;
uniform float outline_darkness : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float edge_highlight : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float depth_sensitivity : hint_range(0.02, 0.5, 0.01) = 0.14;
uniform float normal_sensitivity : hint_range(0.05, 1.5, 0.05) = 0.40;
group_uniforms;

// --- 3. Split-Toning Chaleureux & Contraste Protégé (Sans assombrir) ---
group_uniforms SplitToning_And_Contrast;
uniform bool enable_split_toning = true;
uniform vec4 shadow_tint : source_color = vec4(0.82, 0.92, 0.98, 1.0); // Bleu-pétrole doux pour les ombres
uniform vec4 light_tint : source_color = vec4(1.0, 0.86, 0.64, 1.0);   // Ambre / doré chaud pour les lumières
uniform float warmth : hint_range(0.0, 2.0, 0.05) = 1.25;              // Intensité de la chaleur et vibrance
uniform float contrast : hint_range(0.5, 2.0, 0.01) = 1.12;            // Contraste doux (noirs protégés)
group_uniforms;

const vec3 LUMA_WEIGHTS = vec3(0.2126, 0.7152, 0.0722);
const float SQRT2_2 = 0.70710678;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel_size = vec2(1.0) / VIEWPORT_SIZE;
	vec3 color;

	// =========================================================================
	// 1. KUWAHARA GÉNÉRALISÉ À 8 SECTEURS (Kyprianidis / Papari / Acerola)
	// =========================================================================
	if (!enable_kuwahara || paint_radius <= 0.01) {
		// Court-circuit pour ne rien coûter en FPS
		color = texture(screen_texture, uv).rgb;
	} else {
		// Rayon entier borné pour garder d'excellentes performances GPU + pas continu
		int radius = int(clamp(ceil(paint_radius), 1.0, 4.0));
		float inv_radius = 1.0 / float(radius);
		vec2 step_uv = pixel_size * (paint_radius * inv_radius);

		// Paramètres polynomiaux pour les 8 secteurs angulaires chevauchants
		const float zeta = 0.33;
		const float eta = 0.85;

		vec4 m[8];
		vec3 s[8];

		// Initialisation avec le pixel central dans les 8 secteurs (préserve la netteté des fins détails)
		vec3 center_c = texture(screen_texture, uv).rgb;
		for (int k = 0; k < 8; ++k) {
			m[k] = vec4(center_c * 0.125, 0.125);
			s[k] = center_c * center_c * 0.125;
		}

		for (int y = -radius; y <= radius; ++y) {
			for (int x = -radius; x <= radius; ++x) {
				if (x == 0 && y == 0) {
					continue;
				}
				// Masque circulaire strict : élimine l'effet "carré" et économise ~25% de lectures texture
				int r2 = x * x + y * y;
				if (r2 > radius * radius) {
					continue;
				}

				vec2 v = vec2(float(x), float(y)) * inv_radius;
				vec3 c = texture(screen_texture, uv + vec2(float(x), float(y)) * step_uv).rgb;

				// Poids gaussien radial
				float g = exp(-dot(v, v) * 1.35);

				// Calcul polynomial des 8 secteurs (4 cardinaux + 4 diagonaux tournés à 45°)
				float w[8];
				float z;
				float vxx = zeta - eta * v.x * v.x;
				float vyy = zeta - eta * v.y * v.y;

				z = max(0.0, v.y + vxx);  w[0] = z * z;
				z = max(0.0, -v.x + vyy); w[2] = z * z;
				z = max(0.0, -v.y + vxx); w[4] = z * z;
				z = max(0.0, v.x + vyy);  w[6] = z * z;

				vec2 vd = SQRT2_2 * vec2(v.x - v.y, v.x + v.y);
				vxx = zeta - eta * vd.x * vd.x;
				vyy = zeta - eta * vd.y * vd.y;

				z = max(0.0, vd.y + vxx);  w[1] = z * z;
				z = max(0.0, -vd.x + vyy); w[3] = z * z;
				z = max(0.0, -vd.y + vxx); w[5] = z * z;
				z = max(0.0, vd.x + vyy);  w[7] = z * z;

				float sum_w = w[0] + w[1] + w[2] + w[3] + w[4] + w[5] + w[6] + w[7];
				float norm_factor = g / max(sum_w, 0.00001);

				vec3 c2 = c * c;
				for (int k = 0; k < 8; ++k) {
					float wk = w[k] * norm_factor;
					m[k] += vec4(c * wk, wk);
					s[k] += c2 * wk;
				}
			}
		}

		// Pondération finale par l'inverse de la variance de chaque secteur
		vec4 final_acc = vec4(0.0);
		for (int k = 0; k < 8; ++k) {
			float inv_w = 1.0 / max(m[k].w, 0.00001);
			vec3 mean_k = m[k].rgb * inv_w;
			vec3 var_k = abs(s[k] * inv_w - mean_k * mean_k);
			float sigma2 = dot(var_k, LUMA_WEIGHTS);

			// Poids fort sur les secteurs à faible variance (aplat net sans bavure)
			float s_scaled = 300.0 * sigma2;
			float s2 = s_scaled * s_scaled;
			float wt = 1.0 / (1.0 + s2 * s2);

			final_acc += vec4(mean_k * wt, wt);
		}

		color = final_acc.rgb / max(final_acc.w, 0.00001);
	}

	// =========================================================================
	// 2. SILHOUETTES PROPRES & RIM LIGHT CHAUD (Style No Rest for the Wicked)
	// =========================================================================
	if (enable_dry_brush) {
		// Lecture profondeur : centre, +1px en X, +1px en Y
		float d_c = texture(depth_texture, uv).r;
		float d_x = texture(depth_texture, uv + vec2(pixel_size.x, 0.0)).r;
		float d_y = texture(depth_texture, uv + vec2(0.0, pixel_size.y)).r;

		// Lecture normale en View Space : centre, +1px en X, +1px en Y
		vec3 n_c = texture(normal_texture, uv).rgb * 2.0 - 1.0;
		vec3 n_x = texture(normal_texture, uv + vec2(pixel_size.x, 0.0)).rgb * 2.0 - 1.0;
		vec3 n_y = texture(normal_texture, uv + vec2(0.0, pixel_size.y)).rgb * 2.0 - 1.0;

		// Écart de profondeur relatif (indépendant de la distance : marche de 1m à 40m)
		float base_d = max(d_c, max(d_x, d_y));
		float rel_depth_diff = (abs(d_c - d_x) + abs(d_c - d_y)) / max(base_d, 0.0001);
		float normal_diff = distance(n_c, n_x) + distance(n_c, n_y);

		// 2A. Silhouettes (Contours externes) : assombrit la couleur propre de l'objet
		float silhouette_mask = smoothstep(depth_sensitivity * 0.45, depth_sensitivity, rel_depth_diff) * step(0.00005, base_d);
		color *= (1.0 - silhouette_mask * outline_darkness);

		// 2B. Rim Light Chaud (Lumière de bord dorée orientée vers le haut, jamais de trait blanc !)
		// Effet Fresnel sur les bords rasants + orientation vers le haut (lumière zénithale)
		float fresnel = pow(1.0 - clamp(abs(n_c.z), 0.0, 1.0), 2.6);
		float top_facing = smoothstep(-0.1, 0.65, n_c.y);
		// Légère accroche sur le relief supérieur sans effet grillage
		float soft_ridge = smoothstep(normal_sensitivity * 0.6, normal_sensitivity * 1.4, normal_diff) * top_facing * 0.35;
		float rim_mask = clamp((fresnel * top_facing * 0.9 + soft_ridge) * (1.0 - silhouette_mask), 0.0, 1.0) * step(0.0001, d_c);

		// Protection des ombres : le Rim Light n'apparaît QUE sur les zones un minimum éclairées (jamais sur du noir)
		float scene_luma = dot(color, LUMA_WEIGHTS);
		float luma_gate = smoothstep(0.015, 0.16, scene_luma);

		// Couleur du Rim Light : mélange chaud entre la couleur de l'objet illuminée et un doré/ambre solaire
		vec3 warm_gold = vec3(1.0, 0.72, 0.32); // Ambre doré en espace linéaire
		vec3 rim_color = mix(color * 1.8, warm_gold * max(scene_luma * 2.5, 0.25), 0.6);
		color += rim_color * (rim_mask * luma_gate * edge_highlight);
	}

	// =========================================================================
	// 3. SPLIT-TONING CHALEUREUX & CONTRASTE SANS ASSOMBRIR (Noirs protégés)
	// =========================================================================
	if (enable_split_toning) {
		// Passage en espace perceptuel (Gamma)
		vec3 gamma_col = pow(max(color, vec3(0.0)), vec3(1.0 / 2.2));
		float orig_luma = dot(gamma_col, LUMA_WEIGHTS);

		// 3A. Split-Toning à LUMINANCE CONSTANTE (réchauffe sans jamais assombrir !)
		vec3 s_tint = pow(max(shadow_tint.rgb, vec3(0.001)), vec3(1.0 / 2.2));
		vec3 l_tint = pow(max(light_tint.rgb, vec3(0.001)), vec3(1.0 / 2.2));

		// Dès les tons moyens-sombres (0.18+), on bascule vers la teinte chaude dorée
		float warm_mask = smoothstep(0.10, 0.65, orig_luma);
		vec3 target_tint = mix(s_tint, l_tint, warm_mask);
		vec3 neutral_tint = vec3(1.0);
		vec3 active_tint = mix(neutral_tint, target_tint, clamp(warmth * 0.75, 0.0, 1.5));

		vec3 tinted_col = gamma_col * active_tint;
		// Restauration exacte de la luminance d'origine (+ léger boost chaud dans les lumières)
		float tinted_luma = max(dot(tinted_col, LUMA_WEIGHTS), 0.0001);
		float luma_boost = 1.0 + (warm_mask * 0.06 * warmth);
		gamma_col = tinted_col * ((orig_luma * luma_boost) / tinted_luma);

		// 3B. Vibrance / Saturation chaude (évite l'aspect terne quand on baisse le contraste)
		float cur_luma = dot(gamma_col, LUMA_WEIGHTS);
		float saturation_boost = 1.0 + (warmth * 0.22) + max(contrast - 1.0, 0.0) * 0.25;
		gamma_col = mix(vec3(cur_luma), gamma_col, saturation_boost);

		// 3C. Contraste à "Noirs Protégés" (Toe-Protected Contrast)
		// Au lieu de pivoter autour de 0.5 (qui écrase tout ce qui est < 0.5 dans le noir),
		// on pivote bas (0.20) et on réduit fortement l'assombrissement des zones sombres !
		float pivot = 0.20;
		float delta = cur_luma - pivot;
		// Si le pixel est sombre (delta < 0), on n'applique que 20% de la baisse pour garder la visibilité
		float effective_contrast = (delta < 0.0 && contrast > 1.0)
			? mix(1.0, contrast, 0.20)
			: contrast;
		float contrasted_luma = clamp(pivot + delta * effective_contrast, 0.0, 1.0);

		// Application de la nouvelle luminance sans écraser la chrominance
		gamma_col *= (contrasted_luma / max(cur_luma, 0.0001));
		gamma_col = clamp(gamma_col, 0.0, 1.0);

		// Retour en espace linéaire pour ALBEDO
		color = pow(gamma_col, vec3(2.2));
	}

	ALBEDO = clamp(color, 0.0, 1.0);
	ALPHA = 1.0;
}
