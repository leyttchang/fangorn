shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec3 Main_Color : source_color = vec3(0.5, 1.4, 2.2);
uniform vec3 Effect_Color : source_color = vec3(0.85, 1.2, 1.5);

uniform int Octave_Count : hint_range(1, 8) = 4;
uniform float Amp_Start = 0.46;
uniform float Amp_Coeff = 0.5;
uniform float Freq_Coeff = 2.25;
uniform float Speed = 4.8;

uniform float Y_Size = 5.0;
uniform float X_Size = 1.05;
uniform float Emission_Power = 2.6;

float Hash12(vec2 uv) {
	return fract(cos(mod(dot(uv, vec2(13.9898, 8.141)), 3.14)) * 43758.5453);
}

vec2 Hash22(vec2 uv) {
	uv = vec2(dot(uv, vec2(127.1, 311.7)), dot(uv, vec2(269.5, 183.3)));
	return 2.0 * fract(sin(uv) * 43758.5453123);
}

float Noise(vec2 uv) {
	vec2 iuv = floor(uv);
	vec2 fuv = fract(uv);
	vec2 blur = fuv * fuv * (3.0 - 2.0 * fuv);

	float a = dot(Hash22(iuv + vec2(0.0, 0.0)), fuv - vec2(0.0, 0.0));
	float b = dot(Hash22(iuv + vec2(1.0, 0.0)), fuv - vec2(1.0, 0.0));
	float c = dot(Hash22(iuv + vec2(0.0, 1.0)), fuv - vec2(0.0, 1.0));
	float d = dot(Hash22(iuv + vec2(1.0, 1.0)), fuv - vec2(1.0, 1.0));

	return mix(mix(a, b, blur.x), mix(c, d, blur.x), blur.y) + 0.5;
}

float FBM(vec2 uv) {
	float value = 0.0;
	float amplitude = Amp_Start;
	for (int i = 0; i < Octave_Count; i++) {
		value += amplitude * Noise(uv);
		uv *= Freq_Coeff;
		amplitude *= Amp_Coeff;
	}
	return value;
}

void fragment() {
	vec2 mod_uv = 2.0 * UV - 1.0;
	mod_uv.y *= Y_Size;
	mod_uv.x *= X_Size;

	mod_uv.x -= Amp_Start;
	mod_uv += FBM(mod_uv + TIME * Speed);
	mod_uv.x += 0.5 - Amp_Coeff;

	float dist = max(abs(mod_uv.x), 0.008);
	float flicker = mix(0.014, 0.052, Hash12(vec2(floor(TIME * 30.0) * 0.033)));
	vec3 intensity = Effect_Color * (flicker / dist);

	ALBEDO = intensity * Main_Color * (1.0 + Emission_Power * 0.65);
	ALPHA = clamp(intensity.r, 0.0, 1.0);
}
