class_name WindManager
extends Node

## Gestionnaire Global du Vent (Wind Manager - Autoload 'Wind')
## Centralise la direction, l'intensité et l'évolution temporelle du vent
## pour synchroniser parfaitement l'herbe, la pluie et tout l'environnement.

signal wind_updated(direction: Vector2, strength: float, speed: float)

@export_category("Paramètres Actuels du Vent")
## Direction 2D unifiée du vent (X, Z dans le monde)
@export var current_wind_direction: Vector2 = Vector2(1.0, 0.5).normalized()
## Force du vent pour le shader d'herbe (amplitude d'inclinaison)
@export var current_wind_strength: float = 0.15
## Vitesse de défilement de l'onde de vent
@export var current_wind_speed: float = 2.0
## Force horizontale appliquée à la pluie (en m/s²)
@export var current_rain_wind_force: float = 15.0

@export_category("Progression Tempête (0 à 15 min)")
## Intensité de la tempête (0.0 = beau temps / 0-5 min, 1.0 = tempête maximale / 15 min)
@export_range(0.0, 1.0, 0.01) var storm_intensity: float = 0.0:
	set(val):
		storm_intensity = clampf(val, 0.0, 1.0)

# Paramètres au calme (début de partie : très peu de vent)
@export var calm_wind_strength: float = 0.05
@export var calm_wind_speed: float = 1.3
@export var calm_rain_force: float = 6.0

# Paramètres en pleine tempête (15 minutes : énormément de vent)
@export var storm_wind_strength: float = 1.1
@export var storm_wind_speed: float = 4.2
@export var storm_rain_force: float = 55.0

# Variables internes pour le bruit Simplex fluide
var _noise: FastNoiseLite
var _time: float = 0.0
var _update_timer: float = 0.0
var _wind_time: float = 0.0
var _wind_scroll: Vector2 = Vector2.ZERO
var _grass_materials: Array[WeakRef] = []

func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.02
	_noise.seed = randi()
	
	# Tentative d'auto-détection du matériau d'herbe du projet
	var default_mesh = load("res://assets/3D_models/grass/grass2.res") as ArrayMesh
	if default_mesh != null and default_mesh.get_surface_count() > 0:
		var mat = default_mesh.surface_get_material(0)
		if mat is ShaderMaterial:
			register_grass_material(mat)

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
	
	# 1. Évolution douce et naturelle de la direction du vent :
	# Direction générale Sud-Est (~0.65 rad) avec une dérive douce de +/- 65°
	var base_angle: float = 0.65
	var angle_variation: float = _noise.get_noise_1d(_time * 10.0) * 1.15
	var final_angle: float = base_angle + angle_variation
	current_wind_direction = Vector2(cos(final_angle), sin(final_angle)).normalized()
	
	# 2. Rafales et bourrasques naturelles (fluctuation d'amplitude)
	var gust_noise: float = (_noise.get_noise_1d(_time * 25.0 + 500.0) + 1.0) * 0.5
	var gust_mult: float = lerpf(0.9, 1.15 + 0.5 * storm_intensity, gust_noise)
	
	# 3. Interpolation selon la progression météo (0 à 15 min)
	var target_strength = lerpf(calm_wind_strength, storm_wind_strength, storm_intensity) * gust_mult
	var target_speed = lerpf(calm_wind_speed, storm_wind_speed, storm_intensity)
	var target_rain_force = lerpf(calm_rain_force, storm_rain_force, storm_intensity) * gust_mult
	
	current_wind_strength = lerpf(current_wind_strength, target_strength, delta * 3.0)
	current_wind_speed = lerpf(current_wind_speed, target_speed, delta * 3.0)
	current_rain_wind_force = lerpf(current_rain_wind_force, target_rain_force, delta * 3.0)
	
	# 4. Phase et défilement INTÉGRÉS : si la vitesse ou la direction changent, la phase des ondes
	# continue sans saut (sinon TIME * vitesse fait "sauter" les vagues => herbe qui tremble/saccade).
	_wind_time += delta * current_wind_speed
	_wind_scroll += current_wind_direction * (delta * current_wind_speed)
	
	# 5. Envoi aux shaders CHAQUE frame (1 seul matériau : coût négligeable, évite les paliers visibles)
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
