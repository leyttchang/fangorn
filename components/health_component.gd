class_name HealthComponent
extends Node

# --- SIGNAUX ---
signal health_changed(current_health: float, max_health: float)
signal shield_changed(current_shield: float, max_health: float)
signal shield_damaged(absorbed_amount: float)
signal died
signal damage_taken(amount: float, is_critical: bool)

# --- DEPENDANCES ---
@export var stats_component: StatsComponent

var current_health: float:
	set(value):
		var was_alive: bool = (current_health > 0.0)
		current_health = value
		if was_alive and current_health <= 0.0:
			died.emit()

var current_shield: float = 0.0
var is_intangible: bool = false
var _intangible_count: int = 0
var _known_max_health: float = 100.0
var has_cheat_death: bool = false


func push_intangible() -> void:
	_intangible_count += 1
	is_intangible = true


func pop_intangible() -> void:
	_intangible_count = maxi(0, _intangible_count - 1)
	is_intangible = (_intangible_count > 0)


func _ready() -> void:
	if stats_component == null:
		push_error("HealthComponent sur " + get_parent().name + " : StatsComponent manquant !")
		return

	_known_max_health = stats_component.get_stat_value("max_health")
	current_health = _known_max_health
	stats_component.stat_changed.connect(_on_stat_changed)


func get_max_health() -> float:
	if stats_component != null:
		return stats_component.get_stat_value("max_health")
	return _known_max_health


func set_shield(amount: float) -> void:
	if owner != null and multiplayer.has_multiplayer_peer() and not owner.is_multiplayer_authority():
		rpc_id(owner.get_multiplayer_authority(), "_rpc_set_shield", maxf(0.0, amount))
		return
	_internal_set_shield(maxf(0.0, amount))


func add_shield(amount: float) -> void:
	if amount <= 0.0:
		return
	set_shield(current_shield + amount)


func clear_shield() -> void:
	set_shield(0.0)


func _internal_set_shield(new_shield: float) -> void:
	current_shield = maxf(0.0, new_shield)
	var max_hp: float = get_max_health()
	shield_changed.emit(current_shield, max_hp)
	if multiplayer.has_multiplayer_peer() and (owner == null or owner.is_multiplayer_authority()):
		rpc("_rpc_broadcast_shield", current_shield, max_hp)


func take_damage(raw_damage: float, is_critical: bool = false) -> void:
	if is_intangible:
		return

	if owner != null and multiplayer.has_multiplayer_peer() and not owner.is_multiplayer_authority():
		rpc_id(owner.get_multiplayer_authority(), "_rpc_take_damage", raw_damage, is_critical)
		return
	if current_health <= 0.0:
		return

	var final_damage: float = maxf(0.1, raw_damage)
	var max_hp: float = get_max_health()

	# Absorption par le Bouclier temporaire (ex: Glacial Shell)
	if current_shield > 0.0:
		var absorbed: float = minf(current_shield, final_damage)
		current_shield = maxf(0.0, current_shield - absorbed)
		final_damage = maxf(0.0, final_damage - absorbed)
		shield_damaged.emit(absorbed)
		shield_changed.emit(current_shield, max_hp)
		if multiplayer.has_multiplayer_peer():
			rpc("_rpc_broadcast_shield", current_shield, max_hp)
		if final_damage <= 0.001:
			return

	current_health -= final_damage
	damage_taken.emit(final_damage, is_critical)
	if multiplayer.has_multiplayer_peer():
		rpc("_rpc_broadcast_damage", final_damage, is_critical)

	# --- MECANIQUE CHEAT DEATH (Ignore Death) ---
	if current_health <= 0.0 and has_cheat_death:
		has_cheat_death = false
		current_health = max_hp * 0.25

	current_health = maxf(current_health, 0.0)
	health_changed.emit(current_health, max_hp)

	if current_health == 0.0 and stats_component != null:
		var xp: float = stats_component.get_stat_value("xp_reward")
		if xp > 0.0:
			for p: Node in get_tree().get_nodes_in_group("Player"):
				if p != get_parent():
					var lvl_comp: Node = p.get_node_or_null("lvl_component")
					if lvl_comp != null:
						if multiplayer.has_multiplayer_peer():
							lvl_comp.rpc_id(p.get_multiplayer_authority(), "_rpc_add_xp", int(xp))
						elif lvl_comp.has_method("add_xp"):
							lvl_comp.call("add_xp", int(xp))


func _on_stat_changed(stat_name: String, new_value: float) -> void:
	if stat_name == "max_health":
		if _known_max_health > 0.0:
			var health_percent: float = current_health / _known_max_health
			current_health = new_value * health_percent
		else:
			current_health = new_value

		current_health = minf(current_health, new_value)
		_known_max_health = new_value
		health_changed.emit(current_health, new_value)
		if current_shield > 0.0:
			shield_changed.emit(current_shield, new_value)


func pay_health_cost(amount: float) -> void:
	current_health -= amount
	var max_hp: float = get_max_health()
	if current_health <= 0.0 and has_cheat_death:
		has_cheat_death = false
		current_health = max_hp * 0.25

	current_health = maxf(current_health, 0.0)
	health_changed.emit(current_health, max_hp)


func heal(amount: float) -> void:
	var max_hp: float = get_max_health()
	current_health = minf(current_health + amount, max_hp)
	health_changed.emit(current_health, max_hp)


@rpc("authority", "call_remote", "reliable")
func _rpc_broadcast_damage(final_damage: float, is_critical: bool = false) -> void:
	damage_taken.emit(final_damage, is_critical)


@rpc("authority", "call_remote", "reliable")
func _rpc_broadcast_shield(new_shield: float, max_hp: float) -> void:
	current_shield = new_shield
	shield_changed.emit(current_shield, max_hp)


@rpc("any_peer", "call_local", "reliable")
func _rpc_set_shield(amount: float) -> void:
	if owner == null or owner.is_multiplayer_authority():
		_internal_set_shield(amount)


@rpc("any_peer", "call_local", "reliable")
func _rpc_take_damage(raw_damage: float, is_critical: bool = false) -> void:
	if owner == null or owner.is_multiplayer_authority():
		take_damage(raw_damage, is_critical)
