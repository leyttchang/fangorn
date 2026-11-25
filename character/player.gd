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
@onready var equipment_comp: Node = get_node_or_null("EquipmentComponent")
@onready var inventory_comp: Node = get_node_or_null("InventoryComponent")
@onready var main_droite = %MainDroite

@export var custom_footstep_sound: AudioStream # Optionnel : Glisser un fichier .wav / .ogg
@export var step_interval: float = 2.8 # Distance en mÃ¨tres entre deux bruits de pas

@export_group("Bonus de Route (Convoi)")
## Vitesse nominale synchronisée pour que les alliés connaissent notre vitesse de pointe
@export var nominal_speed: float = 6.0
## Bonus passif accordé sur la route (+20% par défaut)
@export var road_base_bonus: float = 1.20
## Rayon de détection des alliés sur la route pour le convoi (en mètres)
@export var road_squad_radius: float = 35.0
## Accélération progressive vers la vitesse du plus rapide (en m/s²)
@export var road_squad_acceleration: float = 2.5
## Décélération progressive quand on quitte la route (en m/s²)
@export var road_squad_deceleration: float = 4.0

var is_on_road: bool = false
var _current_road_percent_bonus: float = 0.0
var _last_applied_road_bonus: float = 0.0
var _path_generator: PathGenerator = null

var _footstep_distance: float = 0.0
var last_weapon_switch_time: int = 0

const JUMP_VELOCITY = 4.5
var mouse_sensitivity = 0.002
var is_dead: bool = false

# --- PROPULSION AÉRIENNE (Racine-Catapulte style Deadlock) ---
@export_group("Propulsion Aérienne (Catapulte)")
## Contrôle directionnel en l'air pendant un saut propulsé (permet d'incurver légèrement la trajectoire)
@export var air_launch_steer_accel: float = 14.0
## Très légère résistance de l'air pour garder un arc fluide sans accélérer à l'infini
@export var air_launch_drag: float = 1.4

var _is_air_launched: bool = false
var _air_launch_grace_timer: float = 0.0
## Si vrai, une compétence de mouvement/saut (ex: Leap Slam) pilote directement velocity + move_and_slide()
var external_motion_override: bool = false
## Si vrai, une transformation active (ex: Living Lightning, Glacial Ram) bloque les attaques d'arme et autres sorts
var is_in_transformation: bool = false


func set_first_person_arms_visible(vis: bool) -> void:
	if not is_multiplayer_authority():
		return
	var md: Node3D = get_node_or_null("Camera3D/MainDroite") as Node3D
	if md != null:
		md.visible = vis
	var mg: Node3D = get_node_or_null("Camera3D/MainGauche") as Node3D
	if mg != null:
		mg.visible = vis
	var nose: Node3D = get_node_or_null("Camera3D/nez") as Node3D
	if nose != null:
		nose.visible = vis

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	# Ne jamais considérer un ennemi (Layer 9 = 256) comme une plateforme mobile transférant sa vélocité de saut
	platform_floor_layers &= ~256
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING

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
			pseudo_label.text = "Player " + str(my_id)
		pseudo_label.visible = not is_multiplayer_authority()

	if not is_multiplayer_authority():
		# Supprimer le shader plein écran Kuwahara et les quads d'effets d'écran des joueurs distants
		# (on conserve MainDroite, MainGauche et nez intacts pour la synchro 3e personne)
		var global_sh = get_node_or_null("Camera3D/global_shader")
		if global_sh != null:
			if "visible" in global_sh:
				global_sh.visible = false
			global_sh.queue_free()
		var dmg_screen_fx = get_node_or_null("Camera3D/damage_screen_effect")
		if dmg_screen_fx != null:
			if "visible" in dmg_screen_fx:
				dmg_screen_fx.visible = false
			dmg_screen_fx.queue_free()

		# Cacher et désactiver toute l'UI (CanvasLayers) des joueurs distants
		var canvas_layers = find_children("*", "CanvasLayer", true, false)
		for canvas in canvas_layers:
			canvas.visible = false
			canvas.process_mode = Node.PROCESS_MODE_DISABLED
		return # Les clients distants n'ont rien de plus à faire ici

	# --- À partir d'ici : seulement pour NOTRE joueur local ---
	camera.current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Fix Terrain3D : assure qu'il utilise la bonne caméra en solo et multijoueur
	_setup_terrain_camera()

	if equipment_comp != null and starting_equipped_weapon != null:
		var w = starting_equipped_weapon.duplicate(true)
		w.original_base_path = starting_equipped_weapon.resource_path
		equipment_comp.equip_item(w, "main_hand")

	if inventory_comp != null:
		for item in starting_inventory_items:
			if item != null:
				var new_item = item.duplicate(true)
				new_item.original_base_path = item.resource_path
				inventory_comp.add_item(new_item, 1)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority() or is_dead:
		if is_dead:
			external_motion_override = false
			is_in_transformation = false
		if not is_on_floor():
			velocity += get_gravity() * delta
			move_and_slide()
		return

	if external_motion_override:
		return

	# 1. Gestion de la gravitÃ©
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Gestion du saut
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Vitesse de base brute (stats/équipement/arbre passif SANS le buff de route)
	var my_unbuffed_mult = stats_component.get_stat_value_excluding("movement_speed", "road_buff")
	var my_base_speed = base_movement_speed * my_unbuffed_mult
	nominal_speed = my_base_speed

	# Recherche paresseuse du PathGenerator s'il n'est pas encore en mémoire
	if _path_generator == null:
		_path_generator = get_tree().get_first_node_in_group("PathGenerator") as PathGenerator

	# Détection de la route (on conserve l'état en l'air pour préserver le momentum du saut)
	if is_on_floor():
		if _path_generator != null:
			is_on_road = _path_generator.is_point_on_path(Vector2(global_position.x, global_position.z))
		else:
			is_on_road = false

	var target_percent = 0.0

	if is_on_road:
		# 1. Bonus passif de base sur la route : +20%
		target_percent = road_base_bonus - 1.0

		# 2. Effet convoi : chercher le joueur le plus rapide à proximité qui est AUSSI sur la route
		var highest_squad_nominal = my_base_speed
		if get_tree().get_node_count_in_group(&"Player") > 1:
			var max_dist_sq: float = road_squad_radius * road_squad_radius
			for other_p in get_tree().get_nodes_in_group(&"Player"):
				if other_p == self or not is_instance_valid(other_p):
					continue
				if global_position.distance_squared_to(other_p.global_position) <= max_dist_sq:
					var other_pos_2d = Vector2(other_p.global_position.x, other_p.global_position.z)
					if _path_generator != null and _path_generator.is_point_on_path(other_pos_2d):
						var other_nom = other_p.nominal_speed if "nominal_speed" in other_p else other_p.base_movement_speed
						if other_nom > highest_squad_nominal:
							highest_squad_nominal = other_nom

		# 3. Si un allié proche est plus rapide, calculer le pourcentage nécessaire pour atteindre son allure
		if my_base_speed > 0.0:
			var leader_road_speed = highest_squad_nominal * road_base_bonus
			var convoi_percent = (leader_road_speed / my_base_speed) - 1.0
			if convoi_percent > target_percent:
				target_percent = convoi_percent

		# 4. Accélération progressive du pourcentage de buff dans le StatsComponent
		var rate = (road_squad_acceleration / my_base_speed) if my_base_speed > 0.0 else 0.5
		_current_road_percent_bonus = move_toward(_current_road_percent_bonus, target_percent, rate * delta)
		var reached_target: bool = is_equal_approx(_current_road_percent_bonus, target_percent) and not is_equal_approx(_last_applied_road_bonus, target_percent)
		if absf(_current_road_percent_bonus - _last_applied_road_bonus) >= 0.002 or reached_target:
			_last_applied_road_bonus = _current_road_percent_bonus
			stats_component.set_or_update_modifier("movement_speed", StatModifier.Type.PERCENT, _current_road_percent_bonus, "road_buff")
	else:
		# En dehors de la route, décélération progressive vers 0%
		if _current_road_percent_bonus > 0.0 or _last_applied_road_bonus > 0.0:
			var decel_rate = (road_squad_deceleration / my_base_speed) if my_base_speed > 0.0 else 0.8
			_current_road_percent_bonus = move_toward(_current_road_percent_bonus, 0.0, decel_rate * delta)
			if _current_road_percent_bonus <= 0.001:
				_current_road_percent_bonus = 0.0
				_last_applied_road_bonus = 0.0
				stats_component.remove_modifier_by_source("road_buff")
			elif absf(_current_road_percent_bonus - _last_applied_road_bonus) >= 0.002:
				_last_applied_road_bonus = _current_road_percent_bonus
				stats_component.set_or_update_modifier("movement_speed", StatModifier.Type.PERCENT, _current_road_percent_bonus, "road_buff")

	# La vitesse finale découle 100% de StatsComponent (affiché directement dans l'UI des stats !)
	var current_speed = base_movement_speed * stats_component.get_stat_value("movement_speed")

	if main_droite != null and main_droite.is_attacking:
		if equipment_comp != null:
			var weapon = equipment_comp.equipped_items.get("main_hand") as WeaponItem
			if weapon != null:
				current_speed *= weapon.hit_slow

	# ==========================================================
	# 3. NOUVELLE GESTION DU MOUVEMENT (InspirÃ©e de tes anciens scripts)
	# ==========================================================
	
	if _air_launch_grace_timer > 0.0:
		_air_launch_grace_timer -= delta
	elif _is_air_launched and is_on_floor():
		_is_air_launched = false

	# On isole la vitesse horizontale dans un Vector2 (pour ne pas casser la gravitÃ©)
	var vitesse_horizontale = Vector2(velocity.x, velocity.z)

	# On rÃ©cupÃ¨re les inputs du joueur
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# On convertit la direction 3D en direction 2D
	var direction_2d = Vector2(direction.x, direction.z)
	
	var on_ice: bool = false
	var ice_data: Dictionary = {}
	if is_on_floor() and velocity.y <= 1.5 and not _is_air_launched:
		ice_data = BossIceArena.get_ice_physics_at(global_position)
		on_ice = bool(ice_data.get("on_ice", false))
	
	if _is_air_launched and not is_on_floor():
		# Mode arc aérien (Racine-Catapulte style Deadlock) :
		# conserve l'élan horizontal du bond sans freiner vers current_speed quand on maintient Z,
		# tout en permettant d'incurver sa trajectoire ou de freiner volontairement en reculant (S).
		var cur_len = vitesse_horizontale.length()
		if direction_2d != Vector2.ZERO:
			var align = vitesse_horizontale.normalized().dot(direction_2d) if cur_len > 0.1 else 1.0
			if align >= -0.25:
				var preserved_speed = maxf(current_speed, cur_len - air_launch_drag * delta)
				vitesse_horizontale = vitesse_horizontale.move_toward(direction_2d * preserved_speed, air_launch_steer_accel * delta)
				if vitesse_horizontale.length() > preserved_speed:
					vitesse_horizontale = vitesse_horizontale.normalized() * preserved_speed
			else:
				# Freinage aérien volontaire si le joueur tire en arrière
				vitesse_horizontale = vitesse_horizontale.move_toward(direction_2d * current_speed, air_launch_steer_accel * 1.4 * delta)
		else:
			vitesse_horizontale = vitesse_horizontale.move_toward(Vector2.ZERO, air_launch_drag * delta)
	elif on_ice:
		# Physique de patinage / glissade sur la glace de l'Arène du Boss (Phase 2)
		var ice_fric: float = float(ice_data.get("friction", 2.2))
		var ice_accel: float = float(ice_data.get("acceleration", 9.5))
		var rev_mult: float = float(ice_data.get("reverse_brake_mult", 1.35))
		var max_mult: float = float(ice_data.get("max_speed_mult", 1.12))
		var ice_max_spd: float = current_speed * max_mult
		var cur_ice_len: float = vitesse_horizontale.length()

		if direction_2d != Vector2.ZERO:
			var align_ice: float = (vitesse_horizontale / cur_ice_len).dot(direction_2d) if cur_ice_len > 0.5 else 1.0
			if cur_ice_len > ice_max_spd:
				# Conserve l'excédent de vitesse (knockback du Boss ou Dash) en le laissant glisser
				# doucement avec ice_fric tout en permettant d'incurver ou de contre-braquer
				if align_ice < -0.15:
					vitesse_horizontale = vitesse_horizontale.move_toward(direction_2d * ice_max_spd, (ice_accel * rev_mult) * delta)
				else:
					var preserved_ice_spd: float = maxf(ice_max_spd, cur_ice_len - ice_fric * delta)
					vitesse_horizontale = vitesse_horizontale.move_toward(direction_2d * preserved_ice_spd, ice_accel * delta)
					if vitesse_horizontale.length() > preserved_ice_spd:
						vitesse_horizontale = vitesse_horizontale.normalized() * preserved_ice_spd
			else:
				var eff_ice_accel: float = (ice_accel * rev_mult) if (cur_ice_len > 0.5 and align_ice < -0.15) else ice_accel
				vitesse_horizontale = vitesse_horizontale.move_toward(direction_2d * ice_max_spd, eff_ice_accel * delta)
		else:
			vitesse_horizontale = vitesse_horizontale.move_toward(Vector2.ZERO, ice_fric * delta)
	elif direction_2d != Vector2.ZERO:
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
	if is_on_floor() and vitesse_horizontale.length() > 0.5 and (not on_ice or direction_2d != Vector2.ZERO):
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
		
		if equipment_comp != null:
			equipment_comp.swap_weapons()

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

func _on_damage_taken(_amount: float, _is_critical: bool = false) -> void:
	pass

# ==========================================================
# FIX CAMERA TERRAIN3D (LOD & CLIPMAP EN MULTIJOUEUR)
# ==========================================================

func _setup_terrain_camera() -> void:
	if not is_multiplayer_authority() or not is_instance_valid(camera):
		return
		
	var found_terrain := false
	# owned = false est indispensable pour trouver les nœuds instanciés dynamiquement
	var terrains = get_tree().root.find_children("*", "Terrain3D", true, false)
	for t in terrains:
		if is_instance_valid(t) and t.has_method("set_camera"):
			t.set_camera(camera)
			found_terrain = true
			print("Terrain3D: Caméra locale assignée avec succès -> ", camera.name)
			
	if not found_terrain:
		call_deferred("_retry_setup_terrain_camera")

func _retry_setup_terrain_camera() -> void:
	if not is_inside_tree() or not is_multiplayer_authority() or not is_instance_valid(camera):
		return
	await get_tree().process_frame
	var terrains = get_tree().root.find_children("*", "Terrain3D", true, false)
	for t in terrains:
		if is_instance_valid(t) and t.has_method("set_camera"):
			t.set_camera(camera)
			print("Terrain3D: Caméra locale assignée en différé -> ", camera.name)

# ==========================================================
# PROPULSION AÉRIENNE (Racines-Catapultes style Deadlock)
# ==========================================================
func apply_air_launch(launch_velocity: Vector3) -> void:
	if is_dead:
		return
	if not multiplayer.has_multiplayer_peer() or is_multiplayer_authority():
		_internal_apply_air_launch(launch_velocity)
	else:
		rpc_id(get_multiplayer_authority(), "rpc_apply_air_launch", launch_velocity)

@rpc("any_peer", "call_local", "reliable")
func rpc_apply_air_launch(launch_velocity: Vector3) -> void:
	if is_multiplayer_authority():
		_internal_apply_air_launch(launch_velocity)

func _internal_apply_air_launch(launch_velocity: Vector3) -> void:
	velocity = launch_velocity
	_is_air_launched = true
	_air_launch_grace_timer = 0.15
