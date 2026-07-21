class_name CombatFeedbackComponent
extends Node

@export var damage_text_scene: PackedScene # Tu glisseras damage_text.tscn ici
@export var health_component: HealthComponent
@export var spawn_height: float = 1.0 # La hauteur d'apparition
@export var custom_hit_sound: AudioStream # Optionnel : Glisser un fichier .wav / .ogg

func _ready() -> void:
	if health_component != null:
		health_component.damage_taken.connect(_on_damage_taken)
	else:
		push_warning("CombatFeedbackComponent sur " + get_parent().name + " : Pas de HealthComponent assigné !")

func _on_damage_taken(amount: float) -> void:
	# Joue le son d'impact 3D avec variation de pitch
	if get_parent() is Node3D:
		SoundManager.play_hit_sound(self, get_parent().global_position, custom_hit_sound)

	if damage_text_scene != null:
		var text_instance = damage_text_scene.instantiate()
		
		# On attache le texte à la racine du jeu pour ne pas qu'il recule 
		# en même temps que le monstre subit le knockback !
		get_tree().root.add_child(text_instance)
		text_instance.global_position = get_parent().global_position + Vector3(0, spawn_height, 0)
		
		if text_instance.has_method("animate"):
			text_instance.animate(amount)
