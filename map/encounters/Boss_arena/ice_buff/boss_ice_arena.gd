class_name BossIceArena
extends Node3D

## Contrôleur du Buff Boss Glace (activé si au moins 1 Totem Glace a été complété) :
## - Arme le buff au spawn de l'Ogre (+PV max par totem + aura glaciale sur le boss).
## - Au cri de Phase 2 de l'Ogre (`on_boss_phase2_roar`), propage une onde circulaire de gel
##   sur toute l'emprise exacte (`Path3D`) de l'arène en 1 seule draw call (`boss_frozen_floor.gdshader`).
## - Expose `BossIceArena.get_ice_physics_at(world_pos)` en O(1) pour la physique de glissade du joueur.
## - Désactive immédiatement la glissade à la mort du boss (`stop_effect()`) et fait fondre la glace en douceur.

static var _active_frozen_arenas: Array = []

@export_category("Arène de Glace du Boss")

@export_group("Glissade & Physique sur Glace (Sliders)")
## Friction au sol sur la glace quand le joueur lâche les touches (35.0 sur sol normal -> glissade fluide)
@export_range(0.3, 12.0, 0.1) var ice_friction: float = 2.2
## Accélération sur la glace (40.0 sur sol normal -> inertie naturelle en virage)
@export_range(2.0, 28.0, 0.5) var ice_acceleration: float = 9.5
## Multiplicateur d'accélération en contre-braquage quand le joueur pousse à l'opposé de sa glissade
@export_range(0.5, 2.5, 0.05) var ice_reverse_brake_mult: float = 1.35
## Léger gain d'élan maximal de patinage sur la glace
@export_range(1.0, 1.5, 0.02) var ice_max_speed_mult: float = 1.12
## Bonus supplémentaire de glissance par totem de glace au-delà du 1er (2+ totems complétés)
@export_range(0.0, 0.6, 0.02) var extra_totem_slipperiness_bonus: float = 0.20

@export_group("Onde de Gel & Rendu")
## Durée d'expansion de l'onde de gel depuis l'Ogre jusqu'au fond de l'arène (en secondes)
@export_range(0.3, 5.0, 0.1, "suffix:s") var freeze_expand_duration: float = 1.4
## Durée de fonte visuelle de la glace à la mort du boss (en secondes)
@export_range(0.2, 3.0, 0.1, "suffix:s") var thaw_duration: float = 1.0
## Largeur du fondu progressif de la glace au pied du mur d'arbres (en mètres)
@export_range(0.5, 14.0, 0.5, "suffix:m") var edge_fade_width: float = 4.5
## Légère élévation du maillage de glace au-dessus du sol de l'arène (en mètres)
@export_range(0.01, 0.15, 0.005, "suffix:m") var floor_height_offset: float = 0.035
## Optionnel : Path3D explicite délimitant l'arène (sinon détecté automatiquement dans BossArena)
@export var custom_arena_path: Path3D = null

@export_group("Buff Direct sur l'Ogre & Debug")
## Bonus de PV max accordé à l'Ogre par totem de glace complété (0.15 = +15% PV max / totem)
@export_range(0.0, 1.0, 0.05) var boss_hp_bonus_per_totem: float = 0.15
@export var boss_aura_vfx_scene: PackedScene = preload("res://scripts/status_effects/ice_enchant/ice_enchant_vfx.tscn")
@export var ice_floor_shader: Shader = preload("res://map/encounters/Boss_arena/ice_buff/boss_frozen_floor.gdshader")
@export var cracks_texture: Texture2D = preload("res://assets/LeLu's Noise Pack/T_Cracks336_transparent.png")
## Si coché, gèle immédiatement toute l'arène dès l'apparition du boss (sans attendre 50% PV)
@export var debug_freeze_on_engage: bool = false

var is_ice_buff_armed: bool = false
var active_totem_stacks: int = 0

var _is_floor_frozen: bool = false
var _is_thawing: bool = false
var _thaw_alpha: float = 1.0

var _tracked_boss: Node3D = null
var _boss_aura_instance: Node3D = null

var _ice_mesh_instance: MeshInstance3D = null
var _ice_shader_material: ShaderMaterial = null

var _arena_poly_2d: PackedVector2Array = PackedVector2Array()
var _local_aabb_2d: Rect2 = Rect2()
var _arena_ground_y: float = 0.0
var _freeze_origin_world: Vector3 = Vector3.ZERO
var _current_freeze_radius: float = 0.0
var _target_freeze_radius: float = 160.0

var _geometry_built: bool = false
var _last_built_global_xform: Transform3D = Transform3D.IDENTITY
var _cached_physics_dict: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_ensure_visual_nodes()
	_refresh_physics_dict()
	call_deferred("_prepare_arena_geometry")


func _exit_tree() -> void:
	_active_frozen_arenas.erase(self)
	if _boss_aura_instance != null and is_instance_valid(_boss_aura_instance):
		_boss_aura_instance.queue_free()
	_boss_aura_instance = null


## Interrogation statique ultra-rapide O(1) appelée par `player.gd` dans `_physics_process`
static func get_ice_physics_at(world_pos: Vector3) -> Dictionary:
	if _active_frozen_arenas.is_empty():
		return {}

	for i: int in range(_active_frozen_arenas.size() - 1, -1, -1):
		var raw_arena: Variant = _active_frozen_arenas[i]
		if raw_arena == null or not is_instance_valid(raw_arena):
			_active_frozen_arenas.remove_at(i)
			continue
		var arena: BossIceArena = raw_arena as BossIceArena
		if arena == null or not arena._is_floor_frozen:
			continue

		# 1. Vérification verticale rapide autour de l'altitude du sol de l'arène
		if absf(world_pos.y - arena._arena_ground_y) > 2.5:
			continue

		# 2. Vérification circulaire par rapport au front actuel de l'onde de gel
		var dx: float = world_pos.x - arena._freeze_origin_world.x
		var dz: float = world_pos.z - arena._freeze_origin_world.z
		var r: float = arena._current_freeze_radius
		if (dx * dx + dz * dz) > (r * r):
			continue

		# 3. Vérification AABB 2D rapide dans le repère local de l'arène
		var local_pos: Vector3 = arena.to_local(world_pos)
		var pt_local_2d := Vector2(local_pos.x, local_pos.z)
		if not arena._local_aabb_2d.has_point(pt_local_2d):
			continue

		# 4. Test exact d'appartenance au polygone de l'arène
		if arena._arena_poly_2d.size() < 3 or not Geometry2D.is_point_in_polygon(pt_local_2d, arena._arena_poly_2d):
			continue

		return arena._cached_physics_dict

	return {}


## Appelé par BossArena côté serveur/solo quand le boss apparaît (ou si un totem Glace est complété en cours de combat)
func activate_for_boss(boss: Node3D, totem_stacks: int) -> void:
	if boss == null or not is_instance_valid(boss) or totem_stacks <= 0:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	_tracked_boss = boss
	active_totem_stacks = totem_stacks
	is_ice_buff_armed = true
	_refresh_physics_dict()

	# Bonus de PV max sur l'Ogre par totem de glace complété
	if boss_hp_bonus_per_totem > 0.0:
		var stats_comp: StatsComponent = boss.get_node_or_null("StatsComponent") as StatsComponent
		if stats_comp != null:
			var total_hp_bonus: float = boss_hp_bonus_per_totem * float(totem_stacks)
			stats_comp.set_or_update_modifier("max_health", StatModifierData.ModType.PERCENT, total_hp_bonus, "TOTEM_ICE_BOSS")

	# Synchroniser l'état armé et l'aura glaciale sur tous les pairs
	var boss_path: NodePath = boss.get_path()
	if multiplayer.has_multiplayer_peer():
		_rpc_arm_ice_buff_client_state.rpc(boss_path, totem_stacks)
	else:
		_rpc_arm_ice_buff_client_state(boss_path, totem_stacks)

	print("[BossIceArena] Buff Glace armé sur '%s' (totems glace = %d, debug_engage = %s)." % [
		boss.name, totem_stacks, str(debug_freeze_on_engage)
	])

	# Déclenchement immédiat si mode debug activé ou si le boss a déjà poussé son cri de Phase 2
	var already_phase2: bool = bool(boss.get("_has_midlife_roared")) if "_has_midlife_roared" in boss else false
	if (debug_freeze_on_engage or already_phase2) and not _is_floor_frozen:
		on_boss_phase2_roar(boss.global_position)


@rpc("authority", "call_local", "reliable")
func _rpc_arm_ice_buff_client_state(boss_path: NodePath, totem_stacks: int) -> void:
	active_totem_stacks = totem_stacks
	is_ice_buff_armed = true
	_refresh_physics_dict()
	if not _geometry_built:
		_prepare_arena_geometry()
	_resolve_and_attach_boss_aura(boss_path, 4)


func _resolve_and_attach_boss_aura(boss_path: NodePath, retries_left: int) -> void:
	if not is_ice_buff_armed or not is_inside_tree():
		return
	var boss: Node3D = get_node_or_null(boss_path) as Node3D
	if boss != null and is_instance_valid(boss):
		_tracked_boss = boss
		_attach_boss_ice_aura(boss)
		return
	if retries_left > 0 and get_tree() != null:
		get_tree().process_frame.connect(func() -> void:
			_resolve_and_attach_boss_aura(boss_path, retries_left - 1)
		, CONNECT_ONE_SHOT)


func _attach_boss_ice_aura(boss: Node3D) -> void:
	if _boss_aura_instance != null and is_instance_valid(_boss_aura_instance):
		return
	if boss_aura_vfx_scene == null:
		return
	var aura: Node3D = boss_aura_vfx_scene.instantiate() as Node3D
	if aura == null:
		return
	_boss_aura_instance = aura

	var status_comp: Node3D = boss.get_node_or_null("status_effect_componant") as Node3D
	if status_comp != null:
		status_comp.add_child(aura)
	else:
		boss.add_child(aura)
		aura.position = Vector3(0.0, 1.2, 0.0)
		aura.set_deferred("position", Vector3(0.0, 1.2, 0.0))

	# Appliquer scale = 1.65 aussi en différé après l'auto-alignement de ice_enchant_vfx.gd
	aura.scale = Vector3.ONE * 1.65
	aura.set_deferred("scale", Vector3.ONE * 1.65)


## Appelé lorsque l'Ogre pousse son cri de Phase 2 (`play_roar()`)
func on_boss_phase2_roar(roar_world_pos: Vector3 = Vector3.INF) -> void:
	if not is_ice_buff_armed or _is_floor_frozen:
		return

	var resolved_origin: Vector3 = roar_world_pos
	if not resolved_origin.is_finite():
		if _tracked_boss != null and is_instance_valid(_tracked_boss):
			resolved_origin = _tracked_boss.global_position
		else:
			resolved_origin = global_position

	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			_rpc_trigger_arena_freeze.rpc(resolved_origin)
	else:
		_rpc_trigger_arena_freeze(resolved_origin)


@rpc("authority", "call_local", "reliable")
func _rpc_trigger_arena_freeze(origin_pos: Vector3) -> void:
	if not _geometry_built or not _last_built_global_xform.is_equal_approx(global_transform):
		_prepare_arena_geometry()
	else:
		_arena_ground_y = _resolve_reference_ground_y()

	_ensure_visual_nodes()
	_refresh_physics_dict()

	_freeze_origin_world = Vector3(origin_pos.x, _arena_ground_y, origin_pos.z)
	_current_freeze_radius = 0.0
	_target_freeze_radius = _compute_required_freeze_radius(_freeze_origin_world)
	_thaw_alpha = 1.0
	_is_thawing = false
	_is_floor_frozen = true

	if not _active_frozen_arenas.has(self):
		_active_frozen_arenas.append(self)

	if _ice_shader_material != null:
		_ice_shader_material.set_shader_parameter("freeze_origin_world", _freeze_origin_world)
		_ice_shader_material.set_shader_parameter("current_freeze_radius", 0.0)
		_ice_shader_material.set_shader_parameter("thaw_alpha", 1.0)
	if _ice_mesh_instance != null:
		_ice_mesh_instance.visible = true

	print("[BossIceArena] Onde de gel déclenchée depuis %v (rayon cible = %.1fm en %.2fs) !" % [
		_freeze_origin_world, _target_freeze_radius, freeze_expand_duration
	])


## Appelé à la mort du boss : coupe immédiatement la glissade et fait fondre la plaque de glace en ~1.0s
func stop_effect() -> void:
	if not is_ice_buff_armed and not _is_floor_frozen:
		return
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			_rpc_stop_ice_effect.rpc()
	else:
		_rpc_stop_ice_effect()


func stop_ice_arena() -> void:
	stop_effect()


@rpc("authority", "call_local", "reliable")
func _rpc_stop_ice_effect() -> void:
	is_ice_buff_armed = false
	_is_floor_frozen = false
	_active_frozen_arenas.erase(self)
	_tracked_boss = null

	if _boss_aura_instance != null and is_instance_valid(_boss_aura_instance):
		_boss_aura_instance.queue_free()
	_boss_aura_instance = null

	if _ice_mesh_instance != null and _ice_mesh_instance.visible and _current_freeze_radius > 0.05:
		_is_thawing = true
	else:
		_is_thawing = false
		_thaw_alpha = 0.0
		if _ice_mesh_instance != null:
			_ice_mesh_instance.visible = false


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Surveillance serveur de la mort du boss (sécurité identique à BossLightningStorm)
	if is_ice_buff_armed and (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()):
		if _tracked_boss != null and (not is_instance_valid(_tracked_boss) or _is_boss_dead(_tracked_boss)):
			stop_effect()
			return

	# Expansion progressive du front de gel sur tous les pairs (serveur + clients)
	if _is_floor_frozen:
		_refresh_physics_dict()
		if _current_freeze_radius < _target_freeze_radius:
			var expand_speed: float = _target_freeze_radius / maxf(0.15, freeze_expand_duration)
			_current_freeze_radius = minf(_target_freeze_radius, _current_freeze_radius + expand_speed * delta)
			if _ice_shader_material != null:
				_ice_shader_material.set_shader_parameter("current_freeze_radius", _current_freeze_radius)

	# Fonte visuelle douce après la mort du boss
	if _is_thawing:
		var fade_speed: float = 1.0 / maxf(0.15, thaw_duration)
		_thaw_alpha = maxf(0.0, _thaw_alpha - fade_speed * delta)
		if _ice_shader_material != null:
			_ice_shader_material.set_shader_parameter("thaw_alpha", _thaw_alpha)
		if _thaw_alpha <= 0.001:
			_is_thawing = false
			_current_freeze_radius = 0.0
			if _ice_mesh_instance != null:
				_ice_mesh_instance.visible = false


func _refresh_physics_dict() -> void:
	var extra_stacks: int = maxi(active_totem_stacks - 1, 0)
	var slip_scale: float = 1.0 + extra_totem_slipperiness_bonus * float(extra_stacks)
	var eff_friction: float = maxf(0.25, ice_friction / slip_scale)
	var eff_accel: float = maxf(1.8, ice_acceleration / lerpf(1.0, slip_scale, 0.5))
	var eff_max_speed_mult: float = minf(1.55, ice_max_speed_mult + extra_totem_slipperiness_bonus * 0.25 * float(extra_stacks))

	_cached_physics_dict["on_ice"] = true
	_cached_physics_dict["friction"] = eff_friction
	_cached_physics_dict["acceleration"] = eff_accel
	_cached_physics_dict["reverse_brake_mult"] = ice_reverse_brake_mult
	_cached_physics_dict["max_speed_mult"] = eff_max_speed_mult


func _is_boss_dead(boss: Node3D) -> bool:
	var hc: HealthComponent = boss.get_node_or_null("HealthComponent") as HealthComponent
	if hc != null and hc.current_health <= 0.0:
		return true
	if "current_state" in boss and "State" in boss:
		var st_enum: Variant = boss.get("State")
		if typeof(st_enum) == TYPE_DICTIONARY and (st_enum as Dictionary).has("DEAD"):
			if int(boss.get("current_state")) == int((st_enum as Dictionary)["DEAD"]):
				return true
	return false


# ============================================================================
# CONSTRUCTION DU POLYGONE D'ARÈNE & MAILLAGE DE GLACE (1 SEULE DRAW CALL)
# ============================================================================

func _ensure_visual_nodes() -> void:
	if _ice_shader_material == null and ice_floor_shader != null:
		_ice_shader_material = ShaderMaterial.new()
		_ice_shader_material.shader = ice_floor_shader
		if cracks_texture != null:
			_ice_shader_material.set_shader_parameter("cracks_texture", cracks_texture)
			_ice_shader_material.set_shader_parameter("use_cracks_texture", 1.0)
		else:
			_ice_shader_material.set_shader_parameter("use_cracks_texture", 0.0)
		_ice_shader_material.set_shader_parameter("current_freeze_radius", 0.0)
		_ice_shader_material.set_shader_parameter("thaw_alpha", 1.0)

	if _ice_mesh_instance == null:
		_ice_mesh_instance = MeshInstance3D.new()
		_ice_mesh_instance.name = "FrozenFloorMesh"
		_ice_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ice_mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		_ice_mesh_instance.extra_cull_margin = 32.0
		_ice_mesh_instance.visible = false
		if _ice_shader_material != null:
			_ice_mesh_instance.material_override = _ice_shader_material
		add_child(_ice_mesh_instance)


func _prepare_arena_geometry() -> void:
	if not is_inside_tree():
		return

	_ensure_visual_nodes()
	_arena_ground_y = _resolve_reference_ground_y()
	_arena_poly_2d = _extract_arena_polygon_local_2d()

	var tri_indices: PackedInt32Array = Geometry2D.triangulate_polygon(_arena_poly_2d)
	if tri_indices.is_empty():
		var hull: PackedVector2Array = Geometry2D.convex_hull(_arena_poly_2d)
		if hull.size() > 3 and hull[hull.size() - 1].distance_to(hull[0]) < 0.05:
			hull.resize(hull.size() - 1)
		if hull.size() >= 3:
			_arena_poly_2d = hull
			tri_indices = Geometry2D.triangulate_polygon(_arena_poly_2d)

	if tri_indices.is_empty():
		_arena_poly_2d = _build_fallback_circle_polygon()
		tri_indices = Geometry2D.triangulate_polygon(_arena_poly_2d)

	_local_aabb_2d = _compute_polygon_aabb(_arena_poly_2d)
	var mesh: ArrayMesh = _build_ice_array_mesh(_arena_poly_2d, tri_indices)
	if _ice_mesh_instance != null:
		_ice_mesh_instance.mesh = mesh

	_last_built_global_xform = global_transform
	_geometry_built = true


func _find_arena_path_3d() -> Path3D:
	if custom_arena_path != null and is_instance_valid(custom_arena_path) and custom_arena_path.curve != null:
		return custom_arena_path

	var arena_root: Node = get_parent()
	if arena_root != null:
		for child: Node in arena_root.find_children("*", "Path3D", true, false):
			var p3d: Path3D = child as Path3D
			if p3d != null and p3d.curve != null and p3d.curve.point_count >= 3:
				return p3d

	for child_self: Node in find_children("*", "Path3D", true, false):
		var p3d_self: Path3D = child_self as Path3D
		if p3d_self != null and p3d_self.curve != null and p3d_self.curve.point_count >= 3:
			return p3d_self

	return null


func _extract_arena_polygon_local_2d() -> PackedVector2Array:
	var path_node: Path3D = _find_arena_path_3d()
	if path_node == null or path_node.curve == null:
		return _build_fallback_circle_polygon()

	var baked: PackedVector3Array = path_node.curve.get_baked_points()
	if baked.size() < 3:
		return _build_fallback_circle_polygon()

	# 1. Nettoyage des doublons proches (< 0.25m) dans le repère local 2D (XZ)
	var cleaned: Array[Vector2] = []
	for pt: Vector3 in baked:
		var local_pt: Vector3 = to_local(path_node.to_global(pt))
		var p2 := Vector2(local_pt.x, local_pt.z)
		if cleaned.is_empty() or p2.distance_to(cleaned[cleaned.size() - 1]) >= 0.25:
			cleaned.append(p2)

	while cleaned.size() > 3 and cleaned[cleaned.size() - 1].distance_to(cleaned[0]) < 0.25:
		cleaned.pop_back()

	if cleaned.size() < 3:
		return _build_fallback_circle_polygon()

	# 2. Simplification des points intermédiaires colinéaires par rapport au dernier sommet retenu
	#    afin d'accélérer is_point_in_polygon tout en préservant les courbes douces au centimètre près.
	var simplified: PackedVector2Array = PackedVector2Array()
	var n: int = cleaned.size()
	simplified.append(cleaned[0])
	for i: int in range(1, n):
		var anchor: Vector2 = simplified[simplified.size() - 1]
		var p_curr: Vector2 = cleaned[i]
		var p_next: Vector2 = cleaned[(i + 1) % n]
		var seg: Vector2 = p_next - anchor
		var seg_len_sq: float = seg.length_squared()
		if seg_len_sq > 0.0001 and seg_len_sq < (22.0 * 22.0):
			var t: float = clampf((p_curr - anchor).dot(seg) / seg_len_sq, 0.0, 1.0)
			var proj: Vector2 = anchor + seg * t
			if p_curr.distance_to(proj) < 0.03:
				continue
		simplified.append(p_curr)

	if simplified.size() < 3:
		var fallback_packed := PackedVector2Array()
		for v: Vector2 in cleaned:
			fallback_packed.append(v)
		return fallback_packed

	return simplified


func _build_fallback_circle_polygon() -> PackedVector2Array:
	var poly := PackedVector2Array()
	var center := Vector2(0.0, -60.0)
	var radius: float = 68.0
	var sides: int = 48
	poly.resize(sides)
	for i: int in range(sides):
		var angle: float = (TAU * float(i)) / float(sides)
		poly[i] = center + Vector2(cos(angle) * radius, sin(angle) * radius)
	return poly


func _compute_polygon_aabb(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var min_p: Vector2 = poly[0]
	var max_p: Vector2 = poly[0]
	for p: Vector2 in poly:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	return Rect2(min_p, max_p - min_p).grow(0.5)


func _compute_required_freeze_radius(origin_world: Vector3) -> float:
	var max_r: float = 160.0
	for p_local: Vector2 in _arena_poly_2d:
		var wp: Vector3 = to_global(Vector3(p_local.x, 0.0, p_local.y))
		var d2d: float = Vector2(wp.x - origin_world.x, wp.z - origin_world.z).length()
		if d2d + 8.0 > max_r:
			max_r = d2d + 8.0
	return max_r


func _build_ice_array_mesh(poly_2d: PackedVector2Array, base_tris: PackedInt32Array) -> ArrayMesh:
	var verts: Array[Vector2] = []
	verts.resize(poly_2d.size())
	for i: int in range(poly_2d.size()):
		verts[i] = poly_2d[i]

	var tris: PackedInt32Array = base_tris.duplicate()

	# Subdivision conforme sans T-junctions pour que l'attribut COLOR interpole proprement
	# la proximité du bord du mur d'arbres et que le maillage épouse le sol de l'arène.
	var max_edge_len: float = 6.5
	var max_edge_sq: float = max_edge_len * max_edge_len
	for _pass_idx: int in range(6):
		var split_edges: Dictionary = {}
		var tri_count: int = int(float(tris.size()) / 3.0)
		for t: int in range(tri_count):
			var a: int = tris[t * 3]
			var b: int = tris[t * 3 + 1]
			var c: int = tris[t * 3 + 2]
			_register_edge_split(a, b, verts, max_edge_sq, split_edges)
			_register_edge_split(b, c, verts, max_edge_sq, split_edges)
			_register_edge_split(c, a, verts, max_edge_sq, split_edges)

		if split_edges.is_empty():
			break

		var next_tris := PackedInt32Array()
		for t: int in range(tri_count):
			var a: int = tris[t * 3]
			var b: int = tris[t * 3 + 1]
			var c: int = tris[t * 3 + 2]
			var mab: int = int(split_edges.get(_edge_key(a, b), -1))
			var mbc: int = int(split_edges.get(_edge_key(b, c), -1))
			var mca: int = int(split_edges.get(_edge_key(c, a), -1))
			var split_count: int = int(mab >= 0) + int(mbc >= 0) + int(mca >= 0)

			if split_count == 0:
				_append_tri(next_tris, a, b, c)
			elif split_count == 3:
				_append_tri(next_tris, a, mab, mca)
				_append_tri(next_tris, mab, b, mbc)
				_append_tri(next_tris, mca, mbc, c)
				_append_tri(next_tris, mab, mbc, mca)
			elif split_count == 1:
				var v0: int = a
				var v1: int = b
				var v2: int = c
				var m01: int = mab
				if mbc >= 0:
					v0 = b
					v1 = c
					v2 = a
					m01 = mbc
				elif mca >= 0:
					v0 = c
					v1 = a
					v2 = b
					m01 = mca
				_append_tri(next_tris, v0, m01, v2)
				_append_tri(next_tris, m01, v1, v2)
			else:
				# 2 arêtes coupées : rotation cyclique pour que l'arête non coupée soit (v2 -> v0)
				var v0: int = a
				var v1: int = b
				var v2: int = c
				var m01: int = mab
				var m12: int = mbc
				if mab < 0:
					v0 = b
					v1 = c
					v2 = a
					m01 = mbc
					m12 = mca
				elif mbc < 0:
					v0 = c
					v1 = a
					v2 = b
					m01 = mca
					m12 = mab
				_append_tri(next_tris, m01, v1, m12)
				if verts[v0].distance_squared_to(verts[m12]) <= verts[m01].distance_squared_to(verts[v2]):
					_append_tri(next_tris, v0, m01, m12)
					_append_tri(next_tris, v0, m12, v2)
				else:
					_append_tri(next_tris, v0, m01, v2)
					_append_tri(next_tris, m01, m12, v2)

		tris = next_tris
		if verts.size() > 6000:
			break

	var v_count: int = verts.size()
	var vertices_3d := PackedVector3Array()
	var normals_3d := PackedVector3Array()
	var tangents_f32 := PackedFloat32Array()
	var uvs_2d := PackedVector2Array()
	var colors := PackedColorArray()

	vertices_3d.resize(v_count)
	normals_3d.resize(v_count)
	tangents_f32.resize(v_count * 4)
	uvs_2d.resize(v_count)
	colors.resize(v_count)

	var fade_w: float = maxf(0.25, edge_fade_width)
	for i: int in range(v_count):
		var v2: Vector2 = verts[i]
		var world_xz: Vector3 = to_global(Vector3(v2.x, 0.0, v2.y))
		var wy: float = _sample_arena_ground_y(world_xz.x, world_xz.z) + floor_height_offset
		vertices_3d[i] = to_local(Vector3(world_xz.x, wy, world_xz.z))
		normals_3d[i] = Vector3.UP
		tangents_f32[i * 4] = 1.0
		tangents_f32[i * 4 + 1] = 0.0
		tangents_f32[i * 4 + 2] = 0.0
		tangents_f32[i * 4 + 3] = 1.0
		uvs_2d[i] = Vector2(world_xz.x, world_xz.z) * 0.08

		var border_dist: float = _min_distance_to_polygon_edges(v2, poly_2d)
		var edge_factor: float = smoothstep(0.0, fade_w, border_dist)
		colors[i] = Color(edge_factor, edge_factor, edge_factor, 1.0)

	# Garantir l'orientation horaire 3D (+Y vers le haut dans Godot)
	var final_indices := PackedInt32Array()
	final_indices.resize(tris.size())
	var final_tri_count: int = int(float(tris.size()) / 3.0)
	for t: int in range(final_tri_count):
		var i0: int = tris[t * 3]
		var i1: int = tris[t * 3 + 1]
		var i2: int = tris[t * 3 + 2]
		var pa: Vector2 = verts[i0]
		var pb: Vector2 = verts[i1]
		var pc: Vector2 = verts[i2]
		var cross_2d: float = (pb.x - pa.x) * (pc.y - pa.y) - (pb.y - pa.y) * (pc.x - pa.x)
		if cross_2d < 0.0:
			var tmp: int = i1
			i1 = i2
			i2 = tmp
		final_indices[t * 3] = i0
		final_indices[t * 3 + 1] = i1
		final_indices[t * 3 + 2] = i2

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices_3d
	arrays[Mesh.ARRAY_NORMAL] = normals_3d
	arrays[Mesh.ARRAY_TANGENT] = tangents_f32
	arrays[Mesh.ARRAY_TEX_UV] = uvs_2d
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = final_indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _edge_key(i0: int, i1: int) -> int:
	var u: int = mini(i0, i1)
	var v: int = maxi(i0, i1)
	return (u << 20) | v


func _register_edge_split(i0: int, i1: int, verts: Array[Vector2], max_edge_sq: float, split_edges: Dictionary) -> void:
	if verts[i0].distance_squared_to(verts[i1]) <= max_edge_sq:
		return
	var key: int = _edge_key(i0, i1)
	if split_edges.has(key):
		return
	var mid_idx: int = verts.size()
	verts.append((verts[i0] + verts[i1]) * 0.5)
	split_edges[key] = mid_idx


func _append_tri(arr: PackedInt32Array, a: int, b: int, c: int) -> void:
	arr.append(a)
	arr.append(b)
	arr.append(c)


func _min_distance_to_polygon_edges(pt: Vector2, poly: PackedVector2Array) -> float:
	var count: int = poly.size()
	if count < 2:
		return 0.0
	var min_d_sq: float = INF
	for i: int in range(count):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % count]
		var ab: Vector2 = b - a
		var len_sq: float = ab.length_squared()
		var closest: Vector2 = a
		if len_sq > 0.00001:
			var t: float = clampf((pt - a).dot(ab) / len_sq, 0.0, 1.0)
			closest = a + ab * t
		var d_sq: float = pt.distance_squared_to(closest)
		if d_sq < min_d_sq:
			min_d_sq = d_sq
	return sqrt(min_d_sq)


func _resolve_reference_ground_y() -> float:
	var arena: Node = get_parent()
	if arena != null:
		var spawn_marker: Node3D = arena.get_node_or_null("Boss_spawn_position") as Node3D
		if spawn_marker != null:
			return _sample_arena_ground_y(spawn_marker.global_position.x, spawn_marker.global_position.z)
		var entry_m: Node3D = arena.get_node_or_null("entry") as Node3D
		if entry_m != null:
			return _sample_arena_ground_y(entry_m.global_position.x, entry_m.global_position.z)
	return _sample_arena_ground_y(global_position.x, global_position.z)


func _sample_arena_ground_y(wx: float, wz: float) -> float:
	var arena: Node = get_parent()
	if arena != null and arena.has_method("_get_arena_ground_y"):
		var hy: float = float(arena.call("_get_arena_ground_y", wx, wz))
		if not is_nan(hy):
			return hy

	var curr: Node = get_parent()
	while curr != null:
		if curr.has_method("get_terrain_height_at"):
			var th: float = float(curr.call("get_terrain_height_at", wx, wz))
			if not is_nan(th):
				return th
		curr = curr.get_parent()

	return global_position.y
