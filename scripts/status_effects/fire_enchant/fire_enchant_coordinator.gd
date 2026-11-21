class_name FireEnchantCoordinator
extends Node3D

## Coordinateur global auto-instancié par FireEnchantEffectData :
## - Suit tous les monstres portant l'enchantement de feu
## - Fait apparaître derrière eux une traînée de feu au sol lorsqu'ils se déplacent
## - Ajoute une chance d'enflammer (burn.tres) le joueur sur toutes leurs attaques
##   (corps-à-corps, attaques enfants dynamiques comme les racines, et projectiles/AoE détachés comme flèches ou slams)

const COORDINATOR_NODE_NAME := "FireEnchantCoordinator"
const META_FIRE_ENCHANT_APP := &"from_fire_enchant"
const META_BOUND_DETACHED := &"fire_enchant_bound"
const MAX_GLOBAL_ACTIVE_PATCHES := 42

class MobFireState:
	var mob: Node3D
	var config: Resource
	var last_trail_xz: Vector2 = Vector2.ZERO
	var has_last_pos: bool = false
	var spawned_patches: Array[Node3D] = []
	var modified_attacks: Array[AttackComponent] = []

var default_config: Resource
var _mob_states: Dictionary = {} # instance_id (int) -> MobFireState
var _global_active_patches: Array[Node3D] = []
var _listened_containers: Array[Node] = []


static func get_or_create(tree: SceneTree, config_res: Resource) -> FireEnchantCoordinator:
	if tree == null:
		return null
	var host_parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	if host_parent == null:
		return null

	var existing := host_parent.get_node_or_null(COORDINATOR_NODE_NAME) as FireEnchantCoordinator
	if existing != null and is_instance_valid(existing):
		if config_res != null:
			existing.default_config = config_res
		return existing

	var coord := FireEnchantCoordinator.new()
	coord.name = COORDINATOR_NODE_NAME
	coord.set_multiplayer_authority(1)
	coord.default_config = config_res
	host_parent.add_child(coord)
	return coord


func _ready() -> void:
	if _is_server_authority():
		_ensure_spawned_projectiles_listener()


func _is_server_authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func register_mob(mob: Node3D, config_res: Resource = null) -> void:
	if is_mob_invalid_or_dead(mob):
		return
	set_process(true)

	var cfg: Resource = config_res if config_res != null else default_config
	if cfg != null:
		default_config = cfg

	var mid: int = mob.get_instance_id()
	var state: MobFireState = _mob_states.get(mid) as MobFireState
	if state == null:
		state = MobFireState.new()
		state.mob = mob
		state.config = cfg
		state.last_trail_xz = Vector2(mob.global_position.x, mob.global_position.z)
		state.has_last_pos = true
		_mob_states[mid] = state
	else:
		if cfg != null:
			state.config = cfg

	if _is_server_authority():
		_ensure_spawned_projectiles_listener()
		_inject_burn_on_mob_attacks(state)
		var cb := _on_mob_child_entered_tree.bind(mob)
		if not mob.child_entered_tree.is_connected(cb):
			mob.child_entered_tree.connect(cb)


func unregister_mob(mob: Node3D) -> void:
	if mob == null:
		return
	_unregister_by_id(mob.get_instance_id())


func _unregister_by_id(mid: int) -> void:
	if not _mob_states.has(mid):
		return
	var state: MobFireState = _mob_states[mid] as MobFireState
	if state != null:
		_clear_burn_from_modified_attacks(state)
	_mob_states.erase(mid)


func _process(_delta: float) -> void:
	_prune_dead_or_invalid_mobs()

	if _mob_states.is_empty():
		if get_child_count() == 0:
			if multiplayer.has_multiplayer_peer():
				set_process(false)
			else:
				queue_free()
		return

	# Même architecture que LightningEnchantCoordinator & IceEnchantCoordinator :
	# seul le serveur (ou le jeu solo) échantillonne et diffuse les positions exactes des flaques
	if not _is_server_authority():
		return

	_ensure_spawned_projectiles_listener()

	for mid in _mob_states.keys():
		var state: MobFireState = _mob_states.get(mid) as MobFireState
		if state == null or is_mob_invalid_or_dead(state.mob):
			continue
		_update_mob_fire_trail(state)


func _prune_dead_or_invalid_mobs() -> void:
	if _mob_states.is_empty():
		return
	var dead_ids: Array[int] = []
	for mid in _mob_states.keys():
		var state: MobFireState = _mob_states[mid] as MobFireState
		if state == null or is_mob_invalid_or_dead(state.mob):
			dead_ids.append(int(mid))
	for mid in dead_ids:
		_unregister_by_id(mid)


# =========================================================================
# 1. TRAÎNÉE DE FEU DERRIÈRE LES MONSTRES EN MOUVEMENT
# =========================================================================

func _update_mob_fire_trail(state: MobFireState) -> void:
	var mob: Node3D = state.mob
	var cfg: Resource = state.config if state.config != null else default_config
	if cfg == null:
		return

	var patch_scene: PackedScene = cfg.get("trail_patch_scene") as PackedScene if "trail_patch_scene" in cfg else null
	if patch_scene == null:
		return

	var step_dist: float = maxf(0.25, float(cfg.get("trail_step_distance")) if "trail_step_distance" in cfg else 0.85)
	var behind_offset: float = maxf(0.0, float(cfg.get("trail_behind_offset")) if "trail_behind_offset" in cfg else 0.40)
	var cur_xz := Vector2(mob.global_position.x, mob.global_position.z)

	if not state.has_last_pos:
		state.last_trail_xz = cur_xz
		state.has_last_pos = true
		return

	var dist_xz: float = cur_xz.distance_to(state.last_trail_xz)
	if dist_xz > 8.0:
		# Téléportation ou repositionnement initial au spawn : on resynchronise sans poser de flaque
		state.last_trail_xz = cur_xz
		return

	if dist_xz < step_dist:
		return

	var move_dir_2d: Vector2 = (cur_xz - state.last_trail_xz) / dist_xz
	var spawn_xz: Vector2 = cur_xz - move_dir_2d * behind_offset
	var ground_info: Dictionary = _sample_ground_for_mob(mob, spawn_xz)

	state.last_trail_xz = cur_xz
	if not bool(ground_info.get("valid", false)):
		return

	var w_pos: Vector3 = ground_info["position"] as Vector3
	var g_norm: Vector3 = ground_info["normal"] as Vector3

	# Anti-empilement spatial : si une autre flaque active recouvre déjà quasiment ce point (< 1.05m),
	# inutile d'empiler 15 flaques identiques quand toute une meute court dans le même couloir !
	var min_merge_dist_sq: float = 1.10
	for existing_p in _global_active_patches:
		if existing_p != null and is_instance_valid(existing_p) and not existing_p.is_queued_for_deletion():
			if existing_p.get("_fading_out") != true and existing_p.global_position.distance_squared_to(w_pos) < min_merge_dist_sq:
				return

	var mob_id: int = mob.get_instance_id()
	if multiplayer.has_multiplayer_peer():
		_rpc_spawn_trail_patch.rpc(mob_id, w_pos, g_norm)
	else:
		_rpc_spawn_trail_patch(mob_id, w_pos, g_norm)


@rpc("authority", "call_local", "reliable")
func _rpc_spawn_trail_patch(mob_id: int, world_pos: Vector3, ground_normal: Vector3) -> void:
	var state: MobFireState = _mob_states.get(mob_id) as MobFireState
	var cfg: Resource = state.config if (state != null and state.config != null) else default_config
	if cfg == null:
		return
	var patch_scene: PackedScene = cfg.get("trail_patch_scene") as PackedScene if "trail_patch_scene" in cfg else null
	if patch_scene == null:
		return
	_spawn_trail_patch(state, cfg, patch_scene, world_pos, ground_normal)


func _spawn_trail_patch(
	state: MobFireState,
	cfg: Resource,
	patch_scene: PackedScene,
	world_pos: Vector3,
	ground_normal: Vector3
) -> void:
	if get_tree() == null:
		return

	var patch := patch_scene.instantiate() as Node3D
	if patch == null:
		return

	var p_radius: float = maxf(0.25, float(cfg.get("trail_radius")) if "trail_radius" in cfg else 0.95)
	var p_duration: float = maxf(0.6, float(cfg.get("trail_duration")) if "trail_duration" in cfg else 4.0)
	var p_dmg: float = maxf(0.0, float(cfg.get("trail_tick_damage")) if "trail_tick_damage" in cfg else 5.0)
	var p_interval: float = maxf(0.08, float(cfg.get("trail_tick_interval")) if "trail_tick_interval" in cfg else 0.4)
	var custom_vfx: PackedScene = cfg.get("trail_custom_vfx_scene") as PackedScene if "trail_custom_vfx_scene" in cfg else null
	var max_patches: int = maxi(3, int(cfg.get("max_patches_per_mob")) if "max_patches_per_mob" in cfg else 16)

	if patch.has_method("setup_trail"):
		patch.call("setup_trail", p_radius, p_duration, p_dmg, p_interval, custom_vfx)

	var scene_root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	scene_root.add_child(patch)
	patch.global_position = world_pos + Vector3(0.0, 0.02, 0.0)
	_align_patch_to_ground(patch, ground_normal)

	# Si l'utilisateur a remplacé `trail_patch_scene` par une autre scène (ex: ground_fire.tscn), on sécurise ses couches/dégâts
	if not patch.has_method("setup_trail"):
		if patch.has_method("setup"):
			patch.call("setup", p_radius, p_duration)
		var fallback_atk := patch.get_node_or_null("AttackComponent") as AttackComponent
		if fallback_atk != null:
			fallback_atk.collision_layer = 16
			fallback_atk.collision_mask = 2
			fallback_atk.base_damage = 0.0
			fallback_atk.damage_physical = 0.0
			fallback_atk.damage_fire = p_dmg
			fallback_atk.knockback_force = 0.0
			if not _is_server_authority():
				fallback_atk.monitoring = false

	if state == null:
		return

	# Nettoyage de la liste des flaques actives du monstre et respect du plafond par monstre
	var valid_patches: Array[Node3D] = []
	for old_p in state.spawned_patches:
		if old_p != null and is_instance_valid(old_p) and not old_p.is_queued_for_deletion():
			valid_patches.append(old_p)

	while valid_patches.size() >= max_patches:
		var oldest := valid_patches.pop_front() as Node3D
		if oldest != null and is_instance_valid(oldest):
			if oldest.has_method("fade_out_early"):
				oldest.call("fade_out_early")
			else:
				oldest.queue_free()

	valid_patches.append(patch)
	state.spawned_patches = valid_patches

	# Plafond global de sécurité sur l'ensemble de la scène pour préserver les FPS même avec 30+ monstres
	var global_valid: Array[Node3D] = []
	for gp in _global_active_patches:
		if gp != null and is_instance_valid(gp) and not gp.is_queued_for_deletion() and gp.get("_fading_out") != true:
			global_valid.append(gp)
	while global_valid.size() >= MAX_GLOBAL_ACTIVE_PATCHES:
		var old_global := global_valid.pop_front() as Node3D
		if old_global != null and is_instance_valid(old_global):
			if old_global.has_method("fade_out_early"):
				old_global.call("fade_out_early")
			else:
				old_global.queue_free()
	global_valid.append(patch)
	_global_active_patches = global_valid


func _sample_ground_for_mob(mob: Node3D, target_xz: Vector2) -> Dictionary:
	var feet_y: float = _estimate_mob_feet_y(mob)
	if mob.is_inside_tree() and mob.get_world_3d() != null:
		var space_state := mob.get_world_3d().direct_space_state
		if space_state != null:
			var from_pt := Vector3(target_xz.x, feet_y + 1.8, target_xz.y)
			var to_pt := Vector3(target_xz.x, feet_y - 1.5, target_xz.y)
			var query := PhysicsRayQueryParameters3D.create(from_pt, to_pt, 1)
			query.collide_with_areas = false
			query.collide_with_bodies = true
			var hit: Dictionary = space_state.intersect_ray(query)
			if not hit.is_empty() and hit.has("position"):
				var hit_pos: Vector3 = hit["position"] as Vector3
				# Évite de poser du feu en l'air pendant la chute initiale au spawn ou un saut haut
				if (feet_y - hit_pos.y) <= 1.35:
					var normal: Vector3 = hit.get("normal", Vector3.UP) as Vector3
					return {"valid": true, "position": hit_pos, "normal": normal}
				return {"valid": false}

	# Fallback si Terrain3D sans collision raycast immédiate mais CharacterBody3D au sol
	if mob is CharacterBody3D and (mob as CharacterBody3D).is_on_floor():
		return {
			"valid": true,
			"position": Vector3(target_xz.x, feet_y, target_xz.y),
			"normal": Vector3.UP
		}

	return {"valid": false}


static func _estimate_mob_feet_y(mob: Node3D) -> float:
	var cs := mob.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs != null and cs.shape != null:
		var half_h: float = 0.0
		if cs.shape is CapsuleShape3D:
			half_h = (cs.shape as CapsuleShape3D).height * 0.5
		elif cs.shape is CylinderShape3D:
			half_h = (cs.shape as CylinderShape3D).height * 0.5
		elif cs.shape is SphereShape3D:
			half_h = (cs.shape as SphereShape3D).radius
		elif cs.shape is BoxShape3D:
			half_h = (cs.shape as BoxShape3D).size.y * 0.5
		return mob.global_position.y + (cs.position.y - half_h) * mob.scale.y
	return mob.global_position.y


static func _align_patch_to_ground(patch: Node3D, normal: Vector3) -> void:
	var n := normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	if n.y < 0.82:
		n = Vector3(n.x, 0.82, n.z).normalized()
	if n.distance_squared_to(Vector3.UP) < 0.0005:
		return
	var ref_fwd := Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x_axis := n.cross(ref_fwd).normalized()
	var z_axis := x_axis.cross(n).normalized()
	patch.global_basis = Basis(x_axis, n, z_axis)


# =========================================================================
# 2. CHANCE D'ENFLAMMER LE JOUEUR SUR LES ATTAQUES DES MONSTRES
# =========================================================================

func _build_burn_application(cfg: Resource) -> StatusEffectApplication:
	if cfg == null:
		return null
	var burn_eff: StatusEffectData = cfg.get("burn_status_effect") as StatusEffectData if "burn_status_effect" in cfg else null
	var chance: float = clampf(float(cfg.get("burn_chance_on_hit")) if "burn_chance_on_hit" in cfg else 0.35, 0.0, 1.0)
	var dur: float = maxf(0.5, float(cfg.get("burn_duration")) if "burn_duration" in cfg else 5.0)
	if burn_eff == null or chance <= 0.0:
		return null

	var app := StatusEffectApplication.new()
	app.effect = burn_eff
	app.duration = dur
	app.apply_chance = chance
	app.set_meta(META_FIRE_ENCHANT_APP, true)
	return app


func _inject_burn_into_attack(atk: AttackComponent, cfg: Resource, state: MobFireState = null) -> void:
	if atk == null or not is_instance_valid(atk):
		return
	var burn_app := _build_burn_application(cfg)
	if burn_app == null:
		return

	var new_list: Array[StatusEffectApplication] = []
	for existing in atk.status_effects_to_apply:
		if existing != null and not existing.has_meta(META_FIRE_ENCHANT_APP):
			new_list.append(existing)
	new_list.append(burn_app)
	atk.status_effects_to_apply = new_list

	if state != null and not state.modified_attacks.has(atk):
		state.modified_attacks.append(atk)


func _inject_burn_on_mob_attacks(state: MobFireState) -> void:
	if state == null or state.mob == null or not is_instance_valid(state.mob):
		return
	var cfg: Resource = state.config if state.config != null else default_config
	var attacks := _collect_attack_components(state.mob)
	for atk in attacks:
		_inject_burn_into_attack(atk, cfg, state)


func _clear_burn_from_modified_attacks(state: MobFireState) -> void:
	for atk in state.modified_attacks:
		if atk == null or not is_instance_valid(atk):
			continue
		var cleaned: Array[StatusEffectApplication] = []
		for existing in atk.status_effects_to_apply:
			if existing != null and not existing.has_meta(META_FIRE_ENCHANT_APP):
				cleaned.append(existing)
		atk.status_effects_to_apply = cleaned
	state.modified_attacks.clear()


func _on_mob_child_entered_tree(child: Node, mob: Node3D) -> void:
	if not _is_server_authority() or mob == null or not is_instance_valid(mob):
		return
	var state: MobFireState = _mob_states.get(mob.get_instance_id()) as MobFireState
	if state == null:
		return
	var cfg: Resource = state.config if state.config != null else default_config
	for atk in _collect_attack_components(child):
		_inject_burn_into_attack(atk, cfg, state)


func _ensure_spawned_projectiles_listener() -> void:
	if get_tree() == null:
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	_listen_to_container(scene_root)
	var net_objs := scene_root.get_node_or_null("NetworkObjects")
	if net_objs != null:
		_listen_to_container(net_objs)


func _listen_to_container(container: Node) -> void:
	if container == null or not is_instance_valid(container):
		return
	if _listened_containers.has(container):
		return
	_listened_containers.append(container)
	if not container.child_entered_tree.is_connected(_on_spawned_node_entered):
		container.child_entered_tree.connect(_on_spawned_node_entered)


func _on_spawned_node_entered(node: Node) -> void:
	if not _is_server_authority() or _mob_states.is_empty():
		return
	if node == null or node is FireTrailPatch or node is CharacterBody3D:
		return

	# Filet immédiat si l'impact se produit à bout portant sur la frame 0
	for atk in _collect_attack_components(node):
		var cb := _on_detached_attack_landed_fallback.bind(atk, node)
		if not atk.attack_landed.is_connected(cb):
			atk.attack_landed.connect(cb)

	# Laisse s'exécuter `new_arrow.execute(self, {})` et `slam.global_position = spawn_pos` juste après `add_child`
	call_deferred("_bind_detached_attack_node", node)


func _bind_detached_attack_node(node: Node) -> void:
	if not _is_server_authority() or _mob_states.is_empty():
		return
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return

	var attacks := _collect_attack_components(node)
	if attacks.is_empty():
		return

	for atk in attacks:
		var owner_state := _resolve_enchanted_owner_for_attack(atk, node as Node3D)
		if owner_state != null:
			var cfg: Resource = owner_state.config if owner_state.config != null else default_config
			_inject_burn_into_attack(atk, cfg, owner_state)
			atk.set_meta(META_BOUND_DETACHED, true)


func _on_detached_attack_landed_fallback(target: Node, atk: AttackComponent, root_node: Node) -> void:
	if not _is_server_authority() or atk == null or not is_instance_valid(atk):
		return
	# Déjà lié par `_bind_detached_attack_node` -> HitboxComponent a déjà tiré la probabilité de brûlure
	if atk.has_meta(META_BOUND_DETACHED):
		return

	var hb := target as HitboxComponent
	if hb == null:
		return
	var entity: Node = hb.owner if hb.owner != null else hb.get_parent()
	if entity == null or not entity.is_in_group("Player"):
		return

	var owner_state := _resolve_enchanted_owner_for_attack(atk, root_node as Node3D)
	if owner_state == null:
		return

	atk.set_meta(META_BOUND_DETACHED, true)
	var cfg: Resource = owner_state.config if owner_state.config != null else default_config
	var burn_app := _build_burn_application(cfg)
	if burn_app == null:
		return

	if randf() <= burn_app.apply_chance:
		for child in entity.get_children():
			if child is StatusEffectComponent:
				(child as StatusEffectComponent).apply_effect(burn_app.effect, burn_app.duration)
				break


func _resolve_enchanted_owner_for_attack(atk: AttackComponent, attack_root: Node3D) -> MobFireState:
	if atk == null:
		return null

	# 1. Référence explicite `caster` (ex: fire_arrow tirée par dumb_archer)
	if atk.caster != null and is_instance_valid(atk.caster):
		if atk.caster.is_in_group("Player"):
			return null
		return _mob_states.get(atk.caster.get_instance_id()) as MobFireState

	# 2. Sécurité : ignorer tout sort de joueur (caster_authority ou cible HitboxEnemie sur mask 8)
	if atk.has_meta("caster_authority"):
		return null
	if (atk.collision_layer & 16) == 0 or (atk.collision_mask & 2) == 0 or (atk.collision_mask & 8) != 0:
		return null
	if attack_root == null or not is_instance_valid(attack_root):
		return null

	# 3. AoE ennemies sans `caster` assigné (ex: Scout_slam, slams/rochers d'OgreBoss)
	var atk_pos: Vector3 = attack_root.global_position
	var best_state: MobFireState = null
	var best_dist_sq: float = INF

	for mid in _mob_states.keys():
		var st: MobFireState = _mob_states[mid] as MobFireState
		if st == null or is_mob_invalid_or_dead(st.mob):
			continue
		var mob: Node3D = st.mob
		var is_attacking: bool = true
		if "current_state" in mob and "State" in mob and "ATTACK" in mob.State:
			is_attacking = (mob.current_state == mob.State.ATTACK)
		if not is_attacking:
			continue

		var max_range: float = 26.0 if mob.is_in_group("Boss") else 6.5
		var d2: float = mob.global_position.distance_squared_to(atk_pos)
		if d2 <= (max_range * max_range) and d2 < best_dist_sq:
			best_dist_sq = d2
			best_state = st

	return best_state


static func _collect_attack_components(root: Node) -> Array[AttackComponent]:
	var result: Array[AttackComponent] = []
	if root == null:
		return result
	if root is AttackComponent:
		result.append(root as AttackComponent)
	for child in root.get_children():
		result.append_array(_collect_attack_components(child))
	return result


static func is_mob_invalid_or_dead(mob: Node3D) -> bool:
	if mob == null or not is_instance_valid(mob) or mob.is_queued_for_deletion():
		return true
	var hc := mob.get_node_or_null("HealthComponent") as HealthComponent
	if hc != null and hc.current_health <= 0.0:
		return true
	if "current_state" in mob and "State" in mob and "DEAD" in mob.State:
		if mob.current_state == mob.State.DEAD:
			return true
	return false
