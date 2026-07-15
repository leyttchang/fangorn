extends CharacterBody3D

@export var camera: Camera3D
@export var arme_de_depart: WeaponItem
@export var epée: WeaponItem
# On récupère notre composant intelligent grâce à son nom unique (%)
@onready var stats_component: StatsComponent = %StatsComponent
@onready var health_component: HealthComponent = $HealthComponent
const JUMP_VELOCITY = 4.5
const mouse_sensitivity = 0.002

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	health_component.died.connect(_on_died)
	health_component.damage_taken.connect(_on_damage_taken)
	# TEST TEMPORAIRE POUR L'ÉQUIPEMENT
	var equip_comp = $EquipmentComponent # Adapte le chemin si besoin
	if equip_comp != null and arme_de_depart != null:
		equip_comp.equip_item(arme_de_depart, "main_hand")
	$InventoryComponent.add_item(arme_de_depart, 1)
	$InventoryComponent.add_item(epée, 1)
	
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	# --- C'EST ICI QUE TOUT CHANGE ---
	# On demande au composant la vitesse exacte du joueur à CETTE frame
	# Si un monstre te ralentit avec un sort, cette valeur baissera toute seule !
	var current_speed = stats_component.get_stat_value("movement_speed")

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		# On utilise 'current_speed' au lieu de la constante
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
	
func _unhandled_input(event: InputEvent) -> void:
	# Détecte les mouvements de la souris
	if event is InputEventMouseMotion:
		# Tourner le personnage entier de gauche à droite (sur l'axe Y)
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Tourner uniquement la caméra de haut en bas (sur l'axe X)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		
		# Bloquer la caméra pour ne pas pouvoir regarder trop en arrière et se tordre le cou
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
func _on_died() -> void:
	print("mort")
func _on_damage_taken(amount: float) -> void:
	print("Attention : Le joueur vient de perdre ", amount, " PV !")
