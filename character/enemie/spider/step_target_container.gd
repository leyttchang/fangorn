extends Node3D

@export var offset: float = 20.0
@export var rotation_offset: float = 8.0 # Correction du tutoriel : L'overshoot de rotation

@onready var parent = get_parent_node_3d()
@onready var previous_position = parent.global_position
@onready var previous_rotation = parent.global_rotation.y

func _process(delta):
	# 1. Overshoot de la ligne droite (Le code de la vido)
	var velocity = parent.global_position - previous_position
	global_position = parent.global_position + velocity * offset
	previous_position = parent.global_position
	
	# 2. Overshoot de la rotation (Notre correction)
	# On calcule l'arc de cercle entre la frame prcdente et maintenant
	var angular_velocity = wrapf(parent.global_rotation.y - previous_rotation, -PI, PI)
	# On tourne le conteneur lgrement plus loin dans la direction du virage
	global_rotation.y = parent.global_rotation.y + angular_velocity * rotation_offset
	previous_rotation = parent.global_rotation.y
