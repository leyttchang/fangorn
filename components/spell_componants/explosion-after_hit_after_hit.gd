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
		push_error("ERREUR : attack_component est vide ! Glisse le nœud depuis l'arbre vers l'inspecteur.")
		return
		
	attack_component.attack_landed.connect(_on_attack_landed)

func _on_attack_landed(_target: Node) -> void:
	# Si ça a déjà explosé, on bloque tout de suite !
	if has_exploded:
		print("--- X. DOUBLE IMPACT IGNORÉ grâce au verrou ! ---")
		return
		
	has_exploded = true 
	print("--- 1. IMPACT DÉTECTÉ ! Déclenchement de l'explosion ---")
	
	if scaling_component != null:
		radius = scaling_component.final_impact_radius * radius_ratio
		if explosion_area.shape is SphereShape3D:
			explosion_area.shape.radius = radius
			print("--- 2. Rayon de l'explosion mis à jour : ", radius, " ---")
	else:
		push_warning("ATTENTION : Pas de scaling_component assigné.")

	if attack_component != null and explosion != null:
		explosion.damage = attack_component.damage * ratio_degat
		print("--- 3. Dégâts de l'explosion réglés sur : ", explosion.damage, " ---")
		
		if explosion.has_method("reset_hit_entities"):
			explosion.reset_hit_entities()
			
		explosion_area.set_deferred("disabled", false)
		print("--- 4. Hitbox de l'explosion activée ! ---")
		
		await get_tree().create_timer(0.2).timeout
		if is_instance_valid(explosion_area):
			explosion_area.set_deferred("disabled", true)
			print("--- 5. Hitbox de l'explosion désactivée. Fin de l'explosion. ---")
