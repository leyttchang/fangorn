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

# --- ANIMATION TREE ---
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")

# --- ETATS ---
enum State { IDLE, CHASE, ATTACK, DEAD }
var current_state: State = State.IDLE

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: Node3D = null

var _current_attack_anim: String = "zombie_attack"
var _attack_anim_started: bool = false
var _target_update_timer: float = 0.0
var _pending_attacker: Node3D = null
var _is_waiting_for_aggro: bool = false
var is_anim_culled: bool = false

func _ready() -> void:
	randomize()
	if behavior == null:
		push_error("TreeMan (" + name + ") : Fichier EnemyBehaviorData manquant dans l'inspecteur !")

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

	var chosen_attack: String = _current_attack_anim
	if new_state == State.ATTACK and current_state != State.ATTACK:
		chosen_attack = "zombie_attack" if randf() < 0.5 else "zombie_kicking"

	rpc("_rpc_apply_state", new_state, chosen_attack)

func _sync_animation_state() -> void:
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

	current_state = new_state as State
	_current_attack_anim = attack_anim

	if current_state == State.ATTACK:
		_attack_anim_started = false
		disable_hitbox()
	else:
		disable_hitbox()

	_sync_animation_state()

# ==========================================================
# PHYSIQUE & COMPORTEMENTS
# ==========================================================
func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if current_state == State.DEAD:
		return

	var action_speed: float = 1.0
	if stats_component != null:
		action_speed = max(0.0, stats_component.get_stat_value("action_speed"))

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
	elif not anim_tree.active:
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

	# Suivi de la fin de l'animation d'attaque
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

	var distance_to_target = global_position.distance_to(target.global_position)
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
	disable_hitbox()
	collision_layer = 0
	collision_mask = 1
	await get_tree().create_timer(4.0).timeout
	if is_multiplayer_authority():
		queue_free()
