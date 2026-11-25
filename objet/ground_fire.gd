extends Node3D

# La variable qui va stocker le temps transmis par la boule de feu
var lifespan: float = 3.0
var _shape_duplicated: bool = false

# On ajoute un deuxième paramètre : new_duration
func setup(new_radius: float, new_duration: float) -> void:
	# On mémorise la durée voulue
	lifespan = new_duration

	var collision = get_node_or_null("AttackComponent/CollisionShape3D")
	if collision != null and collision.shape is CylinderShape3D:
		if not _shape_duplicated:
			collision.shape = collision.shape.duplicate()
			_shape_duplicated = true
		collision.shape.radius = new_radius

	var particles_node = get_node_or_null("ground_fire_particles")
	if particles_node != null:
		particles_node.radius = new_radius
		# Ne jamais rappeler _ready() manuellement (évite double allocation GPU & 4x duplicate) :
		# si le nœud est déjà prêt dans l'arbre, on met simplement à jour son rayon.
		if particles_node.is_node_ready() and particles_node.has_method("apply_radius"):
			particles_node.apply_radius(new_radius)

func _ready() -> void:
	# Dès que la flaque apparaît dans le monde, le chronomètre se lance
	await get_tree().create_timer(lifespan).timeout

	# Une fois le temps écoulé, la flaque disparaît proprement
	queue_free()
