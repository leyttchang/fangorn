class_name Weapon
extends Node3D

@export var weapon_stats: WeaponItem
@onready var attack_component: AttackComponent = $AttackComponent

func _ready() -> void:
	if weapon_stats != null:
		attack_component.damage = weapon_stats.base_damage
	else:
		push_warning(name + " n'a pas de WeaponItem (.tres) assigné !")

func update_damage_from_stats(player_stats: Node) -> void:
	if weapon_stats != null and player_stats != null:
		var phys_multiplier = player_stats.get_stat_value("physical_damage")
		attack_component.damage = weapon_stats.base_damage * phys_multiplier

# --- NOUVELLE FONCTION ---
# Calcule la vitesse d'attaque totale (Arme * Joueur)
func get_combined_attack_speed(player_stats: Node) -> float:
	if weapon_stats == null or player_stats == null:
		return 1.0
		
	var player_speed = player_stats.get_stat_value("attack_speed")
	var weapon_speed = weapon_stats.base_attack_speed
	
	# On multiplie les deux et on garde notre sécurité pour éviter la division par zéro !
	return max(player_speed * weapon_speed, 0.1)
