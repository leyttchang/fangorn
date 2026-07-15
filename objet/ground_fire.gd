extends Node3D

# La variable qui va stocker le temps transmis par la boule de feu
var lifespan: float = 3.0 

# On ajoute un deuxième paramètre : new_duration
func setup(new_radius: float, new_duration: float) -> void:
	
	# On mémorise la durée voulue
	lifespan = new_duration
	
	# (Le reste de ton code ne change pas)
	var collision = $AttackComponent/CollisionShape3D
	if collision != null and collision.shape is CylinderShape3D:
		collision.shape = collision.shape.duplicate()
		collision.shape.radius = new_radius
		
	var particles_node = $ground_fire_particles
	if particles_node != null:
		particles_node.radius = new_radius
		particles_node._ready()

func _ready() -> void:
	# Dès que la flaque apparaît dans le monde, le chronomètre se lance
	await get_tree().create_timer(lifespan).timeout
	
	# Une fois le temps écoulé, la flaque disparaît proprement
	queue_free()
