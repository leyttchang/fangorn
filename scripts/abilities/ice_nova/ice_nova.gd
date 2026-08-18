extends Node3D

@export var duration_on_ground: float = 0.5

@onready var scaling_component = $SpellScalingComponent
@onready var collision = $AttackComponent/CollisionShape3D
@onready var visuals = $Visuals

func _ready() -> void:
	# On désactive la hitbox au lancement pour pouvoir la délayer avec l'AnimationPlayer
	if collision != null:
		collision.disabled = true

func execute(caster: Node, target_data: Dictionary) -> void:
	# Ice Nova est centré sur le lanceur
	if caster is Node3D:
		global_position = caster.global_position 
	
	# 1. On lance le calcul des stats (Dégâts, Radius, Knockback...)
	if scaling_component != null and scaling_component.has_method("on_execute"):
		scaling_component.on_execute(caster, target_data)
		
		# On récupère le rayon final
		var final_radius = scaling_component.final_impact_radius
		
		# 2. SCALING DE LA HITBOX
		if collision != null and (collision.shape is CylinderShape3D or collision.shape is SphereShape3D):
			collision.shape = collision.shape.duplicate()
			collision.shape.radius = final_radius
			
		# 3. SCALING DES VISUELS
		if visuals != null:
			var base_radius = scaling_component.base_impact_radius
			var scale_factor = final_radius / base_radius
			# On ne scale que X et Z pour ne pas enfoncer les effets dans le sol !
			visuals.scale = Vector3(scale_factor, 1.0, scale_factor)

# NOUVEAU : Méthode à appeler depuis ton AnimationPlayer pour activer les dégâts au bon moment
func enable_damage() -> void:
	if collision != null:
		# On utilise set_deferred pour éviter les erreurs de physique
		collision.set_deferred("disabled", false)
		
	# On démarre le chrono de destruction SEULEMENT quand la hitbox est activée (pour ne pas qu'elle se supprime trop tôt)
	await get_tree().create_timer(duration_on_ground).timeout
	var attack_node = get_node_or_null("AttackComponent")
	if attack_node != null:
		attack_node.queue_free()

# NOUVEAU : Méthode à appeler depuis ton AnimationPlayer tout à la fin de l'animation
func disappear() -> void:
	queue_free()
