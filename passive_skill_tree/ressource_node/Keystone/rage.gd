extends Node

var player: CharacterBody3D
var stats_comp: StatsComponent
var health_comp: HealthComponent

var modifier_source_id: String = "keystone_rage"
var _has_active_bonus: bool = false

func _ready() -> void:
	# Notre architecture : Joueur -> KeystoneModifiers -> Ce script
	player = get_parent().get_parent() as CharacterBody3D
	if player == null:
		return

	# On récupère les composants nécessaires
	stats_comp = player.get_node_or_null("%StatsComponent") as StatsComponent
	if stats_comp == null:
		stats_comp = player.get_node_or_null("StatsComponent") as StatsComponent

	health_comp = player.get_node_or_null("%HealthComponent") as HealthComponent
	if health_comp == null:
		health_comp = player.get_node_or_null("HealthComponent") as HealthComponent

	if health_comp != null and stats_comp != null:
		# On s'abonne au signal du composant de vie
		health_comp.health_changed.connect(_on_health_changed)

		# On applique l'effet une première fois (si on charge une partie où on est déjà blessé)
		var max_hp: float = stats_comp.get_stat_value("max_health")
		_update_rage_modifiers(health_comp.current_health, max_hp)

func _on_health_changed(current_health: float, max_health: float) -> void:
	_update_rage_modifiers(current_health, max_health)

func _update_rage_modifiers(current_health: float, max_health: float) -> void:
	if max_health <= 0.0 or stats_comp == null:
		return

	# Calcul du pourcentage de vie manquante (ex: 30% de vie manquante = 0.30)
	var missing_ratio: float = 1.0 - (current_health / max_health)
	missing_ratio = clampf(missing_ratio, 0.0, 1.0)

	# Si on a perdu de la vie, on crée ou met à jour les bonus en place
	if missing_ratio > 0.0001:
		_has_active_bonus = true
		stats_comp.set_or_update_modifier("attack_speed", StatModifier.Type.PERCENT, missing_ratio, modifier_source_id)
		stats_comp.set_or_update_modifier("knockback_power", StatModifier.Type.PERCENT, missing_ratio, modifier_source_id)
	elif _has_active_bonus:
		_has_active_bonus = false
		stats_comp.remove_modifier_by_source(modifier_source_id)

func _exit_tree() -> void:
	if health_comp != null and health_comp.health_changed.is_connected(_on_health_changed):
		health_comp.health_changed.disconnect(_on_health_changed)

	if stats_comp != null and _has_active_bonus:
		_has_active_bonus = false
		stats_comp.remove_modifier_by_source(modifier_source_id)
