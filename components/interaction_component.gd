class_name InteractionComponent
extends Area3D

## Le texte d'interaction affiché au dessus de l'objet
@export var prompt_text: String = "Appuyez sur E pour interagir"

## La touche d'interaction (par défaut KEY_E)
@export var interaction_key: Key = KEY_E

@onready var prompt_label: Label3D = $Label3D if has_node("Label3D") else null

func _ready() -> void:
	if prompt_label != null:
		prompt_label.text = prompt_text
		prompt_label.hide()

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
