extends Node3D

## Gestionnaire de pluie : Oscillation douce du vent (-30 à +30), compensation balistique de dérive et suivi du joueur/caméra

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

const HEIGHTFIELD_GRID_XZ: float = 8.0
const HEIGHTFIELD_GRID_Y: float = 4.0
const MAX_WIND_LEAD_OFFSET: float = 135.0

var _noise: FastNoiseLite
var _time: float = 0.0
var _heightfield: GPUParticlesCollisionHeightField3D = null
var _orig_hf_cull_mask: int = 4293918721
var _orig_hf_local_pos: Vector3 = Vector3(0.0, 116.11505, 0.0)
var _orig_rain_local_pos: Vector3 = Vector3(0.0, 167.88062, 0.0)
var _initial_vel_avg: float = 25.0
var _target_wind_lead_xz: Vector2 = Vector2.ZERO
var _current_wind_lead_xz: Vector2 = Vector2.ZERO

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

	# Cache de la HeightField de collision (et de son offset Y local d'origine !)
	_heightfield = get_node_or_null("GPUParticlesCollisionHeightField3D") as GPUParticlesCollisionHeightField3D
	if _heightfield == null:
		for child in get_children():
			if child is GPUParticlesCollisionHeightField3D:
				_heightfield = child
				break
	if _heightfield != null:
		_orig_hf_local_pos = _heightfield.position
		if _heightfield.cull_mask != 0:
			_orig_hf_cull_mask = _heightfield.cull_mask
		if not Engine.is_editor_hint():
			_heightfield.top_level = true

	if rain_particles != null:
		_orig_rain_local_pos = rain_particles.position
		# IMPORTANT : Les particules de pluie DOIVENT être en coordonnées globales (local_coords = false).
		# Ainsi, quand le joueur avance, il avance à travers la pluie sans emporter les gouttes dans les airs.
		rain_particles.local_coords = false
		# AABB élargi jusqu'en dessous du joueur + marge au vent pour éviter tout frustum culling intempestif
		rain_particles.visibility_aabb = AABB(Vector3(-340.0, -230.0, -340.0), Vector3(680.0, 280.0, 680.0))

		var mat := rain_particles.process_material as ParticleProcessMaterial
		if mat != null:
			if base_gravity_y == -14.0 and mat.gravity.y != 0.0:
				base_gravity_y = mat.gravity.y
			_initial_vel_avg = maxf(1.0, 0.5 * (mat.initial_velocity_min + mat.initial_velocity_max))
			# Assurer que les gouttes s'inclinent avec le vent
			mat.particle_flag_align_y = true

	visibility_changed.connect(_sync_heightfield_visibility)
	_sync_heightfield_visibility()

## Coupe le rendu orthographique 1024x1024 de la HeightField tant que la pluie est masquée (ex: 0-5 min par TimerSys)
func _sync_heightfield_visibility() -> void:
	if _heightfield == null or not is_instance_valid(_heightfield):
		return
	if is_visible_in_tree():
		_heightfield.cull_mask = _orig_hf_cull_mask
		_update_heightfield_snapped_pos()
	else:
		_heightfield.cull_mask = 0

func _update_heightfield_snapped_pos() -> void:
	if _heightfield == null or not is_instance_valid(_heightfield):
		return
	# Garde exactement la hauteur locale d'origine (+116.115m) et fige par pas de grille
	# pour éviter de rebaker la carte de collision 1024x1024 à chaque micro-mouvement
	var target_hf_pos := Vector3(
		snappedf(global_position.x, HEIGHTFIELD_GRID_XZ),
		snappedf(global_position.y, HEIGHTFIELD_GRID_Y) + _orig_hf_local_pos.y,
		snappedf(global_position.z, HEIGHTFIELD_GRID_XZ)
	)
	if not _heightfield.global_position.is_equal_approx(target_hf_pos):
		_heightfield.global_position = target_hf_pos

var _is_first_follow: bool = true

func _process(delta: float) -> void:
	# 1. Suivi du joueur / de la caméra locale
	if follow_player:
		_follow_target(delta)

	# 2. Oscillation du vent + compensation balistique en amont du vent (garde le cœur dense de la pluie pile sur le joueur !)
	if rain_particles != null:
		if wind_enabled:
			_apply_wind(delta)
		else:
			_target_wind_lead_xz = Vector2.ZERO
		_update_emitter_wind_lead(delta)

func _follow_target(delta: float) -> void:
	var target_pos := _get_target_position()
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
		_update_heightfield_snapped_pos()
		_is_first_follow = false
		return

	if follow_smoothness <= 0.0:
		global_position.x = target_pos.x
		global_position.z = target_pos.z
		if follow_y:
			global_position.y = target_pos.y + height_offset
	else:
		var weight := clampf(delta * follow_smoothness, 0.0, 1.0)
		global_position.x = lerpf(global_position.x, target_pos.x, weight)
		global_position.z = lerpf(global_position.z, target_pos.z, weight)
		if follow_y:
			global_position.y = lerpf(global_position.y, target_pos.y + height_offset, weight)

	_update_heightfield_snapped_pos()

func _get_target_position() -> Vector3:
	# 1. Caméra active du Viewport
	var vp := get_viewport()
	if vp != null:
		var cam := vp.get_camera_3d()
		if cam != null and is_instance_valid(cam):
			return cam.global_position

	# 2. Joueur local dans le groupe "Player"
	if is_inside_tree() and get_tree() != null:
		var players := get_tree().get_nodes_in_group("Player")
		for p in players:
			if is_instance_valid(p) and p is Node3D:
				if p.has_method("is_multiplayer_authority"):
					if p.is_multiplayer_authority():
						return (p as Node3D).global_position
				else:
					return (p as Node3D).global_position

	return global_position

var _wind_timer: float = 0.0

func _apply_wind(delta: float) -> void:
	_wind_timer += delta
	# Throttling à 15 Hz (suffisant pour une brise fluide sans réécrire les uniforms GPU à chaque frame)
	if _wind_timer < 0.066:
		return
	var elapsed := _wind_timer
	_wind_timer = 0.0

	var mat := rain_particles.process_material as ParticleProcessMaterial
	if mat == null:
		return

	# Récupération de la gravité synchronisée avec la direction et la force du vent global
	var grav := Vector3(0.0, base_gravity_y, 0.0)
	var wind_singleton := get_node_or_null("/root/Wind")
	if wind_singleton != null and wind_singleton.has_method("get_rain_gravity"):
		grav = wind_singleton.get_rain_gravity(base_gravity_y)
	elif _noise != null:
		# Fallback local autonome
		_time += elapsed * wind_change_speed
		var wind_x := _noise.get_noise_1d(_time * 100.0) * max_wind
		var wind_z := _noise.get_noise_1d((_time * 100.0) + 10000.0) * max_wind
		grav = Vector3(wind_x, base_gravity_y, wind_z)

	mat.gravity = grav

	# Calcul exact de la dérive horizontale pendant les ~168m de chute :
	# décale la source en amont du vent pour que le centre dense tombe toujours pile au-dessus et autour du joueur !
	var fall_h := maxf(10.0, _orig_rain_local_pos.y)
	var g_down := maxf(1.0, absf(grav.y))
	var v0 := _initial_vel_avg
	var t_fall := (-v0 + sqrt(v0 * v0 + 2.0 * g_down * fall_h)) / g_down
	var drift_factor := 0.5 * t_fall * t_fall
	_target_wind_lead_xz = Vector2(-grav.x * drift_factor, -grav.z * drift_factor).limit_length(MAX_WIND_LEAD_OFFSET)

func _update_emitter_wind_lead(delta: float) -> void:
	_current_wind_lead_xz = _current_wind_lead_xz.lerp(_target_wind_lead_xz, clampf(delta * 1.8, 0.0, 1.0))
	rain_particles.position = Vector3(
		_orig_rain_local_pos.x + _current_wind_lead_xz.x,
		_orig_rain_local_pos.y,
		_orig_rain_local_pos.z + _current_wind_lead_xz.y
	)
