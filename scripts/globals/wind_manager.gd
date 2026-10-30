class_name WindManager
extends Node

## Gestionnaire Global du Vent (Wind Manager - Autoload 'Wind')
## Centralise la direction, l'intensité et l'évolution temporelle du vent
## pour synchroniser parfaitement l'herbe, les arbres, la pluie et tout l'environnement.

signal wind_updated(direction: Vector2, strength: float, speed: float)

@export_category("Paramètres Actuels du Vent")
## Direction 2D unifiée du vent (X, Z dans le monde)
@export var current_wind_direction: Vector2 = Vector2(1.0, 0.5).normalized()
## Force du vent pour les shaders (amplitude d'inclinaison)
@export var current_wind_strength: float = 0.15
## Vitesse de défilement de l'onde de vent
@export var current_wind_speed: float = 2.0
## Force horizontale appliquée à la pluie (en m/s²)
@export var current_rain_wind_force: float = 3.0

@export_category("Progression Tempête (0 à 15 min)")
## Intensité de la tempête (0.0 = beau temps / 0-5 min, 1.0 = tempête maximale / 15 min)
@export_range(0.0, 1.0, 0.01) var storm_intensity: float = 0.0:
	set(val):
		storm_intensity = clampf(val, 0.0, 1.0)

# Paramètres au calme (début de partie : très peu de vent)
@export var calm_wind_strength: float = 0.08
@export var calm_wind_speed: float = 1.4
@export var calm_rain_force: float = 2.0

# Paramètres en pleine tempête (15 minutes : vent violent mais pluie qui atteint bien le joueur)
@export var storm_wind_strength: float = 1.15
@export var storm_wind_speed: float = 4.2
@export var storm_rain_force: float = 10.0

@export_category("Dynamique des Bourrasques et Accalmies")
## Durée minimale d'une accalmie brève (en secondes, 1 à 2s)
@export var lull_min_duration: float = 1.0
## Durée maximale d'une accalmie brève (en secondes, max 3s)
@export var lull_max_duration: float = 2.5
## Force minimale du vent pendant l'accalmie (brise légère)
@export var lull_wind_strength: float = 0.15
## Durée minimale d'une bourrasque forte (en secondes, 90% du temps au max)
@export var blast_min_duration: float = 18.0
## Durée maximale d'une bourrasque forte (en secondes, 90% du temps au max)
@export var blast_max_duration: float = 28.0

@export_category("Changements de Direction")
## Intervalle minimal entre deux changements de cap (en secondes, aléatoire entre 10 et 20s)
@export var shift_min_interval: float = 10.0
## Intervalle maximal entre deux changements de cap (en secondes, aléatoire entre 10 et 20s)
@export var shift_max_interval: float = 20.0
## Vitesse de pivot lors d'un coup de vent (environ 1.0 à 1.5s pour pivoter)
@export var direction_turn_speed: float = 2.8

# Variables internes pour le bruit Simplex fluide
var _noise: FastNoiseLite
var _time: float = 0.0
var _update_timer: float = 0.0
var _wind_time: float = 0.0
var _wind_scroll: Vector2 = Vector2.ZERO
var _tree_wind_time: float = 0.0
var _tree_wind_scroll: Vector2 = Vector2.ZERO
var _tree_strength_current: float = 0.08
var _tree_strength_vel: float = 0.0
var _tree_angle_current: float = 0.65
var _tree_angle_vel: float = 0.0
var _tree_wind_direction: Vector2 = Vector2(1.0, 0.5).normalized()
var _grass_materials: Array[WeakRef] = []

# Gestion de la direction et des virements
var _current_target_angle: float = 0.65
var _current_actual_angle: float = 0.65
var _shift_timer: float = 0.0
var _next_shift_duration: float = 14.0
var _consecutive_turns: int = 0

# Gestion du cycle bourrasque / accalmie
var _cycle_timer: float = 0.0
var _is_in_lull: bool = false
var _current_phase_duration: float = 22.0
var _lull_blend: float = 0.0

func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.02
	_noise.seed = randi()
	
	_next_shift_duration = randf_range(shift_min_interval, shift_max_interval)
	_current_phase_duration = randf_range(blast_min_duration, blast_max_duration)
	
	# Auto-détection du matériau d'herbe du projet
	var default_mesh = load("res://assets/3D_models/grass/grass2.res") as ArrayMesh
	if default_mesh != null and default_mesh.get_surface_count() > 0:
		var mat = default_mesh.surface_get_material(0)
		if mat is ShaderMaterial:
			register_grass_material(mat)
			
	# Auto-détection du matériau des arbres du projet
	var tree_mat = load("res://objet/tree/tree_material.tres") as ShaderMaterial
	if tree_mat != null:
		register_grass_material(tree_mat)

## Enregistre un matériau d'herbe pour qu'il reçoive les mises à jour automatiques du vent
func register_grass_material(mat: ShaderMaterial) -> void:
	if mat == null: return
	for ref in _grass_materials:
		if ref.get_ref() == mat:
			return
	_grass_materials.append(weakref(mat))
	_update_single_grass_material(mat)

## Définit le ratio de progression météo (appelé par timer_sys.gd de 0.0 à 1.0)
func set_storm_progress(progress: float) -> void:
	storm_intensity = clampf(progress, 0.0, 1.0)

## Calcule la gravité 3D complète pour les particules de pluie (alignée avec le vent)
func get_rain_gravity(base_gravity_y: float = -14.0) -> Vector3:
	return Vector3(
		current_wind_direction.x * current_rain_wind_force,
		base_gravity_y,
		current_wind_direction.y * current_rain_wind_force
	)

func _process(delta: float) -> void:
	_time += delta * 0.15 # Vitesse d'évolution lente et organique de la météo
	
	# Facteur de chaos de tempête :
	# Inactif au début (0-7 min), monte progressivement à partir de 8-10 min (storm_intensity >= 0.35)
	# À 15 min (ou si debug_max_wind est coché), chaos_factor = 1.0
	var chaos_factor: float = clampf((storm_intensity - 0.35) / 0.65, 0.0, 1.0)
	
	# -------------------------------------------------------------
	# 1. ÉVOLUTION DE LA DIRECTION DU VENT
	# -------------------------------------------------------------
	if chaos_factor <= 0.001:
		# Début de partie (0-7 min) : dérive douce et lente autour de 0.65 rad (+/- 35°)
		var base_angle: float = 0.65
		var angle_variation: float = _noise.get_noise_1d(_time * 8.0) * 0.6
		_current_target_angle = base_angle + angle_variation
		_current_actual_angle = lerp_angle(_current_actual_angle, _current_target_angle, delta * 1.5)
	else:
		# Mode tempête chaotique : paliers aléatoires entre 10 et 20s, virages francs et 180° réguliers
		_shift_timer += delta
		
		if _shift_timer >= _next_shift_duration:
			_shift_timer = 0.0
			_next_shift_duration = randf_range(shift_min_interval, shift_max_interval)
			
			# Décision : virage 180° (demi-tour) ou changement de cap franc (80° à 120°)
			# Garantit un 180° au moins tous les 2 à 3 changements (~20 à 40 secondes max)
			var is_reversal: bool = false
			if _consecutive_turns >= 2 or (_consecutive_turns >= 1 and randf() < 0.55):
				is_reversal = true
				_consecutive_turns = 0
			else:
				_consecutive_turns += 1
				
			if is_reversal:
				# RETOURNEMENT COMPLET (150° à 180°) : l'herbe se couche dans la direction opposée !
				var sign_flip = 1.0 if randf() > 0.5 else -1.0
				var flip_angle = deg_to_rad(randf_range(150.0, 180.0)) * sign_flip
				_current_target_angle = wrapf(_current_target_angle + flip_angle, -PI, PI)
			else:
				# CHANGEMENT DE CAP FRANC (80° à 120°) : virage latéral bien net
				var sign_turn = 1.0 if randf() > 0.5 else -1.0
				var turn_angle = deg_to_rad(randf_range(80.0, 120.0)) * sign_turn
				_current_target_angle = wrapf(_current_target_angle + turn_angle, -PI, PI)
				
		# Micro-turbulences dans la direction
		var micro_wobble = _noise.get_noise_1d(_time * 15.0) * 0.12 * chaos_factor
		
		# Virement dynamique et franc (environ 1.0 à 1.5s pour pivoter de manière spectaculaire)
		var turn_speed = direction_turn_speed * (0.8 + 0.4 * chaos_factor)
		_current_actual_angle = lerp_angle(_current_actual_angle, _current_target_angle + micro_wobble, delta * turn_speed)

	current_wind_direction = Vector2(cos(_current_actual_angle), sin(_current_actual_angle)).normalized()
	
	# -------------------------------------------------------------
	# 2. CYCLE D'INTENSITÉ : BOURRASQUE (90% du temps) vs ACCALMIE (1-2s, max 3s)
	# -------------------------------------------------------------
	if chaos_factor > 0.001:
		_cycle_timer += delta
		if not _is_in_lull:
			# En pleine bourrasque (dure 18 à 28s)
			if _cycle_timer >= _current_phase_duration:
				_is_in_lull = true
				_cycle_timer = 0.0
				_current_phase_duration = randf_range(lull_min_duration, lull_max_duration)
		else:
			# En accalmie brève (dure 1 à 2.5s, max 3s)
			if _cycle_timer >= _current_phase_duration:
				_is_in_lull = false
				_cycle_timer = 0.0
				_current_phase_duration = randf_range(blast_min_duration, blast_max_duration)
				
	var target_lull = 1.0 if (_is_in_lull and chaos_factor > 0.0) else 0.0
	# Transition : descente douce vers l'accalmie (delta * 3.5), mais retour TRÈS RAPIDE au max (delta * 8.0)
	var blend_speed = 3.5 if target_lull > _lull_blend else 8.0
	_lull_blend = lerpf(_lull_blend, target_lull, delta * blend_speed)
	
	# 3. Rafales légères pendant la bourrasque (maintient le vent au max avec pointes)
	var gust_noise: float = (_noise.get_noise_1d(_time * 25.0 + 500.0) + 1.0) * 0.5
	var gust_mult: float = lerpf(0.98, 1.15 + 0.10 * storm_intensity, gust_noise)
	
	# 4. Intensité maximale selon le timer (10 min vs 15 min ont des max différents)
	var peak_strength = lerpf(calm_wind_strength, storm_wind_strength, storm_intensity) * gust_mult
	var current_lull_strength = lerpf(calm_wind_strength, lull_wind_strength, storm_intensity)
	var target_strength = lerpf(peak_strength, current_lull_strength, _lull_blend * chaos_factor)
	
	var peak_speed = lerpf(calm_wind_speed, storm_wind_speed, storm_intensity)
	var current_lull_speed = lerpf(calm_wind_speed, calm_wind_speed * 1.3, storm_intensity)
	var target_speed = lerpf(peak_speed, current_lull_speed, _lull_blend * chaos_factor)
	
	var peak_rain = lerpf(calm_rain_force, storm_rain_force, storm_intensity) * gust_mult
	var current_lull_rain = lerpf(calm_rain_force, calm_rain_force * 1.5, storm_intensity)
	var target_rain_force = lerpf(peak_rain, current_lull_rain, _lull_blend * chaos_factor)
	
	# Application vive et réactive pour claquer immédiatement au max après l'accalmie
	var strength_lerp_speed = 3.5 if _is_in_lull else 6.0
	current_wind_strength = lerpf(current_wind_strength, target_strength, delta * strength_lerp_speed)
	current_wind_speed = lerpf(current_wind_speed, target_speed, delta * strength_lerp_speed)
	current_rain_wind_force = lerpf(current_rain_wind_force, target_rain_force, delta * strength_lerp_speed)
	
	# 5. Phase et défilement INTÉGRÉS : évite tout saut d'onde dans les shaders
	_wind_time += delta * current_wind_speed
	_wind_scroll += current_wind_direction * (delta * current_wind_speed)
	
	# Vitesse maîtrisée et inertie progressive pour les arbres (évite tout à-coup lors des bourrasques)
	var speed_t: float = clampf((current_wind_speed - calm_wind_speed) / maxf(0.01, storm_wind_speed - calm_wind_speed), 0.0, 1.0)
	var tree_eff_speed: float = calm_wind_speed * lerpf(1.0, 1.5, speed_t)
	_tree_wind_time += delta * tree_eff_speed
	
	# Inertie du second ordre sur la force du vent des arbres :
	# Démarre progressivement (pas d'à-coup à t=0), maintient une vitesse soutenue, puis s'amortit
	var strength_diff: float = target_strength - _tree_strength_current
	var desired_strength_vel: float = clampf(strength_diff * 1.8, -0.75, 0.85)
	_tree_strength_vel = move_toward(_tree_strength_vel, desired_strength_vel, delta * 1.4)
	_tree_strength_current = clampf(_tree_strength_current + _tree_strength_vel * delta, 0.0, 2.0)
	
	# Inertie du second ordre sur la direction du vent des arbres :
	var angle_diff: float = wrapf(_current_actual_angle - _tree_angle_current, -PI, PI)
	var desired_angle_vel: float = clampf(angle_diff * 1.6, -1.2, 1.2)
	_tree_angle_vel = move_toward(_tree_angle_vel, desired_angle_vel, delta * 1.8)
	_tree_angle_current = wrapf(_tree_angle_current + _tree_angle_vel * delta, -PI, PI)
	_tree_wind_direction = Vector2(cos(_tree_angle_current), sin(_tree_angle_current)).normalized()
	
	_tree_wind_scroll += _tree_wind_direction * (delta * tree_eff_speed)
	
	# 6. Envoi aux shaders et signaux
	_update_grass_materials()
	_update_timer += delta
	if _update_timer >= 0.066:
		_update_timer = 0.0
		wind_updated.emit(current_wind_direction, current_wind_strength, current_wind_speed)

func _update_grass_materials() -> void:
	for i in range(_grass_materials.size() - 1, -1, -1):
		var mat = _grass_materials[i].get_ref() as ShaderMaterial
		if mat == null:
			_grass_materials.remove_at(i)
		else:
			_update_single_grass_material(mat)

func _update_single_grass_material(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("wind_direction", current_wind_direction)
	mat.set_shader_parameter("wind_strength", current_wind_strength)
	mat.set_shader_parameter("wind_speed", current_wind_speed)
	mat.set_shader_parameter("wind_time", _wind_time)
	mat.set_shader_parameter("wind_scroll", _wind_scroll)
	mat.set_shader_parameter("tree_wind_direction", _tree_wind_direction)
	mat.set_shader_parameter("tree_wind_strength", _tree_strength_current)
	mat.set_shader_parameter("tree_wind_time", _tree_wind_time)
	mat.set_shader_parameter("tree_wind_scroll", _tree_wind_scroll)
