class_name HitboxComponent
extends Area3D

@export var health_component: HealthComponent
@export var knockback_component: KnockbackComponent # NOUVEAU

@export_group("Mitigation (Armure & Resistances)")
@export var armor_curve: Curve = preload("res://components/stats/armor_curve.tres")
@export var max_expected_armor: float = 500.0

signal hit_received(attack: AttackComponent)
signal aggro_requested(attacker: Node3D) # NOUVEAU SIGNAL RESEAU

func _ready() -> void:
	if health_component == null:
		push_warning("HitboxComponent sur " + get_parent().name + " n'a pas de HealthComponent assign !")

# MODIFI : On reoit l'attaque en entier (AttackComponent) au lieu d'un simple chiffre
func receive_hit(attack: AttackComponent) -> void:
	# 1. Calculs de reduction d'Armure et Resistances
	if health_component != null:
		var dmg_phys = attack.damage_physical
		var dmg_fire = attack.damage_fire
		var dmg_ice = attack.damage_ice
		var dmg_lightning = attack.damage_lightning
		
		if health_component.stats_component != null:
			var stats = health_component.stats_component
			
			# --- ARMURE (Sur le Physique Uniquement) ---
			var armor = max(stats.get_stat_value("armor"), 0.0)
			var armor_reduction = 0.0
			if armor_curve != null:
				var armor_x = min(armor / max_expected_armor, 1.0)
				armor_reduction = armor_curve.sample(armor_x)
			dmg_phys *= (1.0 - armor_reduction)
			
			# --- RESISTANCES ELEMENTAIRES (Capees a 75%) ---
			var res_fire = min(stats.get_stat_value("fire_resistance"), 0.75)
			var res_ice = min(stats.get_stat_value("ice_resistance"), 0.75)
			var res_lightning = min(stats.get_stat_value("lightning_resistance"), 0.75)
			
			dmg_fire *= (1.0 - max(0.0, res_fire))
			dmg_ice *= (1.0 - max(0.0, res_ice))
			dmg_lightning *= (1.0 - max(0.0, res_lightning))
		
		var total_damage = dmg_phys + dmg_fire + dmg_ice + dmg_lightning
		health_component.take_damage(total_damage)
		
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
			# Si c'est une pe, on garde l'ancien calcul bas sur les positions
			push_dir = global_position - attack.global_position
			
		# 1. On l'aplatit pour avoir une direction horizontale pure
		push_dir.y = 0
		if push_dir.length_squared() > 0.001:
			push_dir = push_dir.normalized()
		else:
			push_dir = Vector3.FORWARD
			
		# 2. On applique le fameux angle d'lvation
		var angle_rad = deg_to_rad(attack.knockback_angle)
		push_dir = push_dir * cos(angle_rad)
		push_dir.y = sin(angle_rad)
			
		# On envoie directement la direction calcule au composant de recul
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
