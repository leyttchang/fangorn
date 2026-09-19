@tool
class_name EncountersManager
extends Node3D

@export_category("Points d'intérêt (Encounters)")

## Nombre de POI à placer sur la carte
@export var encounter_count: int = 8

## Distance minimale en mètres entre deux Encounters (évite le clustering)
@export var min_distance_between_encounters: float = 400.0

## Distance minimale en mètres entre un Encounter et les chemins principaux
@export var min_distance_from_main_roads: float = 150.0

@export_category("Spawns d'Encounters")
## Liste des scènes d'encounters possibles à piocher au hasard (ex: camp, coffre, ruine, etc.)
@export var possible_encounters: Array[PackedScene] = []

## Tourner les scènes aléatoirement sur l'axe Y
@export var randomize_rotation: bool = true

@export_category("Dégagement des Arbres")
## Rayon de sécurité (en mètres) autour de chaque encounter pour supprimer les arbres
@export var clear_trees_radius: float = 35.0

@export_category("Actions")
## Cliquer pour générer les encounters sur les points existants
@export var spawn_now: bool = false:
	set(value):
		if value:
			spawn_now = false
			spawn_encounters()

## Cliquer pour nettoyer les encounters instanciés
@export var clear_now: bool = false:
	set(value):
		if value:
			clear_now = false
			clear_encounters()

func clear_encounters() -> void:
	for child in get_children():
		if child is Marker3D:
			for subchild in child.get_children():
				subchild.queue_free()
		elif not child.name.begins_with("encounter_"):
			child.queue_free()
	print("Encounters: nettoyés.")

func spawn_encounters(encounter_seed: int = 0) -> void:
	if possible_encounters.is_empty():
		print("Encounters: Aucune scène d'encounter configurée dans 'possible_encounters'.")
		return
		
	var valid_scenes: Array[PackedScene] = []
	for scn in possible_encounters:
		if scn != null:
			valid_scenes.append(scn)
			
	if valid_scenes.is_empty():
		push_warning("Encounters: Toutes les scènes dans 'possible_encounters' sont null !")
		return

	# Recherche de tous les Marker3D enfants
	var markers: Array[Marker3D] = []
	for child in get_children():
		if child is Marker3D and not child.is_queued_for_deletion():
			markers.append(child)
			
	if markers.is_empty():
		print("Encounters: Aucun Marker3D trouvé pour spawner les encounters.")
		return
		
	# Nettoyer d'abord d'éventuels enfants dans les marqueurs
	for marker in markers:
		for subchild in marker.get_children():
			subchild.queue_free()
			
	var rng = RandomNumberGenerator.new()
	var seed_to_use = encounter_seed
	if seed_to_use == 0:
		var parent = get_parent()
		if parent and "world_seed" in parent and parent.world_seed != 0:
			seed_to_use = parent.world_seed
			
	if seed_to_use != 0:
		rng.seed = seed_to_use + 7777
	else:
		rng.randomize()
		
	for marker in markers:
		var random_index = rng.randi_range(0, valid_scenes.size() - 1)
		var scn: PackedScene = valid_scenes[random_index]
		var instance = scn.instantiate()
		
		marker.add_child(instance)
		
		if randomize_rotation and instance is Node3D:
			instance.rotation.y = rng.randf_range(0.0, TAU)
			
		if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
			instance.owner = get_tree().edited_scene_root
			
	# Faire disparaître les arbres autour de chaque encounter
	_clear_trees_around_markers(markers)
	
	print("Encounters: ", markers.size(), " encounter(s) généré(s) avec succès !")

func _clear_trees_around_markers(markers_list: Array[Marker3D]) -> void:
	var mesh_spawner = _find_mesh_spawner()
	if mesh_spawner and mesh_spawner.has_method("clear_trees_near_positions"):
		var marker_positions: Array[Vector3] = []
		for marker in markers_list:
			if is_instance_valid(marker):
				marker_positions.append(marker.global_position)
		var rad: float = 35.0
		if clear_trees_radius != null and float(clear_trees_radius) > 0.0:
			rad = float(clear_trees_radius)
		mesh_spawner.clear_trees_near_positions(marker_positions, rad)

func _find_mesh_spawner() -> Node:
	if get_parent() != null:
		var ms = get_parent().find_child("MeshSpawner", true, false)
		if ms != null:
			return ms
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		var spawners = get_tree().root.find_children("*", "MeshSpawner", true, false)
		if not spawners.is_empty():
			return spawners[0]
	return null
