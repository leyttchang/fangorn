extends CharacterBody3D

var damage_text_scene = preload("res://ui/damage_text.tscn")

@onready var health_component: HealthComponent = $HealthComponent

# On récupère la force de gravité définie dans les paramètres du projet Godot
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	health_component.damage_taken.connect(_on_damage_taken)
	health_component.died.connect(_on_died)
	
func _physics_process(delta: float) -> void:
	# 1. On applique la gravité si l'entité n'est pas sur le sol
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Le moteur lit la vélocité et déplace le corps
	move_and_slide()
	
	# 3. Le freinage (Friction)
	# On freine UNIQUEMENT les axes X et Z pour ne pas annuler la chute (axe Y)
	velocity.x = move_toward(velocity.x, 0, 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 5.0 * delta)
	
	# (Alternative avec lerp si tu préfères un freinage plus "glissant") :
	# velocity.x = lerp(velocity.x, 0.0, 5.0 * delta)
	# velocity.z = lerp(velocity.z, 0.0, 5.0 * delta)


func _on_damage_taken(amount: float) -> void:
	var text_instance = damage_text_scene.instantiate()
	add_child(text_instance)
	text_instance.position.y = 1.0 
	text_instance.animate(amount)

func _on_died() -> void:
	queue_free()
