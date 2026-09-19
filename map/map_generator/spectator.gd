extends Camera3D

@export var speed: float = 50.0
@export var sprint_multiplier: float = 3.0
@export var mouse_sensitivity: float = 0.003

func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
		
	# Capture la souris pour qu'elle disparaisse et dirige la caméra
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if not Engine.is_editor_hint(): return
	
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Rotation de gauche à droite
		rotation.y -= event.relative.x * mouse_sensitivity
		# Rotation de haut en bas
		rotation.x -= event.relative.y * mouse_sensitivity
		# Bloque la caméra pour ne pas se tordre le cou (90 degrés max)
		rotation.x = clamp(rotation.x, -PI/2.0, PI/2.0)
		
	# Touche Echap pour libérer la souris
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	# Clic gauche pour recapturer la souris
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
	var move_dir = Vector3.ZERO
	
	# Mouvements ZQSD (touches directes du clavier)
	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W): # W pour supporter les claviers QWERTY au cas où
		move_dir.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		move_dir.z += 1.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A):
		move_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move_dir.x += 1.0
		
	# On normalise pour ne pas aller plus vite en diagonale
	if move_dir.length() > 0:
		move_dir = move_dir.normalized()
		
	# Vitesse actuelle (Ctrl enfoncé = sprint x10)
	var current_speed = speed
	if Input.is_key_pressed(KEY_CTRL):
		current_speed *= 10.0
	
	# On déplace la caméra selon la direction où elle regarde
	# transform.basis contient l'orientation de la caméra
	var final_movement = (transform.basis * move_dir) * current_speed * delta
	global_position += final_movement
	
	# Monter et Descendre (Espace / Ctrl)
	# (J'ai mis Ctrl pour descendre car Shift est souvent utilisé pour accélérer, 
	# mais tu peux changer ça par KEY_SHIFT si tu préfères !)
	if Input.is_key_pressed(KEY_SPACE):
		global_position.y += current_speed * delta
	if Input.is_key_pressed(KEY_SHIFT):
		global_position.y -= current_speed * delta
