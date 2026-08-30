shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_thickness : hint_range(0.0, 5.0) = 1.0;
uniform float depth_threshold = 0.05;
uniform float normal_threshold = 0.5;

uniform bool enable_posterization = false;
uniform float posterize_steps = 8.0;

void vertex() {
    POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 texel_size = vec2(1.0) / VIEWPORT_SIZE * outline_thickness;
    
    // Profondeur (Croix + Diagonales)
    float d_center = texture(depth_texture, uv).r;
    float d_up     = texture(depth_texture, uv + vec2(0.0, texel_size.y)).r;
    float d_down   = texture(depth_texture, uv + vec2(0.0, -texel_size.y)).r;
    float d_left   = texture(depth_texture, uv + vec2(-texel_size.x, 0.0)).r;
    float d_right  = texture(depth_texture, uv + vec2(texel_size.x, 0.0)).r;
    float d_up_left = texture(depth_texture, uv + vec2(-texel_size.x, texel_size.y)).r;
    float d_up_right = texture(depth_texture, uv + vec2(texel_size.x, texel_size.y)).r;
    float d_down_left = texture(depth_texture, uv + vec2(-texel_size.x, -texel_size.y)).r;
    float d_down_right = texture(depth_texture, uv + vec2(texel_size.x, -texel_size.y)).r;
    
    // Normales (Croix + Diagonales)
    vec3 n_center = texture(normal_texture, uv).rgb;
    vec3 n_up     = texture(normal_texture, uv + vec2(0.0, texel_size.y)).rgb;
    vec3 n_down   = texture(normal_texture, uv + vec2(0.0, -texel_size.y)).rgb;
    vec3 n_left   = texture(normal_texture, uv + vec2(-texel_size.x, 0.0)).rgb;
    vec3 n_right  = texture(normal_texture, uv + vec2(texel_size.x, 0.0)).rgb;
    vec3 n_up_left = texture(normal_texture, uv + vec2(-texel_size.x, texel_size.y)).rgb;
    vec3 n_up_right = texture(normal_texture, uv + vec2(texel_size.x, texel_size.y)).rgb;
    vec3 n_down_left = texture(normal_texture, uv + vec2(-texel_size.x, -texel_size.y)).rgb;
    vec3 n_down_right = texture(normal_texture, uv + vec2(texel_size.x, -texel_size.y)).rgb;
    
    float depth_diff = abs(d_center - d_up) + abs(d_center - d_down) + abs(d_center - d_left) + abs(d_center - d_right) +
                       abs(d_center - d_up_left) + abs(d_center - d_up_right) + abs(d_center - d_down_left) + abs(d_center - d_down_right);
                       
    float normal_diff = distance(n_center, n_up) + distance(n_center, n_down) + distance(n_center, n_left) + distance(n_center, n_right) +
                        distance(n_center, n_up_left) + distance(n_center, n_up_right) + distance(n_center, n_down_left) + distance(n_center, n_down_right);
    
    bool is_edge = (depth_diff > depth_threshold) || (normal_diff > normal_threshold);
    vec4 original_color = texture(screen_texture, uv);
    
    // -- POSTÉRISATION --
    if (enable_posterization) {
        // Astuce : On convertit en espace Gamma avant de posteriser pour ne pas écraser les couleurs sombres !
        vec3 gamma_color = pow(original_color.rgb, vec3(1.0 / 2.2));
        gamma_color = round(gamma_color * posterize_steps) / posterize_steps;
        original_color.rgb = pow(gamma_color, vec3(2.2));
    }
    
    if (is_edge) {
        ALBEDO = outline_color.rgb;
        ALPHA = 1.0;
    } else {
        ALBEDO = original_color.rgb;
        ALPHA = 1.0;
    }
}