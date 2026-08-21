class_name HitboxComponent
extends Area3D

@export var health_component: HealthComponent
@export var knockback_component: KnockbackComponent # NOUVEAU

signal hit_received(attack: AttackComponent)
signal aggro_requested(attacker: Node3D) # NOUVEAU SIGNAL RESEAU

func _ready() -> void:
	if health_component == null:
		push_warning("HitboxComponent sur " + get_parent().name + " n'a pas de HealthComponent assigné !")

# MODIFIÉ : On reçoit l'attaque en entier (AttackComponent) au lieu d'un simple chiffre
func receive_hit(attack: AttackComponent) -> void:
	# 1. On applique les dégâts
	if health_component != null:
		health_component.take_damage(attack.damage)
		
	hit_received.emit(attack)
	
	# NOUVEAU : On gre l'aggro en rseau
	var attacker_id = 0
	var p = attack.get_parent()
	while p != null:
		if p.is_in_group("Player"):
			attacker_id = p.get_multiplayer_authority()
			break
		p = p.get_parent()
		
	if attacker_id == 0 and attack.has_meta("caster_authority"):
		attacker_id = attack.get_meta("caster_authority")
		
	if attacker_id != 0:
		if get_parent().is_multiplayer_authority():
			_apply_aggro(attacker_id)
		else:
			rpc_id(get_parent().get_multiplayer_authority(), "_rpc_notify_aggro", attacker_id)
		
	# 2. On calcule et applique le recul
	if knockback_component != null:
		var push_dir: Vector3
		
		if attack.is_projectile:
			# MAGIE : Si c'est un sort, on utilise sa direction de vol horizontale
			push_dir = -attack.global_transform.basis.z
		else:
			# Si c'est une épée, on garde l'ancien calcul basé sur les positions
			push_dir = global_position - attack.global_position
			
		# 1. On l'aplatit pour avoir une direction horizontale pure
		push_dir.y = 0
		if push_dir.length_squared() > 0.001:
			push_dir = push_dir.normalized()
		else:
			push_dir = Vector3.FORWARD
			
		# 2. On applique le fameux angle d'élévation
		var angle_rad = deg_to_rad(attack.knockback_angle)
		push_dir = push_dir * cos(angle_rad)
		push_dir.y = sin(angle_rad)
			
		# On envoie directement la direction calculée au composant de recul
		knockback_component.apply_knockback(push_dir, attack.knockback_force)


func _apply_aggro(attacker_id: int) -> void:
	var players = get_tree().get_nodes_in_group("Player")
	for pl in players:
		if pl.get_multiplayer_authority() == attacker_id:
			aggro_requested.emit(pl)
			break

@rpc("any_peer", "call_local", "reliable")
func _rpc_notify_aggro(attacker_id: int) -> void:
	if get_parent().is_multiplayer_authority():
		_apply_aggro(attacker_id)
