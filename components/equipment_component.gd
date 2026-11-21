class_name EquipmentComponent
extends Node

# Signal pour dire à l'UI et au système de combat que l'équipement a changé
signal equipment_changed(slot_name: String, item: ItemData)

# On a besoin d'accéder au sac à dos et aux stats du joueur
@export var inventory_component: InventoryComponent
@export var stats_component: StatsComponent

# Les emplacements disponibles sur ton personnage
var equipped_items: Dictionary = {
	"head": null,
	"chest": null,
	"legs": null,
	"feet": null,
	"hands": null,
	"main_hand": null,
	"second_weapon": null,
	"ring_1": null,
	"ring_2": null
}

var _equip_net_ready: bool = false

func _ready() -> void:
	call_deferred("_init_equipment_network_sync")

func _init_equipment_network_sync() -> void:
	if not is_inside_tree():
		return
	var p: Node = get_parent()
	if p == null or not p.is_in_group("Player"):
		return
	if multiplayer != null and multiplayer.has_multiplayer_peer() and p.is_multiplayer_authority():
		if not multiplayer.peer_connected.is_connected(_on_peer_connected_equip_sync):
			multiplayer.peer_connected.connect(_on_peer_connected_equip_sync)
	if get_tree() != null:
		await get_tree().process_frame
		await get_tree().process_frame
	if not is_inside_tree():
		return
	_equip_net_ready = true
	if _can_send_equip_sync():
		_rpc_sync_all_remote_slots.rpc(_pack_all_slots())

func _can_send_equip_sync() -> bool:
	if not _equip_net_ready or not is_inside_tree() or inventory_component == null:
		return false
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return false
	var p: Node = get_parent()
	return p != null and p.is_in_group("Player") and p.is_multiplayer_authority()

func _on_peer_connected_equip_sync(peer_id: int) -> void:
	if _can_send_equip_sync():
		_rpc_sync_all_remote_slots.rpc_id(peer_id, _pack_all_slots())

func _pack_all_slots() -> Dictionary:
	var out: Dictionary = {}
	if inventory_component == null:
		return out
	for s_key: Variant in equipped_items.keys():
		var slot_str: String = str(s_key)
		var it: ItemData = equipped_items[slot_str] as ItemData
		out[slot_str] = inventory_component.pack_item(it) if it != null else {}
	return out

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_remote_slot(slot_name: String, item_dict: Dictionary) -> void:
	if not equipped_items.has(slot_name) or inventory_component == null:
		return
	var unpacked: ItemData = null
	if not item_dict.is_empty():
		unpacked = inventory_component.unpack_item(item_dict)
	equipped_items[slot_name] = unpacked
	equipment_changed.emit(slot_name, unpacked)

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_all_remote_slots(all_dict: Dictionary) -> void:
	if inventory_component == null:
		return
	for s_key: Variant in all_dict.keys():
		var slot_str: String = str(s_key)
		if not equipped_items.has(slot_str):
			continue
		var sub_dict: Variant = all_dict[slot_str]
		var unpacked: ItemData = null
		if sub_dict is Dictionary and not (sub_dict as Dictionary).is_empty():
			unpacked = inventory_component.unpack_item(sub_dict as Dictionary)
		equipped_items[slot_str] = unpacked
		equipment_changed.emit(slot_str, unpacked)

# --- ÉQUIPER UN OBJET ---
func equip_item(item: ItemData, slot_name: String) -> bool:
	if not equipped_items.has(slot_name):
		push_warning("Ce slot d'équipement n'existe pas : " + slot_name)
		return false

	# 1. Si on a déjà un objet équipé ici, on l'enlève et on le remet dans le sac
	if equipped_items[slot_name] != null:
		var success = unequip_item(slot_name)
		# Si l'inventaire est plein, on annule l'action !
		if not success:
			return false

	# 2. On place le nouvel objet dans le slot
	equipped_items[slot_name] = item

	# 3. On applique les bonus de l'objet sur le joueur
	# Sauf si c'est la 2ème arme (arme de réserve)
	if slot_name != "second_weapon":
		_apply_item_stats(item)

	# 4. On prévient le reste du jeu
	equipment_changed.emit(slot_name, item)
	if _can_send_equip_sync():
		_rpc_sync_remote_slot.rpc(slot_name, inventory_component.pack_item(item) if item != null else {})
	return true

# --- DÉSÉQUIPER UN OBJET ---
func unequip_item(slot_name: String) -> bool:
	if not equipped_items.has(slot_name) or equipped_items[slot_name] == null:
		return true # Rien à déséquiper, donc c'est "réussi"

	var item_to_remove = equipped_items[slot_name]

	# 1. On essaie de remettre l'objet dans l'inventaire
	if inventory_component != null:
		var leftover = inventory_component.add_item(item_to_remove, 1)
		if leftover > 0:
			print("Inventaire plein ! Impossible de retirer l'équipement.")
			return false

	# 2. On retire les bonus de cet objet du StatsComponent
	# Sauf si c'est la 2ème arme (elle ne donnait pas de stats)
	if slot_name != "second_weapon":
		_remove_item_stats(item_to_remove)

	# 3. On vide le slot
	equipped_items[slot_name] = null
	equipment_changed.emit(slot_name, null)
	if _can_send_equip_sync():
		_rpc_sync_remote_slot.rpc(slot_name, {})
	
	return true

# --- INTERVERTIR LES DEUX ARMES ---
func swap_weapons() -> void:
	var w1 = equipped_items["main_hand"]
	var w2 = equipped_items["second_weapon"]
	
	# 1. Retrait des stats de l'arme actuelle
	if w1 != null:
		_remove_item_stats(w1)
		
	# 2. Echange dans les données
	equipped_items["main_hand"] = w2
	equipped_items["second_weapon"] = w1
	
	# 3. Application des stats de la nouvelle arme principale
	if w2 != null:
		_apply_item_stats(w2)
		
	# 4. Rafraîchissement de l'interface
	equipment_changed.emit("main_hand", w2)
	equipment_changed.emit("second_weapon", w1)
	if _can_send_equip_sync():
		_rpc_sync_remote_slot.rpc("main_hand", inventory_component.pack_item(w2) if w2 != null else {})
		_rpc_sync_remote_slot.rpc("second_weapon", inventory_component.pack_item(w1) if w1 != null else {})

# --- GESTION DES STATS (Le pont avec ton StatsComponent) ---
func _apply_item_stats(item: ItemData) -> void:
	if stats_component == null:
		return
		
	if item is EquipmentItem:
		print("Application des stats pour : ", item.item_name)
		
		for stat_name in item.stat_bonuses.keys():
			var bonus_value = item.stat_bonuses[stat_name]
			
			if bonus_value != 0.0:
				stats_component.add_modifier(stat_name, 0, bonus_value, item.id)
				
		# --- GESTION DES OBJETS UNIQUES ---
		var effect_script = item.get("unique_effect_script")
		if effect_script != null and effect_script is GDScript:
			_apply_unique_effect(effect_script, item.id)

func _remove_item_stats(item: ItemData) -> void:
	if stats_component == null:
		return
		
	if item is EquipmentItem:
		print("Retrait des stats pour : ", item.item_name)
		# On retire tous les bonus qui ont pour source l'ID de cette arme
		stats_component.remove_modifier_by_source(item.id)
		
		# --- GESTION DES OBJETS UNIQUES ---
		var effect_script = item.get("unique_effect_script")
		if effect_script != null and effect_script is GDScript:
			_remove_unique_effect(item.id)

func _apply_unique_effect(script: GDScript, item_id: String) -> void:
	if script != null:
		var effect_node = Node.new()
		effect_node.set_script(script)
		effect_node.name = "Unique_" + item_id
		
		var player = get_parent()
		var container = player.get_node_or_null("UniqueItemModifiers")
		if container == null:
			container = Node.new()
			container.name = "UniqueItemModifiers"
			player.add_child(container)
			
		container.add_child(effect_node)
		print("Effet Unique activé (Script) pour l'item : ", item_id)

func _remove_unique_effect(item_id: String) -> void:
	var player = get_parent()
	var container = player.get_node_or_null("UniqueItemModifiers")
	if container != null:
		var effect_node = container.get_node_or_null("Unique_" + item_id)
		if effect_node != null:
			effect_node.queue_free()
			print("Effet Unique retiré : ", item_id)
