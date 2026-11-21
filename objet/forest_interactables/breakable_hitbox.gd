class_name BreakableHitbox
extends HitboxComponent

## Hitbox légère dédiée aux éléments destructibles du décor (champignons, cocons de racines...).
## Hérite de HitboxComponent pour être détectée nativement par toutes les armes et sorts du joueur
## (layer 8 / mask 4), sans nécessiter de HealthComponent ni déclencher de gerbe de sang.

signal breakable_struck(attacker: Node3D, hit_dir: Vector3, attack: AttackComponent)

var _is_broken: bool = false

func _ready() -> void:
	# Pas d'avertissement si health_component est volontairement laissé vide
	collision_layer = 8
	collision_mask = 4

func receive_hit(attack: AttackComponent) -> void:
	if _is_broken:
		return
	_is_broken = true

	# Désactivation immédiate pour éviter tout second coup ou raycast de sang (WeaponImpactComponent)
	collision_layer = 0
	collision_mask = 0
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	# 1. Calcul de la direction d'impact
	var push_dir := Vector3.FORWARD
	if attack != null:
		if attack.is_projectile:
			push_dir = -attack.global_transform.basis.z
		else:
			var origin := attack.global_position
			if attack.caster != null and is_instance_valid(attack.caster):
				origin = attack.caster.global_position
			push_dir = global_position - origin
		push_dir.y = 0.0
		if push_dir.length_squared() > 0.001:
			push_dir = push_dir.normalized()
		else:
			push_dir = Vector3.FORWARD

	# 2. Résolution du joueur attaquant (épée ou sort)
	var attacker_player: Node3D = _resolve_attacker_player(attack)

	hit_received.emit(attack)
	breakable_struck.emit(attacker_player, push_dir, attack)

func _resolve_attacker_player(attack: AttackComponent) -> Node3D:
	if attack == null:
		return null

	if attack.caster != null and is_instance_valid(attack.caster) and attack.caster.is_in_group("Player"):
		return attack.caster

	var p: Node = attack.get_parent()
	while p != null:
		if p is Node3D and p.is_in_group("Player"):
			return p as Node3D
		p = p.get_parent()

	if attack.has_meta("caster_authority") and is_inside_tree():
		var auth_id: int = int(attack.get_meta("caster_authority"))
		for pl in get_tree().get_nodes_in_group("Player"):
			if pl is Node3D and is_instance_valid(pl) and pl.get_multiplayer_authority() == auth_id:
				return pl as Node3D

	return null
