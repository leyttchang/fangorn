shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float shockwave : hint_range(0.0, 1.0) = 0.0;
uniform vec3 elem_tint : source_color = vec3(0.65, 0.35, 1.0);

vec3 rainbow_tint(float t) {
	return vec3(0.55) + vec3(0.45) * cos(6.2831853 * (t + vec3(0.0, 0.33, 0.67)));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (intensity <= 0.001 && shockwave <= 0.001) {
		COLOR = texture(screen_tex, uv);
	} else {
		vec2 centered = uv - vec2(0.5);
		float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.00001);
		vec2 p = vec2(centered.x * aspect, centered.y);
		float r = length(p);
		vec2 radial_dir = (r > 0.0001) ? (centered / r) : vec2(0.0);

		float t = TIME;

		// Légère ondulation douce pendant la montée progressive (pas de flash brutal à t=0 !)
		float ring_band = sin(r * 10.0 - t * 3.0) * 0.5 + 0.5;
		ring_band *= shockwave * smoothstep(0.05, 0.5, r);

		// Forte distorsion liquide psychédélique montant progressivement sur 2-3s avec `intensity`
		float edge_w = mix(0.26, 1.0, smoothstep(0.04, 0.58, r));
		float w_x = sin(uv.y * 13.0 + t * 2.7 + sin(uv.x * 8.0 - t * 1.7))
			+ 0.55 * cos(uv.y * 27.0 - t * 4.1 + uv.x * 11.0);
		float w_y = cos(uv.x * 11.5 - t * 2.4 + cos(uv.y * 9.0 + t * 2.0))
			+ 0.55 * sin(uv.x * 23.0 + t * 3.7 - uv.y * 13.0);

		float barrel = sin(r * 8.5 - t * 3.1) * 0.015 * intensity * edge_w;
		vec2 liquid_warp = vec2(w_x, w_y) * (0.012 * intensity * edge_w);
		vec2 shock_warp = radial_dir * (ring_band * 0.018 * intensity);

		vec2 warped_uv = clamp(uv + liquid_warp + radial_dir * barrel + shock_warp, vec2(0.002), vec2(0.998));

		// Aberration chromatique radiale + tangentielle très marquée
		float ca_amount = (0.0045 + 0.025 * r * r) * intensity;
		float ca_pulse = 0.85 + 0.25 * sin(t * 4.8 + r * 9.0);
		vec2 tangent_dir = vec2(-radial_dir.y, radial_dir.x);
		vec2 ca_vec = (radial_dir + tangent_dir * (0.35 * sin(t * 2.5 + r * 6.0))) * (ca_amount * ca_pulse);

		float col_r = texture(screen_tex, clamp(warped_uv + ca_vec * 1.15, vec2(0.001), vec2(0.999))).r;
		float col_g = texture(screen_tex, warped_uv).g;
		float col_b = texture(screen_tex, clamp(warped_uv - ca_vec * 1.15, vec2(0.001), vec2(0.999))).b;
		vec3 col = vec3(col_r, col_g, col_b);

		// Écho spectral dédoublé vers les bords
		vec2 echo_uv = clamp(vec2(0.5) + (warped_uv - vec2(0.5)) * (1.0 - 0.038 * intensity), vec2(0.001), vec2(0.999));
		vec3 echo_col = vec3(
			texture(screen_tex, clamp(echo_uv - ca_vec * 0.6, vec2(0.001), vec2(0.999))).r,
			texture(screen_tex, echo_uv).g,
			texture(screen_tex, clamp(echo_uv + ca_vec * 0.6, vec2(0.001), vec2(0.999))).b
		);
		col = mix(col, max(col, echo_col * 0.92), 0.36 * intensity * smoothstep(0.10, 0.68, r));

		// Virage colorimétrique onirique + halo prismatique périphérique
		float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
		vec3 prism_edge = rainbow_tint(atan(p.y, p.x) * 0.15915 + t * 0.32 - r * 1.4);
		vec3 dream_tint = mix(prism_edge, elem_tint, 0.60);

		float vig = smoothstep(0.24, 0.88, r);
		col = mix(col, col * mix(vec3(1.0), dream_tint * 1.45, 0.42) + dream_tint * (vig * 0.15), intensity);
		col = mix(vec3(luma), col, 1.0 + 0.30 * intensity);

		COLOR = vec4(col, 1.0);
	}
}
