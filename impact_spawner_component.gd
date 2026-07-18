class_name ImpactSpawnerComponent
extends Node

@export var impact_scene: PackedScene 
@export var duration_on_ground: float = 4.0 

# Il a besoin de l'AttackComponent pour savoir quand on touche
@export var attack_component: AttackComponent
# Il a besoin du ScalingComponent pour connaître la taille calculée !
@export var scaling_component: SpellScalingComponent 

func _ready() -> void:
	if attack_component != null:
		attack_component.attack_landed.connect(_on_attack_landed)

func _on_attack_landed(_target: Node) -> void:
	if impact_scene != null:
		var impact_instance = impact_scene.instantiate()
		
		if impact_instance.has_method("setup"):
			# On récupère le rayon depuis notre autre composant
			var radius = 4.0
			if scaling_component != null:
				radius = scaling_component.final_impact_radius
				
			impact_instance.setup(radius, duration_on_ground) 
		
		get_tree().root.add_child(impact_instance)
		impact_instance.global_position = get_parent().global_position
		
		
	# On détruit le sort entier
	get_parent().hide()
	await get_tree().create_timer(0.05).timeout
	get_parent().queue_free()
