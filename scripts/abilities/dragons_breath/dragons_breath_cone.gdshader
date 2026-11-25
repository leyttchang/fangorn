shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform sampler2D fire_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D simplex_tex : repeat_enable, filter_linear_mipmap;

uniform vec4 core_color : source_color = vec4(1.0, 0.93, 0.54, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.42, 0.06, 1.0);
uniform vec4 tip_color : source_color = vec4(0.86, 0.11, 0.02, 1.0);

uniform float scroll_speed = 2.2;
uniform float tile_u = 2.0;
uniform float density_gain = 0.55;
uniform float erode_bias = 0.0;
uniform float turb_strength = 0.22;
uniform float time_offset = 0.0;

uniform float deploy_progress : hint_range(0.0, 1.2) = 1.0;
uniform float tail_cut : hint_range(0.0, 1.2) = 0.0;
uniform float overheat_ratio : hint_range(0.0, 1.0) = 0.0;
uniform float blue_reach : hint_range(0.2, 0.75) = 0.48;
uniform float global_fade : hint_range(0.0, 1.0) = 1.0;

varying float v_along;

void vertex() {
	// CylinderMesh: VERTEX.y is +0.5 at top (hand) and -0.5 at bottom (mouth)
	v_along = clamp(0.5 - VERTEX.y, 0.0, 1.0);
	float ang = atan(VERTEX.x, VERTEX.z);
	float t = TIME * scroll_speed + time_offset;

	// Soft teardrop pinch near the hand so the base never forms a hard ring
	float nozzle_curve = mix(0.52, 1.0, smoothstep(0.0, 0.16, v_along));
	VERTEX.xz *= nozzle_curve;

	// Organic multi-wave turbulence growing stronger toward the ragged mouth
	float w1 = sin(ang * 3.0 + v_along * 7.5 - t * 3.4);
	float w2 = cos(ang * 5.0 - v_along * 11.0 - t * 2.6);
	float w3 = sin(ang * 2.0 + v_along * 4.2 - t * 4.2);
	float wave = w1 * 0.45 + w2 * 0.35 + w3 * 0.20;

	vec2 rad_dir = length(VERTEX.xz) > 0.0001 ? normalize(VERTEX.xz) : vec2(1.0, 0.0);
	float amp = smoothstep(0.06, 0.88, v_along) * turb_strength;
	VERTEX.xz += rad_dir * (wave * amp);
}

void fragment() {
	float t = TIME * scroll_speed + time_offset;

	// Seamless wrapped UVs scrolling forward from hand (v_along=0) to mouth (v_along=1)
	float sway = sin(v_along * 5.0 - t * 1.4) * 0.06;
	vec2 uv_main = vec2(UV.x * tile_u + sway, v_along * 1.55 - t);
	vec2 uv_detail = vec2(UV.x * (tile_u * 2.0) - sway * 0.8 - t * 0.18, v_along * 2.75 - t * 1.38);

	float n_fire = texture(fire_tex, uv_main).r;
	float n_simp = texture(simplex_tex, uv_detail).r;
	float flame_noise = clamp(n_fire * 0.60 + n_simp * 0.54, 0.0, 1.12);

	// Progressive noise erosion ("dissolution écorchée") tearing the cone tip into jagged flame tongues
	float tip_erode = mix(0.14, 1.05, smoothstep(0.30, 0.98, v_along)) + erode_bias;
	float deploy_mask = smoothstep(v_along - 0.08, v_along + 0.12, deploy_progress);
	float tail_mask = smoothstep(tail_cut - 0.06, tail_cut + 0.18, v_along);

	float erode_cutoff = tip_erode + (1.0 - deploy_mask) * 0.90 + (1.0 - tail_mask) * 0.95;
	float erode_mask = smoothstep(erode_cutoff - 0.09, erode_cutoff + 0.09, flame_noise);

	// Zero sharp edges: soft nozzle start, absolute zero before geometric end, and Fresnel side-falloff
	float nozzle_fade = smoothstep(0.0, 0.16, v_along);
	float tip_guard = 1.0 - smoothstep(0.91, 1.0, v_along);
	float ndv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float side_soft = pow(clamp(ndv, 0.0, 1.0), 0.85);

	// Base fire gradient (golden core -> roaring orange -> torn crimson tips)
	float edge_scorch = smoothstep(erode_cutoff - 0.04, erode_cutoff + 0.24, flame_noise);
	vec3 fire_rgb = mix(tip_color.rgb * 1.45, mid_color.rgb * 1.95, edge_scorch);
	fire_rgb = mix(fire_rgb, core_color.rgb * 2.35, smoothstep(0.62, 0.98, flame_noise) * (1.0 - v_along * 0.62));

	// Progressive Blue/White Plasma Overheat near the base of the jet as channeling continues
	float blue_zone = (1.0 - smoothstep(0.05, blue_reach, v_along)) * overheat_ratio;
	vec3 blue_flame = vec3(0.20, 0.60, 1.0) * 2.45;
	vec3 white_plasma = vec3(0.88, 0.96, 1.0) * 3.25;
	float hot_ridge = smoothstep(0.52, 0.94, flame_noise);
	vec3 plasma_rgb = mix(blue_flame, white_plasma, hot_ridge * (1.0 - v_along * 0.7));

	vec3 final_rgb = mix(fire_rgb, plasma_rgb, clamp(blue_zone * 1.15, 0.0, 1.0));
	float alpha = erode_mask * nozzle_fade * tip_guard * side_soft * density_gain * global_fade;

	ALBEDO = final_rgb;
	ALPHA = clamp(alpha, 0.0, 0.62);
}
