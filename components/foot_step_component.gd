class_name FootstepComponent
extends Node3D

## Le CharacterBody3D auquel ce composant est rattaché (auto-détecté si laissé vide)
@export var character_body: CharacterBody3D

## Liste des sons de pas. Un son sera choisi au hasard à chaque pas.
@export var footstep_sounds: Array[AudioStream] = []

## Distance en mètres à parcourir au sol entre deux sons de pas
@export var step_interval: float = 2.5

## Vitesse minimale (en m/s) à partir de laquelle les sons de pas se déclenchent
@export var min_speed_threshold: float = 0.5

## Volume sonore des bruits de pas (en dB, ex: -16.0 pour normal, 0.0 pour fort, -30.0 pour faible)
@export_range(-80.0, 24.0, 0.5) var volume_db: float = -16.0

## Variation aléatoire de la hauteur/pitch du son (min et max)
@export_range(0.1, 3.0, 0.05) var pitch_min: float = 0.85
@export_range(0.1, 3.0, 0.05) var pitch_max: float = 1.15

## Distance maximale d'écoute du son en 3D (en mètres)
@export var max_distance: float = 15.0

var _accumulated_distance: float = 0.0

func _ready() -> void:
	if character_body == null:
		character_body = get_parent() as CharacterBody3D

func _physics_process(delta: float) -> void:
	if character_body == null:
		return

	# Ne jouer les bruits de pas que si le personnage est au sol
	if not character_body.is_on_floor():
		_accumulated_distance = 0.0
		return

	# Récupération de la vélocité horizontale (axes X et Z)
	var horizontal_velocity = Vector2(character_body.velocity.x, character_body.velocity.z)
	var current_speed = horizontal_velocity.length()

	# Vitesse proportionnelle : la distance s'accumule proportionnellement à la vitesse
	if current_speed > min_speed_threshold:
		_accumulated_distance += current_speed * delta
		if _accumulated_distance >= step_interval:
			_accumulated_distance = 0.0
			_play_random_footstep()
	else:
		_accumulated_distance = 0.0

func _play_random_footstep() -> void:
	var sound_to_play: AudioStream = null
	if not footstep_sounds.is_empty():
		sound_to_play = footstep_sounds.pick_random()

	# Utilisation du SoundManager avec les réglages de volume, pitch et portée 3D
	SoundManager.play_footstep_sound(self, global_position, sound_to_play, volume_db, pitch_min, pitch_max, max_distance)
