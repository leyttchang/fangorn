shader_type spatial;
// skip_vertex_transform : on deplace les sommets en espace MONDE (comme le shader d'herbe de Terrain3D)
render_mode cull_disabled, specular_disabled, diffuse_lambert, skip_vertex_transform;

// ---------------- COULEURS ----------------
uniform vec3 color : source_color;
uniform vec3 color2 : source_color;
// repeat_enable : indispensable pour que le bruit defile/tuile sur toute la carte
uniform sampler2D noise : filter_linear, repeat_enable;
uniform float noiseScale = 20.0;

group_uniforms look;
uniform float base_darkening : hint_range(0.0, 1.0) = 0.45;
uniform float tip_brighten : hint_range(0.0, 1.0) = 0.25;
uniform float color_variation : hint_range(0.0, 1.0) = 0.5;
uniform vec3 dry_color : source_color = vec3(0.48, 0.42, 0.16);
uniform float dry_amount : hint_range(0.0, 1.0) = 0.3;
uniform float normal_up_blend : hint_range(0.0, 1.0) = 0.6;
// Translucidite (lumiere a travers les brins). Couteuse par pixel : desactivee par defaut.
// Pour l'activer, decommenter la ligne suivante :
//#define USE_BACKLIGHT
#ifdef USE_BACKLIGHT
uniform float backlight_amount : hint_range(0.0, 1.0) = 0.25;
#endif
uniform float tip_pinch : hint_range(0.0, 1.0) = 0.0;

group_uniforms wind;
// Ces 4 valeurs sont pilotees par le script global Wind (autoload)
uniform vec2 wind_direction = vec2(1.0, 0.5);
uniform float wind_speed = 2.0;
uniform float wind_strength = 0.15;
// Phase et defilement integres par le script Wind (ne pas modifier a la main)
uniform float wind_time = 0.0;
uniform vec2 wind_scroll = vec2(0.0);
// --- Reglages des rafales ---
// Taille des rafales : 0.04 = taches d'environ 25 m (plus petit = rafales plus larges)
uniform float gust_frequency : hint_range(0.005, 0.2) = 0.04;
// Vitesse de propagation des rafales, multipliee par la vitesse du vent (m/s par unite de vitesse)
uniform float gust_travel : hint_range(0.0, 5.0) = 1.8;
// Rythme des releves / rechutes aleatoires (par unite de temps du vent). Plus haut = plus frequent
uniform float gust_rate : hint_range(0.0, 2.0) = 0.35;
// Part du hasard temporel (0 = uniquement des vagues qui avancent, 1 = uniquement des timings aleatoires)
uniform float gust_randomness : hint_range(0.0, 1.0) = 0.4;
// Contraste : en dessous de x = accalmie (herbe relevee), au dessus de y = pleine rafale. Plus l'ecart est grand, plus c'est progressif
uniform vec2 gust_contrast = vec2(0.2, 0.85);
// Decalage aleatoire par touffe (metres)
uniform float gust_dithering = 1.5;
// Inclinaison qui reste pendant les accalmies (proportion). 0 = herbe totalement droite entre deux rafales
uniform float calm_lean : hint_range(0.0, 1.0) = 0.15;
// Turbulence : amplitude des petits va-et-vient (proportion de max_lean)
uniform float turbulence : hint_range(0.0, 1.0) = 0.35;
// Taille des tourbillons (plus grand = tourbillons plus petits)
uniform float turb_frequency : hint_range(0.02, 1.0) = 0.25;
// Rythme des va-et-vient propres a chaque touffe
uniform float turb_rate : hint_range(0.1, 5.0) = 1.4;
// Retour en arriere max (contre le vent), en proportion de max_lean
uniform float back_swing : hint_range(0.0, 0.5) = 0.15;
// Inclinaison max de la pointe (1.0 ~ 45 deg). Le brin ne se couche jamais au-dela.
uniform float max_lean : hint_range(0.1, 1.5) = 0.9;
// Convertit la force envoyee par le script Wind (0.05 calme .. 1.1 tempete) en intensite 0..1
uniform float strength_mult : hint_range(0.1, 2.0) = 0.85;
// Mouvement lateral individuel (comme la demo), disparait quand le vent est fort
uniform float lateral_amount : hint_range(0.0, 0.5) = 0.15;
// Les rafales eclaircissent l'herbe (effet "vague" visible sur le champ)
uniform float wind_light : hint_range(0.0, 1.0) = 0.25;
// Active ou desactive la coupure de mouvement par distance
uniform bool enable_wind_distance_cutoff = true;
// Au-dela de cette distance (m), aucun calcul de mouvement : l'herbe reste fixe (gain majeur de performance)
uniform float wind_max_distance : hint_range(10.0, 200.0) = 60.0;

group_uniforms distance;
uniform float thin_start : hint_range(10.0, 100.0) = 30.0;
uniform float thin_end : hint_range(50.0, 200.0) = 80.0;
uniform float far_keep : hint_range(0.1, 1.0) = 0.35;
uniform float fade_distance_min : hint_range(0.0, 500.0) = 80.0;
uniform float fade_distance_max : hint_range(0.0, 500.0) = 110.0;

varying vec3 noiseLevel;
// x = hauteur sur le brin (0 base, 1 pointe), y = vague de vent, z = secheresse, w = force de la vague
varying vec4 g_data;
varying vec2 g_rnd;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Bruit de valeur 2D lisse (0..1)
float vnoise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	vec3 cam_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 instance_pos = MODEL_MATRIX[3].xyz;
	float dist = length(instance_pos - cam_pos);
	vec2 p = instance_pos.xz;

	// Aleatoire stable par touffe
	vec2 rnd = vec2(hash12(p), hash12(p.yx + 19.19));

	// 1. Amincissement par distance
	float keep = mix(1.0, far_keep, smoothstep(thin_start, thin_end, dist));
	float alive = smoothstep(rnd.x - 0.08, rnd.x, keep);
	float comp = inversesqrt(max(keep, 0.01));
	VERTEX.xz *= comp;
	VERTEX.y *= mix(1.0, comp, 0.4);
	VERTEX *= alive;

	// 2. Fondu final de disparition
	VERTEX *= clamp(1.0 - smoothstep(fade_distance_min, fade_distance_max, dist), 0.0, 1.0);

	// Hauteur sur le brin : UV.y = 1 a la racine, 0 a la pointe
	float hr = clamp(1.0 - UV.y, 0.0, 1.0);
	VERTEX.xz *= 1.0 - tip_pinch * hr * hr;

	// 3. VENT ET MOUVEMENT ------------------------------------------------------
	float gust = 0.5;
	if (enable_wind_distance_cutoff && dist >= wind_max_distance) {
		// Au-dela de wind_max_distance : AUCUN calcul de mouvement, sommet projete directement
		VERTEX = (VIEW_MATRIX * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		NORMAL = MODELVIEW_NORMAL_MATRIX * NORMAL;
		BINORMAL = MODELVIEW_NORMAL_MATRIX * BINORMAL;
		TANGENT = MODELVIEW_NORMAL_MATRIX * TANGENT;
	} else {
		// Rafales procedurales et turbulence (calculees seulement pres de la camera)
		vec2 wdir = normalize(wind_direction + vec2(0.0001));
		vec2 perp = vec2(-wdir.y, wdir.x);
		float s = clamp(wind_strength * strength_mult, 0.0, 1.0);

		vec2 q = (p + rnd * gust_dithering) * gust_frequency - wind_scroll * gust_frequency * gust_travel;
		float travel = vnoise(q) * 0.65 + vnoise(q * 2.3 + vec2(17.0, 31.0)) * 0.35;
		float timing = vnoise(vec2(wind_time * gust_rate + rnd.x * 0.6, 0.0) + p * 0.025);
		float g = smoothstep(gust_contrast.x, gust_contrast.y, mix(travel, timing, gust_randomness));

		float f = s * mix(calm_lean, 1.0, g);
		float lean_base = max_lean * pow(f, 0.707);

		vec2 tq = p * turb_frequency - wind_scroll * turb_frequency * gust_travel * 1.6;
		float eddy = vnoise(tq + rnd * 3.0) * 2.0 - 1.0;
		float tuft = vnoise(vec2(wind_time * turb_rate + rnd.y * 37.0, rnd.x * 53.0)) * 2.0 - 1.0;
		float side = vnoise(vec2(wind_time * turb_rate * 0.8 + rnd.x * 41.0, rnd.y * 29.0 + 7.0)) * 2.0 - 1.0;
		float t_amp = turbulence * max_lean * s * (0.45 + 0.55 * g);
		float lean_full = clamp(lean_base + (eddy * 0.55 + tuft * 0.45) * t_amp, -back_swing * max_lean, max_lean * 1.1);

		float wf = 1.0;
		if (enable_wind_distance_cutoff) {
			wf = 1.0 - smoothstep(wind_max_distance * 0.75, wind_max_distance, dist);
		}
		float lean_t = lean_full * wf;
		gust = mix(0.5, g, wf);
		float wobble = sin(wind_time * 1.3 * (1.0 + rnd.x + rnd.y)) * lateral_amount * (1.0 - g) * wf;
		float side_n = side * wf;

		float lean = lean_t * hr;
		float side_off = side_n * t_amp * 0.5 * hr;

		vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float vh = max(w.y - instance_pos.y, 0.0);
		w.xz += (wdir + perp * wobble) * (lean * vh) + perp * (side_off * vh);
		w.y -= vh * (lean * lean + side_off * side_off) * 0.5;
		VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
		NORMAL = MODELVIEW_NORMAL_MATRIX * NORMAL;
		BINORMAL = MODELVIEW_NORMAL_MATRIX * BINORMAL;
		TANGENT = MODELVIEW_NORMAL_MATRIX * TANGENT;
	}

	// 4. Donnees pour le fragment (1 lecture de texture par touffe, pas par pixel)
	noiseLevel = textureLod(noise, p / noiseScale, 0.0).rgb;
	float dry_n = textureLod(noise, p / (noiseScale * 3.0) + vec2(0.37, 0.11), 0.0).r;
	g_data = vec4(hr, gust, smoothstep(0.55, 0.8, dry_n), wind_strength * gust);
	g_rnd = rnd;
}

void fragment() {
	float hr = g_data.x;

	vec3 base = mix(color, color2, hr) * mix(color, color2, noiseLevel.r);
	base = mix(base, dry_color, g_data.z * dry_amount);

	// Variation entre touffes
	base *= 1.0 + (g_rnd.x - 0.5) * color_variation * 0.4;
	base.rg *= 1.0 + (g_rnd.y - 0.5) * color_variation * 0.24;

	// Base sombre, pointe claire
	base *= mix(1.0 - base_darkening, 1.0, smoothstep(0.0, 0.5, hr));
	base += base * tip_brighten * smoothstep(0.8, 1.0, hr);

	// Les vagues de vent eclaircissent la pointe (plus visible quand le vent monte)
	base *= 1.0 + wind_light * g_data.y * clamp(g_data.w * 2.0, 0.0, 1.0) * hr;

	ALBEDO = base;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
#ifdef USE_BACKLIGHT
	BACKLIGHT = vec3(backlight_amount) * hr;
#endif

	// Double face : on retourne la normale puis on la rapproche de "haut" pour un eclairage homogene
	vec3 n = NORMAL;
	if (!FRONT_FACING) {
		n = -n;
	}
	vec3 up_view = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	NORMAL = normalize(mix(n, up_view, normal_up_blend));
}