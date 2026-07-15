extends Node3D

@export var scaling_component: SpellScalingComponent 
@onready var ground_fire = $ground_fire
@export var radius: float = 5.0
@export var duration_on_ground: float = 5.0

func _ready() -> void:
	# On ne fait plus rien ici, c'est trop tôt !
	pass

# Cette fonction est appelée automatiquement par ton SkillBarComponent juste après l'apparition du sort
func execute(caster: Node, target_data: Dictionary) -> void:
	# 1. On demande au ScalingComponent de faire ses calculs en lui donnant le Joueur (caster)
	if scaling_component != null and scaling_component.has_method("on_execute"):
		scaling_component.on_execute(caster, target_data)
		
		# 2. Maintenant que le calcul est fait, on récupère le VRAI rayon modifié par les stats
		radius = scaling_component.final_impact_radius
		
	# 3. On applique la bonne taille au visuel et à la hitbox
	if ground_fire != null and ground_fire.has_method("setup"):
		ground_fire.setup(radius, duration_on_ground)
