class_name ChestSpawner
extends Node3D

@export var chest_scene: PackedScene = preload("res://objet/chest/chest.tscn")
@export_range(0.0, 100.0) var spawn_chance: float = 100.0

func _ready() -> void:
	# Tente de trouver le SmartSpawner immédiatement
	var spawners = get_tree().get_nodes_in_group("SmartSpawner")
	if not spawners.is_empty():
		spawners[0].wave_completed.connect(_on_wave_completed)
	else:
		# S'il n'est pas encore là (ex: instancié plus tard), on écoute l'arbre
		get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is SmartSpawner:
		if not node.wave_completed.is_connected(_on_wave_completed):
			node.wave_completed.connect(_on_wave_completed)

func _on_wave_completed(wave_number: int) -> void:
	if chest_scene == null: return
	
	# Tirage au sort : est-ce que le coffre apparaît ?
	if randf() * 100.0 > spawn_chance:
		return # Pas de chance cette fois !
	
	# Instancier le coffre
	var chest = chest_scene.instantiate() as Node3D
	
	# L'ajouter au monde (au parent du spawner pour qu'il soit bien placé dans la scène globale)
	var world = get_parent()
	if world != null:
		world.add_child(chest)
		# Positionner le coffre exactement à la position du spawner
		chest.global_position = self.global_position
		chest.global_rotation = self.global_rotation
