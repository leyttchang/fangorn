extends Node3D

## Gestionnaire de pluie : Oscillation douce du vent (-30 à +30) et suivi du joueur/caméra

@export_category("Vent & Gravité (Oscillation)")
## Active l'oscillation aléatoire et continue du vent sur les axes X et Z
@export var wind_enabled: bool = true
## Force maximale du vent en m/s² (amplitude entre -max_wind et +max_wind, défaut 30.0)
@export var max_wind: float = 30.0
## Vitesse de variation du vent (plus la valeur est petite, plus la transition est lente et douce)
@export var wind_change_speed: float = 0.025
## Gravité verticale de chute (calculée automatiquement depuis le matériau si laissée à 0)
@export var base_gravity_y: float = -14.0

@export_category("Suivi du Joueur")
## Si vrai, ce nœud de pluie se positionne automatiquement sur le joueur / la caméra active
@export var follow_player: bool = true
## Vitesse de lissage du suivi (0.0 = téléportation instantanée sans délai)
@export var follow_smoothness: float = 0.0
## Suivre également la hauteur (altitude) du joueur
@export var follow_y: bool = true
## Décalage vertical par rapport à la caméra/au joueur
@export var height_offset: float = 0.0

@export_category("Références")
## Nœud d'émission de pluie (détecté automatiquement si non renseigné)
@export var rain_particles: GPUParticles3D

var _noise: FastNoiseLite
var _time: float = 0.0

func _ready() -> void:
	# Initialisation d'un générateur de bruit Perlin/Simplex pour des bourrasques douces et organiques
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.05
	_noise.fractal_octaves = 2
	_noise.seed = randi()
	
	# Résolution automatique du nœud de particules
	if rain_particles == null:
		rain_particles = get_node_or_null("rain_P") as GPUParticles3D
	if rain_particles == null:
		rain_particles = get_node_or_null("rain") as GPUParticles3D
	if rain_particles == null:
		for child in get_children():
			if child is GPUParticles3D:
				rain_particles = child
				break

	if rain_particles != null:
		# IMPORTANT : Les particules de pluie DOIVENT être en coordonnées globales (local_coords = false).
		# Ainsi, quand le joueur avance, il avance à travers la pluie sans emporter les gouttes dans les airs.
		rain_particles.local_coords = false
		
		var mat = rain_particles.process_material as ParticleProcessMaterial
		if mat != null:
			if base_gravity_y == -14.0 and mat.gravity.y != 0.0:
				base_gravity_y = mat.gravity.y
			# Assurer que les gouttes s'inclinent avec le vent
			mat.particle_flag_align_y = true

var _is_first_follow: bool = true

func _process(delta: float) -> void:
	# 1. Suivi du joueur / de la caméra locale
	if follow_player:
		_follow_target(delta)

	# 2. Oscillation douce et aléatoire du vent sur X et Z
	if wind_enabled and rain_particles != null:
		_apply_wind(delta)

func _follow_target(delta: float) -> void:
	var target_pos = _get_target_position()
	if target_pos == Vector3.ZERO and not is_inside_tree():
		return

	# Si la cible est encore notre propre position (aucun joueur ni caméra encore apparu), on patiente
	if target_pos == global_position:
		return

	# Premier snap instantané sur le joueur dès qu'il apparaît
	if _is_first_follow:
		global_position.x = target_pos.x
		global_position.z = target_pos.z
		if follow_y:
			global_position.y = target_pos.y + height_offset
		_is_first_follow = false
		return

	if follow_smoothness <= 0.0:
		global_position.x = target_pos.x
		global_position.z = target_pos.z
		if follow_y:
			global_position.y = target_pos.y + height_offset
	else:
		var weight = clampf(delta * follow_smoothness, 0.0, 1.0)
		global_position.x = lerpf(global_position.x, target_pos.x, weight)
		global_position.z = lerpf(global_position.z, target_pos.z, weight)
		if follow_y:
			global_position.y = lerpf(global_position.y, target_pos.y + height_offset, weight)

func _get_target_position() -> Vector3:
	# 1. Caméra active du Viewport
	var vp = get_viewport()
	if vp != null:
		var cam = vp.get_camera_3d()
		if cam != null and is_instance_valid(cam):
			return cam.global_position

	# 2. Joueur local dans le groupe "Player"
	if is_inside_tree() and get_tree() != null:
		var players = get_tree().get_nodes_in_group("Player")
		for p in players:
			if is_instance_valid(p) and p is Node3D:
				if p.has_method("is_multiplayer_authority"):
					if p.is_multiplayer_authority():
						return p.global_position
				else:
					return p.global_position

	return global_position

var _wind_timer: float = 0.0

func _apply_wind(delta: float) -> void:
	_wind_timer += delta
	# Throttling à 15 Hz (suffisant pour une brise fluide sans réécrire les uniforms GPU à chaque frame)
	if _wind_timer < 0.066:
		return
	_wind_timer = 0.0
	
	var mat = rain_particles.process_material as ParticleProcessMaterial
	if mat == null:
		return

	# Récupération de la gravité synchronisée avec la direction et la force du vent global
	var wind_singleton = get_node_or_null("/root/Wind")
	if wind_singleton != null and wind_singleton.has_method("get_rain_gravity"):
		mat.gravity = wind_singleton.get_rain_gravity(base_gravity_y)
	elif _noise != null:
		# Fallback local autonome
		_time += delta * wind_change_speed
		var wind_x = _noise.get_noise_1d(_time * 100.0) * max_wind
		var wind_z = _noise.get_noise_1d((_time * 100.0) + 10000.0) * max_wind
		mat.gravity = Vector3(wind_x, base_gravity_y, wind_z)
