extends CharacterBody3D

@onready var health_component: HealthComponent = $HealthComponent
@onready var stats_component: StatsComponent = $StatsComponent
@onready var movement_comp: EnemyMovementComponent = $EnemyMovementComponent
@onready var navigation_comp: EnemyNavigationComponent = $EnemyNavigationComponent
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback") if anim_tree else null

@export var behavior: EnemyBehaviorData
@export var attack_shape: CollisionShape3D

# --- REGLAGES DU CREEP ---
@export var slow_speed: float = 2.0
@export var run_speed: float = 7.0
@export var safe_distance: float = 12.0
@export var charge_distance: float = 5.0
@export var attack_distance: float = 1.8

# --- ETATS ---
enum State { IDLE, SNEAK, APPROACH, CHARGE, FLEE, ATTACK, DEAD }
var current_state: State = State.IDLE

var flee_time: float = 0.0
var rest_time: float = 0.0
var is_tired: bool = false
var _target_update_timer: float = 0.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: Node3D = null

func _ready() -> void:
	if anim_tree:
		anim_tree.active = true
	if health_component:
		health_component.died.connect(_on_died)
	
	if attack_shape != null:
		attack_shape.disabled = true
		
	var hitbox = find_child("HitboxComponent*", true, false)
	if hitbox and hitbox.has_signal("aggro_requested"):
		hitbox.aggro_requested.connect(_on_aggro_requested)
	
	call_deferred("actor_setup")

func actor_setup() -> void:
	await get_tree().physics_frame
	_update_closest_target()
	change_state(State.SNEAK)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if current_state == State.DEAD:
		_stop_movement(delta)
		move_and_slide()
		return
		
	_target_update_timer += delta
	if _target_update_timer > 15.0 or target == null or not is_instance_valid(target):
		_target_update_timer = 0.0
		_update_closest_target()
		
	_process_state(delta)
	
	if current_state != State.FLEE:
		rest_time += delta
		if rest_time >= 3.0:
			flee_time = 0.0
			is_tired = false
	else:
		rest_time = 0.0
	
	move_and_slide()
	
	# Synchro reseau pour les autres clients (Mouvement / Animations)
	var anim_name = "crouching_walk"
	if current_state == State.CHARGE:
		anim_name = "run_fast"
	elif current_state == State.FLEE:
		anim_name = "tired_walk" if is_tired else "run_fast"
	elif current_state == State.ATTACK:
		anim_name = "stab"
	elif current_state == State.IDLE:
		anim_name = "crouching_walk"
		
	# Synchronisation de la rotation
	var current_rot = rotation.y
	rpc("_rpc_apply_state", current_state, anim_name, current_rot)

func _process_state(delta: float) -> void:
	if target == null:
		change_state(State.IDLE)
		_stop_movement(delta)
		return
		
	var dist = global_position.distance_to(target.global_position)
	var is_seen = _is_player_looking_at_me()
	var is_behind = _am_i_behind_player()

	match current_state:
		State.IDLE:
			_stop_movement(delta)
			if target:
				change_state(State.SNEAK)
				
		State.SNEAK:
			var orbit_dist = safe_distance - 2.0
			var player_back_dir = target.global_transform.basis.z.normalized()
			var dir_from_target = (global_position - target.global_position).normalized()
			
			# S'il est exactement en face, on decale un peu pour eviter qu'il hesite entre gauche/droite
			if dir_from_target.dot(player_back_dir) < -0.99:
				dir_from_target = dir_from_target.rotated(Vector3.UP, 0.1)
				
			# On calcule un point sur le cercle de rayon 'orbit_dist' autour du joueur
			# Le slerp (0.4) fait qu'il va glisser le long du cercle pour rejoindre le dos
			var next_dir = dir_from_target.slerp(player_back_dir, 0.4).normalized()
			var orbit_pos = target.global_position + next_dir * orbit_dist
			
			_move_to(orbit_pos, slow_speed, delta)
			
			if is_seen and dist < safe_distance:
				change_state(State.FLEE)
			elif is_behind:
				change_state(State.APPROACH)
				
		State.APPROACH:
			_move_to(target.global_position, slow_speed, delta)
			
			if is_seen:
				change_state(State.FLEE)
			elif dist <= charge_distance:
				change_state(State.CHARGE)
			elif not is_behind and dist > charge_distance + 2.0:
				change_state(State.SNEAK)
				
		State.CHARGE:
			_move_to(target.global_position, run_speed, delta)
			if dist <= attack_distance:
				change_state(State.ATTACK)
				
		State.FLEE:
			flee_time += delta
			var current_run_speed = run_speed
			if flee_time > 5.0:
				current_run_speed = slow_speed * 1.5 # Moins vite que courir, plus que marcher
				if not is_tired:
					is_tired = true
					if anim_playback: anim_playback.travel("tired_walk")
			
			var dir_away = (global_position - target.global_position).normalized()
			var flee_pos = global_position + (dir_away * 10.0)
			_move_to(flee_pos, current_run_speed, delta)
			
			if dist > safe_distance + 3.0:
				change_state(State.SNEAK)
				
		State.ATTACK:
			_stop_movement(delta)
			var dir = (target.global_position - global_position).normalized()
			movement_comp.rotate_towards_direction(dir, behavior, delta, 2.0)

func _move_to(target_pos: Vector3, speed: float, delta: float) -> void:
	var dir = navigation_comp.get_direction_to_target(target_pos)
	var vel_2d = Vector2(velocity.x, velocity.z)
	vel_2d = movement_comp.accelerate_to_direction(vel_2d, dir, speed, behavior, delta)
	velocity.x = vel_2d.x
	velocity.z = vel_2d.y
	movement_comp.rotate_towards_direction(dir, behavior, delta)

func _stop_movement(delta: float) -> void:
	var vel_2d = Vector2(velocity.x, velocity.z)
	vel_2d = movement_comp.apply_friction(vel_2d, behavior, delta)
	velocity.x = vel_2d.x
	velocity.z = vel_2d.y

func change_state(new_state: State) -> void:
	current_state = new_state
	
	if anim_playback:
		if new_state == State.SNEAK or new_state == State.APPROACH:
			anim_playback.travel("crouching_walk")
		elif new_state == State.CHARGE:
			anim_playback.travel("run_fast")
		elif new_state == State.FLEE:
			if is_tired:
				anim_playback.travel("tired_walk")
			else:
				anim_playback.travel("run_fast")
		elif new_state == State.ATTACK:
			anim_playback.travel("stab")
		elif new_state == State.IDLE:
			anim_playback.travel("crouching_walk")

# --- CONDITIONS DE VISION ---

func _is_player_looking_at_me() -> bool:
	if not target: return false
	var dir_to_me = (global_position - target.global_position).normalized()
	var player_forward = -target.global_transform.basis.z.normalized()
	# Si le dot product est positif, il regarde vers nous
	# (On passe a 0.85 pour reduire le cone : il faut presque le centrer a l'ecran)
	return player_forward.dot(dir_to_me) > 0.85

func _am_i_behind_player() -> bool:
	if not target: return false
	var dir_to_me = (global_position - target.global_position).normalized()
	var player_forward = -target.global_transform.basis.z.normalized()
	# Si le dot product est negatif, on est dans son dos
	return player_forward.dot(dir_to_me) < -0.5

# --- EVENEMENTS D'ANIMATION ---
# A APPELER DEPUIS L'ANIMATION "stab" AVEC UN CALL METHOD TRACK :

func enable_hitbox() -> void:
	if attack_shape: 
		attack_shape.disabled = false
		var attack_comp = attack_shape.get_parent()
		if attack_comp.has_method("reset_hit_entities"):
			attack_comp.reset_hit_entities()
	
func disable_hitbox() -> void:
	if attack_shape: attack_shape.disabled = true

func _on_attack_finished() -> void:
	disable_hitbox()
	if current_state == State.ATTACK:
		# Apres avoir tape, on fuit un peu !
		change_state(State.FLEE)

# --- RESEAU ---

@rpc("authority", "call_local", "unreliable")
func _rpc_apply_state(new_state: int, sync_anim: String, sync_rot: float) -> void:
	if current_state == State.DEAD: return
	
	# Le client met a jour son animation et sa rotation
	if not is_multiplayer_authority():
		rotation.y = lerp_angle(rotation.y, sync_rot, 0.2)
		if anim_playback:
			anim_playback.travel(sync_anim)

func _on_died() -> void:
	if is_multiplayer_authority():
		get_tree().call_group("ScoreManager", "add_kill_point")
		rpc("_rpc_trigger_death", velocity)

@rpc("authority", "call_local", "reliable")
func _rpc_trigger_death(fatal_velocity: Vector3 = Vector3.ZERO) -> void:
	remove_from_group("Enemie")
	current_state = State.DEAD
	
	if has_node("HitboxComponent/CollisionShape3D"):
		$HitboxComponent/CollisionShape3D.set_deferred("disabled", true)
		
	# On garde la collision avec le sol (mask 1) mais on enleve l'obstacle pour les joueurs
	collision_layer = 0
	collision_mask = 1
		
	if anim_tree and anim_tree.active:
		if anim_playback:
			anim_playback.travel("death")
		
	# Ajouter ici la logique de Ragdoll si tu en as (voir Scout)
	
	if is_multiplayer_authority():
		await get_tree().create_timer(4.0).timeout
		queue_free()

func _update_closest_target() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	var closest_dist = INF
	target = null
	for p in players:
		if p.has_method("is_dead") and p.is_dead(): continue
		var d = global_position.distance_to(p.global_position)
		if d < closest_dist:
			closest_dist = d
			target = p

func _on_aggro_requested(attacker: Node3D) -> void:
	if not is_multiplayer_authority() or current_state == State.DEAD: return
	target = attacker
	_target_update_timer = 0.0
