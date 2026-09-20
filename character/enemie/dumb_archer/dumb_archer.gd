extends CharacterBody3D

@export var arrow_scene: PackedScene

# --- DONNÉES DE COMPORTEMENT (Le Profil) ---
# C'est ici que tu vas glisser ton fichier archer_behavior.tres !
@export var base_movement_speed: float = 3.5
@export var behavior: EnemyBehaviorData

# --- COMPOSANTS EXTERNES (Les Muscles et le Guide) ---
@onready var health_component: HealthComponent = $HealthComponent
@onready var stats_component: StatsComponent = $StatsComponent
@onready var knockback_componant = $knockback_componant
@onready var movement_comp: EnemyMovementComponent = $EnemyMovementComponent
@onready var navigation_comp: EnemyNavigationComponent = $EnemyNavigationComponent

# --- ANIMATION TREE ---
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")

# --- ÉTATS ---
enum State { IDLE, CHASE, ATTACK, RETREAT, DEAD }
var current_state: State = State.IDLE

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: Node3D = null

# --- SÉCURITÉ ---
var _attack_anim_started: bool = false

func _ready() -> void:
	if behavior == null:
		push_error("Archer (" + name + ") : Fichier EnemyBehaviorData manquant dans l'inspecteur !")
		
	anim_tree.active = true
	health_component.died.connect(_on_died)
	
	call_deferred("actor_setup")

func actor_setup() -> void:
	await get_tree().physics_frame
	_update_closest_target()
	change_state(State.IDLE)
	
	# On s'abonne au signal pour l'aggro si on se fait taper
	var hitbox = find_child("HitboxComponent*", true, false)
	if hitbox != null:
		hitbox.aggro_requested.connect(_on_aggro_requested)

var _pending_attacker: Node3D = null
var _is_waiting_for_aggro: bool = false

func _on_aggro_requested(attacker: Node3D) -> void:
	if not is_multiplayer_authority() or current_state == State.DEAD: return
	
	_pending_attacker = attacker
	if not _is_waiting_for_aggro:
		_is_waiting_for_aggro = true
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(self) or current_state == State.DEAD: return
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

@rpc("authority", "call_local", "reliable")
func _rpc_apply_state(new_state: int) -> void:
	if current_state == State.DEAD or current_state == new_state:
		return 
		
	current_state = new_state
	
	match current_state:
		State.IDLE:
			anim_playback.travel("anim_stand")
		State.CHASE:
			anim_playback.travel("anim_walk")
		State.RETREAT:
			anim_playback.travel("anim_walk") 
		State.ATTACK:
			anim_playback.travel("anim_standing_draw_arrow")
			_attack_anim_started = false 
		State.DEAD:
			anim_playback.travel("anim_death")


# ==========================================================
# LA PHYSIQUE ET SYNCHRONISATION
# ==========================================================
func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	var action_speed = 1.0
	if stats_component != null:
		action_speed = max(0.0, stats_component.get_stat_value("action_speed"))
		
	# --- STUN TOTAL ---
	if action_speed <= 0.0:
		if not is_on_floor():
			velocity.y -= gravity * delta
		velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
		move_and_slide()
		
		# On fige l'arbre d'animation !
		if anim_tree.active:
			anim_tree.active = false
		

		return
		
	if not anim_tree.active:
		anim_tree.active = true

	# Recherche / actualisation de cible selon le mode de jeu
	_target_update_timer += delta
	var target_check_interval = 15.0 if GameData.current_game_mode == GameData.GameMode.WAVE else (0.5 if target == null else 2.0)
	if _target_update_timer > target_check_interval or not is_instance_valid(target):
		_target_update_timer = 0.0
		_update_closest_target()

	if not is_on_floor():
		velocity.y -= gravity * delta

	var current_anim = anim_playback.get_current_node()

	# Synchronisation de l'animation d'attaque
	if current_state == State.ATTACK:
		if current_anim == "anim_standing_draw_arrow" or current_anim == "anim_aim_recoil":
			_attack_anim_started = true
		elif _attack_anim_started and (current_anim == "anim_stand" or current_anim == "anim_walk"):
			if target != null and global_position.distance_to(target.global_position) < behavior.flee_threshold:
				change_state(State.RETREAT)
			else:
				change_state(State.IDLE)

	var current_speed = base_movement_speed * stats_component.get_stat_value("movement_speed") * action_speed
	var vitesse_horizontale = Vector2(velocity.x, velocity.z)

	match current_state:
		State.DEAD:
			vitesse_horizontale = movement_comp.apply_friction(vitesse_horizontale, behavior, delta)
		State.IDLE:
			vitesse_horizontale = _process_idle_state(vitesse_horizontale, delta)
		State.CHASE:
			vitesse_horizontale = _process_chase_state(vitesse_horizontale, delta, current_speed)
		State.RETREAT:
			vitesse_horizontale = _process_retreat_state(vitesse_horizontale, delta, current_speed) 
		State.ATTACK:
			vitesse_horizontale = _process_attack_state(vitesse_horizontale, delta)

	velocity.x = vitesse_horizontale.x
	velocity.z = vitesse_horizontale.y

	move_and_slide()


# ==========================================================
# GESTION DU TIR (APPELÉ PAR L'ANIMATION PLAYER)
# ==========================================================
func fire_arrow() -> void:
	if not multiplayer.is_server(): return
	if arrow_scene == null: return
		
	var new_arrow = arrow_scene.instantiate()
	get_tree().current_scene.get_node("NetworkObjects").add_child(new_arrow, true)
	new_arrow.execute(self, {})

# ==========================================================
# LOGIQUE DES COMPORTEMENTS (Le Cerveau)
# ==========================================================
var _is_pack_walking: bool = false

func _set_pack_walking(is_walking: bool) -> void:
	if _is_pack_walking == is_walking: return
	_is_pack_walking = is_walking
	if is_multiplayer_authority():
		rpc("_rpc_set_pack_walking", is_walking)

@rpc("authority", "call_local", "unreliable")
func _rpc_set_pack_walking(is_walking: bool) -> void:
	if current_state != State.IDLE: return
	if is_walking:
		anim_playback.travel("anim_walk")
	else:
		anim_playback.travel("anim_stand")

func _process_idle_state(vitesse_horiz: Vector2, delta: float) -> Vector2:
	if target != null:
		var distance = global_position.distance_to(target.global_position)
		if distance < behavior.flee_threshold: 
			change_state(State.RETREAT)
		elif distance <= behavior.attack_range:
			change_state(State.ATTACK)
		else:
			change_state(State.CHASE)
		_set_pack_walking(false)
		return movement_comp.apply_friction(vitesse_horiz, behavior, delta)
		
	# Déplacement de meute hors-combat (patrouille / roam)
	if navigation_comp and navigation_comp.has_pack_destination:
		var dir = navigation_comp.get_pack_roam_direction()
		if dir != Vector3.ZERO:
			movement_comp.rotate_towards_direction(dir, behavior, delta)
			var roam_speed = base_movement_speed * navigation_comp.pack_speed_mult * stats_component.get_stat_value("movement_speed")
			_set_pack_walking(true)
			return movement_comp.accelerate_to_direction(vitesse_horiz, dir, roam_speed, behavior, delta)
		else:
			_set_pack_walking(false)
			
	# En Idle sans destination, on demande au composant de nous freiner
	_set_pack_walking(false)
	return movement_comp.apply_friction(vitesse_horiz, behavior, delta)

func _process_chase_state(vitesse_horiz: Vector2, delta: float, speed: float) -> Vector2:
	if target == null:
		change_state(State.IDLE)
		return movement_comp.apply_friction(vitesse_horiz, behavior, delta)
		
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target <= behavior.attack_range:
		change_state(State.ATTACK)
		return movement_comp.apply_friction(vitesse_horiz, behavior, delta)
		
	var direction = navigation_comp.get_direction_to_target(target.global_position)
	movement_comp.rotate_towards_direction(direction, behavior, delta)
	
	return movement_comp.accelerate_to_direction(vitesse_horiz, direction, speed, behavior, delta)

func _process_retreat_state(vitesse_horiz: Vector2, delta: float, speed: float) -> Vector2:
	if target == null:
		change_state(State.IDLE)
		return movement_comp.apply_friction(vitesse_horiz, behavior, delta)
		
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target >= behavior.attack_range:
		change_state(State.IDLE)
		return movement_comp.apply_friction(vitesse_horiz, behavior, delta)
		
	# Mouvement de fuite (direction opposée)
	var move_direction = (global_position - target.global_position).normalized()
	var new_vitesse = movement_comp.accelerate_to_direction(vitesse_horiz, move_direction, speed, behavior, delta)
	
	# Rotation vers le joueur (L'Archer regarde la cible pendant qu'il recule !)
	var look_direction = (target.global_position - global_position).normalized()
	movement_comp.rotate_towards_direction(look_direction, behavior, delta)
	
	return new_vitesse

func _process_attack_state(vitesse_horiz: Vector2, delta: float) -> Vector2:
	if target != null:
		var look_direction = (target.global_position - global_position).normalized()
		movement_comp.rotate_towards_direction(look_direction, behavior, delta, 1.5)
		
	return movement_comp.apply_friction(vitesse_horiz, behavior, delta)


# ==========================================================
# UTILITAIRES ET ÉVÉNEMENTS
# ==========================================================
func _on_died() -> void:
	get_tree().call_group("ScoreManager", "add_kill_point")
	change_state(State.DEAD)
	if has_node("HitboxComponent/CollisionShape3D"):
		$HitboxComponent/CollisionShape3D.set_deferred("disabled", true)
	await get_tree().create_timer(3.0).timeout
	if is_multiplayer_authority():
		queue_free()
