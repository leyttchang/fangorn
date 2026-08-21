class_name AttackComponent
extends Area3D

@export var damage: float = 1
# NOUVEAU : Une case à cocher dans l'inspecteur, à activer UNIQUEMENT pour tes projectiles
@export var destroy_on_environment: bool = false 
@export var knockback_force: float = 15.0 # La force de poussée de cette attaque
@export_range(0.0, 90.0) var knockback_angle: float = 0.0 # L'angle d'élévation de la cible (0 = plat, 90 = vertical)
@export var is_projectile: bool = false
signal attack_landed(target)

var hit_entities: Array[Area3D] = []
var is_active_for_network: bool = true

func _ready() -> void:
	var p = get_parent()
	while p != null:
		if p is CharacterBody3D:
			is_active_for_network = p.is_multiplayer_authority()
			break
		p = p.get_parent()
	# Si ce n'est pas attach un personnage (ex: sort instanci, pic)
	if p == null:
		if has_meta("caster_authority"):
			var caster_id = get_meta("caster_authority")
			if caster_id != 1:
				is_active_for_network = (caster_id == multiplayer.get_unique_id())
			else:
				is_active_for_network = multiplayer.is_server()
		else:
			# Par dfaut (pics, flches de mobs sans meta), le serveur gre
			is_active_for_network = multiplayer.is_server()

	# On écoute les Hitboxes (Area3D)
	area_entered.connect(_on_area_entered)
	# NOUVEAU : On écoute la physique pure (RigidBody, StaticBody...)
	body_entered.connect(_on_body_entered)

# 1. Collision avec un MONSTRE (Hitbox)
func _on_area_entered(area: Area3D) -> void:
	if not is_active_for_network: return
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
