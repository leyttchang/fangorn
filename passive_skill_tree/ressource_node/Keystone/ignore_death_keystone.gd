extends Node

var player: Node3D
var health_comp: HealthComponent

func _ready() -> void:
	player = get_parent().get_parent()
	health_comp = player.get_node_or_null("%HealthComponent")
	if health_comp == null:
		health_comp = player.get_node_or_null("HealthComponent")
		
	if health_comp != null:
		health_comp.has_cheat_death = true

func _exit_tree() -> void:
	if health_comp != null:
		health_comp.has_cheat_death = false
