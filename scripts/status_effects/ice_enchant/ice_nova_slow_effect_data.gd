class_name IceNovaSlowEffectData
extends StatusEffectData

## Effet de ralentissement cumulable appliqué au joueur par les petites Ice Novas des monstres de Glace :
## - Chaque nova touchant le joueur ajoute 1 stack de slow (s'additionne jusqu'à `max_stacks` / `max_slow_percent`)
## - Rafraîchit la durée du slow à chaque nouvelle nova reçue
## - Garantit un plancher de vitesse (`min_movement_speed_ratio`) pour ne jamais inverser ou bloquer totalement les déplacements

const META_STACKS_KEY := &"ice_nova_slow_stacks"

@export_group("Ralentissement Cumulable (Stacks)")
## Ralentissement ajouté à chaque nova encaissée (0.12 = -12% de vitesse de déplacement par stack)
@export_range(0.01, 0.50, 0.01) var slow_per_stack: float = 0.12
## Nombre maximal de stacks cumulables
@export_range(1, 20, 1) var max_stacks: int = 6
## Plafond maximal du ralentissement total provenant de cet effet (0.72 = -72% max)
@export_range(0.10, 0.90, 0.01) var max_slow_percent: float = 0.72
## Vitesse minimale garantie sur la stat movement_speed (évite toute vitesse nulle ou négative)
@export_range(0.05, 0.50, 0.01) var min_movement_speed_ratio: float = 0.15

func on_apply(target: Node, component: Node, is_refresh: bool) -> void:
	if component == null:
		return

	var prev_stacks: int = int(component.get_meta(META_STACKS_KEY, 0)) if is_refresh else 0
	var new_stacks: int = mini(prev_stacks + 1, maxi(1, max_stacks))
	component.set_meta(META_STACKS_KEY, new_stacks)

	_apply_stack_modifier(target, component, new_stacks)
	_notify_visual_stacks(component, new_stacks, is_refresh)

func on_process(target: Node, component: Node, _delta: float, _time_remaining: float, _total_duration: float) -> void:
	if target == null or component == null:
		return

	# Si le joueur tombe à terre / meurt, on purge immédiatement le slow côté autorité
	if target.get("is_dead") == true or (target.has_method("is_dead") and target.is_dead()):
		if not component.multiplayer.has_multiplayer_peer() or component.is_multiplayer_authority():
			component.call_deferred("remove_effect", effect_id)
		return

	var stacks: int = int(component.get_meta(META_STACKS_KEY, 1))
	_apply_stack_modifier(target, component, stacks)

func on_remove(target: Node, component: Node) -> void:
	if component != null and component.has_meta(META_STACKS_KEY):
		component.remove_meta(META_STACKS_KEY)

	var stats := _get_stats_component(target, component)
	if stats != null:
		stats.remove_modifier_by_source("STATUS_" + effect_id)

func get_current_stacks(component: Node) -> int:
	if component == null or not component.has_meta(META_STACKS_KEY):
		return 0
	return int(component.get_meta(META_STACKS_KEY, 0))

func _apply_stack_modifier(target: Node, component: Node, stacks: int) -> void:
	var stats := _get_stats_component(target, component)
	if stats == null:
		return

	var source_id := "STATUS_" + effect_id
	var desired_slow := minf(float(maxi(1, stacks)) * slow_per_stack, max_slow_percent)
	var effective_slow := _compute_safe_slow_percent(stats, desired_slow, source_id)
	stats.set_or_update_modifier("movement_speed", StatModifier.Type.PERCENT, -effective_slow, source_id)

func _compute_safe_slow_percent(stats: StatsComponent, desired_slow: float, source_id: String) -> float:
	var stat := stats.get_stat("movement_speed")
	if stat == null:
		return desired_slow

	var flat_total: float = stat.base_value
	var other_percent: float = 0.0
	for mod in stat.modifiers:
		if mod.id == source_id:
			continue
		if mod.type == StatModifier.Type.FLAT:
			flat_total += mod.value
		elif mod.type == StatModifier.Type.PERCENT:
			other_percent += mod.value

	if flat_total <= 0.001:
		return 0.0

	var max_allowed_slow := maxf(0.0, 1.0 + other_percent - (min_movement_speed_ratio / flat_total))
	return clampf(desired_slow, 0.0, max_allowed_slow)

func _notify_visual_stacks(component: Node, stacks: int, pulse_flash: bool) -> void:
	if not ("_active_effects" in component):
		return
	var eff = component._active_effects.get(effect_id)
	if eff != null and is_instance_valid(eff.visual_instance):
		if eff.visual_instance.has_method("set_slow_stacks"):
			eff.visual_instance.set_slow_stacks(stacks, maxi(1, max_stacks), pulse_flash)

func _get_stats_component(target: Node, component: Node) -> StatsComponent:
	if component != null and "stats_component" in component and component.stats_component is StatsComponent:
		return component.stats_component
	if target != null:
		var s := target.get_node_or_null("StatsComponent")
		if s is StatsComponent:
			return s
	return null
