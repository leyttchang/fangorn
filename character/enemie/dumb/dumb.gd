extends CharacterBody3D

# --- COMPOSANTS EXTERNES (Les Muscles et le Guide) ---
@onready var health_component: HealthComponent = $HealthComponent
@onready var stats_component: StatsComponent = $StatsComponent
@onready var knockback_componant: Node = $knockback_componant
@onready var movement_comp: EnemyMovementComponent = $EnemyMovementComponent
@onready var navigation_comp: EnemyNavigationComponent = $EnemyNavigationComponent

# --- DONNÉES DE COMPORTEMENT (Le Profil) ---
@export var base_movement_speed: float = 4.5
@export var behavior: EnemyBehaviorData
## Décoche cette case pour revenir instantanément à l'ancienne texture d'origine du modèle Orc.glb
@export var use_handpainted_texture: bool = true

const PUNCH_HIT_START_SEC: float = 0.36
const PUNCH_HIT_END_SEC: float = 0.54
const PUNCH_MAX_DURATION_SEC: float = 1.25

@onready var attack_component: AttackComponent = get_node_or_null("Orc/Armature/Skeleton3D/BoneAttachment3D/AttackComponent") as AttackComponent
@onready var attack_shape: CollisionShape3D = get_node_or_null("Orc/Armature/Skeleton3D/BoneAttachment3D/AttackComponent/CollisionShape3D") as CollisionShape3D

# --- ANIMATION TREE ---
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")

# --- ÉTATS ---
enum State { IDLE, CHASE, ATTACK, DEAD }
var current_state: State = State.IDLE

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: Node3D = null

# Sécurité pour l'AnimationTree & Hitbox de la main
var _attack_anim_started: bool = false
var _attack_elapsed: float = 0.0
var _swing_reset_done: bool = false
var _hand_hitbox_active: bool = false
var is_anim_culled: bool = false


func _ready() -> void:
	if behavior == null:
		push_error("Orc (" + name + ") : Fichier EnemyBehaviorData manquant dans l'inspecteur !")

	# Neutralise toute piste d'animation touchant directement CollisionShape3D:disabled ou AttackComponent
	# (dans RESET comme dans Punch) afin que seul le code physique contrôle la hitbox de la main !
	var anim_player: AnimationPlayer = get_node_or_null("Orc/AnimationPlayer") as AnimationPlayer
	if anim_player != null:
		for anim_name: StringName in anim_player.get_animation_list():
			var anim: Animation = anim_player.get_animation(anim_name)
			if anim == null:
				continue
			for i: int in range(anim.get_track_count() - 1, -1, -1):
				var path_str: String = str(anim.track_get_path(i))
				if path_str.find("AttackComponent") >= 0 or path_str.find("disabled") >= 0 or path_str.find("CollisionShape3D") >= 0:
					anim.remove_track(i)

	_set_hand_hitbox_active(false, true)

	anim_tree.active = true
	health_component.died.connect(_on_died)

	if not use_handpainted_texture:
		var skel: Skeleton3D = get_node_or_null("Orc/Armature/Skeleton3D") as Skeleton3D
		if skel != null:
			for child: Node in skel.get_children():
				if child is MeshInstance3D:
					(child as MeshInstance3D).set_surface_override_material(0, null)

	if not has_node("EnemyOptimizerComponent"):
		var opt := EnemyOptimizerComponent.new()
		opt.name = "EnemyOptimizerComponent"
		add_child(opt)

	call_deferred("actor_setup")


func _set_hand_hitbox_active(active: bool, force_apply: bool = false) -> void:
	if not force_apply and _hand_hitbox_active == active:
		if not active:
			if attack_shape != null and not attack_shape.disabled:
				attack_shape.disabled = true
			if attack_component != null and attack_component.monitoring:
				attack_component.monitoring = false
		return

	_hand_hitbox_active = active
	if attack_shape != null:
		attack_shape.disabled = not active
	if attack_component != null:
		attack_component.monitoring = active
		if active and attack_component.has_method("reset_hit_entities"):
			attack_component.reset_hit_entities()


func actor_setup() -> void:
	await get_tree().physics_frame
	if is_multiplayer_authority() and current_state == State.IDLE:
		_update_closest_target()
		if target != null:
			var distance: float = global_position.distance_to(target.global_position)
			if distance <= behavior.attack_range:
				change_state(State.ATTACK)
			else:
				change_state(State.CHASE)
		else:
			change_state(State.IDLE)

	for hitbox: Node in find_children("*HitboxComponent*", "", true, false):
		if hitbox.has_signal("aggro_requested") and not hitbox.is_connected("aggro_requested", _on_aggro_requested):
			hitbox.connect("aggro_requested", _on_aggro_requested)


var _pending_attacker: Node3D = null
var _is_waiting_for_aggro: bool = false

func _on_aggro_requested(attacker: Node3D) -> void:
	if not is_multiplayer_authority() or current_state == State.DEAD:
		return

	_pending_attacker = attacker
	if not _is_waiting_for_aggro:
		_is_waiting_for_aggro = true
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(self) or current_state == State.DEAD:
			return
		target = _pending_attacker
		_target_update_timer = 0.0
		_is_waiting_for_aggro = false

var _target_update_timer: float = 0.0

func _update_closest_target() -> void:
	if navigation_comp:
		target = navigation_comp.acquire_target(target)
	else:
		target = null


# ==========================================================
# LA VRAIE MACHINE À ÉTATS
# ==========================================================
func change_state(new_state: State) -> void:
	if is_multiplayer_authority():
		rpc("_rpc_apply_state", new_state)

func _sync_animation_state() -> void:
	if not anim_playback:
		return
	match current_state:
		State.IDLE:
			anim_playback.travel("Walk2" if _is_pack_walking else "Stand")
		State.CHASE:
			anim_playback.travel("Walk2")
		State.ATTACK:
			anim_playback.travel("Punch")
		State.DEAD:
			anim_playback.travel("Death")

@rpc("authority", "call_local", "reliable")
func _rpc_apply_state(new_state: int) -> void:
	if current_state == State.DEAD:
		return
	if current_state == new_state and new_state != State.IDLE:
		return

	current_state = new_state as State
	_set_hand_hitbox_active(false, true)

	if current_state == State.IDLE:
		_is_pack_walking = false
	elif current_state == State.ATTACK:
		_attack_anim_started = false
		_attack_elapsed = 0.0
		_swing_reset_done = false

	_sync_animation_state()


# ==========================================================
# LA PHYSIQUE ET SYNCHRONISATION
# ==========================================================
func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		_set_hand_hitbox_active(false)
		return

	var action_speed: float = 1.0
	if stats_component != null:
		action_speed = maxf(0.0, stats_component.get_stat_value("action_speed"))

	# --- STUN TOTAL & CULLING ANIMATION ---
	if is_anim_culled:
		_set_hand_hitbox_active(false)
		if anim_tree.active:
			anim_tree.active = false
	elif action_speed <= 0.0:
		_set_hand_hitbox_active(false)
		if not is_on_floor():
			velocity.y -= gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		move_and_slide()

		if anim_tree.active:
			anim_tree.active = false
		return
	elif not anim_tree.active:
		anim_tree.active = true
		_sync_animation_state()

	# Recherche / actualisation de cible selon le mode de jeu
	_target_update_timer += delta
	var target_check_interval: float = 15.0 if GameData.current_game_mode == GameData.GameMode.WAVE else (0.5 if target == null else 2.0)
	if _target_update_timer > target_check_interval or not is_instance_valid(target):
		_target_update_timer = 0.0
		_update_closest_target()

	if not is_on_floor():
		velocity.y -= gravity * delta

	# Synchronisation stricte de l'animation d'attaque et de la fenêtre active du poing
	var should_enable_fist: bool = false
	if current_state == State.ATTACK:
		_attack_elapsed += delta * action_speed
		if is_anim_culled:
			if _attack_elapsed >= PUNCH_MAX_DURATION_SEC:
				change_state(State.IDLE)
		elif anim_playback != null:
			var current_anim: StringName = anim_playback.get_current_node()
			if current_anim == &"Punch":
				_attack_anim_started = true
				var play_pos: float = anim_playback.get_current_play_position()
				if play_pos >= PUNCH_HIT_START_SEC and play_pos <= PUNCH_HIT_END_SEC:
					should_enable_fist = true
					if not _swing_reset_done:
						_swing_reset_done = true
						if attack_component != null:
							attack_component.reset_hit_entities()
			elif _attack_anim_started and (current_anim == &"Stand" or current_anim == &"Walk2"):
				change_state(State.IDLE)
			elif _attack_elapsed >= PUNCH_MAX_DURATION_SEC:
				change_state(State.IDLE)

	_set_hand_hitbox_active(should_enable_fist)

	var current_speed: float = base_movement_speed * stats_component.get_stat_value("movement_speed") * action_speed
	var vitesse_horizontale := Vector2(velocity.x, velocity.z)

	match current_state:
		State.DEAD:
			vitesse_horizontale = movement_comp.apply_friction(vitesse_horizontale, behavior, delta)
		State.IDLE:
			vitesse_horizontale = _process_idle_state(vitesse_horizontale, delta)
		State.CHASE:
			vitesse_horizontale = _process_chase_state(vitesse_horizontale, delta, current_speed)
		State.ATTACK:
			vitesse_horizontale = _process_attack_state(vitesse_horizontale, delta)

	velocity.x = vitesse_horizontale.x
	velocity.z = vitesse_horizontale.y

	if not vitesse_horizontale.is_zero_approx() or not is_on_floor() or velocity.y != 0.0:
		move_and_slide()


# ==========================================================
# LOGIQUE DES COMPORTEMENTS (Le Cerveau)
# ==========================================================
var _is_pack_walking: bool = false

func _set_pack_walking(is_walking: bool) -> void:
	if _is_pack_walking == is_walking:
		return
	_is_pack_walking = is_walking
	if is_multiplayer_authority():
		rpc("_rpc_set_pack_walking", is_walking)

@rpc("authority", "call_local", "unreliable")
func _rpc_set_pack_walking(is_walking: bool) -> void:
	if current_state != State.IDLE:
		return
	if is_walking:
		anim_playback.travel("Walk2")
	else:
		anim_playback.travel("Stand")

func _process_idle_state(vitesse_horiz: Vector2, delta: float) -> Vector2:
	if target != null and is_instance_valid(target):
		var distance: float = global_position.distance_to(target.global_position)
		if distance <= behavior.attack_range:
			change_state(State.ATTACK)
		else:
			change_state(State.CHASE)
		_set_pack_walking(false)
		return movement_comp.apply_friction(vitesse_horiz, behavior, delta)

	# Déplacement de meute hors-combat (patrouille / roam)
	if navigation_comp and navigation_comp.has_pack_destination:
		var dir: Vector3 = navigation_comp.get_pack_roam_direction()
		if dir != Vector3.ZERO:
			movement_comp.rotate_towards_direction(dir, behavior, delta)
			var roam_speed: float = base_movement_speed * navigation_comp.pack_speed_mult * stats_component.get_stat_value("movement_speed")
			_set_pack_walking(true)
			if anim_tree.active and anim_playback and anim_playback.get_current_node() != &"Walk2":
				anim_playback.travel("Walk2")
			return movement_comp.accelerate_to_direction(vitesse_horiz, dir, roam_speed, behavior, delta)
		else:
			_set_pack_walking(false)

	_set_pack_walking(false)
	return movement_comp.apply_friction(vitesse_horiz, behavior, delta)

func _process_chase_state(vitesse_horiz: Vector2, delta: float, speed: float) -> Vector2:
	if target == null or not is_instance_valid(target):
		change_state(State.IDLE)
		return movement_comp.apply_friction(vitesse_horiz, behavior, delta)

	var distance_to_target: float = global_position.distance_to(target.global_position)
	if distance_to_target <= behavior.attack_range:
		change_state(State.ATTACK)
		return movement_comp.apply_friction(vitesse_horiz, behavior, delta)

	if anim_tree.active and anim_playback and anim_playback.get_current_node() != &"Walk2":
		anim_playback.travel("Walk2")

	var direction: Vector3 = navigation_comp.get_direction_to_target(target.global_position)
	movement_comp.rotate_towards_direction(direction, behavior, delta)
	return movement_comp.accelerate_to_direction(vitesse_horiz, direction, speed, behavior, delta)

func _process_attack_state(vitesse_horiz: Vector2, delta: float) -> Vector2:
	if target != null and is_instance_valid(target):
		var direction: Vector3 = (target.global_position - global_position).normalized()
		var turn_mult: float = 0.75
		if anim_playback != null and anim_playback.get_current_node() == &"Punch" and anim_playback.get_current_play_position() >= 0.34:
			turn_mult = 0.30
		movement_comp.rotate_towards_direction(direction, behavior, delta, turn_mult)

	return movement_comp.apply_friction(vitesse_horiz, behavior, delta)


# ==========================================================
# ÉVÉNEMENTS
# ==========================================================
func _on_died() -> void:
	_set_hand_hitbox_active(false, true)
	remove_from_group("Enemie")
	get_tree().call_group("ScoreManager", "add_kill_point")
	change_state(State.DEAD)
	collision_layer = 0
	collision_mask = 1
	for hb: Node in find_children("*HitboxComponent*", "", true, false):
		var hb_col: CollisionShape3D = hb.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if hb_col != null:
			hb_col.set_deferred("disabled", true)
	await get_tree().create_timer(3.0).timeout
	if is_multiplayer_authority():
		queue_free()
