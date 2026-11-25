class_name ArcaneFlare
extends CharacterBody3D

## Petite orbe d'arcane ("Flare") à 1 PV :
## - Apparaît avec une vitesse initiale (aléatoire selon la source) et accélère lentement au fil du temps
## - Vole en guidage souple vers le joueur vivant le plus proche (maniabilité ajustée avec la vitesse)
## - Cassable par n'importe quelle attaque ou sort du joueur (1 PV, groupe "Enemie" + "ArcaneFlare")
## - Inflige des dégâts magiques au contact du joueur puis explose immédiatement

signal flare_popped

const GROUND_CHECK_INTERVAL: float = 0.32
const TARGET_REFRESH_INTERVAL: float = 0.25
const NET_SYNC_INTERVAL: float = 0.15
const MIN_GROUND_CLEARANCE: float = 0.65
const REFERENCE_TURN_SPEED_VEL: float = 2.8
const MIN_VISUAL_RANGE: float = 44.0

static var _cached_map_gen: Node = null
static var _cached_map_gen_frame: int = -1

@export_group("Mouvement & Guidage")
## Vitesse initiale de déplacement de cette orbe (en m/s)
@export_range(0.5, 20.0, 0.1, "suffix:m/s") var move_speed: float = 3.2
## Accélération progressive de l'orbe au fil du temps (en m/s²) pour rattraper le combat
@export_range(0.0, 5.0, 0.05, "suffix:m/s²") var speed_acceleration: float = 0.35
## Vitesse plafond maximale atteignable par l'orbe (en m/s)
@export_range(1.0, 25.0, 0.01, "suffix:m/s") var max_move_speed: float = 7.22
## Vitesse de braquage de base à basse vitesse (en rad/s, augmente proportionnellement avec la vitesse)
@export_range(0.2, 15.0, 0.1, "suffix:rad/s") var turn_speed: float = 2.6
## Durée de vie maximale avant dissipation automatique (en secondes)
@export_range(2.0, 60.0, 0.5, "suffix:s") var lifetime: float = 22.0

@export_group("Combat")
@export_range(1.0, 200.0, 1.0) var flare_damage: float = 18.0
@export_range(0.0, 25.0, 0.5) var flare_knockback: float = 4.0

var is_dead: bool = false

var _is_popped: bool = false
var _age: float = 0.0
var _current_speed: float = 3.2
var _bob_phase: float = 0.0
var _ground_check_timer: float = 0.0
var _target_refresh_timer: float = 0.0
var _net_sync_timer: float = 0.0
var _has_net_sync_target: bool = false
var _net_sync_pos: Vector3 = Vector3.ZERO
var _has_ground_floor: bool = false
var _min_allowed_y: float = -99999.0
var _move_dir: Vector3 = Vector3.FORWARD
var _target_player: Node3D = null

@onready var stats_component: StatsComponent = $StatsComponent as StatsComponent
@onready var health_component: HealthComponent = $HealthComponent as HealthComponent
@onready var hitbox_component: HitboxComponent = $HitboxComponent as HitboxComponent
@onready var attack_component: AttackComponent = $AttackComponent as AttackComponent
@onready var body_collision: CollisionShape3D = $CollisionShape3D as CollisionShape3D
@onready var visuals_root: Node3D = $Visuals as Node3D

func _enter_tree() -> void:
	set_multiplayer_authority(1)

func _ready() -> void:
	add_to_group("Enemie")
	add_to_group("ArcaneFlare")

	collision_layer = 256
	collision_mask = 0
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING

	_current_speed = maxf(0.1, move_speed)

	if visuals_root != null:
		for child: Node in visuals_root.get_children():
			var geom: GeometryInstance3D = child as GeometryInstance3D
			if geom != null and geom.visibility_range_end > 0.0 and geom.visibility_range_end < MIN_VISUAL_RANGE:
				geom.visibility_range_end = MIN_VISUAL_RANGE

	if health_component != null:
		if health_component.owner == null:
			health_component.owner = self
		if not health_component.died.is_connected(_on_health_died):
			health_component.died.connect(_on_health_died)

	if hitbox_component != null:
		if not hitbox_component.hit_received.is_connected(_on_hitbox_hit_received):
			hitbox_component.hit_received.connect(_on_hitbox_hit_received)

	if attack_component != null:
		if not attack_component.attack_landed.is_connected(_on_attack_landed):
			attack_component.attack_landed.connect(_on_attack_landed)
		if not attack_component.area_entered.is_connected(_on_attack_area_entered):
			attack_component.area_entered.connect(_on_attack_area_entered)

	_apply_stats()
	call_deferred("_post_spawn_init")

func _post_spawn_init() -> void:
	if _is_popped or not is_inside_tree():
		return
	# Déphasage déterministe basé sur la vraie global_position finale (après add_child + positionnement)
	var pos_hash: float = absf(global_position.x * 1.73 + global_position.z * 2.39 + global_position.y * 0.91)
	_bob_phase = fmod(pos_hash, TAU)
	_ground_check_timer = fmod(pos_hash, GROUND_CHECK_INTERVAL)
	_target_refresh_timer = TARGET_REFRESH_INTERVAL

	_refresh_target_player()
	if _target_player != null and is_instance_valid(_target_player):
		var init_delta: Vector3 = _get_player_torso_pos(_target_player) - global_position
		if init_delta.length_squared() > 0.001:
			_move_dir = init_delta.normalized()

	reset_physics_interpolation()

func setup_flare(
	p_speed: float = 3.2,
	p_damage: float = 18.0,
	p_lifetime: float = 22.0,
	p_turn_speed: float = 2.6,
	p_knockback: float = 4.0,
	p_acceleration: float = 0.35,
	p_max_speed: float = 7.22
) -> void:
	move_speed = maxf(0.1, p_speed)
	_current_speed = move_speed
	flare_damage = maxf(0.0, p_damage)
	lifetime = maxf(0.5, p_lifetime)
	turn_speed = maxf(0.1, p_turn_speed)
	flare_knockback = maxf(0.0, p_knockback)
	speed_acceleration = maxf(0.0, p_acceleration)
	max_move_speed = maxf(move_speed, p_max_speed)
	_apply_stats()

func _apply_stats() -> void:
	var atk: AttackComponent = attack_component
	if atk == null:
		atk = get_node_or_null("AttackComponent") as AttackComponent
	if atk != null:
		atk.base_damage = 0.0
		atk.damage_physical = 0.0
		atk.damage_magic = flare_damage
		atk.damage_fire = 0.0
		atk.damage_ice = 0.0
		atk.damage_lightning = 0.0
		atk.knockback_force = flare_knockback
		atk.knockback_angle = 12.0
		atk.can_headshot = false
		atk.ignore_caster = false

func _physics_process(delta: float) -> void:
	if _is_popped:
		return

	_age += delta
	var is_auth: bool = (not multiplayer.has_multiplayer_peer() or is_multiplayer_authority())
	if is_auth and _age >= lifetime:
		pop_flare(true)
		return
	elif not is_auth and _age >= lifetime + 1.25:
		_execute_pop_local(false)
		return

	var speed_cap: float = maxf(move_speed, max_move_speed)
	if speed_acceleration > 0.0 and _current_speed < speed_cap:
		_current_speed = minf(speed_cap, _current_speed + speed_acceleration * delta)

	_target_refresh_timer -= delta
	if _target_refresh_timer <= 0.0 or _is_player_invalid_or_dead(_target_player):
		_target_refresh_timer = TARGET_REFRESH_INTERVAL
		_refresh_target_player()

	if not _is_player_invalid_or_dead(_target_player):
		var target_pos: Vector3 = _get_player_torso_pos(_target_player)
		var to_target: Vector3 = target_pos - global_position
		var dist_sq: float = to_target.length_squared()
		var player_hc: HealthComponent = _target_player.get_node_or_null("HealthComponent") as HealthComponent
		var player_intangible: bool = (player_hc != null and player_hc.is_intangible)
		if is_auth and dist_sq <= 0.65 * 0.65 and not player_intangible:
			if attack_component != null and not attack_component.hit_entities.has(_target_player):
				var p_hb: HitboxComponent = _target_player.get_node_or_null("HitboxComponent") as HitboxComponent
				if p_hb != null:
					attack_component.hit_entities.append(_target_player)
					_apply_stats()
					p_hb.receive_hit(attack_component)
			pop_flare(true)
			return
		if dist_sq > 0.0004 and not (player_intangible and dist_sq < 1.8 * 1.8):
			var desired_dir: Vector3 = to_target / sqrt(dist_sq)
			var speed_ratio: float = maxf(1.0, _current_speed / REFERENCE_TURN_SPEED_VEL)
			var effective_turn: float = turn_speed * lerpf(1.0, speed_ratio, 0.72)
			_move_dir = _steer_direction(_move_dir, desired_dir, effective_turn * delta)

	_bob_phase = fmod(_bob_phase + delta * 3.1, TAU)
	var bob_vel_y: float = cos(_bob_phase) * 0.30

	_ground_check_timer -= delta
	if _ground_check_timer <= 0.0:
		_ground_check_timer = GROUND_CHECK_INTERVAL
		_update_ground_clearance()

	var vel: Vector3 = _move_dir * _current_speed
	vel.y += bob_vel_y

	if _has_ground_floor and global_position.y < _min_allowed_y:
		var lift_speed: float = (_min_allowed_y - global_position.y) * 6.0 + 0.75
		vel.y = maxf(vel.y, lift_speed)
		if global_position.y < _min_allowed_y - 0.45:
			global_position.y = _min_allowed_y

	velocity = vel
	# collision_mask == 0 : déplacement direct O(1) sans sweep-and-slide PhysicsServer3D coûteux
	global_position += vel * delta

	if multiplayer.has_multiplayer_peer():
		if is_auth:
			_net_sync_timer -= delta
			if _net_sync_timer <= 0.0:
				_net_sync_timer = NET_SYNC_INTERVAL
				_rpc_sync_motion.rpc(global_position, _move_dir, _current_speed)
		elif _has_net_sync_target:
			var drift_sq: float = global_position.distance_squared_to(_net_sync_pos)
			if drift_sq > 16.0:
				global_position = _net_sync_pos
			elif drift_sq > 0.0025:
				global_position = global_position.lerp(_net_sync_pos, clampf(delta * 8.5, 0.0, 1.0))

@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_sync_motion(sync_pos: Vector3, sync_dir: Vector3, sync_spd: float) -> void:
	if _is_popped:
		return
	_net_sync_pos = sync_pos
	_has_net_sync_target = true
	if sync_dir.length_squared() > 0.0001:
		_move_dir = sync_dir.normalized()
	if sync_spd > 0.05:
		_current_speed = sync_spd

func _steer_direction(current_dir: Vector3, desired_dir: Vector3, max_angle_rad: float) -> Vector3:
	var cur: Vector3 = current_dir.normalized() if current_dir.length_squared() > 0.0001 else Vector3.FORWARD
	var des: Vector3 = desired_dir.normalized() if desired_dir.length_squared() > 0.0001 else cur
	var angle: float = cur.angle_to(des)
	if angle <= 0.0001:
		return des
	var t: float = clampf(max_angle_rad / angle, 0.0, 1.0)
	if cur.dot(des) < -0.995:
		var perp: Vector3 = Vector3.UP.cross(cur)
		if perp.length_squared() < 0.001:
			perp = Vector3.RIGHT.cross(cur)
		des = (des + perp.normalized() * 0.25).normalized()
	return cur.slerp(des, t).normalized()

func _update_ground_clearance() -> void:
	if not is_inside_tree():
		return
	var cur_frame: int = Engine.get_physics_frames()
	if _cached_map_gen == null or not is_instance_valid(_cached_map_gen):
		if cur_frame != _cached_map_gen_frame and get_tree() != null and get_tree().current_scene != null:
			_cached_map_gen_frame = cur_frame
			_cached_map_gen = get_tree().current_scene.find_child("Map_generator", true, false)
	if _cached_map_gen != null and is_instance_valid(_cached_map_gen) and _cached_map_gen.has_method("get_terrain_height_at"):
		var th: float = float(_cached_map_gen.call("get_terrain_height_at", global_position.x, global_position.z))
		if not is_nan(th) and not is_inf(th):
			_has_ground_floor = true
			_min_allowed_y = th + MIN_GROUND_CLEARANCE
			return

	if get_world_3d() == null:
		return
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state == null:
		return
	var from_pos: Vector3 = global_position + Vector3(0.0, 2.4, 0.0)
	var to_pos: Vector3 = global_position - Vector3(0.0, 3.0, 0.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = space_state.intersect_ray(query)
	if not hit.is_empty() and hit.has("position"):
		var ground_pos: Vector3 = hit["position"] as Vector3
		_has_ground_floor = true
		_min_allowed_y = ground_pos.y + MIN_GROUND_CLEARANCE
	else:
		_has_ground_floor = false

func _refresh_target_player() -> void:
	if get_tree() == null:
		_target_player = null
		return
	var best_player: Node3D = null
	var best_d2: float = INF
	var my_pos: Vector3 = global_position
	for p_node: Node in get_tree().get_nodes_in_group("Player"):
		if p_node == null or not is_instance_valid(p_node):
			continue
		var player: Node3D = p_node as Node3D
		if _is_player_invalid_or_dead(player):
			continue
		var d2: float = my_pos.distance_squared_to(player.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best_player = player
	_target_player = best_player

static func _get_player_torso_pos(player: Node3D) -> Vector3:
	var cs: CollisionShape3D = player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs != null and cs.position.y < 0.25:
		# Player dont l'origine est déjà au centre de la capsule (~1.0m du sol, caméra FPS à +0.74m)
		return player.global_position + Vector3(0.0, 0.20, 0.0)
	return player.global_position + Vector3(0.0, 0.95, 0.0)

static func _is_player_invalid_or_dead(raw_player: Variant) -> bool:
	if raw_player == null or not is_instance_valid(raw_player):
		return true
	var player: Node3D = raw_player as Node3D
	if player == null or player.is_queued_for_deletion():
		return true
	if player.get("is_dead") == true or (player.has_method("is_dead") and bool(player.call("is_dead"))):
		return true
	var hc: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
	if hc != null and hc.current_health <= 0.0:
		return true
	return false

func _on_health_died() -> void:
	if _is_popped:
		return
	pop_flare(true)

func _on_hitbox_hit_received(attack: AttackComponent) -> void:
	if _is_popped:
		return
	if attack != null and attack == attack_component:
		return
	pop_flare(true)

func _on_attack_landed(target: Variant) -> void:
	if _is_popped:
		return
	if target != null and is_instance_valid(target) and target is HitboxComponent:
		var hb: HitboxComponent = target as HitboxComponent
		var raw_ent: Object = hb.owner if hb.owner != null else hb.get_parent()
		if raw_ent != null and is_instance_valid(raw_ent):
			var entity: Node3D = raw_ent as Node3D
			if entity != null and entity.is_in_group("Player"):
				if _is_player_invalid_or_dead(entity):
					if attack_component != null:
						attack_component.hit_entities.erase(entity)
					return
				pop_flare(true)

func _on_attack_area_entered(area: Area3D) -> void:
	if _is_popped:
		return
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	if area == null or not is_instance_valid(area):
		return
	var hb: HitboxComponent = area as HitboxComponent
	if hb == null:
		return
	var raw_ent: Object = hb.owner if hb.owner != null else hb.get_parent()
	if raw_ent == null or not is_instance_valid(raw_ent):
		return
	var entity: Node3D = raw_ent as Node3D
	if entity == null or not entity.is_in_group("Player") or _is_player_invalid_or_dead(entity):
		return
	# AttackComponent._on_area_entered s'exécute sur le même signal et inflige les dégâts via receive_hit
	if attack_component != null and not attack_component.hit_entities.has(entity):
		attack_component.hit_entities.append(entity)
		_apply_stats()
		hb.receive_hit(attack_component)
	pop_flare(true)

func pop_flare(play_vfx: bool = true) -> void:
	if _is_popped:
		return
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		_rpc_pop_flare.rpc(play_vfx)
		if not _is_popped:
			_execute_pop_local(play_vfx)
	else:
		_execute_pop_local(play_vfx)

@rpc("any_peer", "call_local", "reliable")
func _rpc_pop_flare(play_vfx: bool = true) -> void:
	_execute_pop_local(play_vfx)

func _execute_pop_local(play_vfx: bool) -> void:
	if _is_popped:
		return
	_is_popped = true
	is_dead = true
	set_physics_process(false)

	collision_layer = 0
	if body_collision != null:
		body_collision.set_deferred("disabled", true)
	if hitbox_component != null:
		hitbox_component.set_deferred("monitoring", false)
		hitbox_component.set_deferred("monitorable", false)
	if attack_component != null:
		attack_component.is_active_for_network = false
		attack_component.set_deferred("monitoring", false)
		attack_component.set_deferred("monitorable", false)
	if visuals_root != null:
		visuals_root.visible = false

	flare_popped.emit()

	if play_vfx and is_inside_tree():
		_spawn_pop_burst(global_position)

	if is_inside_tree() and multiplayer.has_multiplayer_peer() and get_tree() != null:
		get_tree().create_timer(0.45).timeout.connect(func() -> void:
			if is_instance_valid(self):
				queue_free()
		)
	else:
		queue_free()

func _spawn_pop_burst(world_pos: Vector3) -> void:
	if get_tree() == null:
		return
	var burst: GPUParticles3D = get_node_or_null("PopBurst") as GPUParticles3D
	if burst == null:
		return
	var vp: Viewport = get_viewport()
	if vp != null:
		var cam: Camera3D = vp.get_camera_3d()
		if cam != null and cam.global_position.distance_squared_to(world_pos) > 75.0 * 75.0:
			return

	var host_parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	if host_parent == null:
		return
	remove_child(burst)
	host_parent.add_child(burst)
	burst.global_position = world_pos
	burst.emitting = true

	var burst_ref: WeakRef = weakref(burst)
	burst.finished.connect(burst.queue_free)
	get_tree().create_timer(0.50).timeout.connect(func() -> void:
		var b: Node = burst_ref.get_ref() as Node
		if b != null and is_instance_valid(b):
			b.queue_free()
	)
