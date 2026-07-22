extends CharacterBody3D

# --- COMPOSANTS EXTERNES (Les Muscles et le Guide) ---
@onready var health_component: HealthComponent = $HealthComponent
@onready var stats_component: StatsComponent = $StatsComponent
@onready var knockback_componant = $knockback_componant
@onready var movement_comp: EnemyMovementComponent = $EnemyMovementComponent
@onready var navigation_comp: EnemyNavigationComponent = $EnemyNavigationComponent

# --- DONNÉES DE COMPORTEMENT (Le Profil) ---
@export var base_movement_speed: float = 4.5
@export var behavior: EnemyBehaviorData

@onready var attack_shape: CollisionShape3D = get_node_or_null("Orc/Armature/Skeleton3D/BoneAttachment3D/AttackComponent/CollisionShape3D")

# --- ANIMATION TREE ---
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")

# --- ÉTATS ---
enum State { IDLE, CHASE, ATTACK, DEAD }
var current_state: State = State.IDLE

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: Node3D = null

# Sécurité pour l'AnimationTree
var _attack_anim_started: bool = false

func _ready() -> void:
	if behavior == null:
		push_error("Orc (" + name + ") : Fichier EnemyBehaviorData manquant dans l'inspecteur !")
		
	anim_tree.active = true
	health_component.died.connect(_on_died)
	
	# =====================================================================
	# CORRECTION MAGIQUE : On détruit la piste vicieuse dans l'animation RESET
	# =====================================================================
	var anim_player: AnimationPlayer = get_node_or_null("Orc/AnimationPlayer")
	if anim_player and anim_player.has_animation("RESET"):
		var reset_anim = anim_player.get_animation("RESET")
		# On cherche si le RESET a enregistré la hitbox par erreur
		for i in range(reset_anim.get_track_count() - 1, -1, -1):
			var path_str = str(reset_anim.track_get_path(i))
			if "disabled" in path_str or "CollisionShape3D" in path_str:
				reset_anim.remove_track(i)
				print("[DUMB FIX] Piste 'disabled' supprimée de l'animation RESET !")
	# =====================================================================
	
	# On s'assure qu'elle est bien désactivée au lancement
	if attack_shape != null:
		attack_shape.disabled = true
	
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
			anim_playback.travel("Stand")
		State.CHASE:
			anim_playback.travel("Walk2")
		State.ATTACK:
			anim_playback.travel("Punch")
			_attack_anim_started = false 
		State.DEAD:
			anim_playback.travel("Death")


# ==========================================================
# LA PHYSIQUE ET SYNCHRONISATION
# ==========================================================
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	# Synchronisation de l'animation d'attaque
	if current_state == State.ATTACK:
		var current_anim = anim_playback.get_current_node()
		if current_anim == "Punch":
			_attack_anim_started = true
		elif _attack_anim_started and (current_anim == "Stand" or current_anim == "Walk2"):
			change_state(State.IDLE)
			
	if attack_shape != null:
		if current_state != State.ATTACK and not attack_shape.disabled:
			attack_shape.disabled = true

	var current_speed = base_movement_speed * stats_component.get_stat_value("movement_speed")
	var vitesse_horizontale = Vector2(velocity.x, velocity.z)

	# On passe la vitesse horizontale à nos comportements
	match current_state:
		State.DEAD:
			vitesse_horizontale = movement_comp.apply_friction(vitesse_horizontale, behavior, delta)
		State.IDLE:
			vitesse_horizontale = _process_idle_state(vitesse_horizontale, delta)
		State.CHASE:
			vitesse_horizontale = _process_chase_state(vitesse_horizontale, delta, current_speed)
		State.ATTACK:
			vitesse_horizontale = _process_attack_state(vitesse_horizontale, delta)

	# On réapplique la vitesse horizontale calculée
	velocity.x = vitesse_horizontale.x
	velocity.z = vitesse_horizontale.y

	move_and_slide()


# ==========================================================
# LOGIQUE DES COMPORTEMENTS (Le Cerveau)
# ==========================================================
func _process_idle_state(vitesse_horiz: Vector2, delta: float) -> Vector2:
	if target != null:
		var distance = global_position.distance_to(target.global_position)
		if distance <= behavior.attack_range:
			change_state(State.ATTACK)
		else:
			change_state(State.CHASE)
			
	# En Idle, on demande au composant de nous freiner
	return movement_comp.apply_friction(vitesse_horiz, behavior, delta)

func _process_chase_state(vitesse_horiz: Vector2, delta: float, speed: float) -> Vector2:
	if target == null:
		change_state(State.IDLE)
		return movement_comp.apply_friction(vitesse_horiz, behavior, delta)
		
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target <= behavior.attack_range:
		change_state(State.ATTACK)
		return movement_comp.apply_friction(vitesse_horiz, behavior, delta)
		
	# --- ON DÉLÈGUE LA NAVIGATION ! ---
	var direction = navigation_comp.get_direction_to_target(target.global_position)
	
	# --- ON DÉLÈGUE LA PHYSIQUE ET LA ROTATION ! ---
	movement_comp.rotate_towards_direction(direction, behavior, delta)
	return movement_comp.accelerate_to_direction(vitesse_horiz, direction, speed, behavior, delta)

func _process_attack_state(vitesse_horiz: Vector2, delta: float) -> Vector2:
	if target != null:
		var direction = (target.global_position - global_position).normalized()
		# On demande au composant de pivoter. Le '1.5' sert à pivoter plus vite pendant la frappe (comme dans ton ancien code)
		movement_comp.rotate_towards_direction(direction, behavior, delta, 1.5)
		
	# Pendant qu'il attaque, on demande au composant de nous freiner
	return movement_comp.apply_friction(vitesse_horiz, behavior, delta)


# ==========================================================
# ÉVÉNEMENTS
# ==========================================================
func _on_died() -> void:
	get_tree().call_group("ScoreManager", "add_kill_point")
	change_state(State.DEAD)
	if has_node("HitboxComponent/CollisionShape3D"):
		$HitboxComponent/CollisionShape3D.set_deferred("disabled", true)
	await get_tree().create_timer(3.0).timeout
	queue_free()
