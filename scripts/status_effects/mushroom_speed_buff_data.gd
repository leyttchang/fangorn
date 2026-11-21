class_name MushroomSpeedBuffData
extends StatusEffectData

## Buff de vitesse des Champignons de Forêt :
## - Accorde un bonus fixe de movement_speed (par défaut +30%) pendant sa durée (5s)
## - Se rafraîchit proprement sans empiler la vitesse à l'infini quand on casse plusieurs champignons

@export var speed_bonus_percent: float = 0.30

func on_apply(target: Node, component: Node, _is_refresh: bool) -> void:
	var stats = _get_stats_component(target, component)
	if stats != null:
		stats.set_or_update_modifier("movement_speed", StatModifier.Type.PERCENT, speed_bonus_percent, "STATUS_" + effect_id)

func on_remove(target: Node, component: Node) -> void:
	var stats = _get_stats_component(target, component)
	if stats != null:
		stats.remove_modifier_by_source("STATUS_" + effect_id)

func _get_stats_component(target: Node, component: Node) -> StatsComponent:
	if component != null and "stats_component" in component and component.stats_component is StatsComponent:
		return component.stats_component
	if target != null:
		var s = target.get_node_or_null("StatsComponent")
		if s is StatsComponent:
			return s
	return null
