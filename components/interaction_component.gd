class_name InteractionComponent
extends Area3D

## Le texte d'interaction affiché au dessus de l'objet
@export var prompt_text: String = "Appuyez sur E pour interagir"

## La touche d'interaction (par défaut KEY_E)
@export var interaction_key: Key = KEY_E

var player_in_range: CharacterBody3D = null

@onready var prompt_label: Label3D = $Label3D if has_node("Label3D") else null

func _ready() -> void:
	if prompt_label != null:
		prompt_label.text = prompt_text
		prompt_label.hide()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range != null:
		if event is InputEventKey and event.physical_keycode == interaction_key and event.pressed:
			_trigger_parent_use()

func _trigger_parent_use() -> void:
	var parent = get_parent()
	if parent != null:
		if parent.has_method("use"):
			parent.use(player_in_range)
		elif parent.has_method("interact"):
			parent.interact(player_in_range)
		elif parent.has_method("open_chest"):
			parent.player_in_range = player_in_range
			parent.open_chest()

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		player_in_range = body as CharacterBody3D
		if prompt_label != null:
			prompt_label.text = prompt_text
			prompt_label.show()

func _on_body_exited(body: Node3D) -> void:
	if body == player_in_range:
		player_in_range = null
		if prompt_label != null:
			prompt_label.hide()
