class_name AmbushSpeedBuffData
extends StatusEffectData

## Buff de vitesse d'embuscade :
## - Démarre à +80% (0.80)
## - Décroît linéairement jusqu'à +50% (0.50) pendant les 5 premières secondes
## - Reste stable à +50% (0.50) pendant les 5 secondes suivantes
## - Disparaît au bout de 10 secondes au total

func on_apply(target: Node, component: Node, _is_refresh: bool) -> void:
	var stats = _get_stats_component(target, component)
	if stats != null:
		stats.set_or_update_modifier("movement_speed", StatModifier.Type.PERCENT, 0.80, "STATUS_" + effect_id)

func on_process(target: Node, component: Node, _delta: float, time_remaining: float, total_duration: float) -> void:
	var stats = _get_stats_component(target, component)
	if stats == null:
		return
		
	var elapsed = max(0.0, total_duration - time_remaining)
	var current_boost: float
	if elapsed <= 5.0:
		var t = clampf(elapsed / 5.0, 0.0, 1.0)
		current_boost = lerpf(0.80, 0.50, t)
	else:
		current_boost = 0.50
		
	stats.set_or_update_modifier("movement_speed", StatModifier.Type.PERCENT, current_boost, "STATUS_" + effect_id)

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
