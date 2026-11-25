class_name StatsComponent
extends Node

# On demande  Godot de nous afficher une case pour glisser notre fichier .tres
@export var starting_stats: EntityStats 

# Le dictionnaire qui va contenir nos objets Stat
var _stats: Dictionary = {}
var _net_sync_ready: bool = false
var _applying_remote_sync: bool = false
signal stat_changed(stat_name: String, new_value: float)
func _ready():
	# 1. Scurit : On vrifie qu'on a bien assign un fichier de stats
	if starting_stats == null:
		push_error("StatsComponent sur " + get_parent().name + " : Pas de starting_stats assign !")
		return
		
	# 2. On initialise le dictionnaire avec des objets Stat.new()
	_stats["max_health"] = Stat.new(starting_stats.max_health)
	_stats["max_mana"] = Stat.new(starting_stats.max_mana)
	_stats["mana_regen"] = Stat.new(starting_stats.mana_regen)
	_stats["armor"] = Stat.new(starting_stats.armor)
	_stats["flat_physical_damage"] = Stat.new(starting_stats.flat_physical_damage)
	_stats["flat_fire_damage"] = Stat.new(starting_stats.flat_fire_damage)
	_stats["flat_ice_damage"] = Stat.new(starting_stats.flat_ice_damage)
	_stats["flat_lightning_damage"] = Stat.new(starting_stats.flat_lightning_damage)
	_stats["physical_damage"] = Stat.new(starting_stats.physical_damage)
	_stats["magic_damage"] = Stat.new(starting_stats.magic_damage)
	_stats["fire_damage"] = Stat.new(starting_stats.fire_damage)
	_stats["ice_damage"] = Stat.new(starting_stats.ice_damage)
	_stats["lightning_damage"] = Stat.new(starting_stats.lightning_damage)
	_stats["attack_speed"] = Stat.new(starting_stats.attack_speed)
	_stats["cd_red"] = Stat.new(starting_stats.cd_red)
	_stats["area_of_effect"] = Stat.new(starting_stats.area_of_effect)
	_stats["movement_speed"] = Stat.new(starting_stats.movement_speed)
	_stats["knockback_power"] = Stat.new(starting_stats.knockback_power)
	_stats["knockback_resistance"] = Stat.new(starting_stats.knockback_resistance)
	_stats["casting_speed"] = Stat.new(starting_stats.casting_speed)
	_stats["xp_reward"] = Stat.new(starting_stats.xp_reward)
	_stats["fire_resistance"] = Stat.new(starting_stats.fire_resistance)
	_stats["ice_resistance"] = Stat.new(starting_stats.ice_resistance)
	_stats["lightning_resistance"] = Stat.new(starting_stats.lightning_resistance)
	_stats["action_speed"] = Stat.new(starting_stats.action_speed)
	_stats["damage_taken_multiplier"] = Stat.new(starting_stats.damage_taken_multiplier)
	call_deferred("_init_player_network_sync")

func _is_player_entity() -> bool:
	var p: Node = get_parent()
	return p != null and p.is_in_group("Player")

static func _should_sync_source(source_id: String) -> bool:
	if source_id == "road_buff" or source_id.begins_with("STATUS_"):
		return false
	return true

func _can_send_player_sync() -> bool:
	if _applying_remote_sync or not _net_sync_ready or not is_inside_tree():
		return false
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return false
	var p: Node = get_parent()
	return p != null and p.is_in_group("Player") and p.is_multiplayer_authority()

func _init_player_network_sync() -> void:
	if not is_inside_tree() or not _is_player_entity():
		return
	if multiplayer != null and multiplayer.has_multiplayer_peer() and get_parent().is_multiplayer_authority():
		if not multiplayer.peer_connected.is_connected(_on_peer_connected_stats_sync):
			multiplayer.peer_connected.connect(_on_peer_connected_stats_sync)
	if get_tree() != null:
		await get_tree().process_frame
		await get_tree().process_frame
	if not is_inside_tree():
		return
	_net_sync_ready = true
	if _can_send_player_sync():
		_rpc_apply_modifiers_snapshot.rpc(_pack_synced_modifiers())

func _on_peer_connected_stats_sync(peer_id: int) -> void:
	if _can_send_player_sync():
		_rpc_apply_modifiers_snapshot.rpc_id(peer_id, _pack_synced_modifiers())

func _pack_synced_modifiers() -> Array:
	var packed: Array = []
	for s_name: Variant in _stats.keys():
		var stat_key: String = str(s_name)
		var st: Stat = _stats[stat_key] as Stat
		if st == null:
			continue
		for mod: StatModifier in st.modifiers:
			if mod != null and _should_sync_source(mod.id):
				packed.append([stat_key, int(mod.type), float(mod.value), mod.id])
	return packed

@rpc("authority", "call_remote", "reliable")
func _rpc_apply_modifiers_snapshot(packed: Array) -> void:
	_applying_remote_sync = true
	var to_clear: Dictionary = {}
	for s_name: Variant in _stats.keys():
		var st: Stat = _stats[s_name] as Stat
		if st == null:
			continue
		for mod: StatModifier in st.modifiers:
			if mod != null and _should_sync_source(mod.id):
				to_clear[mod.id] = true
	for src_key: Variant in to_clear.keys():
		remove_modifier_by_source(str(src_key))
	for entry: Variant in packed:
		if entry is Array and (entry as Array).size() >= 4:
			var arr: Array = entry as Array
			add_modifier(str(arr[0]), int(arr[1]), float(arr[2]), str(arr[3]))
	_applying_remote_sync = false

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_add_modifier(stat_name: String, mod_type: int, value: float, source_id: String) -> void:
	_applying_remote_sync = true
	add_modifier(stat_name, mod_type, value, source_id)
	_applying_remote_sync = false

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_remove_modifier(source_id: String) -> void:
	_applying_remote_sync = true
	remove_modifier_by_source(source_id)
	_applying_remote_sync = false

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_set_or_update_modifier(stat_name: String, mod_type: int, value: float, source_id: String) -> void:
	_applying_remote_sync = true
	set_or_update_modifier(stat_name, mod_type, value, source_id)
	_applying_remote_sync = false
# Fonction pour rcuprer rapidement la valeur finale (ex: pour taper un ennemi)
func get_stat_value(stat_name: String) -> float:
	var s: Stat = _stats.get(stat_name)
	if s != null:
		return s.get_value()
	
	push_warning("La stat demande n'existe pas : " + stat_name)
	return 0.0

# Fonction pour rcuprer l'objet Stat complet (ex: pour lui ajouter un buff)
func get_stat(stat_name: String) -> Stat:
	return _stats.get(stat_name)

# --- NOUVELLES FONCTIONS : LE PONT DES MODIFICATEURS ---
func add_modifier(stat_name: String, mod_type: int, value: float, source_id: String) -> void:
	var stat: Stat = _stats.get(stat_name)
	if stat != null:
		var new_modifier := StatModifier.new(source_id, value, mod_type)
		stat.add_modifier(new_modifier)
		
		# NOUVEAU : On prvient le reste du jeu de la nouvelle valeur !
		stat_changed.emit(stat_name, stat.get_value())
		if _should_sync_source(source_id) and _can_send_player_sync():
			_rpc_sync_add_modifier.rpc(stat_name, mod_type, value, source_id)

func remove_modifier_by_source(source_id: String) -> void:
	var any_removed: bool = false
	for stat_name in _stats:
		var stat: Stat = _stats[stat_name]
		if stat == null or not stat.has_modifier(source_id):
			continue
		var old_value: float = stat.get_value()
		if stat.remove_modifier(source_id):
			any_removed = true
			var new_value: float = stat.get_value()
			if not is_equal_approx(new_value, old_value):
				stat_changed.emit(stat_name, new_value)
	if any_removed and _should_sync_source(source_id) and _can_send_player_sync():
		_rpc_sync_remove_modifier.rpc(source_id)

## Récupère la valeur d'une stat en ignorant un modificateur spécifique
func get_stat_value_excluding(stat_name: String, excluded_source_id: String) -> float:
	var stat: Stat = _stats.get(stat_name)
	if stat != null:
		return stat.get_value_excluding(excluded_source_id)
	return 0.0

## Met à jour la valeur d'un modificateur existant ou l'ajoute s'il n'existe pas
func set_or_update_modifier(stat_name: String, mod_type: int, value: float, source_id: String) -> void:
	var stat: Stat = _stats.get(stat_name)
	if stat != null:
		for mod in stat.modifiers:
			if mod.id == source_id:
				if is_equal_approx(mod.value, value) and mod.type == mod_type:
					return
				var old_val: float = stat.get_value()
				mod.value = value
				mod.type = mod_type
				stat.mark_dirty()
				var new_val: float = stat.get_value()
				if not is_equal_approx(old_val, new_val):
					stat_changed.emit(stat_name, new_val)
					if _should_sync_source(source_id) and _can_send_player_sync():
						_rpc_sync_set_or_update_modifier.rpc(stat_name, mod_type, value, source_id)
				return
		add_modifier(stat_name, mod_type, value, source_id)
