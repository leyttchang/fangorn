extends CharacterBody3D

@export var camera: Camera3D

# --- SYSTÈME D'ÉQUIPEMENT ET D'INVENTAIRE DE DÉPART ---
@export var starting_equipped_weapon: WeaponItem 
@export var starting_inventory_items: Array[ItemData] = []
# ------------------------------------------------------

@export var base_movement_speed: float = 6.0
@export var acceleration: float = 40.0
@export var friction: float = 35.0
@export var air_friction: float = 10.0 # Moins de friction en l'air pour garder l'élan du saut
# ------------------------------------------------------

@onready var stats_component: StatsComponent = %StatsComponent
@onready var health_component: HealthComponent = $HealthComponent

@export var custom_footstep_sound: AudioStream # Optionnel : Glisser un fichier .wav / .ogg
@export var step_interval: float = 2.8 # Distance en mètres entre deux bruits de pas

var _footstep_distance: float = 0.0

const JUMP_VELOCITY = 4.5
const mouse_sensitivity = 0.002

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	health_component.died.connect(_on_died)
	health_component.damage_taken.connect(_on_damage_taken)
	
	var equip_comp = $EquipmentComponent 
	if equip_comp != null and starting_equipped_weapon != null:
		# On équipe l'arme telle qu'elle est définie dans l'inspecteur
		equip_comp.equip_item(starting_equipped_weapon.duplicate(true), "main_hand")
		
	var inv_comp = $InventoryComponent
	if inv_comp != null:
		for item in starting_inventory_items:
			if item != null:
				inv_comp.add_item(item.duplicate(true), 1)
	# ========================================
	
func _physics_process(delta: float) -> void:
	# 1. Gestion de la gravité
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Gestion du saut
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var current_speed = base_movement_speed * stats_component.get_stat_value("movement_speed")

	# ==========================================================
	# 3. NOUVELLE GESTION DU MOUVEMENT (Inspirée de tes anciens scripts)
	# ==========================================================
	
	# On isole la vitesse horizontale dans un Vector2 (pour ne pas casser la gravité)
	var vitesse_horizontale = Vector2(velocity.x, velocity.z)

	# On récupère les inputs du joueur
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# On convertit la direction 3D en direction 2D
	var direction_2d = Vector2(direction.x, direction.z)
	
	if direction_2d != Vector2.ZERO:
		# S'il y a un input, on calcule la vitesse à atteindre
		var vitesse_cible_2d = direction_2d * current_speed
		
		# On ACCÉLÈRE vers cette vitesse cible. 
		# Si la vitesse actuelle est à 50 (Knockback), elle va descendre doucement vers la vitesse cible au lieu de "clignoter".
		vitesse_horizontale = vitesse_horizontale.move_toward(vitesse_cible_2d, acceleration * delta)
	else:
		# Si on lâche les touches, on applique la friction
		var friction_actuelle = friction if is_on_floor() else air_friction
		vitesse_horizontale = vitesse_horizontale.move_toward(Vector2.ZERO, friction_actuelle * delta)

	# On réapplique la vélocité horizontale calculée à la vraie vélocité 3D du CharacterBody
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
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

	if event is InputEventKey and event.keycode == KEY_F11 and event.pressed:
		var current_mode = DisplayServer.window_get_mode()
		if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_died() -> void:
	print("mort")
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()

func _on_damage_taken(amount: float) -> void:
	print("Attention : Le joueur vient de perdre ", amount, " PV !")
