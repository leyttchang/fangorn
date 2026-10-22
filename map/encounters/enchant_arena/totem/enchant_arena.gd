class_name EnchantArena
extends Node3D

signal totem_spawned(totem: Node3D)

@export_category("Totems d'Enchantement")
## Liste des scènes de totems possibles à faire apparaître sur le marker (tirage aléatoire selon la world_seed)
@export var possible_totems: Array[PackedScene] = [
	preload("res://map/encounters/enchant_arena/totem/enchant_arcane_totem.tscn")
]

## Marker3D indiquant où faire spawn le totem (utilise "enchant_totem_pos" par défaut)
@export var totem_spawn_marker: Marker3D

## Spawner de monstres de l'arène déclenché à l'activation du totem
@export var mob_spawner: MobRaycastSpawner

## Décalage vertical additionnel par rapport au sol (0.0 = posé pile sur le sol)
@export var ground_offset_y: float = 0.0

@onready var entry_marker: Marker3D = get_node_or_null("entry") as Marker3D

## Fournisseur de hauteur (Callable(x, z) -> float) injecté par l'ArenaGenerator
var height_provider: Callable = Callable()

var _active_totem: Node3D = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if totem_spawn_marker == null:
		totem_spawn_marker = get_node_or_null("enchant_totem_pos") as Marker3D
	if mob_spawner == null:
		mob_spawner = get_node_or_null("mob_raycast_spawner") as MobRaycastSpawner
		
	# Si l'arène est placée manuellement hors ArenaGenerator, on attend que le terrain soit prêt
	var map_gen: Node = _find_map_generator()
	if map_gen != null and map_gen.has_signal("terrain_ready"):
		if not map_gen.is_connected("terrain_ready", _on_map_terrain_ready):
			map_gen.connect("terrain_ready", _on_map_terrain_ready, CONNECT_ONE_SHOT)
	else:
		call_deferred("spawn_totem")


func _on_map_terrain_ready() -> void:
	if _active_totem == null or not is_instance_valid(_active_totem):
		spawn_totem()
	else:
		snap_totem_to_ground()


## Choisit un totem parmi `possible_totems` et l'instancie sur le sol à la position XZ du marker `enchant_totem_pos`
func spawn_totem() -> Node3D:
	if Engine.is_editor_hint():
		return null
	if _active_totem != null and is_instance_valid(_active_totem):
		snap_totem_to_ground()
		return _active_totem
		
	if totem_spawn_marker == null:
		totem_spawn_marker = get_node_or_null("enchant_totem_pos") as Marker3D
	if mob_spawner == null:
		mob_spawner = get_node_or_null("mob_raycast_spawner") as MobRaycastSpawner
		
	var valid_totems: Array[PackedScene] = []
	for scn in possible_totems:
		if scn != null:
			valid_totems.append(scn)
			
	if valid_totems.is_empty():
		push_error("EnchantArena (%s): aucune scène de totem dans 'possible_totems' !" % name)
		return null
		
	var rng := RandomNumberGenerator.new()
	var world_seed: int = _find_world_seed()
	if world_seed != 0:
		rng.seed = hash([world_seed, name, "enchant_totem"])
	else:
		rng.randomize()
		
	var chosen_scene: PackedScene = valid_totems[rng.randi_range(0, valid_totems.size() - 1)]
	var totem_inst: Node3D = chosen_scene.instantiate() as Node3D
	if totem_inst == null:
		push_error("EnchantArena (%s): la scène de totem choisie n'est pas un Node3D !" % name)
		return null
		
	totem_inst.name = "SpawnedTotem"
	if "mob_spawner" in totem_inst and mob_spawner != null:
		totem_inst.set("mob_spawner", mob_spawner)
	add_child(totem_inst)
	_active_totem = totem_inst
	
	snap_totem_to_ground()
			
	totem_spawned.emit(totem_inst)
	print("EnchantArena (%s): Totem '%s' spawné au sol en %v." % [name, chosen_scene.resource_path.get_file(), totem_inst.global_position])
	return totem_inst


## Plaque le totem exactement sur la hauteur réelle du sol en (X, Z)
func snap_totem_to_ground() -> void:
	if _active_totem == null or not is_instance_valid(_active_totem):
		return
	var marker_pos: Vector3 = totem_spawn_marker.global_position if totem_spawn_marker != null else global_position
	var ground_y: float = _get_arena_ground_y(marker_pos.x, marker_pos.z)
	if is_nan(ground_y):
		push_error("EnchantArena (%s): impossible de déterminer la hauteur du sol en (%.1f, %.1f) !" % [name, marker_pos.x, marker_pos.z])
		return
		
	var final_pos := Vector3(marker_pos.x, ground_y + ground_offset_y, marker_pos.z)
	_active_totem.global_position = final_pos
	
	# Orienter le totem horizontalement face à l'entrée de l'arène
	if entry_marker != null:
		var look_target := Vector3(entry_marker.global_position.x, final_pos.y, entry_marker.global_position.z)
		if final_pos.distance_squared_to(look_target) > 0.01:
			_active_totem.look_at(look_target, Vector3.UP)


func _find_map_generator() -> Node:
	var curr: Node = get_parent()
	while curr != null:
		if curr.has_method("get_terrain_height_at") or "world_seed" in curr:
			return curr
		curr = curr.get_parent()
	return null


func _find_world_seed() -> int:
	var map_gen: Node = _find_map_generator()
	if map_gen != null and "world_seed" in map_gen:
		return int(map_gen.get("world_seed"))
	return 0


## Récupère la hauteur réelle du sol sous (x, z) via Terrain3D, MapGenerator ou RayCast physique
func _get_arena_ground_y(x: float, z: float) -> float:
	# 1. Lecture directe dans les données du Terrain3D (incluant la région étendue sous l'arène)
	var map_gen: Node = _find_map_generator()
	if map_gen != null and "terrain" in map_gen:
		var t3d: Terrain3D = map_gen.get("terrain") as Terrain3D
		if t3d != null and t3d.data != null:
			var h_t3d: float = t3d.data.get_height(Vector3(x, 0.0, z))
			if not is_nan(h_t3d):
				return h_t3d
				
	# 2. Via le Callable height_provider injecté par l'ArenaGenerator
	if height_provider.is_valid():
		var h_prov: float = float(height_provider.call(x, z))
		if not is_nan(h_prov):
			return h_prov
			
	# 3. Via MapGenerator.get_terrain_height_at(x, z)
	if map_gen != null and map_gen.has_method("get_terrain_height_at"):
		var h_map: float = float(map_gen.call("get_terrain_height_at", x, z))
		if not is_nan(h_map):
			return h_map
			
	# 4. Fallback RayCast3D physique vers le sol (Layer 1) si testé dans une scène sans MapGenerator
	if is_inside_tree() and get_world_3d() != null:
		var space_state := get_world_3d().direct_space_state
		if space_state != null:
			var query := PhysicsRayQueryParameters3D.create(
				Vector3(x, global_position.y + 500.0, z),
				Vector3(x, global_position.y - 500.0, z),
				1
			)
			var hit: Dictionary = space_state.intersect_ray(query)
			if not hit.is_empty() and hit.has("position"):
				return (hit["position"] as Vector3).y
				
	return NAN
