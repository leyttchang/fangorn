// NOTE: Shader automatically converted from Godot Engine 4.7.stable's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_nearest, repeat_enable;
uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0.1, 128.0, 0.1);

uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;

uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);

uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

// --- PARAMÈTRES DU VENT ---
uniform float wind_height_start = 2.0; // Hauteur de départ (en bas, ne bouge pas)
uniform float wind_height_end = 3.0; // Hauteur de fin (en haut, bouge librement)
uniform float wind_speed = 1.0;
uniform float wind_strength = 0.2;
uniform vec2 wind_direction = vec2(1.0, 0.5);
uniform float wind_max_distance = 80.0; // Au-delà de 80m, plus de calcul de vent (gros gain vertex)

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	
	vec3 node_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 cam_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = length(node_origin - cam_pos);

	if (dist < wind_max_distance) {
		vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float true_height = world_pos.y - node_origin.y;
		float height_mask = smoothstep(wind_height_start, wind_height_end, true_height);
		
		if (height_mask > 0.0) {
			float wf = 1.0 - smoothstep(wind_max_distance * 0.75, wind_max_distance, dist);
			float time = TIME * wind_speed;
			float sway_x = sin(time + world_pos.x) * 0.5 + sin(time * 1.3 + world_pos.z) * 0.5;
			float sway_z = cos(time + world_pos.z) * 0.5 + cos(time * 0.8 + world_pos.x) * 0.5;
			
			vec3 sway_world = vec3(sway_x * wind_direction.x, 0.0, sway_z * wind_direction.y) * (wind_strength * height_mask * wf);
			
			// Transformation mondiale -> locale sans passer par l'inversion de matrice 4x4
			mat3 rot_scale = mat3(MODEL_MATRIX);
			float s2 = dot(rot_scale[0], rot_scale[0]);
			if (s2 > 0.0001) {
				vec3 sway_local = (transpose(rot_scale) * sway_world) / s2;
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
}
