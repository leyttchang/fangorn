@tool
extends Node3D

## Gestionnaire de progression temporelle et météo (Timer Système)
## - 0 à 5 minutes : Jour normal par défaut (pas de pluie)
## - À 5 minutes : Début de la pluie à 500 particules
## - 5 à 15 minutes : Montée progressive jusqu'à 10 000 particules

signal rain_started
signal rain_max_reached

@export_category("Configuration du Timer Météo")
## Active le système de timer météo
@export var timer_enabled: bool = true

## Temps écoulé en secondes depuis le début de la partie (modifiable pour tester)
@export var elapsed_time: float = 0.0

## Vitesse d'écoulement du temps (1.0 = temps réel, ex: 10.0 pour tester 10x plus vite)
@export var time_scale: float = 1.0

@export_group("Paliers de Pluie")
## Moment où la pluie commence (en secondes, 5 minutes = 300.0)
@export var rain_start_time: float = 300.0

## Moment où la pluie atteint son maximum (en secondes, 15 minutes = 900.0)
@export var rain_max_time: float = 900.0

## Nombre de particules au démarrage de la pluie (à 5 min)
@export var min_rain_particles: int = 500

## Nombre maximal de particules de pluie (à 15 min)
@export var max_rain_particles: int = 10000

@export_group("Progression du Vent")
## Le vent reste très faible jusqu'à ce moment (en secondes, 1 minute = 60.0)
@export var wind_start_time: float = 60.0
## Le vent atteint son maximum à ce moment (en secondes, 15 minutes = 900.0)
@export var wind_max_time: float = 900.0
## Courbe de montée : 1.0 = linéaire, >1.0 = monte doucement puis s'accélère vers la fin
@export_range(1.0, 3.0, 0.1) var wind_curve_power: float = 1.6
## DEBUG : force le vent au maximum dès le début de la partie (désactiver pour retrouver la progression normale)
@export var debug_max_wind: bool = true

@export_group("Références")
## Nœud de pluie dans la scène (détecté automatiquement si non renseigné)
@export var rain_node: Node3D

var _rain_particles: GPUParticles3D = null
var _rain_has_started: bool = false
var _rain_has_peaked: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	_resolve_references()
	_update_wind()
	_update_weather(true)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not timer_enabled:
		return

	elapsed_time += delta * time_scale
	_update_wind()
	_update_weather(false)

## Progression du vent : très faible jusqu'à wind_start_time, puis montée en courbe jusqu'à wind_max_time
func _update_wind() -> void:
	var wind_node = get_node_or_null("/root/Wind")
	if wind_node == null or not wind_node.has_method("set_storm_progress"):
		return
	var span: float = maxf(1.0, wind_max_time - wind_start_time)
	var linear: float = clampf((elapsed_time - wind_start_time) / span, 0.0, 1.0)
	wind_node.set_storm_progress(1.0 if debug_max_wind else pow(linear, wind_curve_power))

func _resolve_references() -> void:
	if rain_node == null:
		rain_node = get_parent().get_node_or_null("rain") as Node3D
	if rain_node == null:
		rain_node = get_node_or_null("../rain") as Node3D
	if rain_node == null and is_inside_tree():
		for child in get_parent().get_children():
			if child != self and child.name.to_lower().contains("rain"):
				rain_node = child as Node3D
				break

	if rain_node != null:
		if "rain_particles" in rain_node and rain_node.rain_particles != null:
			_rain_particles = rain_node.rain_particles
		if _rain_particles == null:
			_rain_particles = rain_node.get_node_or_null("rain_P") as GPUParticles3D
		if _rain_particles == null:
			for child in rain_node.get_children():
				if child is GPUParticles3D and child.name != "spraks":
					_rain_particles = child
					break

func _update_weather(is_initial: bool = false) -> void:
	if _rain_particles == null:
		_resolve_references()
		if _rain_particles == null:
			return

	# S'assurer que le buffer est dimensionné pour accueillir le nombre maximal
	if _rain_particles.amount < max_rain_particles:
		_rain_particles.amount = max_rain_particles

	# Phase 1 : 0 à 5 minutes (Plein jour par défaut, aucune pluie)
	if elapsed_time < rain_start_time:
		if _rain_particles.emitting or is_initial:
			_rain_particles.emitting = false
			_rain_particles.amount_ratio = 0.0
			if is_initial:
				_rain_particles.restart()
		# Mise en sommeil complet du nœud de pluie et du heightfield collision
		if rain_node != null and rain_node.process_mode != Node.PROCESS_MODE_DISABLED:
			rain_node.process_mode = Node.PROCESS_MODE_DISABLED
			rain_node.visible = false
		
		_rain_has_started = false
		_rain_has_peaked = false
		return

	# Phase 2 : Déclenchement de la pluie à 5 minutes
	if rain_node != null and rain_node.process_mode == Node.PROCESS_MODE_DISABLED:
		rain_node.process_mode = Node.PROCESS_MODE_INHERIT
		rain_node.visible = true

	if not _rain_particles.emitting:
		_rain_particles.emitting = true

	if not _rain_has_started:
		_rain_has_started = true
		rain_started.emit()
		print("[TimerSys] 5 minutes : La pluie commence à %d particules." % min_rain_particles)

	# Phase 3 : Montée progressive de 500 à 10 000 particules entre 5 min et 15 min
	var progress: float = clampf((elapsed_time - rain_start_time) / (rain_max_time - rain_start_time), 0.0, 1.0)
	var current_particles: float = lerpf(float(min_rain_particles), float(max_rain_particles), progress)
	
	# Mise à jour fluide du ratio sans redémarrer le système de particules
	_rain_particles.amount_ratio = clampf(current_particles / float(max_rain_particles), 0.0, 1.0)

	if progress >= 1.0 and not _rain_has_peaked:
		_rain_has_peaked = true
		rain_max_reached.emit()
		print("[TimerSys] 15 minutes : La pluie atteint son intensité maximale (%d particules)." % max_rain_particles)

## Retourne le nombre estimé de particules actuellement émises
func get_current_particles_count() -> int:
	if _rain_particles == null or not _rain_particles.emitting:
		return 0
	return int(round(_rain_particles.amount * _rain_particles.amount_ratio))

## Retourne le temps écoulé en minutes
func get_time_in_minutes() -> float:
	return elapsed_time / 60.0

## Indique si la pluie est actuellement en train de tomber
func is_raining() -> bool:
	return _rain_particles != null and _rain_particles.emitting and _rain_particles.amount_ratio > 0.0
