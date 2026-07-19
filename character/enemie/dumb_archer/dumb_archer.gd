extends CharacterBody3D

@export var arrow_scene: PackedScene

# --- DONNÉES DE COMPORTEMENT (Le Profil) ---
# C'est ici que tu vas glisser ton fichier archer_behavior.tres !
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

	var current_speed = stats_component.get_stat_value("movement_speed")
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
	if arrow_scene == null:
		push_error("L'Archer essaie de tirer, mais aucune scène de flèche n'est assignée dans l'inspecteur !")
		return
		
	var new_arrow = arrow_scene.instantiate()
	get_tree().current_scene.add_child(new_arrow)
	new_arrow.execute(self, {})


# ==========================================================
# LOGIQUE DES COMPORTEMENTS (Le Cerveau)
# ==========================================================
func _process_idle_state(vitesse_horiz: Vector2, delta: float) -> Vector2:
	if target != null:
		var distance = global_position.distance_to(target.global_position)
		if distance < behavior.flee_threshold: 
			change_state(State.RETREAT)
		elif distance <= behavior.attack_range:
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
	queue_free()
