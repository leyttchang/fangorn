class_name HitboxComponent
extends Area3D

@export var health_component: HealthComponent
@export var knockback_component: KnockbackComponent # NOUVEAU
@export var enable_blood_vfx: bool = true

@export_group("Headshots & Body Parts")
@export var body_part_multiplier: float = 1.0 # 1.0 pour le corps, 2.0 pour la tete, etc.

@export_group("Mitigation (Armure & Resistances)")
@export var armor_curve: Curve = preload("res://components/stats/armor_curve.tres")
@export var max_expected_armor: float = 500.0

signal hit_received(attack: AttackComponent)
signal aggro_requested(attacker: Node3D) # NOUVEAU SIGNAL RESEAU

var _status_comp: StatusEffectComponent = null
var _status_comp_searched: bool = false

func _ready() -> void:
	if health_component == null:
		push_warning("HitboxComponent sur " + get_parent().name + " n'a pas de HealthComponent assign !")

func _get_status_comp() -> StatusEffectComponent:
	if not _status_comp_searched:
		_status_comp_searched = true
		var entity: Node = self.owner if self.owner != null else get_parent()
		if entity != null:
			for child in entity.get_children():
				if child is StatusEffectComponent:
					_status_comp = child
					break
	return _status_comp

# MODIFIÉ : On reçoit l'attaque en entier (AttackComponent) au lieu d'un simple chiffre
func receive_hit(attack: AttackComponent) -> void:
	# Ne rien faire si la cible est un joueur à terre ou intangible (ex: Spark Step)
	var owner_node: Node = get_parent()
	if owner_node != null and owner_node.get("is_dead") == true:
		return
	if health_component != null and health_component.is_intangible:
		return
	
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
		var dmg_magic = attack.damage_magic
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
		
		var total_damage = (dmg_phys + dmg_magic + dmg_fire + dmg_ice + dmg_lightning) * damage_taken_mult
		
		var is_headshot = false
		# Application du multiplicateur de Headshot
		if attack.get("can_headshot") != false:
			total_damage *= body_part_multiplier
			if body_part_multiplier > 1.0:
				is_headshot = true
				
		health_component.take_damage(total_damage, is_headshot)

	# 3. Application des Status Effects
	if "status_effects_to_apply" in attack and attack.status_effects_to_apply.size() > 0:
		var status_comp: StatusEffectComponent = _get_status_comp()
		if status_comp != null:
			for app in attack.status_effects_to_apply:
				if randf() <= app.apply_chance:
					status_comp.apply_effect(app.effect, app.duration)

		
	hit_received.emit(attack)
	
	# 4. On gere l'aggro en reseau
	var attacker_id: int = 0
	var attacker_player: Node3D = null

	var direct_caster = attack.get("caster")
	if direct_caster is Node3D and is_instance_valid(direct_caster) and direct_caster.is_in_group("Player"):
		attacker_player = direct_caster
		attacker_id = direct_caster.get_multiplayer_authority()
	else:
		var p = attack.get_parent()
		while p != null:
			if p.is_in_group("Player"):
				attacker_player = p as Node3D
				attacker_id = p.get_multiplayer_authority()
				break
			var parent_caster = p.get("caster")
			if parent_caster is Node3D and is_instance_valid(parent_caster) and parent_caster.is_in_group("Player"):
				attacker_player = parent_caster
				attacker_id = parent_caster.get_multiplayer_authority()
				break
			p = p.get_parent()
		
	if attacker_id == 0 and attack.has_meta("caster_authority"):
		attacker_id = attack.get_meta("caster_authority")
		
	if attacker_id != 0:
		if get_parent().is_multiplayer_authority():
			_apply_aggro(attacker_id, attacker_player)
		else:
			rpc_id(get_parent().get_multiplayer_authority(), "_rpc_notify_aggro", attacker_id)


func _apply_aggro(attacker_id: int, cached_attacker: Node3D = null) -> void:
	if cached_attacker != null and is_instance_valid(cached_attacker):
		aggro_requested.emit(cached_attacker)
		return
	var players = get_tree().get_nodes_in_group("Player")
	for pl in players:
		if pl.get_multiplayer_authority() == attacker_id:
			aggro_requested.emit(pl)
			break

@rpc("any_peer", "call_local", "reliable")
func _rpc_notify_aggro(attacker_id: int) -> void:
	if get_parent().is_multiplayer_authority():
		_apply_aggro(attacker_id)
