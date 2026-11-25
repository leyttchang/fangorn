shader_type spatial;
render_mode blend_add, depth_draw_never, depth_test_disabled, cull_disabled, unshaded, fog_disabled;

uniform sampler2D curve_tex : filter_linear, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

// 0 = arcane, 1 = lightning, 2 = ice, 3 = fire
uniform int elem_mode = 0;
uniform vec3 color_primary : source_color = vec3(1.5, 0.35, 2.6);
uniform vec3 color_secondary : source_color = vec3(0.45, 0.95, 2.8);
uniform vec3 color_core : source_color = vec3(2.2, 1.9, 2.8);

uniform vec3 origin_anchor = vec3(0.0);
uniform vec3 player_pos = vec3(0.0);
uniform float reveal_progress : hint_range(0.0, 1.0) = 1.0;
uniform float master_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float flow_speed : hint_range(0.01, 0.5) = 0.085;

varying float v_alpha;
varying float v_u;
varying float v_fresnel;
varying float v_seed;
varying float v_view_z;

mat3 rot_axis_angle(vec3 axis, float angle) {
	vec3 a = normalize(axis);
	float s = sin(angle);
	float c = cos(angle);
	float oc = 1.0 - c;
	return mat3(
		vec3(oc * a.x * a.x + c,        oc * a.x * a.y - a.z * s,  oc * a.z * a.x + a.y * s),
		vec3(oc * a.x * a.y + a.z * s,  oc * a.y * a.y + c,        oc * a.y * a.z - a.x * s),
		vec3(oc * a.z * a.x - a.y * s,  oc * a.y * a.z + a.x * s,  oc * a.z * a.z + c)
	);
}

vec3 sample_path(float u) {
	vec3 base_p = texture(curve_tex, vec2(clamp(u, 0.0, 1.0), 0.5)).rgb;
	float follow_w = pow(1.0 - clamp(u, 0.0, 1.0), 2.4);
	return base_p + (player_pos - origin_anchor) * follow_w;
}

void vertex() {
	float u_seed = INSTANCE_CUSTOM.x;
	float rad_seed = INSTANCE_CUSTOM.y;
	float phase = INSTANCE_CUSTOM.z * 6.2831853;
	float scale_m = INSTANCE_CUSTOM.w;

	// Les dernières instances tourbillonnent autour de la base de l'immense colonne du totem !
	bool is_beacon_swirl = (u_seed > 0.90 && rad_seed > 0.65);

	float speed_elem = flow_speed;
	if (elem_mode == 1) {
		speed_elem = flow_speed * 1.65;
	} else if (elem_mode == 2) {
		speed_elem = flow_speed * 0.85;
	} else if (elem_mode == 3) {
		speed_elem = flow_speed * 1.18;
	}

	float u = fract(u_seed + TIME * speed_elem);
	if (is_beacon_swirl) {
		u = 0.998;
	}
	v_u = u;
	v_seed = rad_seed;

	vec3 p_cur = sample_path(u);
	vec3 p_nxt = sample_path(min(1.0, u + 0.015));
	vec3 p_prv = sample_path(max(0.0, u - 0.015));
	vec3 tangent = normalize(p_nxt - p_prv + vec3(0.0001, 0.0, 0.0));
	vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), tangent) + vec3(0.0001, 0.0, 0.0));
	vec3 up_v = normalize(cross(tangent, side));

	// Légère mise à l'échelle avec la distance le long du chemin pour rester bien lisible de loin
	float dist_scale = mix(1.0, 2.35, u);
	vec3 offset_world = vec3(0.0);
	vec3 local_v = VERTEX * (scale_m * dist_scale);
	vec3 local_n = NORMAL;

	if (is_beacon_swirl) {
		float h_frac = fract(phase * 0.31 + TIME * 0.22);
		float spiral_ang = h_frac * 18.0 - TIME * 2.4 + phase;
		float b_rad = mix(6.5, 2.2, h_frac) + 0.8 * sin(TIME * 3.0 + phase);
		offset_world = vec3(cos(spiral_ang) * b_rad, h_frac * 95.0 + 1.0, sin(spiral_ang) * b_rad);
		mat3 r_b = rot_axis_angle(vec3(0.3, 1.0, 0.2), TIME * 2.4 + phase);
		local_v = r_b * (VERTEX * scale_m * 2.8);
		local_n = r_b * local_n;
	} else if (elem_mode == 0) {
		float strand = (rad_seed > 0.5) ? 3.14159265 : 0.0;
		float helix_a = u * 34.0 - TIME * 3.2 + strand + phase * 0.25;
		float radius = (1.15 + rad_seed * 1.65) * (0.65 + 0.35 * sin(u * 12.0 + TIME * 2.0));
		float wave_x = sin(u * 15.0 - TIME * 1.9) * 2.4;
		offset_world = side * (cos(helix_a) * radius + wave_x) + up_v * (sin(helix_a) * radius * 0.78 + 0.45 * cos(u * 19.0 - TIME * 2.3));
		mat3 r_m = rot_axis_angle(normalize(vec3(sin(phase), 1.0, cos(phase))), TIME * 2.6 + phase);
		local_v = r_m * local_v;
		local_n = r_m * local_n;
	} else if (elem_mode == 1) {
		float snap_t = floor(TIME * 17.0 + u * 42.0 + rad_seed * 7.0);
		float jolt_x = (fract(sin(snap_t * 12.9898 + phase) * 43758.5453) - 0.5) * 4.8;
		float jolt_y = (fract(cos(snap_t * 78.233 + phase) * 29143.1234) - 0.5) * 2.8;
		offset_world = side * jolt_x + up_v * (jolt_y + 0.35);
		mat3 align_t = mat3(side, tangent, up_v);
		mat3 spin_t = rot_axis_angle(vec3(0.0, 1.0, 0.0), TIME * 6.5 + phase);
		local_v = align_t * (spin_t * (local_v * vec3(0.82, 1.55, 0.82)));
		local_n = align_t * (spin_t * local_n);
	} else if (elem_mode == 2) {
		float ribbon_w = sin(u * 20.0 - TIME * 2.1 + phase * 0.4) * (1.5 + rad_seed * 1.8);
		float crest_y = cos(u * 16.0 - TIME * 1.6 + rad_seed * 4.0) * 1.1;
		offset_world = side * ribbon_w + up_v * crest_y;
		mat3 r_ice = rot_axis_angle(normalize(vec3(0.25, 1.0, 0.2)), TIME * 1.35 + phase);
		local_v = r_ice * local_v;
		local_n = r_ice * local_n;
	} else {
		float swirl_f = u * 30.0 - TIME * 4.2 + phase;
		float rad_f = 0.95 + rad_seed * 1.9;
		float lick_up = abs(sin(u * 24.0 - TIME * 3.8 + phase)) * 1.95;
		offset_world = side * (cos(swirl_f) * rad_f + sin(u * 11.0 - TIME * 2.0) * 1.6) + up_v * (sin(swirl_f) * rad_f * 0.55 + lick_up - 0.35);
		mat3 r_fire = rot_axis_angle(normalize(vec3(1.0, 0.6, sin(phase))), TIME * 3.8 + phase);
		local_v = r_fire * local_v;
		local_n = r_fire * local_n;
	}

	vec3 world_pos = p_cur + offset_world + local_v;

	float reveal_mask = 1.0 - smoothstep(reveal_progress - 0.06, reveal_progress + 0.02, u);
	if (is_beacon_swirl) {
		reveal_mask = smoothstep(0.65, 0.98, reveal_progress);
	}
	float ends_fade = smoothstep(0.0, 0.045, u);
	v_alpha = reveal_mask * ends_fade * master_intensity;

	vec4 view_p = VIEW_MATRIX * vec4(world_pos, 1.0);
	v_view_z = -view_p.z;

	vec3 cam_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 v_dir = normalize(cam_pos - world_pos);
	v_fresnel = pow(1.0 - clamp(abs(dot(normalize(local_n), v_dir)), 0.0, 1.0), 1.65);

	POSITION = PROJECTION_MATRIX * view_p;
}

void fragment() {
	if (v_alpha <= 0.002) {
		discard;
	}

	float raw_d = texture(depth_texture, SCREEN_UV).r;
	vec4 scene_vs = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_d, 1.0);
	float scene_z = -scene_vs.z / max(abs(scene_vs.w), 0.00001);

	float xray_factor = (v_view_z > scene_z + 0.65) ? 0.56 : 1.0;

	float dist_boost = mix(1.0, 1.75, smoothstep(45.0, 420.0, v_view_z));
	float dist_fade = 1.0 - smoothstep(850.0, 1350.0, v_view_z);

	float pulse = 0.82 + 0.28 * sin(v_u * 40.0 - TIME * 6.5 + v_seed * 6.283);
	vec3 elem_mix = mix(color_primary, color_secondary, 0.5 + 0.5 * sin(v_u * 18.0 + TIME * 2.8 + v_seed * 4.0));
	vec3 final_col = mix(elem_mix, color_core, (1.0 - v_fresnel) * 0.58) * pulse * dist_boost;

	ALBEDO = final_col * xray_factor * v_alpha * dist_fade;
	ALPHA = clamp(v_alpha * xray_factor * dist_fade, 0.0, 1.0);
}
