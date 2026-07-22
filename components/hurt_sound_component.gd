class_name HurtSoundComponent
extends Node3D

## Le HealthComponent à écouter (auto-détecté sur le parent si laissé vide)
@export var health_component: HealthComponent

## Liste de sons de blessure. Un son sera choisi au hasard à chaque fois que l'entité subit des dégâts.
@export var hurt_sounds: Array[AudioStream] = []

## Temps minimum (en secondes) entre deux sons de blessure (ex: 0.5s = 2 fois par seconde max)
@export var min_interval: float = 0.5

## Volume sonore des bruits de blessure (en dB)
@export_range(-80.0, 24.0, 0.5) var volume_db: float = 0.0

## Variation aléatoire de la hauteur/pitch du son (min et max)
@export_range(0.1, 3.0, 0.05) var pitch_min: float = 0.88
@export_range(0.1, 3.0, 0.05) var pitch_max: float = 1.12

## Distance maximale d'écoute du son en 3D (en mètres)
@export var max_distance: float = 30.0

var _last_play_time: float = -999.0

func _ready() -> void:
	if health_component == null:
		if get_parent() != null:
			health_component = get_parent().get_node_or_null("HealthComponent") as HealthComponent

	if health_component != null:
		health_component.damage_taken.connect(_on_damage_taken)
	else:
		push_warning("HurtSoundComponent sur " + get_parent().name + " : Aucun HealthComponent trouvé !")

func _on_damage_taken(_amount: float) -> void:
	if hurt_sounds.is_empty():
		return

	# Vérification du cooldown / intervalle minimum entre deux sons
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - _last_play_time < min_interval:
		return

	var sound_to_play = hurt_sounds.pick_random()
	if sound_to_play != null:
		_last_play_time = current_time
		SoundManager.play_hit_sound(self, global_position, sound_to_play, volume_db, pitch_min, pitch_max, max_distance)
