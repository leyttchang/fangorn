class_name IceEnchantCoordinator
extends Node3D

## Coordinateur global léger auto-instancié par IceEnchantEffectData :
## - Gère tous les monstres portant l'enchantement de glace (Totem de Glace, élites, etc.)
## - Déclenche périodiquement une petite Ice Nova désynchronisée autour de chaque monstre vivant
## - Synchronise les novas en multijoueur et applique l'effet de slow cumulable (0 dégât) aux joueurs touchés

const COORDINATOR_NODE_NAME := "IceEnchantCoordinator"
const DEFAULT_NOVA_SCENE: PackedScene = preload("res://scripts/status_effects/ice_enchant/monster_ice_nova.tscn")
const DEFAULT_SLOW_EFFECT: StatusEffectData = preload("res://scripts/status_effects/ice_enchant/ice_nova_slow.tres")

var effect_config: Resource
var _enchanted_mobs: Array = []
var _enchanted_mob_ids: PackedInt64Array = PackedInt64Array()
var _mob_timers: Dictionary = {}
var _global_stagger_cooldown: float = 0.0
var _active_novas_count: int = 0
var _spawn_index_stagger: int = 0

static func get_or_create(tree: SceneTree, config_res: Resource) -> IceEnchantCoordinator:
	if tree == null:
		return null
	var host_parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var existing := host_parent.get_node_or_null(COORDINATOR_NODE_NAME) as IceEnchantCoordinator
	if existing != null and is_instance_valid(existing):
		if config_res != null:
			existing.apply_config(config_res)
		return existing

	var coord := IceEnchantCoordinator.new()
	coord.name = COORDINATOR_NODE_NAME
	coord.set_multiplayer_authority(1)
	if config_res != null:
		coord.apply_config(config_res)
	host_parent.add_child(coord)
	return coord

func apply_config(config_res: Resource) -> void:
	effect_config = config_res

func register_mob(mob: Node3D) -> void:
	if mob == null or not is_instance_valid(mob):
		return
	set_process(true)
	if not _enchanted_mobs.has(mob):
		var mid := mob.get_instance_id()
		_enchanted_mobs.append(mob)
		_enchanted_mob_ids.append(mid)
		var min_d := _get_cfg_float("initial_delay_min", 1.2)
		var max_d := maxf(min_d, _get_cfg_float("initial_delay_max", 3.6))
		# Échelonner naturellement un pack de monstres qui spawn en même temps
		var slot_offset := fmod(float(_spawn_index_stagger) * 0.28, maxf(0.25, max_d - min_d))
		_spawn_index_stagger += 1
		var init_timer := clampf(min_d + slot_offset + randf_range(0.0, 0.35), min_d, max_d + 0.35)
		_mob_timers[mid] = init_timer

func unregister_mob(mob: Variant) -> void:
	var idx := _enchanted_mobs.find(mob)
	if idx >= 0:
		var mid := _enchanted_mob_ids[idx]
		_enchanted_mobs.remove_at(idx)
		_enchanted_mob_ids.remove_at(idx)
		_mob_timers.erase(mid)
	elif mob != null and is_instance_valid(mob):
		_mob_timers.erase((mob as Object).get_instance_id())

func _process(delta: float) -> void:
	_prune_dead_or_invalid_mobs()

	if _enchanted_mobs.is_empty():
		if _active_novas_count <= 0 and get_child_count() == 0:
			if multiplayer.has_multiplayer_peer():
				set_process(false)
			else:
				queue_free()
		return

	# Seul le serveur (ou le jeu solo) cadence les novas et décide des impacts de slow
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	if _global_stagger_cooldown > 0.0:
		_global_stagger_cooldown = maxf(0.0, _global_stagger_cooldown - delta)

	var interval := maxf(1.0, _get_cfg_float("nova_interval", 3.8))
	var jitter := maxf(0.0, _get_cfg_float("nova_interval_jitter", 0.45))
	var trigger_range := _get_cfg_float("trigger_player_range", 26.0)
	var radius := maxf(1.0, _get_cfg_float("nova_radius", 4.2))

	for raw_mob: Variant in _enchanted_mobs:
		if raw_mob == null or not is_instance_valid(raw_mob):
			continue
		var mob := raw_mob as Node3D
		if mob == null:
			continue
		var mid := mob.get_instance_id()
		var rem := float(_mob_timers.get(mid, interval)) - delta
		if rem <= 0.0:
			if _global_stagger_cooldown > 0.0:
				# Décaler légèrement pour éviter que plusieurs novas explosent à la même milliseconde
				_mob_timers[mid] = _global_stagger_cooldown + randf_range(0.04, 0.14)
				continue

			if trigger_range > 0.0 and not _has_living_player_within(mob.global_position, trigger_range):
				_mob_timers[mid] = randf_range(0.55, 0.95)
				continue

			var next_wait := maxf(1.0, interval + randf_range(-jitter, jitter))
			_mob_timers[mid] = next_wait
			_global_stagger_cooldown = 0.14

			var ground_pos := get_mob_ground_pos(mob)
			if multiplayer.has_multiplayer_peer():
				_rpc_spawn_ice_nova.rpc(ground_pos, radius)
			else:
				_rpc_spawn_ice_nova(ground_pos, radius)
		else:
			_mob_timers[mid] = rem

func _prune_dead_or_invalid_mobs() -> void:
	if _enchanted_mobs.is_empty():
		if not _mob_timers.is_empty():
			_mob_timers.clear()
		return
	for i in range(_enchanted_mobs.size() - 1, -1, -1):
		if is_mob_invalid_or_dead(_enchanted_mobs[i]):
			var mid: int = _enchanted_mob_ids[i]
			_enchanted_mobs.remove_at(i)
			_enchanted_mob_ids.remove_at(i)
			_mob_timers.erase(mid)

func _has_living_player_within(origin: Vector3, max_dist: float) -> bool:
	if get_tree() == null:
		return false
	var max_d2 := max_dist * max_dist
	for p_node in get_tree().get_nodes_in_group("Player"):
		var player := p_node as Node3D
		if _is_player_invalid_or_dead(player):
			continue
		if origin.distance_squared_to(player.global_position) <= max_d2:
			return true
	return false

@rpc("authority", "call_local", "reliable")
func _rpc_spawn_ice_nova(world_pos: Vector3, radius: float) -> void:
	if get_tree() == null:
		return

	var nova_packed: PackedScene = DEFAULT_NOVA_SCENE
	if effect_config != null and "nova_scene" in effect_config and effect_config.get("nova_scene") is PackedScene:
		nova_packed = effect_config.get("nova_scene") as PackedScene
	if nova_packed == null:
		return

	var nova_inst := nova_packed.instantiate() as Node3D
	if nova_inst == null:
		return

	var is_auth := (not multiplayer.has_multiplayer_peer() or multiplayer.is_server())
	var hit_cb := Callable()
	if is_auth:
		hit_cb = func(center_pos: Vector3, hit_radius: float) -> void:
			_apply_nova_slow_to_players(center_pos, hit_radius)

	if nova_inst.has_method("setup"):
		nova_inst.call("setup", radius, hit_cb)

	var scene_root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	_active_novas_count += 1
	nova_inst.tree_exited.connect(func() -> void:
		_active_novas_count = maxi(0, _active_novas_count - 1)
	)
	scene_root.add_child(nova_inst)
	nova_inst.global_position = world_pos

## Applique UNIQUEMENT l'effet de slow cumulable aux joueurs touchés (aucun dégât ni knockback)
func _apply_nova_slow_to_players(nova_ground_pos: Vector3, radius: float) -> void:
	if get_tree() == null:
		return

	var slow_effect: StatusEffectData = DEFAULT_SLOW_EFFECT
	if effect_config != null and "player_slow_effect" in effect_config and effect_config.get("player_slow_effect") is StatusEffectData:
		slow_effect = effect_config.get("player_slow_effect") as StatusEffectData
	if slow_effect == null:
		return

	var slow_dur := maxf(0.5, _get_cfg_float("slow_duration", 5.0))
	var max_horiz_dist := radius + 0.35
	var max_horiz_d2 := max_horiz_dist * max_horiz_dist

	for p_node in get_tree().get_nodes_in_group("Player"):
		var player := p_node as Node3D
		if _is_player_invalid_or_dead(player):
			continue

		var p_pos := player.global_position
		var dx := p_pos.x - nova_ground_pos.x
		var dz := p_pos.z - nova_ground_pos.z
		if (dx * dx + dz * dz) > max_horiz_d2:
			continue

		# Vérification verticale sur la capsule du joueur (pieds à -1.0, tête à +1.0)
		var p_feet_y := p_pos.y - 1.0
		var p_head_y := p_pos.y + 1.0
		if p_feet_y > nova_ground_pos.y + 1.65 or p_head_y < nova_ground_pos.y - 0.85:
			continue

		var status_comp := _find_status_component(player)
		if status_comp != null:
			status_comp.apply_effect(slow_effect, slow_dur)

func _find_status_component(entity: Node) -> StatusEffectComponent:
	for child in entity.get_children():
		if child is StatusEffectComponent:
			return child
	return entity.find_child("*status_effect*", true, false) as StatusEffectComponent

func _get_cfg_float(prop_name: String, default_val: float) -> float:
	if effect_config != null and prop_name in effect_config:
		return float(effect_config.get(prop_name))
	return default_val

static func get_mob_ground_pos(mob: Node3D) -> Vector3:
	if mob == null or not is_instance_valid(mob):
		return Vector3.ZERO

	var base_pos := mob.global_position
	var est_bottom_y := base_pos.y
	var ray_start_y := base_pos.y + 1.2

	var cs := mob.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs != null and cs.shape != null:
		var scale_y := absf(cs.global_transform.basis.get_scale().y)
		var half_h := 0.0
		if cs.shape is CapsuleShape3D:
			half_h = (cs.shape as CapsuleShape3D).height * 0.5 * scale_y
		elif cs.shape is CylinderShape3D:
			half_h = (cs.shape as CylinderShape3D).height * 0.5 * scale_y
		elif cs.shape is BoxShape3D:
			half_h = (cs.shape as BoxShape3D).size.y * 0.5 * scale_y
		elif cs.shape is SphereShape3D:
			half_h = (cs.shape as SphereShape3D).radius * scale_y

		if half_h > 0.01:
			est_bottom_y = cs.global_position.y - half_h
			ray_start_y = cs.global_position.y + 0.5

	# Raycast léger sur le sol (Layer 1) pour plaquer parfaitement la nova au relief
	if mob.is_inside_tree() and mob.get_world_3d() != null:
		var space_state := mob.get_world_3d().direct_space_state
		if space_state != null:
			var query := PhysicsRayQueryParameters3D.create(
				Vector3(base_pos.x, ray_start_y, base_pos.z),
				Vector3(base_pos.x, est_bottom_y - 1.8, base_pos.z),
				1
			)
			query.collide_with_areas = false
			query.collide_with_bodies = true
			var hit: Dictionary = space_state.intersect_ray(query)
			if not hit.is_empty() and hit.has("position"):
				return hit["position"] as Vector3

	return Vector3(base_pos.x, est_bottom_y, base_pos.z)

static func is_mob_invalid_or_dead(raw_mob: Variant) -> bool:
	if raw_mob == null or not is_instance_valid(raw_mob):
		return true
	var mob := raw_mob as Node3D
	if mob == null or mob.is_queued_for_deletion():
		return true
	var hc := mob.get_node_or_null("HealthComponent") as HealthComponent
	if hc != null and hc.current_health <= 0.0:
		return true
	if "current_state" in mob and "State" in mob and "DEAD" in mob.State:
		if mob.current_state == mob.State.DEAD:
			return true
	return false

static func _is_player_invalid_or_dead(player: Node3D) -> bool:
	if player == null or not is_instance_valid(player) or player.is_queued_for_deletion():
		return true
	if player.get("is_dead") == true or (player.has_method("is_dead") and player.is_dead()):
		return true
	var hc := player.get_node_or_null("HealthComponent") as HealthComponent
	if hc != null and hc.current_health <= 0.0:
		return true
	return false
