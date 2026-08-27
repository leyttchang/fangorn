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
	# 1. On calcule et applique d'abord le recul (pour que l'impulsion de mort puisse le recuperer)
	if knockback_component != null:
		var push_dir: Vector3
		if attack.is_projectile:
			push_dir = -attack.global_transform.basis.z
		else:
			push_dir = global_position - attack.global_position
			
		push_dir.y = 0
		if push_dir.length_squared() > 0.001:
			push_dir = push_dir.normalized()
		else:
			push_dir = Vector3.FORWARD
			
		var angle_rad = deg_to_rad(attack.knockback_angle)
		push_dir = push_dir * cos(angle_rad)
		push_dir.y = sin(angle_rad)
			
		knockback_component.apply_knockback(push_dir, attack.knockback_force)

	# 2. Calculs de reduction d'Armure et Resistances
	if health_component != null:
		var dmg_phys = attack.damage_physical
		var dmg_fire = attack.damage_fire
		var dmg_ice = attack.damage_ice
		var dmg_lightning = attack.damage_lightning
		
		var damage_taken_mult = 1.0
		
		if health_component.stats_component != null:
			var stats = health_component.stats_component
			damage_taken_mult = max(0.0, 1.0 + stats.get_stat_value("damage_taken_multiplier"))
			
			var armor = max(stats.get_stat_value("armor"), 0.0)
			var armor_reduction = 0.0
			if armor_curve != null:
				var armor_x = armor / 100.0
				armor_reduction = armor_curve.sample(armor_x)
			dmg_phys *= (1.0 - armor_reduction)
			
			var res_fire = min(stats.get_stat_value("fire_resistance"), 0.75)
			var res_ice = min(stats.get_stat_value("ice_resistance"), 0.75)
			var res_lightning = min(stats.get_stat_value("lightning_resistance"), 0.75)
			
			dmg_fire *= (1.0 - max(0.0, res_fire))
			dmg_ice *= (1.0 - max(0.0, res_ice))
			dmg_lightning *= (1.0 - max(0.0, res_lightning))
		
		var total_damage = (dmg_phys + dmg_fire + dmg_ice + dmg_lightning) * damage_taken_mult
		health_component.take_damage(total_damage)

	# 3. Application des Status Effects
	if "status_effects_to_apply" in attack and attack.status_effects_to_apply.size() > 0:
		var status_comp = null
		for child in get_parent().get_children():
			if child is StatusEffectComponent:
				status_comp = child
				break
		
		if status_comp != null and status_comp.has_method("apply_effect"):
			for app in attack.status_effects_to_apply:
				if randf() <= app.apply_chance:
					status_comp.apply_effect(app.effect, app.duration)

		
	hit_received.emit(attack)
	
	# 4. On gere l'aggro en reseau
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
