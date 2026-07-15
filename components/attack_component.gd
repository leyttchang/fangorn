class_name AttackComponent
extends Area3D

@export var damage: float = 1
# NOUVEAU : Une case à cocher dans l'inspecteur, à activer UNIQUEMENT pour tes projectiles
@export var destroy_on_environment: bool = false 
@export var knockback_force: float = 15.0 # NOUVEAU : La force de poussée de cette attaque
@export var is_projectile: bool = false
signal attack_landed(target)

var hit_entities: Array[Area3D] = []

func _ready() -> void:
	# On écoute les Hitboxes (Area3D)
	area_entered.connect(_on_area_entered)
	# NOUVEAU : On écoute la physique pure (RigidBody, StaticBody...)
	body_entered.connect(_on_body_entered)

# 1. Collision avec un MONSTRE (Hitbox)
func _on_area_entered(area: Area3D) -> void:
	if area is HitboxComponent:
		if hit_entities.has(area):
			return
			
		hit_entities.append(area)
		if area.has_method("receive_hit"):
			area.receive_hit(self)
		attack_landed.emit(area)

# 2. Collision avec le DÉCOR (Sol, Murs)
func _on_body_entered(body: Node3D) -> void:
	# Si c'est le décor ET que ce n'est PAS un personnage (joueur ou monstre)
	if destroy_on_environment and not body is CharacterBody3D:
		attack_landed.emit(body)

func reset_hit_entities() -> void:
	hit_entities.clear()
