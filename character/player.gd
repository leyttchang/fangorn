extends CharacterBody3D

signal player_hit_enemy

@export var camera: Camera3D

# --- SYSTÃˆME D'Ã‰QUIPEMENT ET D'INVENTAIRE DE DÃ‰PART ---
@export var starting_equipped_weapon: WeaponItem 
@export var starting_inventory_items: Array[ItemData] = []
# ------------------------------------------------------

@export var base_movement_speed: float = 6.0
@export var acceleration: float = 40.0
@export var air_acceleration: float = 10.0 # AccÃ©lÃ©ration rÃ©duite en l'air (inertie)
@export var friction: float = 35.0
@export var air_friction: float = 5.0 # Moins de friction en l'air pour garder l'Ã©lan du saut
# ------------------------------------------------------

@onready var stats_component: StatsComponent = %StatsComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var main_droite = %MainDroite

@export var custom_footstep_sound: AudioStream # Optionnel : Glisser un fichier .wav / .ogg
@export var step_interval: float = 2.8 # Distance en mÃ¨tres entre deux bruits de pas

var _footstep_distance: float = 0.0
var last_weapon_switch_time: int = 0

const JUMP_VELOCITY = 4.5
var mouse_sensitivity = 0.002
var is_dead: bool = false

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	if Engine.has_singleton("SettingsManager"):
		var settings = Engine.get_singleton("SettingsManager")
		mouse_sensitivity = settings.mouse_sensitivity
		settings.mouse_sensitivity_changed.connect(func(val): mouse_sensitivity = val)
	elif get_tree().root.has_node("SettingsManager"):
		var settings = get_tree().root.get_node("SettingsManager")
		mouse_sensitivity = settings.mouse_sensitivity
		settings.mouse_sensitivity_changed.connect(func(val): mouse_sensitivity = val)

	# Connexions qui ne dépendent pas de l'autorité : on les fait tout de suite
	var revive = get_node_or_null("ReviveComponant")
	if revive == null:
		revive = get_node_or_null("ReviveComponent")
	if revive:
		revive.player_revived.connect(_on_player_revived)

	health_component.died.connect(_on_died)
	health_component.damage_taken.connect(_on_damage_taken)

	# IMPORTANT : On diffère tout ce qui dépend de is_multiplayer_authority().
	# _enter_tree() assigne l'autorité AVANT _ready(), mais le MultiplayerSpawner
	# peut encore être en train de propager l'info sur les autres clients.
	# call_deferred garantit qu'on attend la fin du frame courant.
	call_deferred("_setup_local_player")

func _setup_local_player() -> void:
	# À ce stade, l'autorité réseau est définitivement établie sur ce client.
	var my_id = name.to_int()

	# -- Affichage du Pseudo --
	var pseudo_label = get_node_or_null("PseudoLabel")
	if pseudo_label != null:
		if GameData.player_pseudos.has(my_id):
			pseudo_label.text = GameData.player_pseudos[my_id]
		else:
			pseudo_label.text = "Joueur " + str(my_id)
		pseudo_label.visible = not is_multiplayer_authority()

	if not is_multiplayer_authority():
		# Cacher toute l'UI (CanvasLayers) des joueurs distants
		var canvas_layers = find_children("*", "CanvasLayer", true, false)
		for canvas in canvas_layers:
			canvas.visible = false
		return # Les clients distants n'ont rien de plus à faire ici

	# --- À partir d'ici : seulement pour NOTRE joueur local ---
	camera.current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Fix Terrain3D : assure qu'il utilise la bonne caméra en multi
	if get_tree().current_scene != null:
		var terrains = get_tree().current_scene.find_children("*", "Terrain3D")
		if terrains.size() > 0:
			terrains[0].set_camera(camera)

	var equip_comp = $EquipmentComponent
	if equip_comp != null and starting_equipped_weapon != null:
		var w = starting_equipped_weapon.duplicate(true)
		w.original_base_path = starting_equipped_weapon.resource_path
		equip_comp.equip_item(w, "main_hand")

	var inv_comp = $InventoryComponent
	if inv_comp != null:
		for item in starting_inventory_items:
			if item != null:
				var new_item = item.duplicate(true)
				new_item.original_base_path = item.resource_path
				inv_comp.add_item(new_item, 1)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority() or is_dead:
		if not is_on_floor():
			velocity += get_gravity() * delta
			move_and_slide()
		return

	# 1. Gestion de la gravitÃ©
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Gestion du saut
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var current_speed = base_movement_speed * stats_component.get_stat_value("movement_speed")

	if main_droite != null and main_droite.is_attacking:
		var equip_comp = $EquipmentComponent
		if equip_comp != null:
			var weapon = equip_comp.equipped_items.get("main_hand") as WeaponItem
			if weapon != null:
				current_speed *= weapon.hit_slow

	# ==========================================================
	# 3. NOUVELLE GESTION DU MOUVEMENT (InspirÃ©e de tes anciens scripts)
	# ==========================================================
	
	# On isole la vitesse horizontale dans un Vector2 (pour ne pas casser la gravitÃ©)
	var vitesse_horizontale = Vector2(velocity.x, velocity.z)

	# On rÃ©cupÃ¨re les inputs du joueur
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# On convertit la direction 3D en direction 2D
	var direction_2d = Vector2(direction.x, direction.z)
	
	if direction_2d != Vector2.ZERO:
		# S'il y a un input, on calcule la vitesse Ã  atteindre
		var vitesse_cible_2d = direction_2d * current_speed
		
		# On choisit l'accÃ©lÃ©ration selon si on est au sol ou en l'air
		var accel_actuelle = acceleration if is_on_floor() else air_acceleration
		
		# On ACCÃ‰LÃˆRE vers cette vitesse cible. 
		vitesse_horizontale = vitesse_horizontale.move_toward(vitesse_cible_2d, accel_actuelle * delta)
	else:
		# Si on lÃ¢che les touches, on applique la friction
		var friction_actuelle = friction if is_on_floor() else air_friction
		vitesse_horizontale = vitesse_horizontale.move_toward(Vector2.ZERO, friction_actuelle * delta)

	# On rÃ©applique la vÃ©locitÃ© horizontale calculÃ©e Ã  la vraie vÃ©locitÃ© 3D du CharacterBody
	velocity.x = vitesse_horizontale.x
	velocity.z = vitesse_horizontale.y

	# 4. On bouge !
	move_and_slide()
	
	# 5. Bruits de pas (Footsteps)
	if is_on_floor() and vitesse_horizontale.length() > 0.5:
		_footstep_distance += vitesse_horizontale.length() * delta
		if _footstep_distance >= step_interval:
			_footstep_distance = 0.0
			SoundManager.play_footstep_sound(self, global_position, custom_footstep_sound)
	else:
		_footstep_distance = 0.0
	
func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or is_dead:
		return
		
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

	var is_f11 = event is InputEventKey and event.keycode == KEY_F11 and event.pressed
	var is_alt_enter = event is InputEventKey and event.keycode == KEY_ENTER and event.alt_pressed and event.pressed
	var is_m_key = event is InputEventKey and event.keycode == KEY_M and event.pressed and not event.echo
	
	if is_m_key:
		var enemies = get_tree().get_nodes_in_group("Enemie")
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.is_inside_tree():
				var health = enemy.get_node_or_null("HealthComponent")
				if health == null or health.current_health > 0:
					global_position = enemy.global_position + Vector3(0, 2, 0)
					print("Teleportation au monstre : ", enemy.name)
					break
	
	if is_f11 or is_alt_enter:
		var current_mode = DisplayServer.window_get_mode()
		if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			
	if event.is_action_pressed("switch_weapons"):
		# Ne pas switch pendant qu'on attaque
		if main_droite != null and main_droite.is_attacking:
			return
			
		# Cooldown de 1 seconde (1000 millisecondes)
		var current_time = Time.get_ticks_msec()
		if current_time - last_weapon_switch_time < 1000:
			return
			
		last_weapon_switch_time = current_time
		
		var equip_comp = $EquipmentComponent
		if equip_comp:
			equip_comp.swap_weapons()

func _on_died() -> void:
	print("Joueur mort : verification du multi...")
	# Propager l'état "à terre" à tous les clients pour bloquer les attaques ennemies en multi
	rpc("_rpc_set_downed")
	
	var all_players = get_tree().get_nodes_in_group("Player")
	var other_players_alive = false
	
	for p in all_players:
		if p != self:
			var h = p.get_node_or_null("HealthComponent")
			if h and h.current_health > 0:
				other_players_alive = true
				break
			
	if other_players_alive:
		print("Passage a terre !")
		var revive_comp = get_node_or_null("ReviveComponant")
		if revive_comp == null:
			revive_comp = get_node_or_null("ReviveComponent")
		if revive_comp:
			revive_comp.enable_revive()
	else:
		print("Tout le monde est mort, GAME OVER")
		for p in all_players:
			p.rpc("_rpc_show_game_over")

@rpc("authority", "call_local", "reliable")
func _rpc_set_downed() -> void:
	is_dead = true

@rpc("any_peer", "call_local", "reliable")
func _rpc_show_game_over() -> void:
	if is_multiplayer_authority():
		var game_over = get_node_or_null("GameOverText")
		if game_over != null:
			game_over.afficher_game_over()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_player_revived() -> void:
	# Appelé uniquement sur l'autorité du joueur (via signal local)
	print("Je suis de nouveau sur pied !")
	# Propager l'état "vivant" à tous les clients pour que les ennemis le sachent
	rpc("_rpc_set_alive")

@rpc("authority", "call_local", "reliable")
func _rpc_set_alive() -> void:
	is_dead = false
	# Purger tout le knockback stacké pendant qu'on était à terre
	velocity = Vector3.ZERO
	var health_comp = get_node_or_null("HealthComponent")
	if health_comp != null:
		health_comp.heal(health_comp.stats_component.get_stat_value("max_health") * 0.5)

func _on_damage_taken(amount: float, is_critical: bool = false) -> void:
	print("Attention : Le joueur vient de perdre ", amount, " PV !")
