shader_type spatial;
render_mode cull_disabled;

uniform vec3 color : source_color;
uniform vec3 color2 : source_color;
uniform sampler2D noise;
uniform float noiseScale = 20.0;

// --- NOUVEAUX PARAMÈTRES POUR LE VENT ---
uniform vec2 wind_direction = vec2(1.0, 0.5); // Direction de la brise (X et Z)
uniform float wind_speed = 2.0;               // Vitesse de l'ondulation
uniform float wind_strength = 0.15;           // Force du vent (amplitude)
// ----------------------------------------

varying vec3 worldPos;

void vertex() {
	// On calcule la position dans le monde
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// --- CALCUL DU VENT ---
	// L'ondulation dépend du temps et de la position dans le monde (pour que toute l'herbe ne bouge pas de la même façon au même moment)
	float wind_wave = sin(TIME * wind_speed + worldPos.x + worldPos.z);
	
	// On utilise UV.y comme "masque de rigidité". 
	// On part du principe que UV.y = 1.0 est la racine (qui ne bouge pas) et 0.0 est la pointe.
	float wind_weight = 1.0 - UV.y; 
	
	// On déforme le modèle sur les axes X et Z
	VERTEX.x += wind_wave * wind_direction.x * wind_strength * wind_weight;
	VERTEX.z += wind_wave * wind_direction.y * wind_strength * wind_weight;
}

void fragment() {
	vec3 noiseLevel = texture(noise, worldPos.xz / noiseScale).rgb;
	ALBEDO = mix(color, color2, 1.0 - UV.y) * mix(color, color2, noiseLevel.r);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}