shader_type spatial;
render_mode cull_disabled, specular_disabled, diffuse_lambert;

uniform vec3 color : source_color;
uniform vec3 color2 : source_color;
uniform sampler2D noise;
uniform float noiseScale = 20.0;

// --- NOUVEAUX PARAMÈTRES POUR LE VENT ---
uniform vec2 wind_direction = vec2(1.0, 0.5); // Direction de la brise (X et Z)
uniform float wind_speed = 2.0;               // Vitesse de l'ondulation
uniform float wind_strength = 0.15;           // Force du vent (amplitude)
// ----------------------------------------

// --- AMINCISSEMENT PAR DISTANCE (DISTANCE THINNING) ---
uniform float thin_start : hint_range(10.0, 100.0) = 35.0;   // Début de l'amincissement (m)
uniform float thin_end : hint_range(50.0, 200.0) = 140.0;    // Distance où on atteint far_keep
uniform float far_keep : hint_range(0.1, 1.0) = 0.35;        // Part de touffes gardées au loin

// --- FONDU DE DISTANCE SANS POPPING (VERTEX SHRINKING) ---
uniform float fade_distance_min : hint_range(0.0, 500.0) = 140.0;
uniform float fade_distance_max : hint_range(0.0, 500.0) = 200.0;

varying vec3 worldPos;
varying vec3 noiseLevel;

void vertex() {
	// On calcule la position de l'instance et de la caméra dans le monde
	vec3 cam_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 instance_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = length(instance_pos - cam_pos);

	// 1. Amincissement par distance : élimine ~65% des touffes au loin tout en élargissant les restantes
	float h = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
	float keep = mix(1.0, far_keep, smoothstep(thin_start, thin_end, dist));
	float alive = smoothstep(h - 0.08, h, keep);
	float comp = inversesqrt(max(keep, 0.01));
	VERTEX.xz *= comp;
	VERTEX.y *= mix(1.0, comp, 0.4);
	VERTEX *= alive;

	// 2. Fondu doux de disparition (réduction des sommets vers 0)
	float fade = clamp(1.0 - smoothstep(fade_distance_min, fade_distance_max, dist), 0.0, 1.0);
	VERTEX *= fade;

	// On calcule la position dans le monde
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// 3. ONDE DE VENT FLUIDE & ORGANIQUE (Inspiré du shader d'herbe Terrain3D)
	vec2 wind_dir = normalize(wind_direction);
	vec2 perp_dir = vec2(-wind_dir.y, wind_dir.x); // Axe perpendiculaire pour le tanguage latéral
	
	// Échantillonnage fluide du bruit qui défile avec le vent (bourrasques douces sans à-coups)
	vec2 wind_uv = (instance_pos.xz * 0.02) - (wind_dir * TIME * wind_speed * 0.08);
	float wind_noise_sample = textureLod(noise, wind_uv, 0.0).r;
	
	// Onde de progression spatiale douce le long du vecteur de vent
	float pos_along_wind = dot(instance_pos.xz, wind_dir);
	float perp_pos = dot(instance_pos.xz, perp_dir);
	float wave1 = sin(pos_along_wind * 0.08 - TIME * wind_speed * 0.9);
	float wave2 = sin(pos_along_wind * 0.18 + perp_pos * 0.05 - TIME * wind_speed * 1.3);
	float wave_combined = (wave1 * 0.6 + wave2 * 0.4) * 0.5 + 0.5; // 0.0 à 1.0
	
	// Fusion continue du bruit et des ondes pour supprimer l'effet de ressort "sec"
	float gust = mix(wave_combined, wind_noise_sample, 0.5);
	// Amortissement de la crête (pow < 1.0 adoucit la redescente et donne de l'élasticité/inertie naturelle)
	gust = pow(clamp(gust, 0.0, 1.0), 0.75);
	
	// Tanguage latéral organique (l'herbe oscille doucement de gauche à droite au lieu d'un mouvement rectiligne)
	float lateral_wobble = sin(TIME * wind_speed * 1.5 + instance_pos.x * 0.4 + instance_pos.z * 0.4) * 0.22;
	
	// Force globale : légère inclinaison de repos + bourrasque souple
	float force = (0.2 + 0.8 * gust) * wind_strength;
	
	// Courbure le long du brin : la base reste bien plantée, le dernier tiers fléchit avec grâce
	float height_ratio = clamp(1.0 - UV.y, 0.0, 1.0);
	float height_curve = height_ratio * height_ratio; // Quadratique pour fouetter en pointe
	float bend = force * height_curve;
	
	// Déplacement mondial combiné (direction principale du vent + composante latérale fluide)
	vec2 total_displacement_dir = wind_dir + perp_dir * lateral_wobble;
	vec3 world_sway = vec3(total_displacement_dir.x * bend, 0.0, total_displacement_dir.y * bend);
	
	// Conversion vers l'espace local pour annuler la rotation aléatoire (rot Y) de chaque instance
	vec3 local_sway = (inverse(MODEL_MATRIX) * vec4(world_sway, 0.0)).xyz;
	
	VERTEX.x += local_sway.x;
	VERTEX.z += local_sway.z;
	// Abaissement physique souple en Y lorsque l'herbe se courbe
	VERTEX.y -= bend * height_curve * 0.35;

	// 4. Échantillonnage du bruit par sommet (1 lecture par instance au lieu de millions par pixel)
	noiseLevel = textureLod(noise, instance_pos.xz / noiseScale, 0.0).rgb;
}

void fragment() {
	ALBEDO = mix(color, color2, 1.0 - UV.y) * mix(color, color2, noiseLevel.r);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}