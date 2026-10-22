class_name BossArena
extends Node3D

## Contrôleur de la scène d'Arène de Boss (boss_arena.tscn).
## Détecte l'entrée d'un joueur via `entry_detection`, fait spawn le boss assigné (par l'inspecteur
## ou par l'ArenaGenerator selon la world_seed) sur `Boss_spawn_position` plaqué au sol,
## écoute le signal `boss_died(ilvl, enchantment)` du boss et fait spawn un coffre de même ilvl
## sur `reward_position` plaqué au sol.

signal arena_boss_spawned(boss: Node3D)
signal arena_boss_defeated(boss_ilvl: int, boss_enchantment: Variant, reward_chest: Node3D)

@export_category("Boss & Récompense")
## Scène du boss à faire apparaître quand le joueur entre dans l'arène (peut être remplacée par ArenaGenerator via la world_seed)
@export var boss_scene: PackedScene = preload("res://character/enemie/ogre_boss/ogre_boss.tscn")
## Scène du coffre de récompense qui apparaît à la mort du boss
@export var reward_chest_scene: PackedScene = preload("res://objet/chest/chest.tscn")
## Si > 0, écrase l'ilvl défini sur la scène du boss au moment du spawn (0 = garde l'ilvl du boss)
@export var boss_ilvl_override: int = 0

@onready var entry_marker: Marker3D = get_node_or_null("entry") as Marker3D
@onready var boss_spawn_marker: Marker3D = get_node_or_null("Boss_spawn_position") as Marker3D
@onready var reward_marker: Marker3D = get_node_or_null("reward_position") as Marker3D
@onready var entry_detection: Area3D = get_node_or_null("entry_detection") as Area3D

## Fournisseur de hauteur (Callable(x, z) -> float) injecté par l'ArenaGenerator
var height_provider: Callable = Callable()

var _boss_spawned: bool = false
var _reward_spawned: bool = false
var _active_boss: Node3D = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if entry_detection != null:
		if not entry_detection.body_entered.is_connected(_on_entry_detection_body_entered):
			entry_detection.body_entered.connect(_on_entry_detection_body_entered)
	else:
		push_error("BossArena (%s): nœud Area3D 'entry_detection' introuvable !" % name)


func _on_entry_detection_body_entered(body: Node3D) -> void:
	if _boss_spawned:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if body == null or not is_instance_valid(body) or not body.is_in_group("Player"):
		return
	if body.get("is_dead") == true:
		return
		
	spawn_boss(body)


## Instancie le boss sur le serveur dans NetworkObjects et le plaque au sol de l'arène
func spawn_boss(triggering_player: Node3D = null) -> Node3D:
	if _boss_spawned:
		return _active_boss
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return null
	if boss_scene == null:
		push_error("BossArena (%s): aucune scène 'boss_scene' assignée !" % name)
		return null
		
	_boss_spawned = true
	if entry_detection != null:
		entry_detection.set_deferred("monitoring", false)
		
	var boss_inst: Node3D = boss_scene.instantiate() as Node3D
	if boss_inst == null:
		push_error("BossArena (%s): la scène boss_scene n'est pas un Node3D !" % name)
		return null
		
	if boss_ilvl_override > 0 and "ilvl" in boss_inst:
		boss_inst.set("ilvl", boss_ilvl_override)
		
	var marker_pos: Vector3 = boss_spawn_marker.global_position if boss_spawn_marker != null else global_position
	var ground_y: float = _get_arena_ground_y(marker_pos.x, marker_pos.z)
	var final_spawn_pos := Vector3(marker_pos.x, ground_y + 0.5, marker_pos.z)
	
	var net_parent: Node = _get_network_objects_parent()
	net_parent.add_child(boss_inst, true)
	boss_inst.global_position = final_spawn_pos
	
	# Orienter le boss face à l'entrée de l'arène
	if entry_marker != null:
		var look_target := Vector3(entry_marker.global_position.x, final_spawn_pos.y, entry_marker.global_position.z)
		if final_spawn_pos.distance_squared_to(look_target) > 0.01:
			boss_inst.look_at(look_target, Vector3.UP)
			
	# Augmenter la portée de détection/aggro pour couvrir toute la profondeur de l'arène (~150m+)
	var nav_comp := boss_inst.get_node_or_null("EnemyNavigationComponent")
	if nav_comp != null:
		if "detection_range_override" in nav_comp:
			nav_comp.detection_range_override = 250.0
		if "lose_aggro_override" in nav_comp:
			nav_comp.lose_aggro_override = 300.0
			
	if triggering_player != null and is_instance_valid(triggering_player) and "target" in boss_inst:
		boss_inst.set("target", triggering_player)
		
	# Connexion au signal de mort du boss (transmettant ilvl et enchantement)
	if boss_inst.has_signal("boss_died"):
		boss_inst.connect("boss_died", _on_boss_died)
	else:
		var hc := boss_inst.get_node_or_null("HealthComponent")
		if hc != null and hc.has_signal("died"):
			hc.died.connect(func():
				var b_ilvl: int = int(boss_inst.get("ilvl")) if "ilvl" in boss_inst else 1
				var b_ench: Variant = boss_inst.get("enchantment") if "enchantment" in boss_inst else null
				_on_boss_died(b_ilvl, b_ench)
			)
			
	_active_boss = boss_inst
	arena_boss_spawned.emit(boss_inst)
	print("BossArena (%s): Boss '%s' spawné en %v (ilvl=%s)." % [
		name,
		boss_inst.name,
		final_spawn_pos,
		str(boss_inst.get("ilvl") if "ilvl" in boss_inst else 1)
	])
	return boss_inst


func _on_boss_died(dead_boss_ilvl: int, dead_boss_enchantment: Variant) -> void:
	if _reward_spawned:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_reward_spawned = true
	var chest := spawn_reward_chest(dead_boss_ilvl, dead_boss_enchantment)
	arena_boss_defeated.emit(dead_boss_ilvl, dead_boss_enchantment, chest)


## Fait apparaître le coffre de récompense au niveau (ilvl) et enchantement transmis par le boss
func spawn_reward_chest(reward_ilvl: int, reward_enchantment: Variant = null) -> Node3D:
	if reward_chest_scene == null:
		push_error("BossArena (%s): aucune scène 'reward_chest_scene' assignée !" % name)
		return null
		
	var chest_inst: Node3D = reward_chest_scene.instantiate() as Node3D
	if chest_inst == null:
		push_error("BossArena (%s): la scène reward_chest_scene n'est pas un Node3D !" % name)
		return null
		
	var effective_ilvl: int = maxi(1, reward_ilvl)
	if "chest_ilvl" in chest_inst:
		chest_inst.set("chest_ilvl", effective_ilvl)
	if "chest_enchantment" in chest_inst:
		chest_inst.set("chest_enchantment", reward_enchantment)
		
	var marker_pos: Vector3 = reward_marker.global_position if reward_marker != null else global_position
	var ground_y: float = _get_arena_ground_y(marker_pos.x, marker_pos.z)
	var final_reward_pos := Vector3(marker_pos.x, ground_y, marker_pos.z)
	
	var net_parent: Node = _get_network_objects_parent()
	net_parent.add_child(chest_inst, true)
	chest_inst.global_position = final_reward_pos
	
	if entry_marker != null:
		var look_target := Vector3(entry_marker.global_position.x, final_reward_pos.y, entry_marker.global_position.z)
		if final_reward_pos.distance_squared_to(look_target) > 0.01:
			chest_inst.look_at(look_target, Vector3.UP)
			
	print("BossArena (%s): Coffre de récompense spawné en %v (chest_ilvl=%d, enchant=%s)." % [
		name,
		final_reward_pos,
		effective_ilvl,
		str(reward_enchantment)
	])
	return chest_inst


## Calcule la hauteur exacte du sol de l'arène au point (x, z)
func _get_arena_ground_y(x: float, z: float) -> float:
	if height_provider.is_valid():
		var h: float = float(height_provider.call(x, z))
		if not is_nan(h):
			return h
			
	# Recherche via le parent ArenaGenerator / MapGenerator
	var curr: Node = get_parent()
	while curr != null:
		if curr.has_method("get_terrain_height_at"):
			var h: float = float(curr.call("get_terrain_height_at", x, z))
			if not is_nan(h):
				return h
		curr = curr.get_parent()
		
	# Le sol de l'arène est plat et aligné sur l'altitude du Marker3D 'entry'
	if entry_marker != null:
		return entry_marker.global_position.y
	return global_position.y


func _get_network_objects_parent() -> Node:
	if is_inside_tree() and get_tree() != null and get_tree().current_scene != null:
		var net_obj := get_tree().current_scene.get_node_or_null("NetworkObjects")
		if net_obj != null:
			return net_obj
	return self
