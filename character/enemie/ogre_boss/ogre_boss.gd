extends CharacterBody3D

@onready var health_component: HealthComponent = $HealthComponent
@onready var stats_component: StatsComponent = $StatsComponent
@onready var knockback_componant = $knockback_componant
# Préparation pour les animations
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
@onready var movement_comp: EnemyMovementComponent = $EnemyMovementComponent
@onready var navigation_comp: EnemyNavigationComponent = $EnemyNavigationComponent

@export var behavior: EnemyBehaviorData
@export var base_movement_speed: float = 4.5
@export var attack_component: Node3D
@export var jumping_attack: PackedScene
@export var slam_attack: PackedScene
@export var slam_pos: Marker3D

@export_category("Saut")
@export var jump_power: float = 15.0
@export var jump_angle: float = 45.0
@export var max_jump_range: float = 20.0
@export var height_detector: RayCast3D
@export var unfreeze_distance: float = 3.0

@export_category("Lancer de rocher")
@export var rock_scene: PackedScene
@export var throw_pos: Marker3D

@export_category("Midlife Roar")
@export var midlife_roar_scene: PackedScene
@export var roar_pos: Marker3D
@export var roar_knockback_force: float = 20.0
@export var roar_knockback_angle: float = 20.0

# --- ETATS ---
enum State { IDLE, CHASE, ATTACK, DEAD }
var current_state: State = State.IDLE

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: Node3D = null

var _current_attack_anim: String = "swing_attack"
var _attack_anim_started: bool = false
var _target_update_timer: float = 0.0

var _is_jump_frozen: bool = false
var _has_left_ground: bool = false
var _chase_timer: float = 0.0
var _next_chase_limit: float = 5.0
var _force_jump: bool = false
var _jump_target_pos: Vector3 = Vector3.ZERO
var _current_rock: RigidBody3D = null
var _has_midlife_roared: bool = false
var _wants_to_roar: bool = false

func _ready() -> void:
	if behavior == null:
		push_error("OgreBoss (" + name + ") : Fichier EnemyBehaviorData manquant !")
		
	health_component.died.connect(_on_died)
	health_component.health_changed.connect(_on_health_changed)
	
	call_deferred("actor_setup")

func actor_setup() -> void:
	await get_tree().physics_frame
	_update_closest_target()
	change_state(State.IDLE)
	
	var hitbox = find_child("HitboxComponent*", true, false)
	if hitbox != null and hitbox.has_signal("aggro_requested"):
		hitbox.aggro_requested.connect(_on_aggro_requested)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		_has_left_ground = true
		velocity.y -= gravity * delta
		
		# Détection d'atterrissage anticipé (quand il tombe)
		if _is_jump_frozen and _has_left_ground and velocity.y < 0.0:
			var dist_to_impact = global_position.distance_to(_jump_target_pos)
			if dist_to_impact <= unfreeze_distance:
				print("OgreBoss: Atterrissage imminent ! (distance = ", dist_to_impact, ")")
				_unfreeze_jump()
	else:
		if _is_jump_frozen and _has_left_ground:
			_unfreeze_jump()

	if current_state == State.DEAD:
		_stop_movement(delta)
		move_and_slide()
		return
		
	_target_update_timer += delta
	if _target_update_timer > 10.0 or target == null or not is_instance_valid(target):
		_target_update_timer = 0.0
		_update_closest_target()
		
	_process_state(delta)
	move_and_slide()
	
	var anim_name = "idle"
	if current_state == State.CHASE:
		anim_name = "walk"
	elif current_state == State.ATTACK:
		anim_name = _current_attack_anim
		
	var current_rot = rotation.y
	rpc("_rpc_apply_state", current_state, anim_name, current_rot)

func _process_state(delta: float) -> void:
	if target == null:
		change_state(State.IDLE)
		_stop_movement(delta)
		return

	var dist = global_position.distance_to(target.global_position)
	
	match current_state:
		State.IDLE:
			_stop_movement(delta)
			# Plus de limite d'aggro, il chasse direct s'il a une cible
			change_state(State.CHASE)
				
		State.CHASE:
			var speed = base_movement_speed
				
			_move_to(target.global_position, speed, delta)
				
			var atk_range = 3.5
			if behavior: atk_range = behavior.attack_range
			
			if dist <= atk_range:
				_chase_timer = 0.0
				_next_chase_limit = clamp(randfn(5.0, 1.0), 3.0, 7.0)
				change_state(State.ATTACK)
			else:
				_chase_timer += delta
				if _chase_timer >= _next_chase_limit:
					_chase_timer = 0.0
					_next_chase_limit = clamp(randfn(5.0, 1.0), 3.0, 7.0)
					_force_jump = true
					change_state(State.ATTACK)
				
		State.ATTACK:
			if is_on_floor():
				_stop_movement(delta)
				if target:
					var dir = (target.global_position - global_position).normalized()
					movement_comp.rotate_towards_direction(dir, behavior, delta, 2.0)
			
			if anim_playback:
				var current_anim = anim_playback.get_current_node()
				if current_anim == _current_attack_anim:
					_attack_anim_started = true
				elif _attack_anim_started and (current_anim == "idle" or current_anim == "walk"):
					_attack_anim_started = false
					disable_hitbox()
					change_state(State.CHASE)

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
	if current_state == State.DEAD: return
	
	# Si on a mis en file d'attente un hurlement et qu'on sortait d'une attaque, on force l'attaque "roar"
	if _wants_to_roar and new_state != State.ATTACK:
		_wants_to_roar = false
		new_state = State.ATTACK
		_current_attack_anim = "roar"
	
	if new_state == State.ATTACK and current_state != State.ATTACK:
		if _current_attack_anim == "roar":
			pass # On le laisse hurler, on ne tire pas au sort
		elif _force_jump: 
			if randf() < 0.5:
				_current_attack_anim = "jumping_attack"
			else:
				_current_attack_anim = "rock_throw"
			_force_jump = false
		elif randf() < 0.33: # 33% de chance de faire le ground slam
			_current_attack_anim = "ground_slam"
		else:
			_current_attack_anim = "swing_attack" # 67% swing normal
		print("OgreBoss: Entre dans l'état ATTACK avec ", _current_attack_anim)
	elif new_state == State.CHASE and current_state != State.CHASE:
		if _current_attack_anim == "roar": _current_attack_anim = "" # Reset pour la prochaine attaque !
		print("OgreBoss: Entre dans l'état CHASE")
	elif new_state == State.IDLE and current_state != State.IDLE:
		if _current_attack_anim == "roar": _current_attack_anim = "" # Reset pour la prochaine attaque !
		print("OgreBoss: Entre dans l'état IDLE")
		
	current_state = new_state
	if anim_playback:
		match current_state:
			State.IDLE: anim_playback.travel("idle")
			State.CHASE: anim_playback.travel("walk")
			State.ATTACK: anim_playback.travel(_current_attack_anim)

func enable_hitbox() -> void:
	if not attack_component:
		print("OgreBoss: ERREUR - attack_component n'est pas assigné dans l'inspecteur !")
		return
		
	for child in attack_component.get_children():
		if child is CollisionShape3D: 
			child.disabled = false
			print("OgreBoss: CollisionShape3D activé sur l'arme")
			
	if attack_component.has_method("reset_hit_entities"):
		attack_component.reset_hit_entities()
		print("OgreBoss: reset_hit_entities() appelé sur l'arme")

func spawn_slam_attack() -> void:
	if not is_multiplayer_authority():
		return
		
	if jumping_attack == null:
		push_error("OgreBoss: jumping_attack n'est pas assigné !")
		return
		
	var slam = jumping_attack.instantiate() as Node3D
	var spawn_pos: Vector3
	
	if slam_pos != null:
		spawn_pos = slam_pos.global_position
	else:
		var forward_direction = -global_transform.basis.z.normalized()
		spawn_pos = global_position + (forward_direction * 2.5)
		
	# Ajustement du Y pour être exactement sur le sol
	if height_detector != null and height_detector.is_colliding():
		spawn_pos.y = height_detector.get_collision_point().y
	elif is_on_floor():
		spawn_pos.y = global_position.y
		
	# Si c'est un noeud qui doit se rajouter à la scène principale
	get_tree().current_scene.add_child(slam)
	slam.global_position = spawn_pos
	print("OgreBoss: Jumping attack spammée à ", spawn_pos)

func spawn_ground_slam() -> void:
	if not is_multiplayer_authority():
		return
		
	if slam_attack == null:
		push_error("OgreBoss: slam_attack n'est pas assigné !")
		return
		
	var slam = slam_attack.instantiate() as Node3D
	var spawn_pos: Vector3
	
	if slam_pos != null:
		spawn_pos = slam_pos.global_position
	else:
		var forward_direction = -global_transform.basis.z.normalized()
		spawn_pos = global_position + (forward_direction * 2.5)
		
	# Ajustement du Y pour être exactement sur le sol
	if height_detector != null and height_detector.is_colliding():
		spawn_pos.y = height_detector.get_collision_point().y
	elif is_on_floor():
		spawn_pos.y = global_position.y
		
	# Si c'est un noeud qui doit se rajouter à la scène principale
	get_tree().current_scene.add_child(slam)
	slam.global_position = spawn_pos
	print("OgreBoss: Ground slam spammé à ", spawn_pos)

func pick_up_rock() -> void:
	if not is_multiplayer_authority(): return
	
	if rock_scene == null or throw_pos == null:
		push_error("OgreBoss: rock_scene ou throw_pos non assigné !")
		return
		
	# Si on a déjà un rocher en main (bug), on le détruit
	if is_instance_valid(_current_rock):
		_current_rock.queue_free()
		
	_current_rock = rock_scene.instantiate() as RigidBody3D
	if _current_rock != null:
		throw_pos.add_child(_current_rock)
		_current_rock.position = Vector3.ZERO
		_current_rock.rotation = Vector3.ZERO
		_current_rock.scale = Vector3(1.5, 1.5, 1.5)
		
		# On désactive la physique pendant qu'il l'a en main
		_current_rock.freeze = true
		print("OgreBoss: Rocher ramassé !")

func throw_rock() -> void:
	if not is_multiplayer_authority(): return
	
	if is_instance_valid(_current_rock):
		var main_scene = get_tree().current_scene
		
		# Récupère la position globale avant de le détacher de la main
		var global_p = _current_rock.global_position
		var global_r = _current_rock.global_basis
		
		_current_rock.get_parent().remove_child(_current_rock)
		main_scene.add_child(_current_rock)
		
		_current_rock.global_position = global_p
		_current_rock.global_basis = global_r
		
		# On réactive la physique
		_current_rock.freeze = false
		
		var target_pos = global_position - global_transform.basis.z.normalized() * 5.0
		if target != null and is_instance_valid(target):
			target_pos = target.global_position
			
		if _current_rock.has_method("throw_at"):
			_current_rock.throw_at(target_pos)
		else:
			print("OgreBoss: Le rocher n'a pas la méthode throw_at()")
			
		_current_rock = null
		print("OgreBoss: Rocher jeté !")

func apply_jump() -> void:
	if not is_multiplayer_authority():
		return
		
	var angle_rad = deg_to_rad(jump_angle)
	
	# Par défaut, saute en avant de 5 mètres si pas de cible
	var target_pos = global_position - global_transform.basis.z.normalized() * 5.0
	if target != null and is_instance_valid(target):
		target_pos = target.global_position
		
		# Anticipation (Target Leading)
		var approx_dist = Vector2(target_pos.x - global_position.x, target_pos.z - global_position.z).length()
		var time_of_flight = 1.0
		if gravity > 0.1 and angle_rad > 0.01:
			time_of_flight = sqrt((2.0 * approx_dist * tan(angle_rad)) / gravity)
			
		var target_vel = Vector3.ZERO
		if "velocity" in target:
			var v = target.get("velocity")
			if typeof(v) == TYPE_VECTOR3:
				target_vel = v
				target_vel.y = 0.0 # On anticipe uniquement sur le sol
				
		# On déplace la cible pour anticiper sa position à l'atterrissage
		target_pos += target_vel * time_of_flight
		
	var dir_to_target = target_pos - global_position
	var dist_2d = Vector2(dir_to_target.x, dir_to_target.z).length()
	
	if dist_2d > max_jump_range:
		dist_2d = max_jump_range
		
	var req_power = jump_power
	
	# Formule de la balistique: v = sqrt( d * g / sin(2 * angle) )
	if dist_2d > 0.1 and sin(2.0 * angle_rad) > 0.01:
		var v2 = (dist_2d * gravity) / sin(2.0 * angle_rad)
		if v2 > 0:
			req_power = sqrt(v2)
			
	# On limite la puissance max pour éviter qu'il s'envole en orbite
	if req_power > 40.0: req_power = 40.0
	
	# 90° = purement vertical, 0° = purement horizontal (math standard)
	var vertical_vel = req_power * sin(angle_rad)
	var forward_vel = req_power * cos(angle_rad)
	
	velocity.y = vertical_vel
	
	if forward_vel > 0.0:
		var jump_dir = Vector3(dir_to_target.x, 0, dir_to_target.z).normalized()
		if jump_dir == Vector3.ZERO:
			jump_dir = -global_transform.basis.z.normalized()
			
		velocity.x = jump_dir.x * forward_vel
		velocity.z = jump_dir.z * forward_vel
		
		# On calcule le point d'impact exact pour savoir quand dé-freeze l'animation
		_jump_target_pos = global_position + jump_dir * dist_2d
	else:
		_jump_target_pos = global_position
		
	print("OgreBoss: apply_jump balistique appelé ! Puissance: ", req_power, " Cible prévue: ", _jump_target_pos)
	
func disable_hitbox() -> void:
	if not attack_component:
		return
		
	for child in attack_component.get_children():
		if child is CollisionShape3D: 
			child.disabled = true
			print("OgreBoss: CollisionShape3D désactivé sur l'arme")
			
	if attack_component and attack_component.has_method("reset_hit_entities"):
		attack_component.reset_hit_entities()
		print("OgreBoss: reset_hit_entities() appelé (depuis disable)")

func freeze_animation() -> void:
	if not is_multiplayer_authority():
		return
	_is_jump_frozen = true
	var anim_tree = find_child("AnimationTree", true, false)
	if anim_tree:
		anim_tree.set("parameters/jumping_attack/TimeScale/scale", 0.0)
	print("OgreBoss: Animation figée en l'air !")

func _unfreeze_jump() -> void:
	_is_jump_frozen = false
	_has_left_ground = false
	var anim_tree = find_child("AnimationTree", true, false)
	if anim_tree:
		anim_tree.set("parameters/jumping_attack/TimeScale/scale", 1.0)
	print("OgreBoss: Atterrissage ! Reprise de l'animation.")

@rpc("authority", "call_local", "unreliable")
func _rpc_apply_state(new_state: int, sync_anim: String, sync_rot: float) -> void:
	if current_state == State.DEAD: return
	if not is_multiplayer_authority():
		current_state = new_state
		rotation.y = lerp_angle(rotation.y, sync_rot, 0.2)
		if anim_playback:
			anim_playback.travel(sync_anim)

func _on_health_changed(current_health: float, max_health: float) -> void:
	if not is_multiplayer_authority() or current_state == State.DEAD: return
	
	if not _has_midlife_roared and current_health <= (max_health * 0.5):
		_has_midlife_roared = true
		_wants_to_roar = true
		
		# S'il n'est pas déjà en train d'attaquer, on peut déclencher le cri immédiatement
		if current_state != State.ATTACK:
			change_state(State.ATTACK)

func play_roar() -> void:
	if midlife_roar_scene == null or roar_pos == null:
		push_error("OgreBoss: midlife_roar_scene ou roar_pos non défini !")
		return
		
	var roar = midlife_roar_scene.instantiate() as Node3D
	roar_pos.add_child(roar)
	roar.position = Vector3.ZERO
	roar.rotation = Vector3.ZERO
	print("OgreBoss: Scene Midlife Roar instanciée !")
	
	# Le boss s'énerve et court 20% plus vite !
	base_movement_speed *= 1.2

func apply_roar_knockback() -> void:
	if not is_multiplayer_authority(): return
	
	var players = get_tree().get_nodes_in_group("Player")
	for player in players:
		var distance = global_position.distance_to(player.global_position)
		if distance <= 20.0:
			# Le knockback va de roar_knockback_force (à 0m) jusqu'à 0 (à 20m)
			var power = lerp(roar_knockback_force, 0.0, distance / 20.0)
			
			# Direction de la poussée (boss vers joueur)
			var push_dir = player.global_position - global_position
			var flat_dir = Vector3(push_dir.x, 0, push_dir.z).normalized()
			
			# On applique l'angle d'élévation
			var elevation_rad = deg_to_rad(roar_knockback_angle)
			var final_push_dir = (flat_dir * cos(elevation_rad) + Vector3.UP * sin(elevation_rad)).normalized()
			
			# On cherche le composant de knockback sur le joueur
			var kb_comp = null
			for child in player.get_children():
				if child is KnockbackComponent:
					kb_comp = child
					break
			
			if kb_comp != null:
				kb_comp.apply_knockback(final_push_dir, power)
				print("OgreBoss: Roar knockback de ", power, " appliqué sur ", player.name)

func _on_died() -> void:
	if is_multiplayer_authority():
		rpc("_rpc_trigger_death")

@rpc("authority", "call_local", "reliable")
func _rpc_trigger_death() -> void:
	current_state = State.DEAD
	disable_hitbox()
	collision_layer = 0
	collision_mask = 1
	if anim_playback:
		anim_playback.travel("death")
	if is_multiplayer_authority():
		await get_tree().create_timer(5.0).timeout
		queue_free()

func _update_closest_target() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	var closest_dist = INF
	target = null
	for p in players:
		if p.get("is_dead") == true: continue
		var d = global_position.distance_to(p.global_position)
		if d < closest_dist:
			closest_dist = d
			target = p

func _on_aggro_requested(attacker: Node3D) -> void:
	if not is_multiplayer_authority() or current_state == State.DEAD: return
	target = attacker
	_target_update_timer = 0.0
