extends Node3D

enum GrappleState {
	INACTIVE,
	FLYING,
	REEL_ANCHOR,
	RETRACT
}

const TETHER_SEGMENTS: int = 6
const BARK_DIFF_PATH: String = "res://assets/texture/bark_brown_text/bark_brown_02_diff_1k.jpg"

class TreeVolume:
	var base_pos: Vector3 = Vector3.ZERO
	var crown_center: Vector3 = Vector3.ZERO
	var inv_rxz: float = 0.2
	var inv_ry: float = 0.2
	var trunk_radius: float = 1.0
	var trunk_min_y: float = 0.0
	var trunk_max_y: float = 5.0

static var _tether_cyl_mesh: CylinderMesh = null
static var _tip_spear_mesh: CylinderMesh = null
static var _anchor_ring_mesh: TorusMesh = null
static var _bark_tether_mat: StandardMaterial3D = null
static var _rune_strand_mat: StandardMaterial3D = null
static var _assist_sphere: SphereShape3D = null

@export var projectile_speed: float = 58.0
@export var max_distance: float = 34.0
@export var reel_duration: float = 0.14
@export var reel_speed: float = 26.0
@export var retract_duration: float = 0.14

@onready var attack_component: AttackComponent = $AttackComponent
@onready var scaling_component: SpellScalingComponent = $SpellScalingComponent

var _state: GrappleState = GrappleState.INACTIVE
var _caster: Node3D = null
var _caster_body: CharacterBody3D = null
var _hand_node: Node3D = null
var _camera: Camera3D = null
var _is_auth: bool = true

var _tip_pos: Vector3 = Vector3.ZERO
var _fly_dir: Vector3 = Vector3.FORWARD
var _distance_travelled: float = 0.0
var _phase_elapsed: float = 0.0

var _anchor_pos: Vector3 = Vector3.ZERO
var _anchor_dir_3d: Vector3 = Vector3.FORWARD
var _initial_anchor_dist: float = 0.0
var _retract_start_pos: Vector3 = Vector3.ZERO

var _motion_overridden: bool = false
var _saved_collision_layer: int = 2
var _saved_collision_mask: int = 257
var _exception_bodies: Array[PhysicsBody3D] = []
var _exclude_rids: Array[RID] = []
var _nearby_trees: Array[TreeVolume] = []

var _tip_holder: Node3D = null
var _bark_segs: Array[MeshInstance3D] = []
var _rune_segs: Array[MeshInstance3D] = []


static func _ensure_shared_visuals() -> void:
	if _tether_cyl_mesh == null:
		_tether_cyl_mesh = CylinderMesh.new()
		_tether_cyl_mesh.top_radius = 1.0
		_tether_cyl_mesh.bottom_radius = 1.0
		_tether_cyl_mesh.height = 1.0
		_tether_cyl_mesh.radial_segments = 6
		_tether_cyl_mesh.rings = 0
		_tether_cyl_mesh.cap_top = false
		_tether_cyl_mesh.cap_bottom = false

	if _tip_spear_mesh == null:
		_tip_spear_mesh = CylinderMesh.new()
		_tip_spear_mesh.top_radius = 0.015
		_tip_spear_mesh.bottom_radius = 0.11
		_tip_spear_mesh.height = 0.52
		_tip_spear_mesh.radial_segments = 6
		_tip_spear_mesh.rings = 1

	if _anchor_ring_mesh == null:
		_anchor_ring_mesh = TorusMesh.new()
		_anchor_ring_mesh.inner_radius = 0.22
		_anchor_ring_mesh.outer_radius = 0.34
		_anchor_ring_mesh.rings = 12
		_anchor_ring_mesh.ring_segments = 6

	if _bark_tether_mat == null:
		_bark_tether_mat = StandardMaterial3D.new()
		_bark_tether_mat.albedo_color = Color(0.46, 0.38, 0.28, 1.0)
		_bark_tether_mat.roughness = 0.86
		_bark_tether_mat.emission_enabled = true
		_bark_tether_mat.emission = Color(0.42, 0.22, 0.72, 1.0)
		_bark_tether_mat.emission_energy_multiplier = 0.55
		if ResourceLoader.exists(BARK_DIFF_PATH):
			_bark_tether_mat.albedo_texture = load(BARK_DIFF_PATH) as Texture2D
			_bark_tether_mat.uv1_scale = Vector3(1.0, 2.5, 1.0)

	if _rune_strand_mat == null:
		_rune_strand_mat = StandardMaterial3D.new()
		_rune_strand_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_rune_strand_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_rune_strand_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_rune_strand_mat.albedo_color = Color(2.05, 0.68, 3.35, 0.88)

	if _assist_sphere == null:
		_assist_sphere = SphereShape3D.new()
		_assist_sphere.radius = 0.28


static func _find_mob_hitbox(mob: Node3D) -> HitboxComponent:
	if mob == null:
		return null
	var hb: HitboxComponent = mob.get_node_or_null("HitboxComponent") as HitboxComponent
	if hb == null:
		for cand: Node in mob.find_children("*", "Area3D", true, false):
			var cand_hb: HitboxComponent = cand as HitboxComponent
			if cand_hb != null:
				hb = cand_hb
				if cand_hb.body_part_multiplier <= 1.05:
					break
	return hb


func _ready() -> void:
	_ensure_shared_visuals()
	if attack_component != null:
		attack_component.monitoring = false
		attack_component.monitorable = false
		attack_component.is_active_for_network = false

	_tip_holder = Node3D.new()
	_tip_holder.name = "GrappleTip"
	_tip_holder.visible = false
	add_child(_tip_holder)

	var tip_core: MeshInstance3D = MeshInstance3D.new()
	tip_core.mesh = _tip_spear_mesh
	tip_core.material_override = _bark_tether_mat
	tip_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tip_core.rotation.x = -PI * 0.5
	_tip_holder.add_child(tip_core)

	var tip_rune: MeshInstance3D = MeshInstance3D.new()
	tip_rune.mesh = _tip_spear_mesh
	tip_rune.material_override = _rune_strand_mat
	tip_rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tip_rune.rotation.x = -PI * 0.5
	tip_rune.scale = Vector3(0.55, 1.12, 0.55)
	_tip_holder.add_child(tip_rune)

	for _i: int in range(TETHER_SEGMENTS):
		var b_mi: MeshInstance3D = MeshInstance3D.new()
		b_mi.mesh = _tether_cyl_mesh
		b_mi.material_override = _bark_tether_mat
		b_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b_mi.visible = false
		add_child(b_mi)
		_bark_segs.append(b_mi)

		var r_mi: MeshInstance3D = MeshInstance3D.new()
		r_mi.mesh = _tether_cyl_mesh
		r_mi.material_override = _rune_strand_mat
		r_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r_mi.visible = false
		add_child(r_mi)
		_rune_segs.append(r_mi)


func execute(caster: Node3D, target_data: Dictionary) -> void:
	if caster == null or not is_instance_valid(caster):
		queue_free()
		return

	_caster = caster
	_caster_body = caster as CharacterBody3D
	var is_remote: bool = bool(target_data.get("is_remote_visual", false))
	_is_auth = (not is_remote) and (not multiplayer.has_multiplayer_peer() or caster.is_multiplayer_authority())

	var ab_data: AbilityData = target_data.get("ability_data") as AbilityData
	if ab_data != null and ab_data.max_range > 0.0:
		max_distance = ab_data.max_range

	_camera = caster.get_node_or_null("Camera3D") as Camera3D
	_hand_node = caster.get_node_or_null("Camera3D/MainGauche") as Node3D
	if _hand_node == null:
		_hand_node = caster.find_child("MainGauche", true, false) as Node3D
	if _hand_node == null:
		_hand_node = caster.find_child("CastPoint", true, false) as Node3D

	_build_caster_exclude_rids(caster)
	_collect_nearby_trees(caster.global_position)

	if attack_component != null:
		attack_component.on_execute(caster, target_data)
		attack_component.is_active_for_network = false
	if scaling_component != null:
		scaling_component.on_execute(caster, target_data)

	var hand_origin: Vector3 = _get_hand_world_pos()
	var aim_origin: Vector3 = _camera.global_position if _camera != null else (caster.global_position + Vector3(0.0, 1.45, 0.0))
	var cam_fwd: Vector3 = -_camera.global_transform.basis.z.normalized() if _camera != null else -caster.global_transform.basis.z.normalized()

	var aim_target: Vector3 = _compute_crosshair_aim_point(aim_origin, cam_fwd)
	_tip_pos = aim_origin + cam_fwd * 0.55
	var to_aim: Vector3 = aim_target - _tip_pos
	if to_aim.length_squared() > 0.01:
		_fly_dir = to_aim.normalized()
	else:
		_fly_dir = cam_fwd

	global_position = hand_origin
	_distance_travelled = 0.0
	_phase_elapsed = 0.0
	_state = GrappleState.FLYING
	_tip_holder.visible = true
	_update_tether_visuals(hand_origin, _tip_pos, 1.0)

	SpellAudioManager.play_ice_cast(self, hand_origin, 1.32, -2.5)


func _build_caster_exclude_rids(caster: Node3D) -> void:
	_exclude_rids.clear()
	var root_co: CollisionObject3D = caster as CollisionObject3D
	if root_co != null:
		_exclude_rids.append(root_co.get_rid())
	for child: Node in caster.find_children("*", "CollisionObject3D", true, false):
		var co: CollisionObject3D = child as CollisionObject3D
		if co != null:
			_exclude_rids.append(co.get_rid())


func _register_tree_volume(pos: Vector3, tree_scale: float, origin: Vector3, max_r_sq: float) -> void:
	if tree_scale <= 0.1:
		return
	var dx: float = pos.x - origin.x
	var dz: float = pos.z - origin.z
	if (dx * dx + dz * dz) > max_r_sq:
		return

	var tv: TreeVolume = TreeVolume.new()
	tv.base_pos = pos
	tv.crown_center = pos + Vector3(0.0, 1.28 * tree_scale, 0.0)
	var rxz: float = maxf(0.4, 0.50 * tree_scale)
	var ry: float = maxf(0.4, 0.55 * tree_scale)
	tv.inv_rxz = 1.0 / rxz
	tv.inv_ry = 1.0 / ry
	tv.trunk_radius = maxf(0.25, 0.30 * tree_scale)
	tv.trunk_min_y = pos.y + 0.45 * tree_scale
	tv.trunk_max_y = pos.y + 1.35 * tree_scale
	_nearby_trees.append(tv)


func _collect_from_multimesh_children(spawner_node: Node3D, origin: Vector3, max_r_sq: float) -> void:
	for child: Node in spawner_node.get_children():
		var mmi: MultiMeshInstance3D = child as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null:
			continue
		var mm: MultiMesh = mmi.multimesh
		var count: int = mm.instance_count
		if count <= 0:
			continue
		var mesh_h: float = 1.85
		if mm.mesh != null:
			var aabb_h: float = mm.mesh.get_aabb().size.y
			if aabb_h > 0.05:
				mesh_h = aabb_h
		for i: int in range(count):
			var inst_t: Transform3D = mm.get_instance_transform(i)
			var w_pos: Vector3 = mmi.to_global(inst_t.origin)
			var dx: float = w_pos.x - origin.x
			var dz: float = w_pos.z - origin.z
			if (dx * dx + dz * dz) > max_r_sq:
				continue
			var world_h: float = mesh_h * inst_t.basis.get_scale().y
			var est_scale: float = maxf(1.0, world_h / 1.85)
			_register_tree_volume(w_pos, est_scale, origin, max_r_sq)


func _collect_nearby_trees(origin: Vector3) -> void:
	_nearby_trees.clear()
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return

	var reach: float = max_distance + 18.0
	var max_r_sq: float = reach * reach

	# Note Godot 4 : find_children filtre uniquement les types C++ ClassDB ("Node3D"),
	# on teste donc les scripts GDScript MeshSpawner / MarkerTreeSpawnerComponent sur chaque Node3D.
	for nd: Node in tree.root.find_children("*", "Node3D", true, false):
		var nd3d: Node3D = nd as Node3D
		if nd3d == null or not is_instance_valid(nd3d):
			continue

		if nd3d is MeshSpawner or "spawned_tree_instances" in nd3d:
			var arr_var: Variant = nd3d.get("spawned_tree_instances")
			var arr: Array = arr_var as Array if arr_var is Array else []
			if not arr.is_empty():
				for item: Variant in arr:
					if item is Dictionary:
						var d: Dictionary = item as Dictionary
						var p: Vector3 = d.get("pos", Vector3.ZERO) as Vector3
						var s: float = float(d.get("scale", 10.0))
						_register_tree_volume(p, s, origin, max_r_sq)
			else:
				_collect_from_multimesh_children(nd3d, origin, max_r_sq)

		elif nd3d is MarkerTreeSpawnerComponent or "_spawned_instances_data" in nd3d:
			var m_var: Variant = nd3d.get("_spawned_instances_data")
			var m_arr: Array = m_var as Array if m_var is Array else []
			if not m_arr.is_empty():
				for item_m: Variant in m_arr:
					if item_m is Dictionary:
						var dm: Dictionary = item_m as Dictionary
						var wp: Vector3 = dm.get("world_pos", Vector3.ZERO) as Vector3
						var sm: float = float(dm.get("scale", 24.0))
						_register_tree_volume(wp, sm, origin, max_r_sq)
			else:
				_collect_from_multimesh_children(nd3d, origin, max_r_sq)

		elif nd3d.scene_file_path != "" and nd3d.scene_file_path.findn("tree") != -1:
			var sc_y: float = maxf(1.0, nd3d.global_transform.basis.get_scale().y)
			_register_tree_volume(nd3d.global_position, sc_y, origin, max_r_sq)


func _raycast_tree_foliage(seg_from: Vector3, seg_to: Vector3) -> Dictionary:
	if _nearby_trees.is_empty():
		return {}
	var seg_vec: Vector3 = seg_to - seg_from
	if seg_vec.length_squared() < 0.000001:
		return {}

	var best_t: float = 2.0
	var best_pos: Vector3 = Vector3.ZERO
	var best_normal: Vector3 = Vector3.UP

	for tv: TreeVolume in _nearby_trees:
		# 1) Ellipsoïde du feuillage et des branches (center = pos + (0, 1.28*s, 0), rxz = 0.50*s, ry = 0.55*s)
		var p0: Vector3 = Vector3(
			(seg_from.x - tv.crown_center.x) * tv.inv_rxz,
			(seg_from.y - tv.crown_center.y) * tv.inv_ry,
			(seg_from.z - tv.crown_center.z) * tv.inv_rxz
		)
		var d: Vector3 = Vector3(
			seg_vec.x * tv.inv_rxz,
			seg_vec.y * tv.inv_ry,
			seg_vec.z * tv.inv_rxz
		)
		var a: float = d.length_squared()
		if a > 0.000001:
			var b: float = 2.0 * p0.dot(d)
			var c: float = p0.length_squared() - 1.0
			var disc: float = b * b - 4.0 * a * c
			if disc >= 0.0:
				var t_enter: float = (-b - sqrt(disc)) / (2.0 * a)
				if t_enter >= 0.0 and t_enter <= 1.0 and t_enter < best_t:
					best_t = t_enter
					best_pos = seg_from + seg_vec * t_enter
					var n_raw: Vector3 = Vector3(
						(best_pos.x - tv.crown_center.x) * tv.inv_rxz * tv.inv_rxz,
						(best_pos.y - tv.crown_center.y) * tv.inv_ry * tv.inv_ry,
						(best_pos.z - tv.crown_center.z) * tv.inv_rxz * tv.inv_rxz
					)
					best_normal = n_raw.normalized() if n_raw.length_squared() > 0.0001 else -seg_vec.normalized()
				elif c < 0.0:
					# Si le joueur est déjà sous le bord externe d'un grand feuillage, permet d'accrocher le cœur des branches
					var c_inner: float = p0.length_squared() - 0.3025
					var disc_in: float = b * b - 4.0 * a * c_inner
					if disc_in >= 0.0:
						var t_in: float = (-b - sqrt(disc_in)) / (2.0 * a)
						if t_in >= 0.0 and t_in <= 1.0 and t_in < best_t:
							best_t = t_in
							best_pos = seg_from + seg_vec * t_in
							var n_in: Vector3 = best_pos - tv.crown_center
							best_normal = n_in.normalized() if n_in.length_squared() > 0.0001 else -seg_vec.normalized()

		# 2) Partie haute du tronc (0.45*s .. 1.35*s, rayon 0.30*s)
		var ox: float = seg_from.x - tv.base_pos.x
		var oz: float = seg_from.z - tv.base_pos.z
		var a_xz: float = seg_vec.x * seg_vec.x + seg_vec.z * seg_vec.z
		if a_xz > 0.000001:
			var b_xz: float = 2.0 * (ox * seg_vec.x + oz * seg_vec.z)
			var c_xz: float = ox * ox + oz * oz - tv.trunk_radius * tv.trunk_radius
			var disc_xz: float = b_xz * b_xz - 4.0 * a_xz * c_xz
			if disc_xz >= 0.0:
				var t_cyl: float = (-b_xz - sqrt(disc_xz)) / (2.0 * a_xz)
				if t_cyl >= 0.0 and t_cyl <= 1.0 and t_cyl < best_t:
					var hit_y: float = seg_from.y + seg_vec.y * t_cyl
					if hit_y >= tv.trunk_min_y and hit_y <= tv.trunk_max_y:
						best_t = t_cyl
						best_pos = seg_from + seg_vec * t_cyl
						var n_cyl: Vector3 = Vector3(best_pos.x - tv.base_pos.x, 0.0, best_pos.z - tv.base_pos.z)
						best_normal = n_cyl.normalized() if n_cyl.length_squared() > 0.0001 else Vector3.UP

	if best_t <= 1.0:
		return {
			"position": best_pos,
			"normal": best_normal,
			"t": best_t
		}
	return {}


func _compute_crosshair_aim_point(origin: Vector3, dir: Vector3) -> Vector3:
	var fallback: Vector3 = origin + dir * max_distance
	var best_pt: Vector3 = fallback
	var best_dist: float = max_distance + 1.0

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state != null:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			origin,
			fallback,
			393,
			_exclude_rids
		)
		q.collide_with_areas = true
		q.collide_with_bodies = true
		var res: Dictionary = space_state.intersect_ray(q)
		if not res.is_empty() and res.has("position"):
			var p_phys: Vector3 = res["position"] as Vector3
			best_dist = origin.distance_to(p_phys)
			best_pt = p_phys

	var fol_hit: Dictionary = _raycast_tree_foliage(origin, fallback)
	if not fol_hit.is_empty():
		var p_fol: Vector3 = fol_hit["position"] as Vector3
		var d_fol: float = origin.distance_to(p_fol)
		if d_fol < best_dist:
			best_dist = d_fol
			best_pt = p_fol

	return best_pt


func _get_hand_world_pos() -> Vector3:
	if _hand_node != null and is_instance_valid(_hand_node):
		return _hand_node.global_position
	if _caster != null and is_instance_valid(_caster):
		return _caster.global_position + Vector3(0.0, 1.25, 0.0)
	return global_position


func _process(_delta: float) -> void:
	if _state == GrappleState.INACTIVE:
		return
	if _caster == null or not is_instance_valid(_caster):
		return
	var hand_pos: Vector3 = _get_hand_world_pos()
	var width_scale: float = 1.0
	if _state == GrappleState.RETRACT:
		width_scale = maxf(0.15, 1.0 - (_phase_elapsed / maxf(0.04, retract_duration)))
	_update_tether_visuals(hand_pos, _tip_pos, width_scale)


func _physics_process(delta: float) -> void:
	if _state == GrappleState.INACTIVE:
		return
	if _caster == null or not is_instance_valid(_caster) or _caster.get("is_dead") == true:
		_restore_player_state()
		queue_free()
		return

	match _state:
		GrappleState.FLYING:
			_step_flying(delta)
		GrappleState.REEL_ANCHOR:
			_step_reel_anchor(delta)
		GrappleState.RETRACT:
			_step_retract(delta)


func _step_flying(delta: float) -> void:
	var remaining: float = max_distance - _distance_travelled
	if remaining <= 0.001:
		_begin_retract()
		return

	var step_dist: float = minf(projectile_speed * delta, remaining)
	var prev_pos: Vector3 = _tip_pos
	var next_pos: Vector3 = prev_pos + _fly_dir * step_dist

	var fol_hit: Dictionary = _raycast_tree_foliage(prev_pos, next_pos)
	var has_fol: bool = not fol_hit.is_empty()
	var fol_dist: float = prev_pos.distance_to(fol_hit["position"] as Vector3) if has_fol else 99999.0

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state != null:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			prev_pos,
			next_pos,
			393,
			_exclude_rids
		)
		q.collide_with_areas = true
		q.collide_with_bodies = true
		var hit: Dictionary = space_state.intersect_ray(q)
		if not hit.is_empty():
			var hit_pos: Vector3 = hit.get("position", next_pos) as Vector3
			var phys_dist: float = prev_pos.distance_to(hit_pos)

			# Si le feuillage / branche d'arbre a été coupé AVANT l'impact physique plus lointain
			if has_fol and fol_dist < phys_dist:
				_latch_onto_environment(
					fol_hit["position"] as Vector3,
					fol_hit["normal"] as Vector3
				)
				return

			var hit_normal: Vector3 = hit.get("normal", Vector3.UP) as Vector3
			var col_obj: Object = hit.get("collider") as Object
			var resolved: Dictionary = _classify_hit_collider(col_obj)
			var kind: String = str(resolved.get("kind", "none"))

			if kind == "enemy":
				var hb_hit: HitboxComponent = resolved.get("hitbox") as HitboxComponent
				_hit_enemy_and_retract(hb_hit, hit_pos)
				return
			elif kind == "env":
				_latch_onto_environment(hit_pos, hit_normal)
				return

		if has_fol:
			_latch_onto_environment(
				fol_hit["position"] as Vector3,
				fol_hit["normal"] as Vector3
			)
			return

		# Légère aide à la visée sur les HitboxComponent ennemies en vol libre
		var mid_assist: Dictionary = _query_enemy_hitbox_near(space_state, next_pos)
		if not mid_assist.is_empty():
			var m_hb: HitboxComponent = mid_assist.get("hitbox") as HitboxComponent
			_hit_enemy_and_retract(m_hb, next_pos)
			return

	elif has_fol:
		_latch_onto_environment(
			fol_hit["position"] as Vector3,
			fol_hit["normal"] as Vector3
		)
		return

	_tip_pos = next_pos
	_distance_travelled += step_dist
	if _distance_travelled >= max_distance - 0.01:
		_begin_retract()


func _classify_hit_collider(col_obj: Object) -> Dictionary:
	# IMPORTANT : Les troncs d'arbres de MeshSpawner et MarkerTreeSpawnerComponent sont créés via
	# PhysicsServer3D.body_create() sans Node -> `collider` vaut `null` alors que le raycast a bien touché !
	if col_obj == null:
		return {"kind": "env"}

	var hb: HitboxComponent = col_obj as HitboxComponent
	if hb != null:
		var ent: Node = hb.owner if hb.owner != null else hb.get_parent()
		if ent == null or ent == _caster or ent.is_in_group("Player"):
			return {"kind": "none"}
		return {
			"kind": "enemy",
			"mob": ent as Node3D,
			"hitbox": hb
		}

	var col_node: Node = col_obj as Node
	if col_node == null:
		return {"kind": "env"}
	if col_node == _caster or col_node.is_in_group("Player"):
		return {"kind": "none"}

	var check: Node = col_node
	while check != null:
		if check.is_in_group("Player"):
			return {"kind": "none"}
		if check.is_in_group("Enemie") or check.is_in_group("Boss"):
			var mob_3d: Node3D = check as Node3D
			return {
				"kind": "enemy",
				"mob": mob_3d,
				"hitbox": _find_mob_hitbox(mob_3d)
			}
		check = check.get_parent()

	return {"kind": "env"}


func _query_enemy_hitbox_near(space_state: PhysicsDirectSpaceState3D, center: Vector3) -> Dictionary:
	var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	params.shape = _assist_sphere
	params.transform = Transform3D(Basis.IDENTITY, center)
	params.collision_mask = 8
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.exclude = _exclude_rids

	var hits: Array[Dictionary] = space_state.intersect_shape(params, 6)
	for entry: Dictionary in hits:
		var hb: HitboxComponent = entry.get("collider") as HitboxComponent
		if hb == null:
			continue
		var ent: Node = hb.owner if hb.owner != null else hb.get_parent()
		if ent == null or ent == _caster or ent.is_in_group("Player"):
			continue
		if ent.get("is_dead") == true:
			continue
		return {
			"mob": ent as Node3D,
			"hitbox": hb
		}
	return {}


func _hit_enemy_and_retract(hb: HitboxComponent, hit_pos: Vector3) -> void:
	_tip_pos = hit_pos
	_spawn_latch_ring(hit_pos, -_fly_dir)
	SpellAudioManager.play_ice_cast(self, hit_pos, 0.94, -1.5)

	if _is_auth and attack_component != null and hb != null:
		attack_component.global_position = hit_pos
		if _fly_dir.length_squared() > 0.001:
			var up_ref: Vector3 = Vector3.UP if absf(_fly_dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
			attack_component.look_at(hit_pos + _fly_dir, up_ref)
		hb.receive_hit(attack_component)

	_begin_retract()


func _latch_onto_environment(hit_pos: Vector3, hit_normal: Vector3) -> void:
	_anchor_pos = hit_pos
	_tip_pos = hit_pos
	_phase_elapsed = 0.0

	_spawn_latch_ring(hit_pos, hit_normal)
	SpellAudioManager.play_ice_cast(self, hit_pos, 1.24, -2.2)

	if _caster_body != null and _is_auth:
		var chest_pos: Vector3 = _caster_body.global_position + Vector3(0.0, 0.9, 0.0)
		var to_anchor: Vector3 = _anchor_pos - chest_pos
		_initial_anchor_dist = to_anchor.length()
		if _initial_anchor_dist > 0.05:
			_anchor_dir_3d = to_anchor / _initial_anchor_dist
		else:
			_anchor_dir_3d = _fly_dir

		# Si déjà très proche (< 2.2m), impulsion immédiate vers le point d'ancrage sans phase de traction
		if _initial_anchor_dist < 2.2:
			_apply_directional_anchor_impulse()
			_begin_retract()
			return

		_begin_motion_override()

	_state = GrappleState.REEL_ANCHOR


func _step_reel_anchor(delta: float) -> void:
	_phase_elapsed += delta
	_tip_pos = _anchor_pos

	if not _is_auth or _caster_body == null:
		if _phase_elapsed >= reel_duration:
			_begin_retract()
		return

	_add_enemy_exceptions()

	var chest_pos: Vector3 = _caster_body.global_position + Vector3(0.0, 0.9, 0.0)
	var to_anchor: Vector3 = _anchor_pos - chest_pos
	var dist_to_anchor: float = to_anchor.length()

	if _phase_elapsed < reel_duration and dist_to_anchor >= 2.2:
		var dir_3d: Vector3 = to_anchor / maxf(0.01, dist_to_anchor)
		_anchor_dir_3d = dir_3d
		var vel: Vector3 = dir_3d * reel_speed
		if _caster_body.is_on_floor() and vel.y < 1.8:
			vel.y = 1.8
		_caster_body.velocity = vel
		_caster_body.move_and_slide()
		return

	_restore_player_state()
	_apply_directional_anchor_impulse()
	_begin_retract()


func _apply_directional_anchor_impulse() -> void:
	if _caster_body == null or not is_instance_valid(_caster_body) or not _is_auth:
		return

	var chest_pos: Vector3 = _caster_body.global_position + Vector3(0.0, 0.9, 0.0)
	var to_anchor: Vector3 = _anchor_pos - chest_pos
	var rem_dist: float = to_anchor.length()
	var dir_3d: Vector3 = (to_anchor / rem_dist) if rem_dist > 0.30 else _anchor_dir_3d
	if dir_3d.length_squared() < 0.001:
		dir_3d = _fly_dir

	var ref_dist: float = maxf(_initial_anchor_dist, rem_dist)
	var impulse_speed: float = clampf(16.0 + ref_dist * 0.32, 17.0, 25.5)
	var launch_vel: Vector3 = dir_3d * impulse_speed

	# En hauteur (branche / feuillage) : léger coup de pouce vertical pour franchir la branche
	if dir_3d.y > 0.35:
		launch_vel.y += 2.0
	elif launch_vel.y < 2.6:
		# Au sol ou à plat : juste de quoi décoller du frottement du sol sans jamais catapulter vers le ciel !
		launch_vel.y = maxf(launch_vel.y, 2.6)

	if _caster_body.has_method("apply_air_launch"):
		_caster_body.call("apply_air_launch", launch_vel)
	else:
		_caster_body.velocity = launch_vel

	SpellAudioManager.play_ice_windup(self, _caster_body.global_position, 1.18, -1.5)


func _begin_retract() -> void:
	_restore_player_state()
	_retract_start_pos = _tip_pos
	_phase_elapsed = 0.0
	_state = GrappleState.RETRACT


func _step_retract(delta: float) -> void:
	_phase_elapsed += delta
	var u: float = clampf(_phase_elapsed / maxf(0.04, retract_duration), 0.0, 1.0)
	var hand_pos: Vector3 = _get_hand_world_pos()
	_tip_pos = _retract_start_pos.lerp(hand_pos, u * u)
	if u >= 1.0:
		_state = GrappleState.INACTIVE
		queue_free()


func _begin_motion_override() -> void:
	if _motion_overridden or _caster_body == null or not _is_auth:
		return
	_motion_overridden = true
	_saved_collision_layer = _caster_body.collision_layer
	_saved_collision_mask = _caster_body.collision_mask
	_caster_body.set("external_motion_override", true)
	_caster_body.collision_layer = 0
	_caster_body.collision_mask = _saved_collision_mask & ~256
	_add_enemy_exceptions()


func _add_enemy_exceptions() -> void:
	if _caster_body == null or not is_instance_valid(_caster_body):
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group("Enemie"):
		var pb: PhysicsBody3D = node as PhysicsBody3D
		if pb != null and is_instance_valid(pb) and not _exception_bodies.has(pb):
			_caster_body.add_collision_exception_with(pb)
			_exception_bodies.append(pb)
	for boss_node: Node in tree.get_nodes_in_group("Boss"):
		var b_pb: PhysicsBody3D = boss_node as PhysicsBody3D
		if b_pb != null and is_instance_valid(b_pb) and not _exception_bodies.has(b_pb):
			_caster_body.add_collision_exception_with(b_pb)
			_exception_bodies.append(b_pb)


func _restore_player_state() -> void:
	if not _motion_overridden:
		return
	_motion_overridden = false

	if _caster_body != null and is_instance_valid(_caster_body) and _is_auth:
		for pb: PhysicsBody3D in _exception_bodies:
			if pb != null and is_instance_valid(pb):
				_caster_body.remove_collision_exception_with(pb)
		_exception_bodies.clear()
		_caster_body.collision_layer = _saved_collision_layer
		_caster_body.collision_mask = _saved_collision_mask
		_caster_body.set("external_motion_override", false)
	else:
		_exception_bodies.clear()


func _exit_tree() -> void:
	_restore_player_state()


func _spawn_latch_ring(pos: Vector3, normal: Vector3) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.mesh = _anchor_ring_mesh
	ring.material_override = _rune_strand_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tree.root.add_child(ring)
	ring.global_position = pos
	var n_clean: Vector3 = normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	var up_ref: Vector3 = Vector3.UP if absf(n_clean.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	ring.look_at(pos + n_clean, up_ref)
	ring.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	ring.scale = Vector3.ONE * 0.4
	var tw: Tween = ring.create_tween()
	tw.tween_property(ring, "scale", Vector3.ONE * 1.65, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(ring.queue_free)


func _update_tether_visuals(p_start: Vector3, p_end: Vector3, width_mult: float) -> void:
	var diff: Vector3 = p_end - p_start
	var dist: float = diff.length()
	if dist < 0.08:
		_tip_holder.visible = false
		for i_hide: int in range(TETHER_SEGMENTS):
			_bark_segs[i_hide].visible = false
			_rune_segs[i_hide].visible = false
		return

	var fwd: Vector3 = diff / dist
	var up_ref: Vector3 = Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var side_ax: Vector3 = up_ref.cross(fwd).normalized()
	var perp_ax: Vector3 = fwd.cross(side_ax).normalized()

	_tip_holder.visible = (_state != GrappleState.RETRACT)
	_tip_holder.global_position = p_end
	_tip_holder.look_at(p_end + fwd, up_ref)

	var wave_amp: float = 0.0
	if _state == GrappleState.FLYING:
		wave_amp = 0.10 * clampf(1.0 - (_distance_travelled / max_distance) * 0.4, 0.25, 1.0)

	var bark_pts: PackedVector3Array = PackedVector3Array()
	var rune_pts: PackedVector3Array = PackedVector3Array()
	bark_pts.resize(TETHER_SEGMENTS + 1)
	rune_pts.resize(TETHER_SEGMENTS + 1)

	var phase_t: float = float(Time.get_ticks_msec()) * 0.012
	for s: int in range(TETHER_SEGMENTS + 1):
		var frac: float = float(s) / float(TETHER_SEGMENTS)
		var base_p: Vector3 = p_start.lerp(p_end, frac)
		var env: float = sin(frac * PI)
		var whip_off: Vector3 = side_ax * (sin(frac * TAU * 1.5 - phase_t) * wave_amp * env)
		var b_p: Vector3 = base_p + whip_off
		bark_pts[s] = b_p

		var twist_ang: float = frac * TAU * 2.5 + phase_t * 0.4
		var spiral_r: float = 0.048 * width_mult * (0.35 + 0.65 * env)
		var r_p: Vector3 = b_p + (side_ax * cos(twist_ang) + perp_ax * sin(twist_ang)) * spiral_r
		rune_pts[s] = r_p

	var bark_r: float = 0.042 * width_mult
	var rune_r: float = 0.018 * width_mult

	for i: int in range(TETHER_SEGMENTS):
		_place_cylinder_segment(_bark_segs[i], bark_pts[i], bark_pts[i + 1], bark_r)
		_place_cylinder_segment(_rune_segs[i], rune_pts[i], rune_pts[i + 1], rune_r)


func _place_cylinder_segment(mi: MeshInstance3D, a: Vector3, b: Vector3, radius: float) -> void:
	var seg_vec: Vector3 = b - a
	var seg_len: float = seg_vec.length()
	if seg_len < 0.002:
		mi.visible = false
		return
	mi.visible = true
	var y_ax: Vector3 = seg_vec / seg_len
	var up_ref: Vector3 = Vector3.UP if absf(y_ax.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var x_ax: Vector3 = up_ref.cross(y_ax).normalized()
	var z_ax: Vector3 = x_ax.cross(y_ax).normalized()
	var mid: Vector3 = a.lerp(b, 0.5)
	mi.global_transform = Transform3D(Basis(x_ax * radius, y_ax * seg_len, z_ax * radius), mid)
