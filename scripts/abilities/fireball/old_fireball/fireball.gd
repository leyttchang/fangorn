extends RigidBody3D

@export var projectile_speed: float = 30.0
@export var base_damage: float = 100.0
@export var lifespan: float = 5.0 
@export var ground_fire_duration: float = 4.0 

# NOUVEAU : Le rayon de base de l'explosion, modifiable depuis l'inspecteur
@export var base_impact_radius: float = 4.0 

@export var impact_scene: PackedScene 
@onready var attack_component = $AttackComponent

# Variable interne qui va mémoriser la taille calculée au moment du lancer
var final_impact_radius: float = 4.0 

func _ready() -> void:
	attack_component.damage = base_damage
	if attack_component != null:
		attack_component.attack_landed.connect(_on_attack_landed)
	
	await get_tree().create_timer(lifespan).timeout
	if is_instance_valid(self):
		queue_free()

func execute(caster: Node3D, target_data: Dictionary) -> void:
	var caster_stats = caster.find_child("StatsComponent", true, false)
	
	if caster_stats != null:
		if attack_component != null:
			attack_component.damage *= caster_stats.get_stat_value("magic_damage")
		
		# --- LE CALCUL DE L'AOE EST ICI ---
		var aoe_mult = caster_stats.get_stat_value("area_of_effect")
		
		# Petite sécurité : si la stat "aoe_multiplier" vaut 0 (oubli d'ajout dans le StatsComponent), on force à 1.0 pour ne pas avoir un sort invisible
		if aoe_mult == 0.0:
			aoe_mult = 1.0
			
		# On calcule le rayon final et on le stocke dans la variable
		final_impact_radius = base_impact_radius * aoe_mult
			
	var cast_point = caster.find_child("CastPoint", true, false)
	
	if cast_point != null:
		global_position = cast_point.global_position
		var forward_direction = -cast_point.global_transform.basis.z.normalized()
		apply_central_impulse(forward_direction * projectile_speed)
	else:
		global_position = caster.global_position + Vector3(0, 1.5, 0) 
		var forward_direction = -caster.global_transform.basis.z.normalized()
		apply_central_impulse(forward_direction * projectile_speed)

# --- A L'IMPACT ---
func _on_attack_landed(target: Node) -> void:
	if impact_scene != null:
		var impact_instance = impact_scene.instantiate()
		
		if impact_instance.has_method("setup"):
			# ON UTILISE LA VARIABLE CALCULÉE : final_impact_radius
			impact_instance.setup(final_impact_radius, ground_fire_duration) 
		
		get_tree().root.add_child(impact_instance)
		
		impact_instance.global_position = global_position
		impact_instance.global_position.y = 0 
		
	queue_free()
