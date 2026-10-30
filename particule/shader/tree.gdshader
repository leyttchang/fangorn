// NOTE: Shader automatically converted from Godot Engine 4.7.stable's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0.1, 128.0, 0.1);

uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;

uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);

uniform sampler2D texture_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;

uniform sampler2D texture_ambient_occlusion : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 ao_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float ao_light_affect : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float ao_strength : hint_range(0.0, 1.0, 0.01) = 1.0;

uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

// --- PARAMÈTRES DU VENT (pilotés automatiquement par l'autoload Wind) ---
group_uniforms wind;
uniform vec2 wind_direction = vec2(1.0, 0.5);
uniform float wind_speed = 2.0;
uniform float wind_strength = 0.215;
// Paramètres lissés avec inertie dédiés aux arbres (envoyés par WindManager)
uniform vec2 tree_wind_direction = vec2(0.0, 0.0);
uniform float tree_wind_strength = -1.0;
// Phases et défilements intégrés par le script Wind (fallback automatique sur TIME en éditeur)
uniform float wind_time = 0.0;
uniform vec2 wind_scroll = vec2(0.0);
uniform float tree_wind_time = 0.0;
uniform vec2 tree_wind_scroll = vec2(0.0);

// Distance maximale d'oscillation (en unités locales du modèle) pour un vertex blanc (COLOR.r = 1.0) en pleine tempête
uniform float max_sway_distance : hint_range(0.05, 2.5) = 0.70;
// Proportion de la distance max déjà active par vent calme en début de partie (0.30 = 30% au calme -> 100% en tempête)
uniform float calm_amplitude_ratio : hint_range(0.05, 0.8) = 0.30;
// Vitesse globale de défilement des ondes sur le feuillage (plus bas = plus lent et lourd)
uniform float sway_frequency : hint_range(0.05, 1.5) = 0.20;
// Échelle spatiale de l'onde sur la forêt (0.005 = vague de ~200m, tous les arbres proches sont bien synchronisés)
uniform float gust_frequency : hint_range(0.001, 0.05) = 0.005;
// Tension élastique du tronc : rend la poussée plus progressive/soutenue, et le retour proportionnel au déplacement subi
uniform float trunk_tension : hint_range(0.0, 0.6) = 0.32;
// Intensité des doubles rebonds et paliers à mi-course
uniform float rebound_amount : hint_range(0.0, 1.0) = 0.45;
// Maintien minimal dans le sens du vent en pleine tempête (proportion de la distance max)
uniform float storm_base_lean : hint_range(0.1, 0.8) = 0.42;
// Très léger flottement latéral cohérent (perpendiculaire au vent)
uniform float lateral_amount : hint_range(0.0, 0.3) = 0.06;
// Courbure verticale quand le feuillage s'incline au loin
uniform float vertical_dip : hint_range(0.0, 0.5) = 0.15;
// Au-delà de cette distance (m), plus de calcul de vent
uniform float wind_max_distance : hint_range(10.0, 300.0) = 120.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Bruit de valeur 2D quintique C2 (accélération 100% continue, zéro à-coup aux jonctions)
float vnoise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	// Courbe quintique de Perlin (6f^5 - 15f^4 + 10f^3) : dérivées 1ère et 2nde nulles aux bords
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Évalue l'onde organique (sans clamp brusque ni pic de vitesse)
float eval_organic_wave(vec2 c, float t, float reb_amt, float storm_fac, float s_base) {
	// 3 ondes continues C2 sans saturation brutale (reste rapide et fluide sur toute la poussée)
	float n1 = vnoise(c);
	float n2 = vnoise(c * 1.85 + vec2(17.3, 31.7) + vec2(t * 0.25, 0.0));
	float n3 = vnoise(vec2(t * 0.42, 11.3) + c * 0.65);
	
	// Onde porteuse souple (pas de smoothstep étroit qui bloque au sommet)
	float carrier = clamp((mix(n1, n3, 0.35) - 0.18) / 0.76, 0.0, 1.0);
	// Courbe progressive au départ qui garde une vitesse soutenue longtemps
	float env_calm = carrier * carrier * (2.2 - 1.2 * carrier);
	
	// Onde secondaire pour les arrêts à mi-course et les doubles rebonds souples
	float sub_wave = n2 * n2 * (3.0 - 2.0 * n2);
	float calm_wave = env_calm * mix(1.0 - reb_amt * 0.55, 1.0, sub_wave);
	
	// En tempête : maintien en tension avec oscillations amples et fluides
	float storm_floor = clamp(carrier * 2.2, 0.0, 1.0) * s_base;
	float storm_surge = clamp(env_calm * 0.60 + sub_wave * 0.40, 0.0, 1.0);
	float storm_wave = mix(storm_floor, 1.0, storm_surge);
	
	return mix(calm_wave, storm_wave, storm_fac);
}

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	
	vec3 node_origin = MODEL_MATRIX[3].xyz;
	vec3 cam_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = length(node_origin - cam_pos);

	if (dist < wind_max_distance) {
		// Le Vertex Color (R) contrôle la distance de déplacement :
		// Noir (0.0) = immobile, Gris = déplacement moyen, Blanc (1.0) = ondule le plus loin
		float wind_mask = COLOR.r;
		
		if (wind_mask > 0.001) {
			float wf = 1.0 - smoothstep(wind_max_distance * 0.75, wind_max_distance, dist);
			
			vec2 p = node_origin.xz;
			// Utilise la direction et la force lissées avec inertie pour les arbres si disponibles
			vec2 raw_dir = (dot(tree_wind_direction, tree_wind_direction) > 0.0001) ? tree_wind_direction : wind_direction;
			float eff_strength = (tree_wind_strength >= 0.0) ? tree_wind_strength : wind_strength;
			
			vec2 wdir = normalize(raw_dir + vec2(0.0001));
			vec2 perp = vec2(-wdir.y, wdir.x);
			
			// Temps et défilement maîtrisés (max 1.5x en tempête via tree_wind_time, ou fallback éditeur)
			float eff_time = (tree_wind_time > 0.0001) ? tree_wind_time : ((wind_time > 0.0001) ? wind_time : (TIME * 1.5));
			vec2 eff_scroll = (dot(tree_wind_scroll, tree_wind_scroll) > 0.0001) ? tree_wind_scroll : ((dot(wind_scroll, wind_scroll) > 0.0001) ? wind_scroll : (wdir * eff_time));
			
			// Ratio de progression entre vent calme (0.08 -> storm_factor = 0.0) et pleine tempête (1.15 -> storm_factor = 1.0)
			float storm_factor = clamp((eff_strength - 0.08) / 1.07, 0.0, 1.0);
			float active_wind = clamp(eff_strength / 0.08, 0.0, 1.0);
			float amp = max_sway_distance * mix(calm_amplitude_ratio, 1.0, pow(storm_factor, 0.8)) * active_wind;
			
			// Coordonnée spatio-temporelle continue
			vec2 base_coord = p * gust_frequency - eff_scroll * sway_frequency;
			float t_scaled = eff_time * sway_frequency;
			
			// 1. Pré-évaluation de l'extension pour calculer la tension élastique du tronc
			float pre_lean = eval_organic_wave(base_coord, t_scaled, rebound_amount, storm_factor, storm_base_lean);
			
			// 2. Asymétrie physique Poussée / Retour (Tension du tronc) :
			// - À l'aller (quand pre_lean monte), "+ wdir * trunk_tension * pre_lean" s'oppose à "- eff_scroll" :
			//   la poussée démarre progressivement et maintient sa vitesse plus longtemps sans à-coup.
			// - Au retour (quand pre_lean redescend vers 0), le décalage s'ajoute au défilement :
			//   plus l'arbre est allé loin (pre_lean élevé = forte tension dans le tronc), plus le retour a du répondant,
			//   puis s'adoucit naturellement en arrivant à sa position de départ (pre_lean -> 0).
			vec2 tension_coord = base_coord + wdir * (trunk_tension * pre_lean);
			float forward_lean = eval_organic_wave(tension_coord, t_scaled - trunk_tension * pre_lean, rebound_amount, storm_factor, storm_base_lean);
			
			// Très léger flottement latéral cohérent (même sens pour les arbres voisins)
			float side_noise = (vnoise(tension_coord * 1.2 + vec2(43.1, 19.7)) - 0.5) * 2.0;
			float side_wave = side_noise * lateral_amount * (0.3 + 0.7 * forward_lean);
			
			// Déplacement final modulé par le Vertex Color (wind_mask)
			float displacement = amp * wf * wind_mask;
			vec2 offset_xz = (wdir * forward_lean + perp * side_wave) * displacement;
			float offset_y = -abs(forward_lean) * vertical_dip * displacement;
			vec3 sway_world_dir = vec3(offset_xz.x, offset_y, offset_xz.y);
			
			// Inversion exacte de la rotation 3D de l'arbre (compense à 100% rot_y et l'orientation DAE sur les 3 axes)
			mat3 rot_scale = mat3(MODEL_MATRIX);
			float sx2 = dot(rot_scale[0], rot_scale[0]);
			float sy2 = dot(rot_scale[1], rot_scale[1]);
			float sz2 = dot(rot_scale[2], rot_scale[2]);
			if (sx2 > 0.0001 && sy2 > 0.0001 && sz2 > 0.0001) {
				float tree_scale = sqrt(sx2);
				vec3 world_offset = sway_world_dir * tree_scale;
				vec3 sway_local = vec3(
					dot(rot_scale[0], world_offset) / sx2,
					dot(rot_scale[1], world_offset) / sy2,
					dot(rot_scale[2], world_offset) / sz2
				);
				VERTEX += sway_local;
			}
		}
	}
}

void fragment() {
	vec2 base_uv = UV;

	vec4 albedo_tex = texture(texture_albedo, base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;

	float metallic_tex = dot(texture(texture_metallic, base_uv), metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	SPECULAR = specular;

	vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
	float roughness_tex = dot(texture(texture_roughness, base_uv), roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;

	NORMAL_MAP = texture(texture_normal, base_uv).rgb;
	NORMAL_MAP_DEPTH = normal_scale;

	float ao_tex = dot(texture(texture_ambient_occlusion, base_uv), ao_texture_channel);
	AO = mix(1.0, ao_tex, ao_strength);
	AO_LIGHT_AFFECT = ao_light_affect;
}
