@tool
class_name OrcVillage
extends Node3D

## Campement Orc complet adapté aux reliefs Terrain3D :
## - 1 Grande Graine / Cocon d'Oracle (`OracleVisionCocoon`) au beau milieu du village
## - 1 Petit Feu de camp (`CampfirePit` + `fire_particule.tscn`) devant la place centrale
## - 2 Tentes de guerre Orcs orientées vers le centre, posées à niveau avec pilotis & rampe d'accès
## - `Chest` dans la Tente 1 et `SkillChest` dans la Tente 2, garantis 100% AU-DESSUS du sol (jamais enterrés !)
## - `MobRaycastSpawner` projetant tous les Orcs sur le vrai sol autour du campement.

const TENT_1_LOCAL_POS := Vector3(-5.45, 0.0, -3.45)
const TENT_1_LOCAL_YAW_DEG: float = 46.0

const TENT_2_LOCAL_POS := Vector3(5.45, 0.0, -3.45)
const TENT_2_LOCAL_YAW_DEG: float = -46.0

const CAMPFIRE_LOCAL_POS := Vector3(0.0, 0.0, 3.65)
const ORACLE_SEED_LOCAL_POS := Vector3(0.0, 0.0, 0.0)

@export_category("Paramètres du Camp Orc")
@export var camp_ilvl: int = 1:
	set(val):
		camp_ilvl = maxi(1, val)
		_apply_camp_level()

@export_category("Actions (Inspecteur)")
@export var rebuild_and_snap_now: bool = false:
	set(val):
		rebuild_and_snap_now = false
		if is_inside_tree():
			if Engine.is_editor_hint():
				OrcCampProps.clear_caches()
			_build_camp_structures()
			snap_camp_to_ground()

var _props_root: Node3D = null
var _tent_1: Node3D = null
var _tent_2: Node3D = null
var _campfire_pit: Node3D = null
var _cached_map_gen: Node = null


func _ready() -> void:
	_build_camp_structures()
	_apply_camp_level()
	snap_camp_to_ground()
	# Second passage différé une fois la position globale et le monde physique 100% stabilisés
	call_deferred("_deferred_snap_and_check")


func _deferred_snap_and_check() -> void:
	if not is_inside_tree():
		return
	if not Engine.is_editor_hint() and camp_ilvl <= 1 and global_position != Vector3.ZERO:
		camp_ilvl = WorldLevelScaler.get_camp_ilvl_at(self, global_position)
	_apply_camp_level()
	snap_camp_to_ground()


func _apply_camp_level() -> void:
	var eff_lvl: int = maxi(1, camp_ilvl)
	var spawner: MobRaycastSpawner = get_node_or_null("mob_raycast_spawner") as MobRaycastSpawner
	if spawner != null:
		spawner.encounter_level = eff_lvl
	var chest_node: Node = get_node_or_null("Chest")
	if chest_node != null and "chest_ilvl" in chest_node:
		chest_node.set("chest_ilvl", eff_lvl)


func _build_camp_structures() -> void:
	if _props_root != null and is_instance_valid(_props_root):
		remove_child(_props_root)
		_props_root.queue_free()
	var old_props: Node = get_node_or_null("CampProps")
	if old_props != null:
		remove_child(old_props)
		old_props.queue_free()

	_props_root = Node3D.new()
	_props_root.name = "CampProps"
	add_child(_props_root)

	_tent_1 = OrcCampProps.build_orc_tent_node("Tent_Left", 0)
	_tent_1.position = TENT_1_LOCAL_POS
	_tent_1.rotation.y = deg_to_rad(TENT_1_LOCAL_YAW_DEG)
	_props_root.add_child(_tent_1)

	_tent_2 = OrcCampProps.build_orc_tent_node("Tent_Right", 1)
	_tent_2.position = TENT_2_LOCAL_POS
	_tent_2.rotation.y = deg_to_rad(TENT_2_LOCAL_YAW_DEG)
	_props_root.add_child(_tent_2)

	_campfire_pit = OrcCampProps.build_campfire_pit_node("CampfirePit")
	_campfire_pit.position = CAMPFIRE_LOCAL_POS
	_props_root.add_child(_campfire_pit)


## Aligne les tentes, les coffres dans les tentes, le feu de camp et la graine centrale sur le relief réel
func snap_camp_to_ground() -> void:
	if not is_inside_tree():
		return
	if _props_root == null or not is_instance_valid(_props_root):
		_build_camp_structures()

	var exclude_rids: Array[RID] = _collect_own_collision_rids()
	var camp_yaw: float = global_rotation.y
	var camp_horiz := Transform3D(Basis(Vector3.UP, camp_yaw), global_position)
	var base_ref_y: float = global_position.y

	# 1. Graine / Grand Cocon d'Oracle au centre exact du village
	var cocoon: Node3D = get_node_or_null("OracleVisionCocoon") as Node3D
	if cocoon != null and is_instance_valid(cocoon):
		var seed_w: Vector3 = camp_horiz * ORACLE_SEED_LOCAL_POS
		var seed_y: float = _sample_ground_y(seed_w.x, seed_w.z, base_ref_y, exclude_rids)
		cocoon.global_transform = Transform3D(Basis(Vector3.UP, camp_yaw), Vector3(seed_w.x, seed_y - 0.05, seed_w.z))

	# 2. Feu de camp sur la place centrale
	if _campfire_pit != null and is_instance_valid(_campfire_pit):
		var fire_w: Vector3 = camp_horiz * CAMPFIRE_LOCAL_POS
		var fy_c: float = _sample_ground_y(fire_w.x, fire_w.z, base_ref_y, exclude_rids)
		var fy_max: float = fy_c
		for off: Vector2 in [Vector2(0.55, 0.0), Vector2(-0.55, 0.0), Vector2(0.0, 0.55), Vector2(0.0, -0.55)]:
			var h_ring: float = _sample_ground_y(fire_w.x + off.x, fire_w.z + off.y, fy_c, exclude_rids)
			fy_max = maxf(fy_max, h_ring)
		var fire_final_y: float = lerpf(fy_c, fy_max, 0.45) - 0.02
		_campfire_pit.global_transform = Transform3D(Basis(Vector3.UP, camp_yaw), Vector3(fire_w.x, fire_final_y, fire_w.z))

	# 3. Tente 1 + Coffre d'équipement (`Chest`) posé sur le plancher à l'intérieur
	var chest_1: Node3D = get_node_or_null("Chest") as Node3D
	_snap_tent_and_chest(_tent_1, TENT_1_LOCAL_POS, deg_to_rad(TENT_1_LOCAL_YAW_DEG), chest_1, camp_horiz, camp_yaw, base_ref_y, exclude_rids)

	# 4. Tente 2 + Coffre de compétence (`SkillChest`) posé sur le plancher à l'intérieur
	var chest_2: Node3D = get_node_or_null("SkillChest") as Node3D
	_snap_tent_and_chest(_tent_2, TENT_2_LOCAL_POS, deg_to_rad(TENT_2_LOCAL_YAW_DEG), chest_2, camp_horiz, camp_yaw, base_ref_y, exclude_rids)


func _snap_tent_and_chest(
	tent: Node3D,
	local_pos: Vector3,
	local_yaw: float,
	chest: Node3D,
	camp_horiz: Transform3D,
	camp_yaw: float,
	base_ref_y: float,
	exclude_rids: Array[RID]
) -> void:
	var tent_w: Vector3 = camp_horiz * local_pos
	var tent_yaw: float = camp_yaw + local_yaw
	var tent_basis := Basis(Vector3.UP, tent_yaw)

	# Sonde le centre, les 4 coins de la tente et l'emplacement exact du coffre pour prendre le point haut :
	# ainsi le plancher reste 100% au-dessus de la pente amont et les pilotis s'ancrent côté aval !
	var sample_offsets: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(-1.76, 0.0, -1.96),
		Vector3(1.76, 0.0, -1.96),
		Vector3(-1.76, 0.0, 1.96),
		Vector3(1.76, 0.0, 1.96),
		Vector3(OrcCampProps.TENT_CHEST_LOCAL_POS.x, 0.0, OrcCampProps.TENT_CHEST_LOCAL_POS.z)
	]

	var max_ground_y: float = -INF
	for s_off: Vector3 in sample_offsets:
		var wp: Vector3 = tent_w + tent_basis * s_off
		var gy: float = _sample_ground_y(wp.x, wp.z, base_ref_y, exclude_rids)
		if gy > max_ground_y:
			max_ground_y = gy

	if is_inf(max_ground_y):
		max_ground_y = base_ref_y

	var tent_origin_y: float = max_ground_y + 0.02
	var tent_global_xf := Transform3D(tent_basis, Vector3(tent_w.x, tent_origin_y, tent_w.z))
	if tent != null and is_instance_valid(tent):
		tent.global_transform = tent_global_xf

	# Positionnement autoritaire du coffre à l'intérieur de la tente, strictement au-dessus du sol
	var is_auth: bool = Engine.is_editor_hint() or (not multiplayer.has_multiplayer_peer()) or multiplayer.is_server()
	if is_auth and chest != null and is_instance_valid(chest):
		var chest_world_pos: Vector3 = tent_global_xf * OrcCampProps.TENT_CHEST_LOCAL_POS
		var direct_ground_y: float = _sample_ground_y(chest_world_pos.x, chest_world_pos.z, max_ground_y, exclude_rids)
		chest_world_pos.y = maxf(chest_world_pos.y, direct_ground_y + 0.04)
		chest.global_transform = Transform3D(tent_basis, chest_world_pos)


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
		var from_pt := Vector3(wx, fallback_y + 45.0, wz)
		var to_pt := Vector3(wx, fallback_y - 60.0, wz)
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
	var cur: Node = get_parent()
	while cur != null:
		if cur.has_method("get_terrain_height_at") and cur.has_method("get_arena_generator"):
			_cached_map_gen = cur
			return _cached_map_gen
		cur = cur.get_parent()
	if get_tree() != null:
		var search_root: Node = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene
		if search_root != null and search_root != self:
			if search_root.has_method("get_terrain_height_at") and search_root.has_method("get_arena_generator"):
				_cached_map_gen = search_root
				return _cached_map_gen
			var mg: Node = search_root.find_child("Map_generator", true, false)
			if mg != null:
				_cached_map_gen = mg
				return _cached_map_gen
	return null
