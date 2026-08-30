class_name InteractionComponent
extends Area3D

## Le texte d'interaction affiche au dessus de l'objet
@export var prompt_text: String = "Press E to interact"

## La touche d'interaction
@export var interaction_key: Key = KEY_E

@onready var prompt_label: Label3D = $Label3D if has_node("Label3D") else null

func _ready() -> void:
	if prompt_label != null:
		prompt_label.text = prompt_text
		prompt_label.hide()
		prompt_label.top_level = true # Detache le label pour ignorer la rotation du parent (RigidBody)

func _process(_delta: float) -> void:
	if prompt_label != null and prompt_label.visible:
		# On le maintient toujours strictement au-dessus, peu importe comment le parent tourne
		# En Godot 4, scale s'utilise plutot que global_scale s'il n'y a pas d'heritage de scale complexe
		prompt_label.global_position = global_position + Vector3(0, 1.5 * scale.y, 0)

func show_prompt() -> void:
	if prompt_label != null:
		prompt_label.text = prompt_text
		prompt_label.show()

func hide_prompt() -> void:
	if prompt_label != null:
		prompt_label.hide()

func trigger_interaction(player: Node3D) -> void:
	var parent = get_parent()
	if parent != null:
		if parent.has_method("use"):
			parent.use(player)
		elif parent.has_method("interact"):
			parent.interact(player)
		elif parent.has_method("open_chest"):
			parent.player_in_range = player
			parent.open_chest()
