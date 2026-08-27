extends CharacterBody3D

@onready var health_component: HealthComponent = $HealthComponent
@onready var stats_component: StatsComponent = $StatsComponent
@onready var knockback_componant = $knockback_componant
@onready var movement_comp: EnemyMovementComponent = $EnemyMovementComponent
@onready var navigation_comp: EnemyNavigationComponent = $EnemyNavigationComponent

# --- DONNEES DE COMPORTEMENT (Le Profil) ---
@export var base_movement_speed: float = 4.5
@export var behavior: EnemyBehaviorData

@export var slam_scene: PackedScene
@onready var attack_shape: CollisionShape3D = get_node_or_null("Great Sword Run/Skeleton3D/BoneAttachment3D/hand/AttackComponent/CollisionShape3D")

# --- ANIMATION TREE ---
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")

# --- ETATS ---
enum State { IDLE, CHASE, ATTACK, DEAD }
var current_state: State = State.IDLE

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: Node3D = null

# Securite pour l'AnimationTree
var _attack_anim_started: bool = false
var _attack_counter: int = 0
var _current_attack_anim: String = ""
var _is_enraged: bool = false # <-- NOUVEAU

func _ready() -> void:
	if behavior == null:
		push_error("Scout (" + name + ") : Fichier EnemyBehaviorData manquant dans l'inspecteur !")
		
	anim_tree.active = true
	health_component.died.connect(_on_died)
	health_component.health_changed.connect(_on_health_changed) # <-- NOUVEAU
	
	# =====================================================================
	# CORRECTION MAGIQUE : On detruit la piste vicieuse dans l'animation RESET
	# =====================================================================
	var anim_player: AnimationPlayer = get_node_or_null("Great Sword Run/AnimationPlayer")
	if anim_player and anim_player.has_animation("RESET"):
		var reset_anim = anim_player.get_animation("RESET")
		for i in range(reset_anim.get_track_count() - 1, -1, -1):
			var path_str = str(reset_anim.track_get_path(i))
			if "disabled" in path_str or "CollisionShape3D" in path_str:
				reset_anim.remove_track(i)
				print("[SCOUT FIX] Piste 'disabled' supprimee de l'animation RESET !")
	# =====================================================================
	
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
			anim_playback.travel("run") # Remplacer par "idle" quand l'animation existera
		State.CHASE:
			anim_playback.travel("run")
		State.ATTACK:
			if _is_enraged:
				# En phase 2: 1 chance sur 2 de faire le gros slam
				if randf() < 0.5:
					_current_attack_anim = "heavy_weapon_swing"
				else:
					_current_attack_anim = "standing_mele_downward"
			else:
				# En phase 1: Combo normal 3 coups
				_attack_counter += 1
				if _attack_counter % 3 == 0:
					_current_attack_anim = "attaque"
				else:
					_current_attack_anim = "standing_mele_downward"
				
			anim_playback.travel(_current_attack_anim)
			_attack_anim_started = false 
		State.DEAD:
			pass # Pas d'animation de mort pour le moment

func _process(delta: float) -> void:
	if current_state == State.DEAD: return
	
	# Le client et le serveur partagent cette logique pour pauser/reprendre l'animation
	# selon le action_speed (qui est synchronis).
	if stats_component != null and anim_tree != null:
		var action_speed = max(0.0, stats_component.get_stat_value("action_speed"))
		if action_speed <= 0.0:
			if anim_tree.active: anim_tree.active = false
		else:
			if not anim_tree.active: anim_tree.active = true

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	if current_state == State.DEAD: return # Arrête de faire tomber le corps parent !
	
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
			elif _attack_anim_started and (current_anim == "run" or current_anim == ""):
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
		State.ATTACK:
			vitesse_horizontale = _process_attack_state(vitesse_horizontale, delta)

	velocity.x = vitesse_horizontale.x
	velocity.z = vitesse_horizontale.y
	
	var old_pos = global_position
	move_and_slide()
	
	if Engine.get_frames_drawn() % 30 == 0 and current_state == State.CHASE:
		var moved_dist = old_pos.distance_to(global_position)
		if moved_dist < 0.01 and vitesse_horizontale.length() > 0.5:
			print("--- SCOUT COINCE ---")
			print("Il essaie d'avancer avec une vitesse de: ", vitesse_horizontale)
			for i in get_slide_collision_count():
				var col = get_slide_collision(i)
				var collider = col.get_collider()
				if collider:
					print("Bloque par: ", collider.name, " (Type: ", collider.get_class(), ")")

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
		
	var direction = navigation_comp.get_direction_to_target(target.global_position)
	
	if Engine.get_frames_drawn() % 30 == 0:
		var nav = navigation_comp.nav_agent
		print("--- DEBUG NAV ---")
		print("Agent cible: ", nav.target_position)
		print("Chemin atteignable ? ", nav.is_target_reachable())
		print("Distance au chemin: ", nav.distance_to_target())
		print("Direction finale: ", direction)
		print("Scout pos: ", global_position, " | Next path pos: ", nav.get_next_path_position())

	movement_comp.rotate_towards_direction(direction, behavior, delta)
	return movement_comp.accelerate_to_direction(vitesse_horiz, direction, speed, behavior, delta)

func _process_attack_state(vitesse_horiz: Vector2, delta: float) -> Vector2:
	return movement_comp.apply_friction(vitesse_horiz, behavior, delta)

# =========================================================================
# GESTION DES ATTAQUES SPÉCIALES (Appelé par l'AnimationPlayer)
# =========================================================================
func spawn_slam_attack() -> void:
	if not is_multiplayer_authority():
		return
		
	if slam_scene == null:
		push_warning("Scout : Aucune scene de Slam assignée !")
		return
		
	var slam = slam_scene.instantiate() as Node3D
	
	# On cherche le Marker3D "slam_position"
	var slam_marker = find_child("slam_position", true, false)
	var spawn_pos: Vector3
	
	if slam_marker != null:
		spawn_pos = slam_marker.global_position
	else:
		# Fallback au cas ou le marqueur n'est pas trouv
		var forward_direction = -global_transform.basis.z.normalized()
		spawn_pos = global_position + (forward_direction * 2.5)
	
	get_tree().current_scene.get_node("NetworkObjects").add_child(slam, true)
	
	# On force la position sur le Serveur d'abord
	slam.global_position = spawn_pos
	
	# Puis on demande au client de synchroniser si la fonction existe
	if slam.has_method("rpc_set_position"):
		slam.rpc("rpc_set_position", spawn_pos)
# =========================================================================

func _on_died() -> void:
	if is_multiplayer_authority():
		get_tree().call_group("ScoreManager", "add_kill_point")
		rpc("_rpc_trigger_death")

func _on_health_changed(current_hp: float, max_hp: float) -> void:
	if not is_multiplayer_authority(): return
	
	# Si on passe sous 50% de vie et qu'on n'est pas encore enrage
	if current_hp <= max_hp * 0.5 and not _is_enraged:
		_is_enraged = true
		
		# On augmente sa vitesse de deplacement de +50% (+0.50 en type PERCENT)
		if stats_component != null:
			stats_component.add_modifier("movement_speed", 1, 0.5, "enrage_buff")
			# Optionnel: on peut aussi augmenter son action_speed si on veut qu'il tape plus vite !
			# stats_component.add_modifier("action_speed", 1, 0.2, "enrage_buff")

@rpc("authority", "call_local", "reliable")
func _rpc_trigger_death() -> void:
	print("Le Scout est mort ! Activation du Ragdoll (Serveur + Client)...")
	remove_from_group("Enemie")
	current_state = State.DEAD
	
	if has_node("HitboxComponent/CollisionShape3D"):
		$HitboxComponent/CollisionShape3D.set_deferred("disabled", true)
	
	if has_node("CollisionShape3D"):
		$CollisionShape3D.set_deferred("disabled", true)
		
	# --- RAGDOLL ---
	if anim_tree and anim_tree.active:
		anim_tree.active = false # Coupe les animations
		
	var simulator = get_node_or_null("Great Sword Run/Skeleton3D/PhysicalBoneSimulator3D")
	var skeleton: Skeleton3D = get_node_or_null("Great Sword Run/Skeleton3D")
	
	if simulator != null:
		simulator.physical_bones_start_simulation()
	elif skeleton != null and skeleton.has_method("physical_bones_start_simulation"):
		skeleton.physical_bones_start_simulation()
		
	if is_multiplayer_authority():
		await get_tree().create_timer(4.0).timeout
		queue_free()
