shader_type spatial;
render_mode blend_add, depth_draw_never, depth_test_disabled, cull_back, unshaded, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

// 0 = arcane, 1 = lightning, 2 = ice, 3 = fire
uniform int elem_mode = 0;
uniform vec3 color_primary : source_color = vec3(1.75, 0.28, 2.75);
uniform vec3 color_secondary : source_color = vec3(0.48, 0.78, 2.85);
uniform vec3 color_core : source_color = vec3(2.8, 2.4, 3.4);

uniform float rise_progress : hint_range(0.0, 1.0) = 0.0;
uniform float master_intensity : hint_range(0.0, 2.0) = 0.0;
// 0 = coeur intense, 1 = vortex intermédiaire animé, 2 = large halo atmosphérique doux
uniform int layer_kind = 0;

varying float v_height_u;
varying float v_view_z;
varying vec3 v_world_pos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void vertex() {
	// UV.y sur CylinderMesh Godot : 0.0 en haut, 1.0 en bas -> on inverse pour avoir 0.0 au sol et 1.0 au sommet !
	v_height_u = clamp(1.0 - UV.y, 0.0, 1.0);

	// Légère ondulation vivante de la colonne dans le ciel
	float sway_t = TIME * 1.8;
	vec3 v_mod = VERTEX;
	if (layer_kind == 1) {
		float w = sin(v_height_u * 14.0 - sway_t * 2.2) * 0.65;
		v_mod.x += w;
		v_mod.z += cos(v_height_u * 11.0 - sway_t * 1.9) * 0.65;
	}

	vec4 wp = MODEL_MATRIX * vec4(v_mod, 1.0);
	v_world_pos = wp.xyz;
	vec4 vp = VIEW_MATRIX * wp;
	v_view_z = -vp.z;
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	if (master_intensity <= 0.001 || rise_progress <= 0.001) {
		discard;
	}

	// Élévation progressive depuis le sol vers les nuages (0 -> 460m)
	float height_gate = 1.0 - smoothstep(max(0.0, rise_progress - 0.14), rise_progress + 0.02, v_height_u);
	if (height_gate <= 0.002) {
		discard;
	}

	// Bords latéraux ultra-doux (aucune arête géométrique visible : pur faisceau volumétrique !)
	float ndotv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float radial_profile = pow(ndotv, (layer_kind == 0) ? 1.8 : ((layer_kind == 1) ? 2.6 : 3.8));

	// Atténuation douce à la base et tout en haut dans les étoiles
	float base_soft = smoothstep(0.0, 0.025, v_height_u);
	float top_fade = 1.0 - smoothstep(0.55, 1.0, v_height_u);
	// Surbrillance au pied du totem pour bien marquer le sol
	float ground_flare = exp(-v_height_u * 26.0) * 1.35;

	float t = TIME;
	float angle_u = UV.x * 6.0;
	float pattern = 1.0;

	if (layer_kind == 1) {
		if (elem_mode == 1) {
			// Foudre : filaments électriques rapides montant le long de la colonne
			float n_bolt = vnoise(vec2(angle_u * 3.5 + sin(v_height_u * 30.0 - t * 9.0) * 1.8, v_height_u * 28.0 - t * 6.5));
			pattern = 0.45 + 1.35 * smoothstep(0.52, 0.88, n_bolt);
		} else if (elem_mode == 2) {
			// Glace : draperies d'aurore boréale verticales
			float n_ice = sin(angle_u * 2.0 + v_height_u * 10.0 - t * 1.8) * 0.5 + 0.5;
			float n_ice2 = vnoise(vec2(angle_u * 2.2, v_height_u * 14.0 - t * 1.4));
			pattern = 0.55 + 0.95 * n_ice * n_ice2;
		} else if (elem_mode == 3) {
			// Feu : tourbillon solaire ascendant
			float n_fire = vnoise(vec2(angle_u * 2.4 - v_height_u * 8.0, v_height_u * 22.0 - t * 4.2));
			pattern = 0.50 + 1.25 * pow(n_fire, 1.5);
		} else {
			// Arcane : rubans hélicoïdaux cosmiques
			float hel = 0.5 + 0.5 * sin(angle_u * 2.0 + v_height_u * 22.0 - t * 3.0);
			float n_arc = vnoise(vec2(angle_u * 1.8, v_height_u * 16.0 - t * 2.4));
			pattern = 0.50 + 1.15 * hel * (0.5 + 0.5 * n_arc);
		}
	} else if (layer_kind == 2) {
		pattern = 0.65 + 0.35 * sin(v_height_u * 9.0 - t * 2.1);
	}

	// Test de profondeur : au-dessus des collines/arbres = 100% éclat céleste ; derrière le relief = halo X-Ray doux (38%)
	float raw_d = texture(depth_texture, SCREEN_UV).r;
	vec4 scene_vs = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_d, 1.0);
	float scene_z = -scene_vs.z / max(abs(scene_vs.w), 0.00001);
	float occ_mult = (v_view_z > scene_z + 1.0) ? 0.38 : 1.0;

	// Boost longue distance pour que la colonne reste majestueuse même à 900m, et s'adoucit si on est pile dedans (< 18m)
	float near_soft = smoothstep(4.0, 24.0, v_view_z);
	float far_boost = mix(1.0, 1.85, smoothstep(80.0, 550.0, v_view_z));

	float layer_gain = (layer_kind == 0) ? 1.55 : ((layer_kind == 1) ? 0.92 : 0.36);
	vec3 base_col = (layer_kind == 0)
		? mix(color_primary, color_core, 0.62)
		: ((layer_kind == 1) ? mix(color_primary, color_secondary, 0.45 + 0.45 * sin(v_height_u * 12.0 - t * 2.5)) : color_primary);

	float energy = radial_profile * (base_soft * top_fade + ground_flare) * height_gate * pattern * layer_gain * occ_mult * near_soft * far_boost * master_intensity;

	ALBEDO = base_col * energy;
	ALPHA = clamp(energy, 0.0, 1.0);
}
