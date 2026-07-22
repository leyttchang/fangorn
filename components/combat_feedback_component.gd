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

# NOUVEAU : Limite stricte de textes par frame pour les AoE
static var _texts_spawned_this_frame: int = 0
static var _frame_reset_active: bool = false

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
		var pos = get_parent().global_position + Vector3(0, spawn_height, 0)
		CombatFeedbackComponent.request_damage_text(damage_text_scene, pos, amount, get_tree())

static func request_damage_text(scene: PackedScene, pos: Vector3, amount: float, tree: SceneTree) -> void:
	if _texts_spawned_this_frame >= 2:
		return # On ignore les textes excǸdentaires cette frame !
		
	_texts_spawned_this_frame += 1
	
	var text_instance = scene.instantiate()
	tree.root.add_child(text_instance)
	text_instance.global_position = pos
	if text_instance.has_method("animate"):
		text_instance.animate(amount)
		
	if not _frame_reset_active and tree != null:
		_reset_counter_next_frame(tree)

static func _reset_counter_next_frame(tree: SceneTree) -> void:
	_frame_reset_active = true
	await tree.process_frame
	_texts_spawned_this_frame = 0
	_frame_reset_active = false
