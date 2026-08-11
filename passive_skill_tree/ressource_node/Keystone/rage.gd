extends Node


var player: CharacterBody3D
var stats_comp: StatsComponent
var health_comp: HealthComponent

var modifier_source_id: String = "keystone_rage"

func _ready() -> void:
	# Notre architecture : Joueur -> KeystoneModifiers -> Ce script
	player = get_parent().get_parent() as CharacterBody3D
	if player == null:
		return
		
	# On récupère les composants nécessaires
	stats_comp = player.get_node_or_null("StatsComponent")
	health_comp = player.get_node_or_null("HealthComponent")
	
	if health_comp != null and stats_comp != null:
		# On s'abonne au signal du composant de vie
		health_comp.health_changed.connect(_on_health_changed)
		
		# On applique l'effet une première fois (si on charge une partie où on est déjà blessé)
		var max_hp = stats_comp.get_stat_value("max_health")
		_update_rage_modifiers(health_comp.current_health, max_hp)

func _on_health_changed(current_health: float, max_health: float) -> void:
	_update_rage_modifiers(current_health, max_health)

func _update_rage_modifiers(current_health: float, max_health: float) -> void:
	if max_health <= 0 or stats_comp == null:
		return
		
	# Calcul du pourcentage de vie manquante (ex: 30% de vie manquante = 0.30)
	var missing_ratio = 1.0 - (current_health / max_health)
	missing_ratio = clamp(missing_ratio, 0.0, 1.0)
	
	# On retire les anciens modificateurs de cette keystone
	stats_comp.remove_modifier_by_source(modifier_source_id)
	
	# Si on a perdu de la vie, on ajoute les nouveaux bonus
	if missing_ratio > 0.0:
		# mod_type = 1 correspond à PERCENT (pourcentage) dans ton système de stats
		# La valeur attendue pour 30% est 0.30, ce qui correspond exactement à missing_ratio !
		stats_comp.add_modifier("attack_speed", 1, missing_ratio, modifier_source_id)
		stats_comp.add_modifier("knockback_power", 1, missing_ratio, modifier_source_id)
