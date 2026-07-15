class_name HitboxComponent
extends Area3D

@export var health_component: HealthComponent
@export var knockback_component: KnockbackComponent # NOUVEAU

func _ready() -> void:
	if health_component == null:
		push_warning("HitboxComponent sur " + get_parent().name + " n'a pas de HealthComponent assigné !")

# MODIFIÉ : On reçoit l'attaque en entier (AttackComponent) au lieu d'un simple chiffre
func receive_hit(attack: AttackComponent) -> void:
	# 1. On applique les dégâts
	if health_component != null:
		health_component.take_damage(attack.damage)
		
	# 2. On calcule et applique le recul
	if knockback_component != null:
		var push_dir: Vector3
		
		if attack.is_projectile:
			# MAGIE : Si c'est un sort, on utilise sa direction de vol (son axe Z inversé)
			push_dir = -attack.global_transform.basis.z
		else:
			# Si c'est une épée, on garde l'ancien calcul basé sur les positions
			push_dir = global_position - attack.global_position
			
		# On envoie directement la direction calculée au composant de recul
		knockback_component.apply_knockback(push_dir, attack.knockback_force)
