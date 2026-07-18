extends CharacterBody3D

var damage_text_scene = preload("res://ui/damage_text.tscn")
@export var arrow_scene: PackedScene

# --- COMPOSANTS ---
@onready var health_component: HealthComponent = $HealthComponent
@onready var stats_component: StatsComponent = $StatsComponent
@onready var knockback_componant = $knockback_componant
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

# --- ANIMATION TREE ---
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")

# --- ÉTATS ---
enum State { IDLE, CHASE, ATTACK, RETREAT, DEAD }
var current_state: State = State.IDLE

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var attack_range: float = 15.0 
var flee_threshold: float = 7.0 
var target: Node3D = null

# --- SÉCURITÉ ---
var _attack_anim_started: bool = false

# --- OPTIMISATION NAVIGATION ---
var frames_since_path_update: int = 0
var next_path_update_frame: int = 0

func _ready() -> void:
	anim_tree.active = true
	health_component.damage_taken.connect(_on_damage_taken)
	health_component.died.connect(_on_died)
	
	next_path_update_frame = randi_range(20, 40)
	
	call_deferred("actor_setup")

func actor_setup() -> void:
	await get_tree().physics_frame
	target = get_tree().get_first_node_in_group("Player")
	change_state(State.IDLE)


# ==========================================================
# LA VRAIE MACHINE À ÉTATS
# ==========================================================
func change_state(new_state: State) -> void:
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
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	if current_state == State.DEAD:
		_apply_friction(delta)
		move_and_slide()
		return

	var current_anim = anim_playback.get_current_node()

	# --- SYNCHRONISATION ARBRE -> CODE ---
	if current_state == State.ATTACK:
		
		if current_anim == "anim_standing_draw_arrow" or current_anim == "anim_aim_recoil":
			_attack_anim_started = true
			
		elif _attack_anim_started and (current_anim == "anim_stand" or current_anim == "anim_walk"):
			if target != null and global_position.distance_to(target.global_position) < flee_threshold:
				change_state(State.RETREAT)
			else:
				change_state(State.IDLE)

	var current_speed = stats_component.get_stat_value("movement_speed")

	match current_state:
		State.IDLE:
			_process_idle_state(delta)
		State.CHASE:
			_process_chase_state(delta, current_speed)
		State.RETREAT:
			_process_retreat_state(delta, current_speed) 
		State.ATTACK:
			_process_attack_state(delta)

	move_and_slide()


# ==========================================================
# GESTION DU TIR (APPELÉ PAR L'ANIMATION PLAYER)
# ==========================================================
func fire_arrow() -> void:
	if arrow_scene == null:
		push_error("L'Archer essaie de tirer, mais aucune scène de flèche n'est assignée dans l'inspecteur !")
		return
		
	var new_arrow = arrow_scene.instantiate()
	get_tree().current_scene.add_child(new_arrow)
	new_arrow.execute(self, {})


# ==========================================================
# LOGIQUE DES COMPORTEMENTS
# ==========================================================
func _process_idle_state(delta: float) -> void:
	_apply_friction(delta)
	
	if target != null:
		var distance = global_position.distance_to(target.global_position)
		if distance < flee_threshold: 
			change_state(State.RETREAT)
		elif distance <= attack_range:
			change_state(State.ATTACK)
		else:
			change_state(State.CHASE)

func _process_chase_state(delta: float, speed: float) -> void:
	if target == null:
		change_state(State.IDLE)
		return
		
	var distance_to_target = global_position.distance_to(target.global_position)
	
	if distance_to_target <= attack_range:
		change_state(State.ATTACK)
		return
		
	frames_since_path_update += 1
	
	if frames_since_path_update >= next_path_update_frame:
		nav_agent.target_position = target.global_position
		frames_since_path_update = 0
		next_path_update_frame = randi_range(20, 40)
		
	var next_path_pos: Vector3 = nav_agent.get_next_path_position()
	var direction: Vector3 = (next_path_pos - global_position).normalized()
	
	velocity.x = move_toward(velocity.x, direction.x * speed, speed * 10.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, speed * 10.0 * delta)
	
	var horizontal_velocity = Vector2(velocity.x, velocity.z)
	if horizontal_velocity.length() > 0.1:
		var target_rotation_y = atan2(velocity.x, velocity.z)
		rotation.y = lerp_angle(rotation.y, target_rotation_y, 10.0 * delta)

func _process_retreat_state(delta: float, speed: float) -> void:
	if target == null:
		change_state(State.IDLE)
		return
		
	var distance_to_target = global_position.distance_to(target.global_position)
	
	if distance_to_target >= attack_range:
		change_state(State.IDLE)
		return
		
	var direction = (global_position - target.global_position).normalized()
	
	velocity.x = move_toward(velocity.x, direction.x * speed, speed * 10.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, speed * 10.0 * delta)
	
	var look_direction = (target.global_position - global_position).normalized()
	var target_rotation_y = atan2(look_direction.x, look_direction.z)
	rotation.y = lerp_angle(rotation.y, target_rotation_y, 15.0 * delta)

func _process_attack_state(delta: float) -> void:
	_apply_friction(delta) 
	
	if target != null:
		var direction = (target.global_position - global_position).normalized()
		var target_rotation_y = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation_y, 15.0 * delta)


# ==========================================================
# UTILITAIRES ET ÉVÉNEMENTS
# ==========================================================
func _apply_friction(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 5.0 * delta)

func _on_damage_taken(amount: float) -> void:
	var text_instance = damage_text_scene.instantiate()
	add_child(text_instance)
	text_instance.position.y = 1.0 
	text_instance.animate(amount)

func _on_died() -> void:
	get_tree().call_group("ScoreManager", "add_kill_point")
	change_state(State.DEAD)
	if has_node("HitboxComponent/CollisionShape3D"):
		$HitboxComponent/CollisionShape3D.set_deferred("disabled", true)
	await get_tree().create_timer(3.0).timeout
	queue_free()
