extends CharacterBody3D

# --- COMPOSANTS EXTERNES ---
@onready var health_component: HealthComponent = $HealthComponent
@onready var stats_component: StatsComponent = $StatsComponent
@onready var knockback_componant = $knockback_componant
@onready var movement_comp: EnemyMovementComponent = $EnemyMovementComponent
@onready var navigation_comp: EnemyNavigationComponent = $EnemyNavigationComponent

# --- DONNEES DE COMPORTEMENT ---
@export var base_movement_speed: float = 4.5
@export var behavior: EnemyBehaviorData

@export_group("Composants d'Attaque")
@export var hand_attack_component: Node3D
@export var foot_attack_component: Node3D
@export var hand_attack_shape: CollisionShape3D
@export var foot_attack_shape: CollisionShape3D

@export_group("Attaque de Racines (Root Attack)")
## Scène de l'attaque de racines (lancée automatiquement en mode aller-retour puis coupée à la rétraction)
@export var root_attack_scene: PackedScene = preload("res://character/enemie/tree_man/tree_man_root_attack.tscn")
## Marqueur Marker3D d'où spawnent les racines sur le Tree Man
@export var root_spawn: Marker3D
## Temps de recharge entre deux attaques de racines (en secondes)
@export var root_attack_cooldown: float = 8.0
## Portée minimale pour déclencher l'attaque de racines en poursuite (en mètres)
@export var root_attack_min_range: float = 3.2
## Portée maximale de déclenchement de l'attaque de racines (en mètres)
@export var root_attack_max_range: float = 15.5
## Probabilité d'utiliser l'attaque de racines au corps-à-corps quand le cooldown est prêt
@export_range(0.0, 1.0) var root_attack_melee_chance: float = 0.35
## Vitesse de l'animation stand_up jouée à l'envers (pour se plaquer au sol avant le spawn des racines)
@export var stand_down_speed: float = 1.25
## Vitesse de l'animation stand_up jouée à l'endroit (pour se relever une fois les racines rentrées)
@export var stand_up_recovery_speed: float = 1.35

# --- ANIMATION TREE & PLAYER ---
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
@onready var anim_player: AnimationPlayer = $"T-Pose/AnimationPlayer"
@onready var _skeleton: Skeleton3D = get_node_or_null("T-Pose/Armature/Skeleton3D") as Skeleton3D

# --- ETATS ---
enum State { IDLE, CHASE, ATTACK, ROOT_ATTACK, DEAD }
enum RootPhase { NONE, KNEELING_DOWN, HOLDING_GROUND, STANDING_UP }

var current_state: State = State.IDLE
var _root_phase: RootPhase = RootPhase.NONE

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: Node3D = null

var _current_attack_anim: String = "zombie_attack"
var _attack_anim_started: bool = false
var _target_update_timer: float = 0.0
var _pending_attacker: Node3D = null
var _is_waiting_for_aggro: bool = false
var is_anim_culled: bool = false

# Variables internes de l'attaque de racines
var _root_attack_cd_timer: float = 2.0
var _chase_time_elapsed: float = 0.0
var _root_phase_timer: float = 0.0
var _locked_root_yaw: float = 0.0
var _stand_up_anim_len: float = 2.3333
var _active_root_attack: Node3D = null

func _ready() -> void:
	randomize()
	if behavior == null:
		push_error("TreeMan (" + name + ") : Fichier EnemyBehaviorData manquant dans l'inspecteur !")

	if anim_player != null and anim_player.has_animation("anim/stand_up"):
		var su_anim := anim_player.get_animation("anim/stand_up")
		if su_anim != null:
			_stand_up_anim_len = maxf(0.1, su_anim.length)

	if root_spawn == null:
		root_spawn = find_child("root_spawn", true, false) as Marker3D

	if anim_tree != null:
		anim_tree.active = true

	health_component.died.connect(_on_died)
	health_component.health_changed.connect(_on_health_changed)

	disable_hitbox()

	if not has_node("EnemyOptimizerComponent"):
		var opt = EnemyOptimizerComponent.new()
		opt.name = "EnemyOptimizerComponent"
		add_child(opt)

	call_deferred("actor_setup")

func actor_setup() -> void:
	await get_tree().physics_frame
	var hitboxes = find_children("*HitboxComponent*", "", true, false)
	for hitbox in hitboxes:
		if hitbox.has_signal("aggro_requested") and not hitbox.aggro_requested.is_connected(_on_aggro_requested):
			hitbox.aggro_requested.connect(_on_aggro_requested)

	if is_multiplayer_authority() and current_state == State.IDLE:
		_update_closest_target()
		if target != null:
			var distance = global_position.distance_to(target.global_position)
			if distance <= behavior.attack_range:
				change_state(State.ATTACK)
			else:
				change_state(State.CHASE)
		else:
			change_state(State.IDLE)

# ==========================================================
# GESTION DES HITBOXES D'ATTAQUE (Appelees par l'AnimationPlayer)
# ==========================================================
func enable_hitbox() -> void:
	if current_state != State.ATTACK:
		return
	if _current_attack_anim == "zombie_kicking":
		enable_foot_hitbox()
	else:
		enable_hand_hitbox()

func enable_hand_hitbox() -> void:
	if hand_attack_shape != null:
		hand_attack_shape.disabled = false
	if hand_attack_component != null and hand_attack_component.has_method("reset_hit_entities"):
		hand_attack_component.reset_hit_entities()

func enable_foot_hitbox() -> void:
	if foot_attack_shape != null:
		foot_attack_shape.disabled = false
	if foot_attack_component != null and foot_attack_component.has_method("reset_hit_entities"):
		foot_attack_component.reset_hit_entities()

func disable_hitbox() -> void:
	if hand_attack_shape != null:
		hand_attack_shape.disabled = true
	if foot_attack_shape != null:
		foot_attack_shape.disabled = true
	if hand_attack_component != null and hand_attack_component.has_method("reset_hit_entities"):
		hand_attack_component.reset_hit_entities()
	if foot_attack_component != null and foot_attack_component.has_method("reset_hit_entities"):
		foot_attack_component.reset_hit_entities()

# ==========================================================
# RECHERCHE DE CIBLE & AGGRO (Camouflage en T-Pose en IDLE)
# ==========================================================
func _on_aggro_requested(attacker: Node3D) -> void:
	if not is_multiplayer_authority() or current_state == State.DEAD:
		return

	_pending_attacker = attacker
	if not _is_waiting_for_aggro:
		_is_waiting_for_aggro = true
		await get_tree().create_timer(0.2).timeout
		if not is_instance_valid(self) or current_state == State.DEAD:
			return
		target = _pending_attacker
		_target_update_timer = 0.0
		_is_waiting_for_aggro = false

func _update_closest_target() -> void:
	if navigation_comp == null:
		target = null
		return

	var candidate = navigation_comp.acquire_target(target)
	# Si le Tree Man est camoufle en IDLE (T-Pose), il attend qu'un joueur entre dans sa detection_range
	if current_state == State.IDLE and candidate != null and is_instance_valid(candidate):
		var det_range: float = behavior.detection_range if (behavior != null and behavior.detection_range > 0.0) else navigation_comp.default_detection_radius
		if global_position.distance_squared_to(candidate.global_position) > (det_range * det_range):
			target = null
			return

	target = candidate

# ==========================================================
# MACHINE A ETATS & SYNCHRONISATION RESEAU
# ==========================================================
func change_state(new_state: State) -> void:
	if not is_multiplayer_authority() or current_state == State.DEAD:
		return

	if new_state == State.ATTACK and current_state != State.ATTACK:
		# Intégration dans le pattern : peut lancer l'attaque de racines au corps-à-corps si prête
		if root_attack_scene != null and _root_attack_cd_timer <= 0.0 and randf() < root_attack_melee_chance:
			_trigger_root_attack_towards_target()
			return

	var chosen_attack: String = _current_attack_anim
	if new_state == State.ATTACK and current_state != State.ATTACK:
		chosen_attack = "zombie_attack" if randf() < 0.5 else "zombie_kicking"

	rpc("_rpc_apply_state", new_state, chosen_attack)

func _trigger_root_attack_towards_target() -> void:
	if not is_multiplayer_authority() or current_state == State.DEAD:
		return
	var yaw := global_rotation.y
	if target != null and is_instance_valid(target):
		var dir := target.global_position - global_position
		if Vector2(dir.x, dir.z).length_squared() > 0.001:
			yaw = atan2(dir.x, dir.z)
	_root_attack_cd_timer = root_attack_cooldown
	rpc("_rpc_start_root_attack", yaw)

func _sync_animation_state() -> void:
	# Empêche EnemyOptimizerComponent de réactiver l'AnimationTree en plein milieu de ROOT_ATTACK !
	if current_state == State.ROOT_ATTACK:
		if anim_tree != null and anim_tree.active:
			anim_tree.active = false
		_restore_root_phase_pose()
		return

	if not anim_playback:
		return
	match current_state:
		State.IDLE:
			anim_playback.travel("t_pose")
		State.CHASE:
			anim_playback.travel("zombie_running")
		State.ATTACK:
			anim_playback.travel(_current_attack_anim)

@rpc("authority", "call_local", "reliable")
func _rpc_apply_state(new_state: int, attack_anim: String = "zombie_attack") -> void:
	if current_state == State.DEAD:
		return
	if current_state == new_state and new_state != State.IDLE:
		return

	var was_root_attack := (current_state == State.ROOT_ATTACK)
	current_state = new_state as State
	_current_attack_anim = attack_anim
	_root_phase = RootPhase.NONE

	if current_state == State.CHASE:
		_chase_time_elapsed = 0.0

	if was_root_attack and anim_tree != null and not is_anim_culled:
		anim_tree.active = true

	if current_state == State.ATTACK:
		_attack_anim_started = false
		disable_hitbox()
	else:
		disable_hitbox()

	_sync_animation_state()

# ==========================================================
# SEQUENCE COMPLETE DE ROOT_ATTACK (Serveur & Clients)
# 1. stand_up à l'envers -> 2. Plaquer au sol + spawn racines (aller-retour coupé à 0) -> 3. stand_up à l'endroit
# ==========================================================
@rpc("authority", "call_local", "reliable")
func _rpc_start_root_attack(target_yaw: float) -> void:
	if current_state == State.DEAD:
		return

	disable_hitbox()
	_cleanup_active_root_attack()

	current_state = State.ROOT_ATTACK
	_root_phase = RootPhase.KNEELING_DOWN
	_root_phase_timer = 0.0
	_locked_root_yaw = target_yaw
	_root_attack_cd_timer = root_attack_cooldown

	if anim_tree != null:
		anim_tree.active = false

	# Étape 1 : Jouer l'animation stand_up À L'ENVERS (du debout vers le sol)
	if anim_player != null and anim_player.has_animation("anim/stand_up"):
		anim_player.speed_scale = 1.0
		anim_player.play("anim/stand_up", 0.18, -stand_down_speed, true)

func _enter_root_holding_ground_phase() -> void:
	if current_state != State.ROOT_ATTACK or _root_phase == RootPhase.HOLDING_GROUND:
		return

	_root_phase = RootPhase.HOLDING_GROUND
	_root_phase_timer = 0.0
	global_rotation.y = _locked_root_yaw

	# Étape 2A : Rester plaqué contre le sol (fin de l'animation stand_up inversée = t=0.0)
	_lock_ground_pose()

	# Étape 2B : Spawner la scène root_man_root_attack directement sur le Marker3D root_spawn
	if root_attack_scene != null:
		var inst := root_attack_scene.instantiate() as Node3D
		if inst != null:
			_active_root_attack = inst
			inst.top_level = true
			add_child(inst)

			var basis_aligned := Basis(Vector3.UP, _locked_root_yaw)
			var spawn_pos := root_spawn.global_position if (root_spawn != null and is_instance_valid(root_spawn)) else global_position
			inst.global_transform = Transform3D(basis_aligned, spawn_pos)

			var atk := inst.get_node_or_null("AttackComponent") as AttackComponent
			if atk != null:
				atk.caster = self

			if inst.has_signal("roots_retracted"):
				inst.connect("roots_retracted", _on_roots_retracted, CONNECT_ONE_SHOT)

func _on_roots_retracted() -> void:
	if current_state != State.ROOT_ATTACK or _root_phase != RootPhase.HOLDING_GROUND:
		return
	_active_root_attack = null
	_enter_root_standing_up_phase()

func _enter_root_standing_up_phase() -> void:
	if current_state != State.ROOT_ATTACK or _root_phase == RootPhase.STANDING_UP:
		return

	_root_phase = RootPhase.STANDING_UP
	_root_phase_timer = 0.0

	# Étape 3 : Une fois les racines rentrées, le Tree Man se relève du sol
	if anim_player != null and anim_player.has_animation("anim/stand_up"):
		anim_player.speed_scale = 1.0
		anim_player.play("anim/stand_up", 0.0, stand_up_recovery_speed, false)

func _finish_root_attack_sequence() -> void:
	if current_state != State.ROOT_ATTACK:
		return

	_root_phase = RootPhase.NONE
	if anim_tree != null and not is_anim_culled:
		anim_tree.active = true

	if is_multiplayer_authority():
		if target != null and is_instance_valid(target):
			var dist := global_position.distance_to(target.global_position)
			if behavior != null and dist <= behavior.attack_range:
				change_state(State.ATTACK)
			else:
				change_state(State.CHASE)
		else:
			change_state(State.IDLE)

func _lock_ground_pose() -> void:
	if anim_tree != null and anim_tree.active:
		anim_tree.active = false
	if anim_player != null and anim_player.has_animation("anim/stand_up"):
		anim_player.play("anim/stand_up", 0.0, 0.0, false)
		anim_player.seek(0.0, true)
		anim_player.pause()
	if _skeleton != null:
		_skeleton.force_update_all_bone_transforms()

func _restore_root_phase_pose() -> void:
	if _root_phase == RootPhase.HOLDING_GROUND:
		_lock_ground_pose()

func _cleanup_active_root_attack() -> void:
	if _active_root_attack != null and is_instance_valid(_active_root_attack):
		_active_root_attack.queue_free()
	_active_root_attack = null

func _process(delta: float) -> void:
	if current_state != State.ROOT_ATTACK:
		return

	# Garantir que l'AnimationTree ne reprend jamais la main pendant ROOT_ATTACK
	if anim_tree != null and anim_tree.active:
		anim_tree.active = false

	var action_speed: float = 1.0
	if stats_component != null:
		action_speed = maxf(0.0, stats_component.get_stat_value("action_speed"))

	if anim_player != null and _root_phase != RootPhase.HOLDING_GROUND:
		anim_player.speed_scale = action_speed
	if _active_root_attack != null and is_instance_valid(_active_root_attack) and _active_root_attack.has_method("set_speed_scale"):
		_active_root_attack.set_speed_scale(action_speed)

	if action_speed <= 0.0:
		return

	_root_phase_timer += delta * action_speed

	match _root_phase:
		RootPhase.KNEELING_DOWN:
			# Aligne doucement l'orientation sur la direction verrouillée pendant le début de la descente
			global_rotation.y = lerp_angle(global_rotation.y, _locked_root_yaw, 10.0 * delta)
			var expected_dur := _stand_up_anim_len / maxf(0.1, stand_down_speed)
			var anim_done := false
			if anim_player != null and not is_anim_culled:
				if not anim_player.is_playing() and _root_phase_timer > 0.12:
					anim_done = true
				elif _root_phase_timer > 0.15 and anim_player.current_animation_position <= 0.03:
					anim_done = true
			if anim_done or _root_phase_timer >= expected_dur + 0.06:
				_enter_root_holding_ground_phase()

		RootPhase.HOLDING_GROUND:
			# Maintient strictement la pose contre le sol tant que les racines ne sont pas rentrées
			if anim_player != null and anim_player.is_playing():
				_lock_ground_pose()
			# Filet de sécurité si l'instance des racines a été détruite ou hors-écran > 4.25s
			if (_active_root_attack == null or not is_instance_valid(_active_root_attack)) and _root_phase_timer > 0.2:
				_enter_root_standing_up_phase()
			elif _root_phase_timer >= 4.35:
				_cleanup_active_root_attack()
				_enter_root_standing_up_phase()

		RootPhase.STANDING_UP:
			var expected_up := _stand_up_anim_len / maxf(0.1, stand_up_recovery_speed)
			var up_done := false
			if anim_player != null and not is_anim_culled:
				if not anim_player.is_playing() and _root_phase_timer > 0.12:
					up_done = true
				elif _root_phase_timer > 0.15 and anim_player.current_animation_position >= _stand_up_anim_len - 0.04:
					up_done = true
			if up_done or _root_phase_timer >= expected_up + 0.06:
				_finish_root_attack_sequence()

# ==========================================================
# PHYSIQUE & COMPORTEMENTS (Autorité Serveur)
# ==========================================================
func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if current_state == State.DEAD:
		return

	var action_speed: float = 1.0
	if stats_component != null:
		action_speed = max(0.0, stats_component.get_stat_value("action_speed"))

	if _root_attack_cd_timer > 0.0 and current_state != State.ROOT_ATTACK:
		_root_attack_cd_timer = maxf(0.0, _root_attack_cd_timer - delta * action_speed)

	# --- STUN TOTAL & CULLING ANIMATION ---
	if is_anim_culled:
		if anim_tree.active:
			anim_tree.active = false
	elif action_speed <= 0.0:
		if not is_on_floor():
			velocity.y -= gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		move_and_slide()
		if anim_tree.active:
			anim_tree.active = false
		disable_hitbox()
		return
	elif current_state != State.ROOT_ATTACK and not anim_tree.active:
		anim_tree.active = true
		_sync_animation_state()

	# Actualisation periodique de la cible
	_target_update_timer += delta
	var target_check_interval: float = 0.4 if target == null else 1.5
	if _target_update_timer >= target_check_interval or not is_instance_valid(target):
		_target_update_timer = 0.0
		_update_closest_target()

	if not is_on_floor():
		velocity.y -= gravity * delta

	# Suivi de la fin de l'animation d'attaque au corps-à-corps
	if current_state == State.ATTACK and anim_playback != null:
		var current_anim: StringName = anim_playback.get_current_node()
		if current_anim == _current_attack_anim:
			_attack_anim_started = true
		elif _attack_anim_started and (current_anim == &"zombie_running" or current_anim == &"t_pose"):
			_attack_anim_started = false
			disable_hitbox()
			if target != null and is_instance_valid(target):
				change_state(State.CHASE)
			else:
				change_state(State.IDLE)

	if current_state != State.ATTACK:
		if (hand_attack_shape != null and not hand_attack_shape.disabled) or (foot_attack_shape != null and not foot_attack_shape.disabled):
			disable_hitbox()

	var current_speed: float = base_movement_speed * stats_component.get_stat_value("movement_speed") * action_speed
	var vitesse_horizontale := Vector2(velocity.x, velocity.z)

	match current_state:
		State.IDLE:
			vitesse_horizontale = _process_idle_state(vitesse_horizontale, delta)
		State.CHASE:
			vitesse_horizontale = _process_chase_state(vitesse_horizontale, delta, current_speed)
		State.ATTACK:
			vitesse_horizontale = _process_attack_state(vitesse_horizontale, delta)
		State.ROOT_ATTACK:
			vitesse_horizontale = movement_comp.apply_friction(vitesse_horizontale, behavior, delta)

	velocity.x = vitesse_horizontale.x
	velocity.z = vitesse_horizontale.y

	if not vitesse_horizontale.is_zero_approx() or not is_on_floor() or velocity.y != 0.0:
		move_and_slide()

func _process_idle_state(vitesse_horiz: Vector2, delta: float) -> Vector2:
	# En IDLE, le Tree Man reste totalement immobile en T-Pose pour se camoufler en arbre
	if target != null and is_instance_valid(target):
		var distance = global_position.distance_to(target.global_position)
		if distance <= behavior.attack_range:
			change_state(State.ATTACK)
		else:
			change_state(State.CHASE)
	return movement_comp.apply_friction(vitesse_horiz, behavior, delta)

func _process_chase_state(vitesse_horiz: Vector2, delta: float, speed: float) -> Vector2:
	if target == null or not is_instance_valid(target):
		change_state(State.IDLE)
		return movement_comp.apply_friction(vitesse_horiz, behavior, delta)

	_chase_time_elapsed += delta
	var distance_to_target = global_position.distance_to(target.global_position)

	# Déclenchement de l'attaque de racines à moyenne/longue portée dès que prête !
	if root_attack_scene != null and _root_attack_cd_timer <= 0.0 and _chase_time_elapsed >= 0.45:
		if distance_to_target >= root_attack_min_range and distance_to_target <= root_attack_max_range:
			_trigger_root_attack_towards_target()
			return movement_comp.apply_friction(vitesse_horiz, behavior, delta)

	if distance_to_target <= behavior.attack_range:
		change_state(State.ATTACK)
		return movement_comp.apply_friction(vitesse_horiz, behavior, delta)

	if anim_tree.active and anim_playback and anim_playback.get_current_node() != &"zombie_running":
		anim_playback.travel("zombie_running")

	var direction = navigation_comp.get_direction_to_target(target.global_position)
	movement_comp.rotate_towards_direction(direction, behavior, delta)
	return movement_comp.accelerate_to_direction(vitesse_horiz, direction, speed, behavior, delta)

func _process_attack_state(vitesse_horiz: Vector2, delta: float) -> Vector2:
	if target != null and is_instance_valid(target):
		var direction = (target.global_position - global_position).normalized()
		movement_comp.rotate_towards_direction(direction, behavior, delta, 1.5)
	return movement_comp.apply_friction(vitesse_horiz, behavior, delta)

# ==========================================================
# EVENEMENTS DE SANTE & MORT
# ==========================================================
func _on_health_changed(_current_hp: float, _max_hp: float) -> void:
	pass

func _on_died() -> void:
	if is_multiplayer_authority():
		if current_state == State.DEAD:
			return
		get_tree().call_group("ScoreManager", "add_kill_point")
		rpc("_rpc_trigger_death")

@rpc("authority", "call_local", "reliable")
func _rpc_trigger_death() -> void:
	remove_from_group("Enemie")
	current_state = State.DEAD
	_root_phase = RootPhase.NONE
	_cleanup_active_root_attack()
	disable_hitbox()
	collision_layer = 0
	collision_mask = 1
	await get_tree().create_timer(4.0).timeout
	if is_multiplayer_authority():
		queue_free()
