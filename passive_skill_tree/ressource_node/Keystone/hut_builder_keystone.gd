extends Node

var player: CharacterBody3D
var tree_raycast: RayCast3D
var is_climbing: bool = false
var climb_speed: float = 3.0

func _ready() -> void:
	# Le joueur est supposé être le parent du parent
	var p = get_parent().get_parent()
	if p is CharacterBody3D:
		player = p
		
	# On attend la fin de la frame pour laisser le joueur instancier ses trucs
	call_deferred("_setup_raycast")

func _setup_raycast() -> void:
	if player != null:
		tree_raycast = player.get_node_or_null("tree_climber")
		if tree_raycast == null:
			push_warning("Hut Builder : Le RayCast3D 'tree_climber' n'a pas été trouvé sur le joueur !")

func _physics_process(delta: float) -> void:
	if player == null or tree_raycast == null:
		return
		
	# 1. Vérifier si on DOIT s'accrocher
	if not is_climbing and tree_raycast.is_colliding() and not player.is_on_floor():
		var input_dir = Input.get_vector("left", "right", "forward", "backward")
		if input_dir.y < 0: # Le joueur avance vers l'arbre
			_start_climbing()
			
	# 2. Si on est accroché, on gère la grimpe
	if is_climbing:
		_handle_climbing()

func _start_climbing() -> void:
	is_climbing = true
	# On coupe temporairement la physique normale du joueur (gravité, course)
	player.set_physics_process(false)
	# On annule son élan
	player.velocity = Vector3.ZERO

func _stop_climbing() -> void:
	if not is_climbing: return
	is_climbing = false
	# On réactive la physique normale du joueur
	player.set_physics_process(true)

func _handle_climbing() -> void:
	# Si on a sauté ou si l'arbre s'arrête, on tombe
	if Input.is_action_just_pressed("jump") or not tree_raycast.is_colliding():
		if Input.is_action_just_pressed("jump"):
			# On lui donne une petite impulsion vers l'arrière/haut pour décoller de l'arbre
			var backward = player.global_transform.basis.z
			player.velocity = (backward * 3.0) + Vector3(0, 5.0, 0)
			
		_stop_climbing()
		return
		
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	
	player.velocity.x = 0
	player.velocity.z = 0
	
	if input_dir.y < 0: # forward
		player.velocity.y = climb_speed
	elif input_dir.y > 0: # backward
		player.velocity.y = -climb_speed
	else:
		player.velocity.y = 0 # On reste agrippé sur place
		
	player.move_and_slide()
	
	# Si en descendant on touche le sol, on lâche l'arbre
	if player.is_on_floor():
		_stop_climbing()

func _exit_tree() -> void:
	if is_climbing:
		_stop_climbing()
