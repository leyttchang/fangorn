extends CharacterBody3D

@onready var health_component: HealthComponent = $HealthComponent
@onready var stats_component: StatsComponent = $StatsComponent
@onready var knockback_componant = $knockback_componant
@onready var movement_comp: EnemyMovementComponent = $EnemyMovementComponent
@onready var navigation_comp: EnemyNavigationComponent = $EnemyNavigationComponent

# --- DONNEES DE COMPORTEMENT (Le Profil) ---
@export var base_movement_speed: float = 4.5
@export var behavior: EnemyBehaviorData

@export_group("Intelligence des Attaques")
@export var tension_enter_distance: float = 10.0
@export var tension_reset_distance: float = 6.0
@export var strafe_min_distance: float = 3.0
@export var strafe_max_distance: float = 6.0
@export var tension_min_time: float = 2.0
@export var tension_max_time: float = 5.0

@export var anti_kite_min_time: float = 6.0
@export var anti_kite_max_time: float = 10.0

@export var heavy_attack_close_distance: float = 0.75
@export var heavy_attack_far_distance: float = 1.5
@export_range(0.0, 1.0) var heavy_attack_far_probability: float = 0.15
@export_range(0.0, 1.0) var heavy_attack_mid_probability: float = 0.30

@export var slam_scene: PackedScene
@export var attack_shape: CollisionShape3D

# --- ANIMATION TREE ---
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")

# --- ETATS ---
enum State { IDLE, CHASE, STRAFE, ATTACK, DEAD }
var current_state: State = State.IDLE

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: Node3D = null

# Securite pour l'AnimationTree
var _attack_anim_started: bool = false
var _current_attack_anim: String = ""
var _is_enraged: bool = false 

var _tension_timer: float = 0.0
var _chase_timer: float = 0.0
var _chase_limit: float = 10.0
var _tension_cleared: bool = false
var _strafe_dir: float = 1.0
var _is_rotation_locked: bool = false

var _last_hitbox_disabled: bool = true

func _ready() -> void:
	if behavior == null:
		push_error("Scout (" + name + ") : Fichier EnemyBehaviorData manquant dans l'inspecteur !")
		
	anim_tree.active = true
	health_component.died.connect(_on_died)
	health_component.health_changed.connect(_on_health_changed)
	
	if attack_shape != null:
		attack_shape.disabled = true
	
	call_deferred("actor_setup")

func actor_setup() -> void:
	await get_tree().physics_frame
	_update_closest_target()
	change_state(State.IDLE)
	
	var hitbox = find_child("HitboxComponent*", true, false)
	if hitbox != null:
		hitbox.aggro_requested.connect(_on_aggro_requested)

func enable_hitbox() -> void:
	if attack_shape != null:
		attack_shape.disabled = false
		print("[HITBOX] ENABLED BY ANIMATION METHOD")

func disable_hitbox() -> void:
	if attack_shape != null:
		attack_shape.disabled = true
		print("[HITBOX] DISABLED BY ANIMATION METHOD")

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
	var players = get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		target = null
		return
		
	var closest = null
	var min_dist = 999999.0
	for p in players:
		var d = global_position.distance_squared_to(p.global_position)
		if d < min_dist:
			min_dist = d
			closest = p
			
	target = closest

func lock_rotation() -> void:
	_is_rotation_locked = true
	
func set_attack_speed(speed: float) -> void:
	if _current_attack_anim != "":
		anim_tree.set("parameters/" + _current_attack_anim + "/TimeScale/scale", speed)

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
			anim_playback.travel("idle")
		State.CHASE:
			_chase_timer = 0.0
			_chase_limit = randf_range(anti_kite_min_time, anti_kite_max_time)
			anim_playback.travel("run")
		State.STRAFE:
			_tension_timer = randf_range(tension_min_time, tension_max_time)
			_strafe_dir = 1.0 if randf() < 0.5 else -1.0
			anim_tree.set("parameters/strafe/TimeScale/scale", _strafe_dir)
			anim_playback.travel("strafe")
		State.ATTACK:
			_is_rotation_locked = false 
			anim_tree.set("parameters/attaque/TimeScale/scale", 1.0)
			anim_tree.set("parameters/heavy_weapon_swing/TimeScale/scale", 1.0)
			
			if _is_enraged:
				if randf() < 0.5:
					_current_attack_anim = "heavy_weapon_swing"
				else:
					_current_attack_anim = "standing_mele_downward" 
			else:
				var dist = 0.0
				if target != null:
					var pos_2d = Vector2(global_position.x, global_position.z)
					var target_2d = Vector2(target.global_position.x, target.global_position.z)
					dist = pos_2d.distance_to(target_2d)
					
				var rand_val = randf()
				
				if dist <= heavy_attack_close_distance:
					_current_attack_anim = "attaque"
				elif dist > heavy_attack_far_distance:
					if rand_val < heavy_attack_far_probability:
						_current_attack_anim = "attaque"
					else:
						_current_attack_anim = "standing_mele_downward"
				else:
					if rand_val < heavy_attack_mid_probability:
						_current_attack_anim = "attaque"
					else:
						_current_attack_anim = "standing_mele_downward"
						
			anim_playback.travel(_current_attack_anim)
			_attack_anim_started = false 
		State.DEAD:
			pass 

func _process(delta: float) -> void:
	if current_state == State.DEAD: return
	
	if stats_component != null and anim_tree != null:
		var action_speed = max(0.0, stats_component.get_stat_value("action_speed"))
		if action_speed <= 0.0:
			if anim_tree.active: anim_tree.active = false
		else:
			if not anim_tree.active: anim_tree.active = true

	if attack_shape != null:
		if attack_shape.disabled != _last_hitbox_disabled:
			_last_hitbox_disabled = attack_shape.disabled
			print("[HITBOX DEBUG] Frame ", Engine.get_frames_drawn(), " - disabled = ", attack_shape.disabled, " | State = ", current_state, " | Anim = ", anim_playback.get_current_node() if anim_playback else "null")

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	if current_state == State.DEAD: return 
	
	var action_speed = 1.0
	if stats_component != null:
		action_speed = max(0.0, stats_component.get_stat_value("action_speed"))
		
	if action_speed <= 0.0:
		if not is_on_floor():
			velocity.y -= gravity * delta
		velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
		move_and_slide()
		
		if attack_shape != null and not attack_shape.disabled:
			attack_shape.disabled = true
		return

	_target_update_timer += delta
	if _target_update_timer > 15.0 or target == null or not is_instance_valid(target):
		_target_update_timer = 0.0
		_update_closest_target()

	if not is_on_floor():
		velocity.y -= gravity * delta
		
	if current_state == State.ATTACK:
		if anim_playback:
			var current_anim = anim_playback.get_current_node()
			if current_anim == _current_attack_anim:
				_attack_anim_started = true
			elif _attack_anim_started and (current_anim == "idle" or current_anim == "run" or current_anim == "" or current_anim == "strafe"):
				if target != null:
					var dist = global_position.distance_to(target.global_position)
					if dist > tension_reset_distance:
						_tension_cleared = false
				change_state(State.IDLE)
			
	if attack_shape != null:
		if current_state != State.ATTACK and not attack_shape.disabled:
			attack_shape.disabled = true

	var current_speed = base_movement_speed * stats_component.get_stat_value("movement_speed") * action_speed
	var vitesse_horizontale = Vector2(velocity.x, velocity.z)

	match current_state:
		State.DEAD:
			vitesse_horizontale = movement_comp.apply_friction(vitesse_horizontale, behavior, delta)
		State.IDLE:
			vitesse_horizontale = _process_idle_state(vitesse_horizontale, delta)
		State.CHASE:
			vitesse_horizontale = _process_chase_state(vitesse_horizontale, delta, current_speed)
		State.STRAFE:
			vitesse_horizontale = _process_strafe_state(vitesse_horizontale, delta, current_speed)
		State.ATTACK:
			vitesse_horizontale = _process_attack_state(vitesse_horizontale, delta)

	velocity.x = vitesse_horizontale.x
	velocity.z = vitesse_horizontale.y
	
	move_and_slide()
	
func _process_idle_state(vitesse_horiz: Vector2, delta: float) -> Vector2:
	if target != null:
		var distance = global_position.distance_to(target.global_position)
		if distance <= behavior.attack_range:
			change_state(State.ATTACK)
		else:
			change_state(State.CHASE)
			
	return movement_comp.apply_friction(vitesse_horiz, behavior, delta)

func _process_chase_state(vitesse_horiz: Vector2, delta: float, speed: float) -> Vector2:
	if target == null:
		change_state(State.IDLE)
		return movement_comp.apply_friction(vitesse_horiz, behavior, delta)
		
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target <= behavior.attack_range:
		change_state(State.ATTACK)
		return movement_comp.apply_friction(vitesse_horiz, behavior, delta)
		
	if not _is_enraged and not _tension_cleared and distance_to_target <= tension_enter_distance:
		change_state(State.STRAFE)
		return vitesse_horiz
		
	if not _is_enraged:
		_chase_timer += delta
		if _chase_timer >= _chase_limit:
			_tension_cleared = false 
			change_state(State.STRAFE)
			return vitesse_horiz
		
	var direction = navigation_comp.get_direction_to_target(target.global_position)
	movement_comp.rotate_towards_direction(direction, behavior, delta)
	return movement_comp.accelerate_to_direction(vitesse_horiz, direction, speed, behavior, delta)

func _process_strafe_state(vitesse_horiz: Vector2, delta: float, speed: float) -> Vector2:
	if target == null:
		change_state(State.IDLE)
		return movement_comp.apply_friction(vitesse_horiz, behavior, delta)
		
	var distance_to_target = global_position.distance_to(target.global_position)
	
	_tension_timer -= delta
	if _tension_timer <= 0.0:
		_tension_cleared = true
		change_state(State.CHASE)
		return vitesse_horiz
		
	if distance_to_target <= behavior.attack_range:
		change_state(State.ATTACK)
		return movement_comp.apply_friction(vitesse_horiz, behavior, delta)
		
	var dir_to_target = global_position.direction_to(target.global_position)
	dir_to_target.y = 0
	dir_to_target = dir_to_target.normalized()
	
	movement_comp.rotate_towards_direction(dir_to_target, behavior, delta)
	
	var right_dir = dir_to_target.cross(Vector3.UP).normalized()
	var strafe_dir_3d = right_dir * _strafe_dir
	
	var forward_factor = 0.0
	if distance_to_target > strafe_max_distance:
		forward_factor = 0.5
	elif distance_to_target < strafe_min_distance:
		forward_factor = -0.5
		
	var final_dir = (strafe_dir_3d + (dir_to_target * forward_factor)).normalized()
	
	return movement_comp.accelerate_to_direction(vitesse_horiz, final_dir, speed * 0.5, behavior, delta)

func _process_attack_state(vitesse_horiz: Vector2, delta: float) -> Vector2:
	if not _is_rotation_locked and target != null:
		var dir_to_target = global_position.direction_to(target.global_position)
		dir_to_target.y = 0
		if dir_to_target.length_squared() > 0.01:
			movement_comp.rotate_towards_direction(dir_to_target.normalized(), behavior, delta * 0.3)
			
	if _current_attack_anim == "attaque":
		pass
	elif _current_attack_anim == "heavy_weapon_swing":
		pass
		
	return movement_comp.apply_friction(vitesse_horiz, behavior, delta)

func spawn_slam_attack() -> void:
	if not is_multiplayer_authority():
		return
		
	if slam_scene == null:
		return
		
	var slam = slam_scene.instantiate() as Node3D
	var slam_marker = find_child("slam_position", true, false)
	var spawn_pos: Vector3
	
	if slam_marker != null:
		spawn_pos = slam_marker.global_position
	else:
		var forward_direction = -global_transform.basis.z.normalized()
		spawn_pos = global_position + (forward_direction * 2.5)
	
	get_tree().current_scene.get_node("NetworkObjects").add_child(slam, true)
	slam.global_position = spawn_pos
	
	if slam.has_method("rpc_set_position"):
		slam.rpc("rpc_set_position", spawn_pos)

func _on_died() -> void:
	if is_multiplayer_authority():
		get_tree().call_group("ScoreManager", "add_kill_point")
		rpc("_rpc_trigger_death")

func _on_health_changed(current_hp: float, max_hp: float) -> void:
	if not is_multiplayer_authority(): return
	
	if current_hp <= max_hp * 0.5 and not _is_enraged:
		_is_enraged = true
		if stats_component != null:
			stats_component.add_modifier("movement_speed", 1, 0.5, "enrage_buff")

@rpc("authority", "call_local", "reliable")
func _rpc_trigger_death() -> void:
	remove_from_group("Enemie")
	current_state = State.DEAD
	
	if has_node("HitboxComponent/CollisionShape3D"):
		$HitboxComponent/CollisionShape3D.set_deferred("disabled", true)
	
	if has_node("CollisionShape3D"):
		$CollisionShape3D.set_deferred("disabled", true)
		
	if anim_tree and anim_tree.active:
		anim_tree.active = false 
		
	var simulator = get_node_or_null("Great Sword Run/Skeleton3D/PhysicalBoneSimulator3D")
	var skeleton: Skeleton3D = get_node_or_null("Great Sword Run/Skeleton3D")
	
	if simulator != null:
		simulator.physical_bones_start_simulation()
	elif skeleton != null and skeleton.has_method("physical_bones_start_simulation"):
		skeleton.physical_bones_start_simulation()
		
	if is_multiplayer_authority():
		await get_tree().create_timer(4.0).timeout
		queue_free()
