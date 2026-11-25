class_name BossFireBuff
extends Node3D

## Contrôleur du Buff Feu du Boss Final (activé si au moins 1 Totem Feu a été complété) :
## - Augmente les PV max de l'Ogre (`"TOTEM_FIRE_BOSS"`) et lui attache une aura ardente (`scale = 1.65`).
## - À chaque impact de `ground_slam` ou `jumping_attack`, libère en étoile 3 à 4 tornades de feu
##   (+ bonus de totems) synchronisées entre serveur et clients, qui balayent l'arène et projettent
##   les joueurs vers le haut.

const SLAM_DEBOUNCE_MSEC: int = 100
const SPAWN_RING_OFFSET: float = 2.15

@export_category("Buff Feu du Boss (Tornades)")

@export_group("Quantité de Tornades (Sliders)")
@export_range(1, 8, 1) var tornado_count_min: int = 3
@export_range(1, 10, 1) var tornado_count_max: int = 4
@export_range(0, 4, 1) var extra_tornadoes_per_extra_totem: int = 1

@export_group("Mouvement, Dégâts & Knockback")
@export_range(2.0, 18.0, 0.2, "suffix:m/s") var tornado_speed: float = 6.2
@export_range(1.5, 12.0, 0.2, "suffix:s") var tornado_duration: float = 4.8
@export_range(1.0, 200.0, 1.0) var tornado_damage: float = 24.0
@export_range(0.0, 50.0, 0.5) var tornado_knockback_force: float = 15.0
@export_range(0.0, 85.0, 1.0, "suffix:°") var tornado_knockback_angle: float = 30.0
@export_range(-2.5, 2.5, 0.05) var tornado_curve_strength: float = 0.45

@export_group("Buff Direct sur l'Ogre & Scènes")
@export_range(0.0, 1.0, 0.05) var boss_hp_bonus_per_totem: float = 0.15
@export var tornado_scene: PackedScene = preload("res://map/encounters/Boss_arena/fire_buff/boss_fire_tornado.tscn")
@export var boss_aura_vfx_scene: PackedScene = preload("res://scripts/status_effects/fire_enchant/fire_enchant_vfx.tscn")

var is_buff_active: bool = false
var active_totem_stacks: int = 0

var _tracked_boss: Node3D = null
var _boss_aura_instance: Node3D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _active_tornadoes: Array = []
var _last_slam_msec: int = -10000


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_rng.randomize()


## Appelé par BossArena côté serveur/solo quand le boss apparaît (ou si un totem feu est complété en cours de combat).
func activate_for_boss(boss: Node3D, totem_stacks: int) -> void:
	if boss == null or not is_instance_valid(boss) or totem_stacks <= 0:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	_tracked_boss = boss
	active_totem_stacks = totem_stacks
	is_buff_active = true

	if boss_hp_bonus_per_totem > 0.0:
		var stats_comp: StatsComponent = boss.get_node_or_null("StatsComponent") as StatsComponent
		if stats_comp != null:
			var total_hp_bonus: float = boss_hp_bonus_per_totem * float(totem_stacks)
			stats_comp.set_or_update_modifier(
				"max_health",
				StatModifierData.ModType.PERCENT,
				total_hp_bonus,
				"TOTEM_FIRE_BOSS"
			)

	var boss_path: NodePath = boss.get_path()
	if multiplayer.has_multiplayer_peer():
		_rpc_start_fire_buff_client_state.rpc(boss_path, totem_stacks)
	else:
		_rpc_start_fire_buff_client_state(boss_path, totem_stacks)

	print("[BossFireBuff] Buff Feu activé sur '%s' (totems feu = %d, tornades = %d-%d) !" % [
		boss.name,
		totem_stacks,
		mini(tornado_count_min, tornado_count_max),
		maxi(tornado_count_min, tornado_count_max) + maxi(totem_stacks - 1, 0) * extra_tornadoes_per_extra_totem
	])


@rpc("authority", "call_local", "reliable")
func _rpc_start_fire_buff_client_state(boss_path: NodePath, totem_stacks: int) -> void:
	active_totem_stacks = totem_stacks
	is_buff_active = true
	_resolve_and_attach_boss_aura(boss_path, 4)


func _resolve_and_attach_boss_aura(boss_path: NodePath, retries_left: int) -> void:
	if not is_buff_active or not is_inside_tree():
		return
	var boss: Node3D = get_node_or_null(boss_path) as Node3D
	if boss != null and is_instance_valid(boss):
		_tracked_boss = boss
		_attach_boss_fire_aura(boss)
		return
	if retries_left > 0 and get_tree() != null:
		get_tree().process_frame.connect(func() -> void:
			_resolve_and_attach_boss_aura(boss_path, retries_left - 1)
		, CONNECT_ONE_SHOT)


func _attach_boss_fire_aura(boss: Node3D) -> void:
	if _boss_aura_instance != null and is_instance_valid(_boss_aura_instance):
		_boss_aura_instance.scale = Vector3.ONE * 1.65
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

	# `fire_enchant_vfx.gd` ajuste le scale en `call_deferred` dans `_ready()`,
	# on force donc aussi 1.65 en `set_deferred` juste après pour conserver l'ampleur Boss.
	aura.scale = Vector3.ONE * 1.65
	aura.set_deferred("scale", Vector3.ONE * 1.65)


## Appelé côté serveur/solo lors d'un `ground_slam` ou d'un `jumping_attack` de l'Ogre.
func on_boss_slam_impact(
	impact_pos: Vector3,
	boss_forward: Vector3 = Vector3.FORWARD,
	is_jump_slam: bool = false
) -> void:
	if not is_buff_active or tornado_scene == null:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if _tracked_boss != null and is_instance_valid(_tracked_boss) and _is_boss_dead(_tracked_boss):
		stop_effect()
		return

	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_slam_msec < SLAM_DEBOUNCE_MSEC:
		return
	_last_slam_msec = now_msec

	var min_c: int = mini(tornado_count_min, tornado_count_max)
	var max_c: int = maxi(tornado_count_min, tornado_count_max)
	var base_roll: int = _rng.randi_range(min_c, max_c)
	if is_jump_slam:
		# Le Jump Slam garde les bornes min..max mais favorise la borne haute
		base_roll = maxi(base_roll, _rng.randi_range(min_c, max_c))

	var extra_stacks: int = maxi(active_totem_stacks - 1, 0)
	var count: int = maxi(1, base_roll + extra_stacks * extra_tornadoes_per_extra_totem)

	var flat_fwd := Vector3(boss_forward.x, 0.0, boss_forward.z)
	if flat_fwd.length_squared() < 0.0001 and _tracked_boss != null and is_instance_valid(_tracked_boss):
		flat_fwd = -_tracked_boss.global_transform.basis.z
		flat_fwd.y = 0.0
	if flat_fwd.length_squared() < 0.0001:
		flat_fwd = Vector3.FORWARD
	else:
		flat_fwd = flat_fwd.normalized()

	var sector_step: float = TAU / float(count)
	var base_yaw: float = atan2(flat_fwd.x, flat_fwd.z) + _rng.randf_range(-sector_step * 0.5, sector_step * 0.5)
	var max_jitter: float = sector_step * 0.24
	var start_curve_sign: float = 1.0 if _rng.randf() < 0.5 else -1.0

	var directions := PackedVector3Array()
	var curve_signs := PackedFloat32Array()

	for i: int in range(count):
		var angle: float = base_yaw + float(i) * sector_step + _rng.randf_range(-max_jitter, max_jitter)
		var dir := Vector3(sin(angle), 0.0, cos(angle)).normalized()
		directions.append(dir)

		var alt_sign: float = start_curve_sign if (i % 2 == 0) else -start_curve_sign
		var curve_mult: float = alt_sign * _rng.randf_range(0.82, 1.18)
		curve_signs.append(curve_mult)

	var ground_y: float = _resolve_ground_y(impact_pos.x, impact_pos.z, impact_pos.y)
	var resolved_origin := Vector3(impact_pos.x, ground_y, impact_pos.z)

	if multiplayer.has_multiplayer_peer():
		_rpc_spawn_fire_tornadoes.rpc(resolved_origin, directions, curve_signs)
	else:
		_rpc_spawn_fire_tornadoes(resolved_origin, directions, curve_signs)


@rpc("authority", "call_local", "reliable")
func _rpc_spawn_fire_tornadoes(
	origin: Vector3,
	directions: PackedVector3Array,
	curve_signs: PackedFloat32Array
) -> void:
	if tornado_scene == null or get_tree() == null:
		return

	var scene_root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	var total: int = directions.size()

	for i: int in range(total):
		var tornado: BossFireTornado = tornado_scene.instantiate() as BossFireTornado
		if tornado == null:
			continue

		var raw_dir: Vector3 = directions[i]
		var dir := Vector3(raw_dir.x, 0.0, raw_dir.z)
		if dir.length_squared() > 0.0001:
			dir = dir.normalized()
		else:
			dir = Vector3.FORWARD

		var c_sign: float = curve_signs[i] if i < curve_signs.size() else 1.0
		tornado.setup_tornado(
			dir,
			tornado_speed,
			tornado_duration,
			tornado_damage,
			tornado_knockback_force,
			tornado_knockback_angle,
			tornado_curve_strength * c_sign,
			_tracked_boss
		)

		_active_tornadoes.append(tornado)
		tornado.tree_exited.connect(func() -> void:
			_active_tornadoes.erase(tornado)
		)

		scene_root.add_child(tornado)
		var spawn_pos: Vector3 = origin + dir * SPAWN_RING_OFFSET
		spawn_pos.y = _resolve_ground_y(spawn_pos.x, spawn_pos.z, origin.y)
		tornado.global_position = spawn_pos
		tornado.reset_physics_interpolation()


## Retire l'aura de feu et dissipe proprement toutes les tornades actives (appelé à la mort du boss).
func stop_effect() -> void:
	if not is_buff_active and _active_tornadoes.is_empty() and _boss_aura_instance == null:
		return

	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			_rpc_stop_fire_buff.rpc()
	else:
		_rpc_stop_fire_buff()


@rpc("authority", "call_local", "reliable")
func _rpc_stop_fire_buff() -> void:
	is_buff_active = false
	_tracked_boss = null

	if _boss_aura_instance != null and is_instance_valid(_boss_aura_instance):
		_boss_aura_instance.queue_free()
	_boss_aura_instance = null

	var current_list: Array = _active_tornadoes.duplicate()
	_active_tornadoes.clear()
	for raw_tornado: Variant in current_list:
		if raw_tornado != null and is_instance_valid(raw_tornado):
			var tornado: BossFireTornado = raw_tornado as BossFireTornado
			if tornado != null:
				tornado.begin_dissipate(false)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_buff_active:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	if _tracked_boss == null or not is_instance_valid(_tracked_boss) or _is_boss_dead(_tracked_boss):
		stop_effect()


func _is_boss_dead(boss: Node3D) -> bool:
	var hc: HealthComponent = boss.get_node_or_null("HealthComponent") as HealthComponent
	if hc != null and hc.current_health <= 0.0:
		return true
	if "current_state" in boss and "State" in boss and "DEAD" in boss.State:
		if boss.current_state == boss.State.DEAD:
			return true
	return false


func _resolve_ground_y(x: float, z: float, fallback_y: float) -> float:
	if is_inside_tree() and get_world_3d() != null:
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		if space != null:
			var q := PhysicsRayQueryParameters3D.create(
				Vector3(x, fallback_y + 35.0, z),
				Vector3(x, fallback_y - 40.0, z),
				1
			)
			q.collide_with_areas = false
			q.collide_with_bodies = true
			var hit: Dictionary = space.intersect_ray(q)
			if not hit.is_empty() and hit.has("position"):
				var hit_pos: Vector3 = hit["position"] as Vector3
				return hit_pos.y

	var arena: Node = get_parent()
	if arena != null and arena.has_method("_get_arena_ground_y"):
		var hy: float = float(arena.call("_get_arena_ground_y", x, z))
		if not is_nan(hy):
			return hy

	return fallback_y
