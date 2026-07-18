extends CharacterBody3D

var damage_text_scene = preload("res://ui/damage_text.tscn")

# --- COMPOSANTS ---
@onready var health_component: HealthComponent = $HealthComponent
@onready var stats_component: StatsComponent = $StatsComponent
@onready var knockback_componant = $knockback_componant
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

# --- ANIMATION TREE ---
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")

# --- ÉTATS ---
enum State { IDLE, CHASE, ATTACK, DEAD }
var current_state: State = State.IDLE

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var attack_range: float = 1.5
var target: Node3D = null

# Variable de sécurité vitale pour lire l'AnimationTree sans bugger
var _attack_anim_started: bool = false

func _ready() -> void:
	anim_tree.active = true
	health_component.damage_taken.connect(_on_damage_taken)
	health_component.died.connect(_on_died)
	
	call_deferred("actor_setup")

func actor_setup() -> void:
	await get_tree().physics_frame
	target = get_tree().get_first_node_in_group("Player")
	# On initialise l'IA proprement (si le perso n'est pas mort frame 1)
	change_state(State.IDLE)


# ==========================================================
# LA VRAIE MACHINE À ÉTATS
# Cette fonction envoie l'ordre à l'arbre UNE SEULE FOIS.
# ==========================================================
func change_state(new_state: State) -> void:
	# 1. On ne fait rien si on est mort ou si on est déjà dans l'état demandé
	if current_state == State.DEAD or current_state == new_state:
		return 
		
	current_state = new_state
	
	# 2. L'ordre de voyage propre pour l'AnimationTree
	match current_state:
		State.IDLE:
			anim_playback.travel("Stand")
		State.CHASE:
			anim_playback.travel("Walk2")
		State.ATTACK:
			anim_playback.travel("Punch")
			_attack_anim_started = false # On arme la sécurité du coup de poing
		State.DEAD:
			anim_playback.travel("Death")


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

	# --- LA MAGIE EST ICI : SYNCHRONISATION ARBRE -> CODE ---
	# Quand l'Orc attaque, on écoute ce que fait l'AnimationTree
	if current_state == State.ATTACK:
		var current_anim = anim_playback.get_current_node()
		
		# Étape A : L'arbre a bien commencé à frapper
		if current_anim == "Punch":
			_attack_anim_started = true
			
		# Étape B : L'arbre a fini le Punch et est retourné à "Stand" tout seul
		elif _attack_anim_started and (current_anim == "Stand" or current_anim == "Walk2"):
			# On remet le cerveau à zéro. À la frame suivante, l'Orc décidera 
			# s'il doit refrapper ou courir selon ta position.
			change_state(State.IDLE)


	var current_speed = stats_component.get_stat_value("movement_speed")

	# Le cerveau gère uniquement la logique, plus aucune animation ici !
	match current_state:
		State.IDLE:
			_process_idle_state(delta)
		State.CHASE:
			_process_chase_state(delta, current_speed)
		State.ATTACK:
			_process_attack_state(delta)

	move_and_slide()


# ==========================================================
# LOGIQUE DES COMPORTEMENTS
# ==========================================================
func _process_idle_state(delta: float) -> void:
	_apply_friction(delta)
	
	if target != null:
		var distance = global_position.distance_to(target.global_position)
		if distance <= attack_range:
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
		
	nav_agent.target_position = target.global_position
	var next_path_pos: Vector3 = nav_agent.get_next_path_position()
	var direction: Vector3 = (next_path_pos - global_position).normalized()
	
	velocity.x = move_toward(velocity.x, direction.x * speed, speed * 10.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, speed * 10.0 * delta)
	
	var horizontal_velocity = Vector2(velocity.x, velocity.z)
	if horizontal_velocity.length() > 0.1:
		var target_rotation_y = atan2(velocity.x, velocity.z)
		rotation.y = lerp_angle(rotation.y, target_rotation_y, 10.0 * delta)

func _process_attack_state(delta: float) -> void:
	_apply_friction(delta) 
	
	if target != null:
		# Pivot en temps réel vers le joueur pendant la frappe
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
	change_state(State.DEAD)
	if has_node("HitboxComponent/CollisionShape3D"):
		$HitboxComponent/CollisionShape3D.set_deferred("disabled", true)
	await get_tree().create_timer(3.0).timeout
	queue_free()
