class_name CombatFeedbackComponent
extends Node

@export var damage_text_scene: PackedScene # Tu glisseras damage_text.tscn ici
@export var health_component: HealthComponent
@export var spawn_height: float = 1.0 # La hauteur d'apparition
@export var play_impact_sound: bool = true ## Décocher si un HurtSoundComponent gère déjà les sons de dégâts

## Liste de sons d'impact personnalisés. Un son sera choisi au hasard à chaque coup reçu.
@export var hit_sounds: Array[AudioStream] = []

## Optionnel : Un fichier son d'impact unique (conservation pour rétrocompatibilité)
@export var custom_hit_sound: AudioStream

## Volume sonore des bruits d'impact (en dB)
@export_range(-80.0, 24.0, 0.5) var volume_db: float = 0.0

## Variation aléatoire de la hauteur/pitch du son (min et max)
@export_range(0.1, 3.0, 0.05) var pitch_min: float = 0.88
@export_range(0.1, 3.0, 0.05) var pitch_max: float = 1.12

## Distance maximale d'écoute du son en 3D (en mètres)
@export var max_distance: float = 40.0

func _ready() -> void:
	if health_component != null:
		health_component.damage_taken.connect(_on_damage_taken)
	else:
		push_warning("CombatFeedbackComponent sur " + get_parent().name + " : Pas de HealthComponent assigné !")

func _on_damage_taken(amount: float) -> void:
	# Joue le son d'impact 3D uniquement si activé
	if play_impact_sound and get_parent() is Node3D:
		var sound_to_play: AudioStream = null
		if not hit_sounds.is_empty():
			sound_to_play = hit_sounds.pick_random()
		elif custom_hit_sound != null:
			sound_to_play = custom_hit_sound
			
		SoundManager.play_hit_sound(self, get_parent().global_position, sound_to_play, volume_db, pitch_min, pitch_max, max_distance)

	if damage_text_scene != null:
		var text_instance = damage_text_scene.instantiate()
		
		# On attache le texte à la racine du jeu pour ne pas qu'il recule 
		# en même temps que le monstre subit le knockback !
		get_tree().root.add_child(text_instance)
		text_instance.global_position = get_parent().global_position + Vector3(0, spawn_height, 0)
		
		if text_instance.has_method("animate"):
			text_instance.animate(amount)
