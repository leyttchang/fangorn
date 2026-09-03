extends CharacterBody3D

enum State {
	IDLE,
	CHASE,
	ATTACK,
	DEAD
}

var current_state: State = State.IDLE
var target: Node3D = null

@export var behavior: EnemyBehaviorData
@export var base_movement_speed: float = 4.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var health_component = $HealthComponent
@onready var stats_component = $StatsComponent
@onready var movement_comp = $EnemyMovementComponent
@onready var navigation_comp = $EnemyNavigationComponent
@onready var anim_player = $AnimationPlayer # Nouveau !

# Rcupration de la hitbox d'attaque (le composant qui fait des dgts)
@onready var attack_shape: CollisionShape3D = _find_attack_shape()

var _target_update_timer: float = 0.0
var _is_attacking: bool = false
var _pending_attacker: Node3D = null
var _is_waiting_for_aggro: bool = false

func _find_attack_shape() -> CollisionShape3D:
	# On cherche un AttackComponent dans les enfants
	for child in get_children():
		if "AttackComponent" in child.name or "attack_component" in child.name.to_lower():
			if child.has_node("CollisionShape3D"):
				return child.get_node("CollisionShape3D") as CollisionShape3D
	return null

# =========================================================================
# Mthodes appeles par l'AnimationPlayer (Piste Call Method)
# =========================================================================
func enable_attack() -> void:
	if attack_shape: 
		attack_shape.disabled = false
		var attack_comp = attack_shape.get_parent()
		if attack_comp.has_method("reset_hit_entities"):
			attack_comp.reset_hit_entities()

func disable_attack() -> void:
	if attack_shape: 
		attack_shape.disabled = true
# =========================================================================

func _ready() -> void:
	if behavior == null:
		push_error("Spider (" + name + ") : Fichier EnemyBehaviorData manquant dans l'inspecteur !")
		
	if health_component:
		health_component.died.connect(_on_died)
		
	if attack_shape:
		attack_shape.disabled = true
	
	call_deferred("actor_setup")

func actor_setup() -> void:
	await get_tree().physics_frame
	_update_closest_target()
	change_state(State.IDLE)
	
	var hitbox = find_child("HitboxComponent*", true, false)
	if hitbox != null:
		hitbox.aggro_requested.connect(_on_aggro_requested)

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

func change_state(new_state: State) -> void:
	if is_multiplayer_authority():
		rpc("_rpc_apply_state", new_state)

@rpc("authority", "call_local", "reliable")
func _rpc_apply_state(new_state: int) -> void:
	if current_state == State.DEAD or current_state == new_state:
		return 
		
	current_state = new_state
	
	if current_state == State.ATTACK:
		_perform_attack()

func _perform_attack() -> void:
	_is_attacking = true
	
	if anim_player != null and anim_player.has_animation("attaque"):
		anim_player.play("attaque")
	
	# Animation d'attaque rudimentaire (petit bond en avant)
	var tween = get_tree().create_tween()
	var forward = -global_transform.basis.z * 1.5
	tween.tween_property(self, "global_position", global_position + forward, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", global_position, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# On attend la fin de l'attaque
	var attack_duration = 1.0
	if anim_player != null and anim_player.has_animation("attaque"):
		attack_duration = anim_player.get_animation("attaque").length
		
	await get_tree().create_timer(attack_duration).timeout
	_is_attacking = false
	if current_state != State.DEAD:
		change_state(State.IDLE)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	# Quand on meurt, on gèle complètement la physique (pas de gravité !)
	# Comme on désactive les collisions, ça l'empêche de tomber sous la map avec ses particules.
	if current_state == State.DEAD:
		velocity = Vector3.ZERO
		return
	
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
		return

	# Verrouillage de la cible
	_target_update_timer += delta
	if _target_update_timer > 15.0 or target == null or not is_instance_valid(target):
		_target_update_timer = 0.0
		_update_closest_target()

	if not is_on_floor():
		velocity.y -= gravity * delta
		
	var current_speed = base_movement_speed
	if stats_component:
		current_speed *= stats_component.get_stat_value("movement_speed") * action_speed
		
	var vitesse_horizontale = Vector2(velocity.x, velocity.z)

	match current_state:
		State.IDLE:
			vitesse_horizontale = _process_idle_state(vitesse_horizontale, delta)
		State.CHASE:
			vitesse_horizontale = _process_chase_state(vitesse_horizontale, delta, current_speed)
		State.ATTACK:
			vitesse_horizontale = _process_attack_state(vitesse_horizontale, delta)

	velocity.x = vitesse_horizontale.x
	velocity.z = vitesse_horizontale.y

	move_and_slide()


func _process_idle_state(vitesse_horiz: Vector2, delta: float) -> Vector2:
	if target != null:
		var distance = global_position.distance_to(target.global_position)
		if behavior and distance <= behavior.attack_range:
			change_state(State.ATTACK)
		else:
			change_state(State.CHASE)
			
	if movement_comp and behavior:
		return movement_comp.apply_friction(vitesse_horiz, behavior, delta)
	return Vector2.ZERO

func _process_chase_state(vitesse_horiz: Vector2, delta: float, speed: float) -> Vector2:
	if target == null:
		change_state(State.IDLE)
		if movement_comp and behavior: return movement_comp.apply_friction(vitesse_horiz, behavior, delta)
		return Vector2.ZERO
		
	if behavior:
		var distance_to_target = global_position.distance_to(target.global_position)
		if distance_to_target <= behavior.attack_range:
			change_state(State.ATTACK)
			if movement_comp: return movement_comp.apply_friction(vitesse_horiz, behavior, delta)
			return Vector2.ZERO
		
	if navigation_comp and movement_comp and behavior:
		var direction = navigation_comp.get_direction_to_target(target.global_position)
		movement_comp.rotate_towards_direction(direction, behavior, delta)
		return movement_comp.accelerate_to_direction(vitesse_horiz, direction, speed, behavior, delta)
		
	return Vector2.ZERO

func _process_attack_state(vitesse_horiz: Vector2, delta: float) -> Vector2:
	if target != null and movement_comp and behavior:
		var direction = (target.global_position - global_position).normalized()
		movement_comp.rotate_towards_direction(direction, behavior, delta, 2.0)
		
	if movement_comp and behavior:
		return movement_comp.apply_friction(vitesse_horiz, behavior, delta)
	return Vector2.ZERO

func _on_died() -> void:
	remove_from_group("Enemie")
	get_tree().call_group("ScoreManager", "add_kill_point")
	change_state(State.DEAD)
	
	# Dsactivation de la Hitbox
	var hitbox = find_child("HitboxComponent*", true, false)
	if hitbox and hitbox.has_node("CollisionShape3D"):
		hitbox.get_node("CollisionShape3D").set_deferred("disabled", true)
		
	# Dsactivation du corps physique (pour ne plus bloquer le joueur)
	if has_node("CollisionShape3D"):
		$CollisionShape3D.set_deferred("disabled", true)
		
	# On joue l'animation de mort si elle existe
	if anim_player != null and anim_player.has_animation("death"):
		anim_player.play("death")
		
	# TRS IMPORTANT : On doit arrter tous les IK !
	for ik in find_children("*", "SkeletonIK3D", true, false):
		if ik.has_method("stop"):
			ik.stop()
			
	await get_tree().create_timer(3.0).timeout
	queue_free()
