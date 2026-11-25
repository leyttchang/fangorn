shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform float intersect_thickness : hint_range(0.05, 1.0) = 0.36;
uniform float fade_factor : hint_range(0.0, 1.0) = 1.0;
uniform vec4 outline_core_color : source_color = vec4(1.0, 0.94, 0.66, 1.0);
uniform vec4 outline_fire_color : source_color = vec4(1.0, 0.34, 0.04, 1.0);
uniform vec4 surface_fire_color : source_color = vec4(1.0, 0.38, 0.06, 1.0);

varying vec3 v_local_pos;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float n000 = hash31(i);
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));

	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);

	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);
	return mix(nxy0, nxy1, f.z);
}

float fbm3(vec3 p) {
	float v = 0.62 * vnoise3(p);
	v += 0.38 * vnoise3(p * 2.15 + vec3(4.2, -1.7, 2.9));
	return v;
}

void vertex() {
	v_local_pos = VERTEX;
}

void fragment() {
	float raw_depth = texture(depth_tex, SCREEN_UV).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth * 2.0 - 1.0);
	#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
	#endif
	vec4 upos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float scene_z = -upos.z / upos.w;
	float frag_z = -VERTEX.z;
	float depth_diff = abs(scene_z - frag_z);

	// Seamless scrolling 3D procedural fire across the sphere
	vec3 flow_p = v_local_pos * 2.85 - vec3(0.0, TIME * 1.75, 0.0);
	float flame_n = fbm3(flow_p);
	float lick = 0.76 + 0.34 * flame_n;

	// Depth Intersection Outline on terrain, walls, trees, and monsters crossing the sphere
	float has_geometry = step(0.00002, raw_depth);
	float eff_thick = intersect_thickness * lick;
	float outline_band = (1.0 - smoothstep(0.0, eff_thick, depth_diff)) * has_geometry;
	float outline_core = (1.0 - smoothstep(0.0, intersect_thickness * 0.28, depth_diff)) * has_geometry;

	vec3 intersect_col = mix(outline_fire_color.rgb * 1.9, outline_core_color.rgb * 2.8, outline_core);

	// Soft transparent surface fire: ultra-clean from inside (FPS) via FRONT_FACING, warm Fresnel from outside
	float ndv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float fresnel = pow(1.0 - clamp(ndv, 0.0, 1.0), 2.3);
	float flame_wisps = smoothstep(0.36, 0.86, flame_n);

	float surf_alpha = 0.0;
	if (FRONT_FACING) {
		surf_alpha = (0.045 + 0.16 * fresnel) * (0.45 + 0.75 * flame_wisps);
	} else {
		// Viewed from inside in 1st person: keep center crystal-clear (0.05..0.12)
		float horizon_band = 1.0 - abs(v_local_pos.y) * 0.45;
		surf_alpha = (0.042 + 0.078 * flame_wisps * horizon_band);
	}

	vec3 surf_col = mix(surface_fire_color.rgb, outline_core_color.rgb, flame_wisps * 0.42) * 1.35;

	float outline_alpha = pow(outline_band, 1.25) * 0.94;
	float total_alpha = clamp(max(surf_alpha, outline_alpha) * fade_factor, 0.0, 0.96);
	vec3 final_rgb = mix(surf_col, intersect_col, clamp(outline_band * 1.2, 0.0, 1.0));

	ALBEDO = final_rgb;
	ALPHA = total_alpha;
}
