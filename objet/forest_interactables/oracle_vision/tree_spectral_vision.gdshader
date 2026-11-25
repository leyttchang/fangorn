shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale : hint_range(-16.0, 16.0) = 0.1;
uniform sampler2D texture_ambient_occlusion : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 ao_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float ao_light_affect : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float ao_strength : hint_range(0.0, 1.0, 0.01) = 0.85;

uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);

// --- PARAMÈTRES DU VENT (synchronisés à 100% avec tree.gdshader via l'autoload Wind) ---
group_uniforms wind;
uniform vec2 wind_direction = vec2(1.0, 0.5);
uniform float wind_speed = 2.0;
uniform float wind_strength = 0.215;
uniform vec2 tree_wind_direction = vec2(0.0, 0.0);
uniform float tree_wind_strength = -1.0;
uniform float wind_time = 0.0;
uniform vec2 wind_scroll = vec2(0.0);
uniform float tree_wind_time = 0.0;
uniform vec2 tree_wind_scroll = vec2(0.0);

uniform float max_sway_distance : hint_range(0.05, 2.5) = 0.70;
uniform float calm_amplitude_ratio : hint_range(0.05, 0.8) = 0.30;
uniform float sway_frequency : hint_range(0.05, 1.5) = 0.20;
uniform float gust_frequency : hint_range(0.001, 0.05) = 0.005;
uniform float trunk_tension : hint_range(0.0, 0.6) = 0.32;
uniform float rebound_amount : hint_range(0.0, 1.0) = 0.45;
uniform float storm_base_lean : hint_range(0.1, 0.8) = 0.42;
uniform float lateral_amount : hint_range(0.0, 0.3) = 0.06;
uniform float vertical_dip : hint_range(0.0, 0.5) = 0.15;
uniform float wind_max_distance : hint_range(10.0, 300.0) = 160.0;

// --- PARAMÈTRES DE VISION SPECTRALE (0.0 = 100% identique à tree.gdshader -> zéro pop !) ---
group_uniforms spectral_vision;
uniform float vision_phase : hint_range(0.0, 1.0) = 0.0;
uniform vec3 vision_tint_primary : source_color = vec3(0.45, 0.92, 1.0);
uniform vec3 vision_tint_secondary : source_color = vec3(0.88, 0.30, 1.0);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float eval_organic_wave(vec2 c, float t, float reb_amt, float storm_fac, float s_base) {
	float n1 = vnoise(c);
	float n2 = vnoise(c * 1.85 + vec2(17.3, 31.7) + vec2(t * 0.25, 0.0));
	float n3 = vnoise(vec2(t * 0.42, 11.3) + c * 0.65);

	float carrier = clamp((mix(n1, n3, 0.35) - 0.18) / 0.76, 0.0, 1.0);
	float env_calm = carrier * carrier * (2.2 - 1.2 * carrier);
	float sub_wave = n2 * n2 * (3.0 - 2.0 * n2);
	float calm_wave = env_calm * mix(1.0 - reb_amt * 0.55, 1.0, sub_wave);

	float storm_floor = clamp(carrier * 2.2, 0.0, 1.0) * s_base;
	float storm_surge = clamp(env_calm * 0.60 + sub_wave * 0.40, 0.0, 1.0);
	float storm_wave = mix(storm_floor, 1.0, storm_surge);

	return mix(calm_wave, storm_wave, storm_fac);
}

varying float v_cam_dist;
varying float v_world_y;

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;

	vec3 node_origin = MODEL_MATRIX[3].xyz;
	vec3 cam_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = length(node_origin - cam_pos);
	v_cam_dist = dist;

	if (dist < wind_max_distance) {
		float wind_mask = COLOR.r;
		if (wind_mask > 0.001) {
			float wf = 1.0 - smoothstep(wind_max_distance * 0.75, wind_max_distance, dist);
			vec2 p = node_origin.xz;
			vec2 raw_dir = (dot(tree_wind_direction, tree_wind_direction) > 0.0001) ? tree_wind_direction : wind_direction;
			float eff_strength = (tree_wind_strength >= 0.0) ? tree_wind_strength : wind_strength;

			vec2 wdir = normalize(raw_dir + vec2(0.0001));
			vec2 perp = vec2(-wdir.y, wdir.x);

			float eff_time = (tree_wind_time > 0.0001) ? tree_wind_time : ((wind_time > 0.0001) ? wind_time : (TIME * 1.5));
			vec2 eff_scroll = (dot(tree_wind_scroll, tree_wind_scroll) > 0.0001) ? tree_wind_scroll : ((dot(wind_scroll, wind_scroll) > 0.0001) ? wind_scroll : (wdir * eff_time));

			float storm_factor = clamp((eff_strength - 0.08) / 1.07, 0.0, 1.0);
			float active_wind = clamp(eff_strength / 0.08, 0.0, 1.0);
			float amp = max_sway_distance * mix(calm_amplitude_ratio, 1.0, pow(storm_factor, 0.8)) * active_wind;

			vec2 base_coord = p * gust_frequency - eff_scroll * sway_frequency;
			float t_scaled = eff_time * sway_frequency;
			float pre_lean = eval_organic_wave(base_coord, t_scaled, rebound_amount, storm_factor, storm_base_lean);
			vec2 tension_coord = base_coord + wdir * (trunk_tension * pre_lean);
			float forward_lean = eval_organic_wave(tension_coord, t_scaled - trunk_tension * pre_lean, rebound_amount, storm_factor, storm_base_lean);

			float side_noise = (vnoise(tension_coord * 1.2 + vec2(43.1, 19.7)) - 0.5) * 2.0;
			float side_wave = side_noise * lateral_amount * (0.3 + 0.7 * forward_lean);

			float displacement = amp * wf * wind_mask;
			vec2 offset_xz = (wdir * forward_lean + perp * side_wave) * displacement;
			float offset_y = -abs(forward_lean) * vertical_dip * displacement;
			vec3 sway_world_dir = vec3(offset_xz.x, offset_y, offset_xz.y);

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

	v_world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec2 base_uv = UV;
	vec3 tex_col = albedo.rgb * texture(texture_albedo, base_uv).rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;

	if (v_cam_dist < 85.0) {
		float detail_fade = 1.0 - smoothstep(65.0, 85.0, v_cam_dist);
		NORMAL_MAP = texture(texture_normal, base_uv).rgb;
		NORMAL_MAP_DEPTH = normal_scale * detail_fade;
		float ao_tex = dot(texture(texture_ambient_occlusion, base_uv), ao_texture_channel);
		AO = mix(1.0, ao_tex, ao_strength * detail_fade);
		AO_LIGHT_AFFECT = ao_light_affect;
	} else {
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
		NORMAL_MAP_DEPTH = 0.0;
		AO = 1.0;
		AO_LIGHT_AFFECT = 0.0;
	}

	float ndotv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, 2.2);

	float wave = 0.5 + 0.5 * sin(v_cam_dist * 0.05 - TIME * 3.1 + v_world_y * 0.12);
	vec3 spec_col = mix(vision_tint_primary, vision_tint_secondary, wave);

	// À vision_phase = 0.0 : ALBEDO = tex_col, EMISSION = 0, ALPHA = 1.0 -> 100% identique à l'arbre normal (zéro coupure !)
	// En 2-3s (vision_phase -> 1.0) : les arbres deviennent fantomatiques avec contours lumineux et coeur translucide !
	float luma = dot(tex_col, vec3(0.299, 0.587, 0.114));
	vec3 spectral_albedo = mix(vec3(luma) * vec3(0.18, 0.24, 0.38), spec_col * 0.35, 0.40);
	ALBEDO = mix(tex_col, spectral_albedo, vision_phase * 0.85);
	EMISSION = spec_col * (fresnel * (0.95 + 0.35 * wave) + 0.08) * vision_phase;

	float center_cone = 1.0 - smoothstep(0.06, 0.65, length(SCREEN_UV - vec2(0.5)));
	float interior_alpha = mix(0.26, 0.14, center_cone);
	float rim_alpha = mix(0.74, 0.56, center_cone * 0.45);
	float target_alpha = mix(interior_alpha, rim_alpha, fresnel);

	ALPHA = mix(1.0, target_alpha, vision_phase);
	ALPHA_HASH_SCALE = 1.0;
}
