class_name ArcaneEnchantCoordinator
extends Node3D

## Coordinateur global léger auto-instancié par ArcaneEnchantEffectData :
## - Gère tous les monstres portant l'enchantement d'Arcane (Totem d'Arcane, élites, etc.)
## - Cadencé à 10 Hz (0.10s) avec cache de positions joueurs pour un coût CPU quasi-nul (~0.02 ms)
## - Échelonne les timers initiaux et périodiques pour qu'aucune salve simultanée ne se produise
## - Respecte le plafond par monstre (`max_flares_per_monster = 1`) ainsi que le plafond global (`12`)

const COORDINATOR_NODE_NAME: String = "ArcaneEnchantCoordinator"
const DEFAULT_FLARE_SCENE: PackedScene = preload("res://scripts/status_effects/arcane_enchant/arcane_flare.tscn")
const GLOBAL_SPAWN_STAGGER: float = 0.32
const TICK_INTERVAL: float = 0.10

var effect_config: Resource
var _enchanted_mobs: Array = []
var _enchanted_mob_ids: PackedInt64Array = PackedInt64Array()
var _mob_timers: Dictionary = {}
var _mob_active_flares: Dictionary = {}
var _global_stagger_cooldown: float = 0.0
var _active_flares_count: int = 0
var _spawn_index_stagger: int = 0
var _flare_spawn_serial: int = 0
var _tick_accum: float = 0.0
var _cached_player_positions: PackedVector3Array = PackedVector3Array()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

static func get_or_create(tree: SceneTree, config_res: Resource) -> ArcaneEnchantCoordinator:
	if tree == null:
		return null
	var host_parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var existing: ArcaneEnchantCoordinator = host_parent.get_node_or_null(COORDINATOR_NODE_NAME) as ArcaneEnchantCoordinator
	if existing != null and is_instance_valid(existing):
		if config_res != null:
			existing.apply_config(config_res)
		return existing

	var coord: ArcaneEnchantCoordinator = ArcaneEnchantCoordinator.new()
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
		var mid: int = mob.get_instance_id()
		_enchanted_mobs.append(mob)
		_enchanted_mob_ids.append(mid)
		var min_d: float = maxf(0.2, _get_cfg_float("initial_delay_min", 1.4))
		var max_d: float = maxf(min_d + 0.2, _get_cfg_float("initial_delay_max", 9.8))
		var span: float = maxf(0.5, max_d - min_d)
		var ratio: float = fmod(float(_spawn_index_stagger) * 0.6180339887 + 0.11, 1.0)
		_spawn_index_stagger += 1
		var init_timer: float = clampf(min_d + ratio * span + _rng.randf_range(-0.22, 0.22), min_d, max_d)
		_mob_timers[mid] = init_timer

func unregister_mob(mob: Variant) -> void:
	var idx: int = _enchanted_mobs.find(mob)
	var mid: int = 0
	if idx >= 0:
		mid = _enchanted_mob_ids[idx]
		_enchanted_mobs.remove_at(idx)
		_enchanted_mob_ids.remove_at(idx)
	elif mob != null and is_instance_valid(mob):
		mid = (mob as Object).get_instance_id()
	if mid != 0:
		_mob_timers.erase(mid)
		if _mob_active_flares.has(mid) and int(_mob_active_flares.get(mid, 0)) <= 0:
			_mob_active_flares.erase(mid)

func pop_all_active_flares(play_vfx: bool = true) -> void:
	if get_tree() == null:
		return
	for node: Node in get_tree().get_nodes_in_group("ArcaneFlare"):
		if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
			if node.has_method("pop_flare"):
				node.call("pop_flare", play_vfx)
			else:
				node.queue_free()

func _process(delta: float) -> void:
	_tick_accum += delta
	if _tick_accum < TICK_INTERVAL:
		return
	var step_dt: float = _tick_accum
	_tick_accum = 0.0

	_prune_dead_or_invalid_mobs()

	if _enchanted_mobs.is_empty():
		if _active_flares_count <= 0 and get_child_count() == 0:
			if multiplayer.has_multiplayer_peer():
				set_process(false)
			else:
				queue_free()
		return

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	if _global_stagger_cooldown > 0.0:
		_global_stagger_cooldown = maxf(0.0, _global_stagger_cooldown - step_dt)

	_refresh_cached_player_positions()

	var interval: float = maxf(1.5, _get_cfg_float("spawn_interval", 10.5))
	var jitter: float = maxf(0.0, _get_cfg_float("spawn_interval_jitter", 1.4))
	var trigger_range: float = _get_cfg_float("trigger_player_range", 38.0)
	var trigger_range_sq: float = trigger_range * trigger_range
	var max_per_mob: int = maxi(1, _get_cfg_int("max_flares_per_monster", 1))
	var max_flares: int = maxi(1, _get_cfg_int("max_global_active_flares", 12))

	for raw_mob: Variant in _enchanted_mobs:
		if raw_mob == null or not is_instance_valid(raw_mob):
			continue
		var mob: Node3D = raw_mob as Node3D
		if mob == null:
			continue
		var mid: int = mob.get_instance_id()
		var rem: float = float(_mob_timers.get(mid, interval)) - step_dt
		if rem <= 0.0:
			var mob_active: int = int(_mob_active_flares.get(mid, 0))
			if mob_active >= max_per_mob:
				_mob_timers[mid] = _rng.randf_range(0.95, 1.45)
				continue

			if _global_stagger_cooldown > 0.0:
				_mob_timers[mid] = _global_stagger_cooldown + _rng.randf_range(0.10, 0.30)
				continue

			if _active_flares_count >= max_flares:
				_mob_timers[mid] = _rng.randf_range(0.95, 1.75)
				continue

			if trigger_range > 0.0 and not _has_cached_player_within_sq(mob.global_position, trigger_range_sq):
				_mob_timers[mid] = _rng.randf_range(0.85, 1.45)
				continue

			var next_wait: float = maxf(1.5, interval + _rng.randf_range(-jitter, jitter))
			_mob_timers[mid] = next_wait
			_global_stagger_cooldown = GLOBAL_SPAWN_STAGGER

			var spawn_pos: Vector3 = mob.global_position + Vector3(0.0, 1.5, 0.0)
			var initial_speed: float = _roll_flare_initial_speed()
			_flare_spawn_serial += 1
			var net_serial: int = _flare_spawn_serial
			if multiplayer.has_multiplayer_peer():
				_rpc_spawn_arcane_flare.rpc(spawn_pos, initial_speed, mid, net_serial)
			else:
				_rpc_spawn_arcane_flare(spawn_pos, initial_speed, mid, net_serial)
		else:
			_mob_timers[mid] = rem

func _refresh_cached_player_positions() -> void:
	_cached_player_positions.clear()
	if get_tree() == null:
		return
	for p_node: Node in get_tree().get_nodes_in_group("Player"):
		var player: Node3D = p_node as Node3D
		if player == null or not is_instance_valid(player) or player.is_queued_for_deletion():
			continue
		if player.get("is_dead") == true:
			continue
		_cached_player_positions.append(player.global_position)

func _has_cached_player_within_sq(origin: Vector3, max_d2: float) -> bool:
	for p_pos: Vector3 in _cached_player_positions:
		if origin.distance_squared_to(p_pos) <= max_d2:
			return true
	return false

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
			if _mob_active_flares.has(mid) and int(_mob_active_flares.get(mid, 0)) <= 0:
				_mob_active_flares.erase(mid)

func _is_mob_id_registered(mob_id: int) -> bool:
	return _enchanted_mob_ids.has(mob_id)

func _roll_flare_initial_speed() -> float:
	if effect_config != null and "flare_speed_min" in effect_config and "flare_speed_max" in effect_config:
		var v_min: float = float(effect_config.get("flare_speed_min"))
		var v_max: float = float(effect_config.get("flare_speed_max"))
		var lo: float = maxf(0.2, minf(v_min, v_max))
		var hi: float = maxf(lo, maxf(v_min, v_max))
		return _rng.randf_range(lo, hi)
	return maxf(0.2, _get_cfg_float("flare_speed", 3.2))

@rpc("authority", "call_local", "reliable")
func _rpc_spawn_arcane_flare(spawn_pos: Vector3, initial_speed: float = -1.0, owner_mob_id: int = 0, flare_net_id: int = 0) -> void:
	if get_tree() == null:
		return

	var flare_packed: PackedScene = DEFAULT_FLARE_SCENE
	if effect_config != null and "flare_scene" in effect_config and effect_config.get("flare_scene") is PackedScene:
		flare_packed = effect_config.get("flare_scene") as PackedScene
	if flare_packed == null:
		return

	var flare_inst: Node3D = flare_packed.instantiate() as Node3D
	if flare_inst == null:
		return

	var resolved_serial: int = flare_net_id
	if resolved_serial <= 0:
		_flare_spawn_serial += 1
		resolved_serial = _flare_spawn_serial
	else:
		_flare_spawn_serial = maxi(_flare_spawn_serial, resolved_serial)
	flare_inst.name = "ArcaneFlare_%d" % resolved_serial
	flare_inst.set_multiplayer_authority(1)
	flare_inst.position = spawn_pos

	var f_speed: float = initial_speed if initial_speed > 0.0 else _get_cfg_float("flare_speed_min", 2.8)
	var f_accel: float = _get_cfg_float("flare_acceleration", 0.35)
	var f_max_speed: float = _get_cfg_float("flare_max_speed", 7.22)
	var f_damage: float = _get_cfg_float("flare_damage", 18.0)
	var f_lifetime: float = _get_cfg_float("flare_lifetime", 20.0)
	var f_turn: float = _get_cfg_float("flare_turn_speed", 2.6)
	var f_kb: float = _get_cfg_float("flare_knockback", 4.0)

	if flare_inst.has_method("setup_flare"):
		flare_inst.call("setup_flare", f_speed, f_damage, f_lifetime, f_turn, f_kb, f_accel, f_max_speed)

	var scene_root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	var track_mob_cap: bool = (owner_mob_id != 0) and (not multiplayer.has_multiplayer_peer() or multiplayer.is_server())
	if track_mob_cap:
		_mob_active_flares[owner_mob_id] = int(_mob_active_flares.get(owner_mob_id, 0)) + 1
	_active_flares_count += 1

	var release_state: Dictionary = {"released": false}
	var release_slot_cb := func() -> void:
		if bool(release_state["released"]):
			return
		release_state["released"] = true
		_active_flares_count = maxi(0, _active_flares_count - 1)
		if track_mob_cap and _mob_active_flares.has(owner_mob_id):
			var new_c: int = maxi(0, int(_mob_active_flares.get(owner_mob_id, 0)) - 1)
			if new_c <= 0 and not _is_mob_id_registered(owner_mob_id):
				_mob_active_flares.erase(owner_mob_id)
			else:
				_mob_active_flares[owner_mob_id] = new_c

	if flare_inst.has_signal("flare_popped"):
		flare_inst.connect("flare_popped", release_slot_cb)
	flare_inst.tree_exited.connect(release_slot_cb)

	scene_root.add_child(flare_inst)
	flare_inst.global_position = spawn_pos
	flare_inst.reset_physics_interpolation()

func _get_cfg_float(prop_name: String, default_val: float) -> float:
	if effect_config != null and prop_name in effect_config:
		return float(effect_config.get(prop_name))
	return default_val

func _get_cfg_int(prop_name: String, default_val: int) -> int:
	if effect_config != null and prop_name in effect_config:
		return int(effect_config.get(prop_name))
	return default_val

static func is_mob_invalid_or_dead(raw_mob: Variant) -> bool:
	if raw_mob == null or not is_instance_valid(raw_mob):
		return true
	var mob: Node3D = raw_mob as Node3D
	if mob == null or mob.is_queued_for_deletion():
		return true
	if mob.get("is_dead") == true:
		return true
	var hc: HealthComponent = mob.get_node_or_null("HealthComponent") as HealthComponent
	if hc != null and hc.current_health <= 0.0:
		return true
	return false
