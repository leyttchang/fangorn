@tool
class_name LesserSkillSteleEncounter
extends Node3D

## Rencontre de Petite Stèle de Compétences Tier I protégée par un petit groupe de monstres (~4-5 au niv. 1).
## - 1 spawn garanti proche du départ à ~20m du chemin sur toutes les seeds (niv. 1)
## - Jusqu'à 3 autres spawns aléatoires sur la carte avec scaling de distance au spawn (niv. 1 -> 5 : stats, loot iLvl & crédits)

signal encounter_unsealed

const SCOUT_SCENE: PackedScene = preload("res://character/enemie/Scout/scout.tscn")
const STELE_CAMPFIRE_LOCAL_POS := Vector3(1.65, 0.0, 1.25)

@export_category("Niveau & Crédits des Gardiens")
@export var is_starter_stele: bool = false
@export var stele_level: int = 1:
	set(val):
		stele_level = maxi(1, val)
		_apply_level_to_spawner()

@export var base_guard_credits: int = 40
@export var extra_credits_per_level: int = 15

@export var is_unsealed: bool = false:
	set(val):
		is_unsealed = val
		if is_inside_tree():
			_sync_stele_seal()

@export_category("Actions (Inspecteur)")
@export var snap_and_preview_now: bool = false:
	set(val):
		snap_and_preview_now = false
		if is_inside_tree():
			snap_camp_to_ground()

@export var test_unseal_now: bool = false:
	set(val):
		test_unseal_now = false
		if is_inside_tree():
			unseal_stele()

var _stele: LesserSkillStele = null
var _spawner: MobRaycastSpawner = null
var _campfire_pit: Node3D = null
var _cached_map_gen: Node = null
var _guards_spawned: bool = false
var _spawn_started: bool = false
var _watchdog_timer: float = 0.0


func _ready() -> void:
	_resolve_nodes()
	_ensure_stele_campfire()
	_sync_stele_seal()
	_apply_level_to_spawner()
	snap_camp_to_ground()

	if Engine.is_editor_hint():
		set_physics_process(false)
		return

	if _spawner != null and not _spawner.all_mobs_defeated.is_connected(_on_all_guards_defeated):
		_spawner.all_mobs_defeated.connect(_on_all_guards_defeated)

	var mg: Node = _find_map_generator()
	if mg != null and mg.has_signal("terrain_ready") and ("is_terrain_ready" in mg) and not bool(mg.get("is_terrain_ready")):
		if not mg.is_connected("terrain_ready", _on_world_terrain_ready):
			mg.connect("terrain_ready", _on_world_terrain_ready, Object.CONNECT_ONE_SHOT)
	else:
		call_deferred("_deferred_init_and_spawn_guards")


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if _spawner != null and is_instance_valid(_spawner):
		_spawner.clear_mobs()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or is_unsealed or not _guards_spawned:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	_watchdog_timer += delta
	if _watchdog_timer < 0.35:
		return
	_watchdog_timer = 0.0

	if _spawner == null or not is_instance_valid(_spawner) or _spawner.get_alive_mobs_count() == 0:
		unseal_stele()


func _on_world_terrain_ready() -> void:
	call_deferred("_deferred_init_and_spawn_guards")


func _deferred_init_and_spawn_guards() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or _spawn_started:
		return
	_spawn_started = true

	_resolve_nodes()
	if is_starter_stele:
		stele_level = 1
	elif stele_level <= 1 and global_position != Vector3.ZERO:
		stele_level = WorldLevelScaler.get_zone_ilvl_at(self, global_position)

	_apply_level_to_spawner()
	snap_camp_to_ground()

	if is_unsealed:
		_sync_stele_seal()
		return

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	if _spawner == null:
		unseal_stele()
		return

	if get_tree() != null:
		await get_tree().physics_frame
		if not is_inside_tree() or is_queued_for_deletion():
			return

	var spawned: Array[Node3D] = _spawner.spawn_mobs()
	if spawned.is_empty():
		spawned = _fallback_spawn_guards_on_terrain()

	_guards_spawned = true
	if spawned.is_empty():
		unseal_stele()


func _fallback_spawn_guards_on_terrain() -> Array[Node3D]:
	var result: Array[Node3D] = []
	if _spawner == null or not is_instance_valid(_spawner):
		return result
	var mg: Node = _find_map_generator()
	if mg == null or not mg.has_method("get_terrain_height_at"):
		return result

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var total_credits: int = _spawner._calculate_total_credits()
	var credits_left: int = total_credits

	var target_container: Node = _spawner.mobs_container
	if target_container == null and get_tree() != null and get_tree().current_scene != null:
		target_container = get_tree().current_scene.get_node_or_null("NetworkObjects")
	if target_container == null:
		target_container = _spawner

	while credits_left > 0:
		var affordable: Array[Dictionary] = _spawner._get_affordable_monsters(credits_left)
		if affordable.is_empty():
			break
		var entry: Dictionary = _spawner._pick_weighted_random(affordable, rng)
		var scn: PackedScene = entry.get("scene") as PackedScene
		var cost: int = int(entry.get("cost", 10))
		if scn == null:
			break

		var ang: float = rng.randf_range(0.0, TAU)
		var r: float = sqrt(rng.randf_range(_spawner.min_spawn_radius * _spawner.min_spawn_radius, _spawner.spawn_radius * _spawner.spawn_radius))
		var wx: float = global_position.x + cos(ang) * r
		var wz: float = global_position.z + sin(ang) * r
		var gy: float = float(mg.call("get_terrain_height_at", wx, wz))
		if is_nan(gy) or is_inf(gy):
			gy = global_position.y

		var mob: Node3D = scn.instantiate() as Node3D
		if mob == null:
			break
		target_container.add_child(mob, true)
		mob.global_position = Vector3(wx, gy + _spawner.spawn_height_offset, wz)
		WorldLevelScaler.apply_level_to_monster(mob, maxi(1, stele_level))
		_spawner._apply_facing(mob, rng)
		_spawner._track_mob(mob)
		result.append(mob)
		credits_left -= cost

	return result


func _resolve_nodes() -> void:
	if _stele == null or not is_instance_valid(_stele):
		_stele = get_node_or_null("LesserSkillStele") as LesserSkillStele
	if _spawner == null or not is_instance_valid(_spawner):
		_spawner = get_node_or_null("mob_raycast_spawner") as MobRaycastSpawner


func _sync_stele_seal() -> void:
	_resolve_nodes()
	if _stele != null and is_instance_valid(_stele):
		_stele.is_unsealed = is_unsealed


func _apply_level_to_spawner() -> void:
	_resolve_nodes()
	if _spawner == null or not is_instance_valid(_spawner):
		return
	var eff_lvl: int = 1 if is_starter_stele else maxi(1, stele_level)
	_spawner.base_credits = base_guard_credits
	_spawner.credits_per_level = extra_credits_per_level
	_spawner.encounter_level = eff_lvl

	# À partir du niveau de zone 3 (loin du spawn), les gardiens peuvent inclure un Scout Orc
	if eff_lvl >= 3 and SCOUT_SCENE != null and not _spawner.monster_scenes.has(SCOUT_SCENE):
		var scenes_copy: Array[PackedScene] = _spawner.monster_scenes.duplicate()
		var weights_copy: Array[float] = _spawner.monster_weights.duplicate()
		scenes_copy.append(SCOUT_SCENE)
		if weights_copy.size() == _spawner.monster_scenes.size():
			weights_copy.append(0.35)
		_spawner.monster_scenes = scenes_copy
		_spawner.monster_weights = weights_copy


func _on_all_guards_defeated() -> void:
	unseal_stele()


func unseal_stele() -> void:
	if is_unsealed:
		return
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		rpc("_rpc_unseal_stele")
	else:
		_do_unseal_stele()


@rpc("authority", "call_local", "reliable")
func _rpc_unseal_stele() -> void:
	_do_unseal_stele()


func _do_unseal_stele() -> void:
	if is_unsealed:
		return
	is_unsealed = true
	_sync_stele_seal()
	encounter_unsealed.emit()
	print("[LesserSkillSteleEncounter] Gardiens vaincus -> Petite Stèle Tier I descellée (niv. %d) !" % stele_level)


func snap_camp_to_ground() -> void:
	if not is_inside_tree():
		return
	_resolve_nodes()
	_ensure_stele_campfire()
	var exclude_rids: Array[RID] = _collect_own_collision_rids()
	var wx: float = global_position.x
	var wz: float = global_position.z
	var base_y: float = _sample_ground_y(wx, wz, global_position.y, exclude_rids)

	# Sonde légèrement autour du socle pour que la dalle ne soit jamais enterrée à moitié en amont
	var top_y: float = base_y
	for off: Vector2 in [Vector2(0.30, 0.0), Vector2(-0.30, 0.0), Vector2(0.0, 0.22), Vector2(0.0, -0.22)]:
		var hy: float = _sample_ground_y(wx + off.x, wz + off.y, base_y, exclude_rids)
		top_y = maxf(top_y, hy)
	var final_y: float = lerpf(base_y, top_y, 0.45)

	global_position = Vector3(wx, final_y, wz)
	if _stele != null and is_instance_valid(_stele):
		_stele.position = Vector3.ZERO

	# Plaque aussi le petit feu de camp adjacent directement sur le relief réel du sol
	if _campfire_pit != null and is_instance_valid(_campfire_pit):
		var yaw: float = global_rotation.y
		var horiz := Transform3D(Basis(Vector3.UP, yaw), global_position)
		var fire_w: Vector3 = horiz * STELE_CAMPFIRE_LOCAL_POS
		var fy_c: float = _sample_ground_y(fire_w.x, fire_w.z, final_y, exclude_rids)
		var fy_max: float = fy_c
		for f_off: Vector2 in [Vector2(0.45, 0.0), Vector2(-0.45, 0.0), Vector2(0.0, 0.45), Vector2(0.0, -0.45)]:
			var h_ring: float = _sample_ground_y(fire_w.x + f_off.x, fire_w.z + f_off.y, fy_c, exclude_rids)
			fy_max = maxf(fy_max, h_ring)
		var fire_final_y: float = lerpf(fy_c, fy_max, 0.45) - 0.02
		var fire_scale: Vector3 = _campfire_pit.scale
		_campfire_pit.global_transform = Transform3D(Basis(Vector3.UP, yaw).scaled(fire_scale), Vector3(fire_w.x, fire_final_y, fire_w.z))


func _ensure_stele_campfire() -> void:
	if _campfire_pit != null and is_instance_valid(_campfire_pit):
		return
	var existing: Node3D = get_node_or_null("SteleCampfire") as Node3D
	if existing != null:
		_campfire_pit = existing
		return
	_campfire_pit = OrcCampProps.build_stele_beacon_campfire_node("SteleCampfire")
	_campfire_pit.position = STELE_CAMPFIRE_LOCAL_POS
	add_child(_campfire_pit)


func _sample_ground_y(wx: float, wz: float, fallback_y: float, exclude_rids: Array[RID]) -> float:
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root == self:
		return fallback_y

	var mg: Node = _find_map_generator()
	if mg != null and mg.has_method("get_terrain_height_at"):
		var th: float = float(mg.call("get_terrain_height_at", wx, wz))
		if not is_nan(th) and not is_inf(th):
			return th

	var w3d: World3D = get_world_3d()
	if w3d != null and w3d.direct_space_state != null:
		var from_pt := Vector3(wx, fallback_y + 40.0, wz)
		var to_pt := Vector3(wx, fallback_y - 55.0, wz)
		var query := PhysicsRayQueryParameters3D.create(from_pt, to_pt, 1, exclude_rids)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var hit: Dictionary = w3d.direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.has("position"):
			return float((hit["position"] as Vector3).y)

	return fallback_y


func _collect_own_collision_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for n: Node in find_children("*", "CollisionObject3D", true, false):
		var co := n as CollisionObject3D
		if co != null and co.get_rid().is_valid():
			rids.append(co.get_rid())
	return rids


func _find_map_generator() -> Node:
	if _cached_map_gen != null and is_instance_valid(_cached_map_gen):
		return _cached_map_gen
	_cached_map_gen = WorldLevelScaler.find_map_generator(self)
	return _cached_map_gen
