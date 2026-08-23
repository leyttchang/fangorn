extends Node3D

@export var attack_component: AttackComponent
@export var scaling_component: SpellScalingComponent 
@export var explosion: AttackComponent
@export var ratio_degat: float = 0.4
@export var radius_ratio: float = 1


@onready var explosion_area: CollisionShape3D = $explosion/CollisionShape3D

var radius: float = 4.0
var has_exploded: bool = false # NOTRE VERROU

func _ready() -> void:
	if attack_component == null:
		push_error("ERREUR : attack_component est vide ! Glisse le nud depuis l'arbre vers l'inspecteur.")
		return
		
	attack_component.attack_landed.connect(_on_attack_landed)

func _on_attack_landed(_target: Node) -> void:
	# Si a a dj explos, on bloque tout de suite !
	if has_exploded:
		print("--- X. DOUBLE IMPACT IGNOR grce au verrou ! ---")
		return
		
	has_exploded = true 
	print("--- 1. IMPACT DTECT ! Dclenchement de l'explosion ---")
	
	if scaling_component != null:
		radius = scaling_component.final_impact_radius * radius_ratio
		if explosion_area.shape is SphereShape3D:
			explosion_area.shape.radius = radius
			print("--- 2. Rayon de l'explosion mis  jour : ", radius, " ---")
	else:
		push_warning("ATTENTION : Pas de scaling_component assign.")

	if attack_component != null and explosion != null:
		explosion.base_damage = attack_component.base_damage * ratio_degat
		explosion.damage_physical = attack_component.damage_physical * ratio_degat
		explosion.damage_fire = attack_component.damage_fire * ratio_degat
		explosion.damage_ice = attack_component.damage_ice * ratio_degat
		explosion.damage_lightning = attack_component.damage_lightning * ratio_degat
		print("--- 3. Dgts de l'explosion rgls sur : ", explosion.base_damage, " ---")
		
		if explosion.has_method("reset_hit_entities"):
			explosion.reset_hit_entities()
			
		explosion_area.set_deferred("disabled", false)
		print("--- 4. Hitbox de l'explosion active ! ---")
		
		await get_tree().create_timer(0.2).timeout
		if is_instance_valid(explosion_area):
			explosion_area.set_deferred("disabled", true)
			print("--- 5. Hitbox de l'explosion dsactive. Fin de l'explosion. ---")
