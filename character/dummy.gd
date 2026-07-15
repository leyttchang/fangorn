extends CharacterBody3D

# On charge la scène du texte en mémoire (vérifie bien le chemin d'accès !)
var damage_text_scene = preload("res://ui/damage_text.tscn")

@onready var health_component: HealthComponent = $HealthComponent

func _ready() -> void:
	# On connecte le nouveau signal
	health_component.damage_taken.connect(_on_damage_taken)
	health_component.died.connect(_on_died)
	
func _physics_process(delta: float) -> void:
	# 1. Le moteur lit la vélocité (modifiée par ton KnockbackComponent) et déplace le corps
	move_and_slide()
	
	# 2. Le freinage : on réduit la vélocité petit à petit, sinon le Dummy 
	# va glisser à l'infini dans le décor comme sur une patinoire
	velocity = velocity.lerp(Vector3.ZERO, 5.0 * delta)
# Quand le mannequin reçoit des dégâts
func _on_damage_taken(amount: float) -> void:
	# 1. On fabrique un nouveau texte
	var text_instance = damage_text_scene.instantiate()
	
	# 2. On l'ajoute dans le monde (au niveau du mannequin)
	add_child(text_instance)
	
	# 3. On le place un peu au-dessus du mannequin pour ne pas qu'il pop dans ses pieds
	# (Si ton cylindre fait 2m de haut, mets y = 1.0 ou 1.5)
	text_instance.position.y = 1.0 
	
	# 4. On lance l'animation !
	text_instance.animate(amount)

func _on_died() -> void:
	queue_free()
