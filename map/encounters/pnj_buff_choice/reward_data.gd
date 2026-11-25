class_name RewardData
extends Resource

enum RewardType {
	SKILL_POINTS,
	RANDOM_SPELL,
	RANDOM_EQUIPMENT,
	UPGRADE_WEAPON_ILVL,
	UPGRADE_ITEM_RARITY,
	HEAL_PERCENT
}

@export_category("Identité de la Récompense")
## Identifiant unique de la récompense
@export var id: String = "reward_id"
## Titre affiché sur la carte dans l'interface
@export var title: String = "Reward Title"
## Description détaillée des effets du bonus
@export_multiline var description: String = "Detailed reward description."
## Icône optionnelle de la carte
@export var icon: Texture2D
## Couleur d'accentuation du titre et des bordures
@export var card_color: Color = Color(1.0, 1.0, 1.0)
## Texte du bouton d'action
@export var button_text: String = "Choose"
## Poids de tirage aléatoire parmi le pool
@export var weight: float = 1.0

@export_category("Mécanique & Type")
## Catégorie de mécanique de la récompense
@export var reward_type: RewardType = RewardType.SKILL_POINTS

@export_group("Paramètres : Points de Talent")
## Nombre de points de compétence accordés
@export var skill_points_amount: int = 2

@export_group("Paramètres : Soin")
## Pourcentage des points de vie maximum soignés (ex: 0.25 = 25%)
@export_range(0.01, 1.0, 0.01) var heal_percent: float = 0.25

@export_group("Paramètres : Équipement Aléatoire")
## -2 pour équipement hors armes, -1 pour n'importe quel type, ou ItemData.ItemType (0: main_hand, 1: chest, 2: legs, 3: feet, 4: head, 5: hands)
@export var target_item_type: int = -1
## Si vrai, exclut toutes les armes du tirage aléatoire
@export var exclude_weapons: bool = false
## Poids des raretés tirées pour l'équipement généré
@export var rarity_weights: Dictionary = {
	ItemData.Rarity.RARE: 75,
	ItemData.Rarity.LEGENDARY: 25
}

## Helpers de résolution des composants sur le joueur
func _get_skill_tree(player: Node) -> SkillTreeComponent:
	if player == null:
		return null
	var st = player.get_node_or_null("Skill_tree_comp") as SkillTreeComponent
	if st != null:
		return st
	st = player.get_node_or_null("SkillTreeComponent") as SkillTreeComponent
	if st != null:
		return st
	var ui_mgr = player.get_node_or_null("UI_manager")
	if ui_mgr != null and "skill_tree_comp" in ui_mgr and ui_mgr.skill_tree_comp is SkillTreeComponent:
		return ui_mgr.skill_tree_comp as SkillTreeComponent
	for child in player.get_children():
		if child is SkillTreeComponent:
			return child
	var found = player.find_children("*", "SkillTreeComponent", true, false)
	if not found.is_empty():
		return found[0] as SkillTreeComponent
	return null

func _get_spellbook_ui(player: Node) -> SpellBookUI:
	if player == null:
		return null
	var sb = player.get_node_or_null("SpellBook_UI") as SpellBookUI
	if sb != null:
		return sb
	var ui_mgr = player.get_node_or_null("UI_manager")
	if ui_mgr == null:
		ui_mgr = player.find_child("*UI_manager*", true, false)
	if ui_mgr != null and "spellbook_ui" in ui_mgr and ui_mgr.spellbook_ui is SpellBookUI:
		return ui_mgr.spellbook_ui as SpellBookUI
	for child in player.get_children():
		if child is SpellBookUI:
			return child
	var found = player.find_children("*", "SpellBookUI", true, false)
	if not found.is_empty():
		return found[0] as SpellBookUI
	return player.find_child("SpellBook*", true, false) as SpellBookUI

func _get_skill_bar(player: Node) -> SkillBarComponent:
	if player == null:
		return null
	var bar = player.get_node_or_null("SkillBarComponent") as SkillBarComponent
	if bar != null:
		return bar
	for child in player.get_children():
		if child is SkillBarComponent:
			return child
	var found = player.find_children("*", "SkillBarComponent", true, false)
	if not found.is_empty():
		return found[0] as SkillBarComponent
	return null

func _get_locked_spells(player: Node) -> Array[AbilityData]:
	var locked: Array[AbilityData] = []
	var spellbook_ui = _get_spellbook_ui(player)
	if spellbook_ui == null:
		return locked
	var skill_bar = _get_skill_bar(player)
	var all_spells: Array[AbilityData] = GameData.get_droppable_skills(0.14)
	if all_spells.is_empty():
		all_spells = GameData.get_all_non_evolution_skills()
	for sp in all_spells:
		if sp == null or sp.is_evolution_only:
			continue
		var already_unlocked = false
		for unlocked in spellbook_ui.unlocked_spells:
			if unlocked != null and (unlocked == sp or unlocked.ability_name == sp.ability_name):
				already_unlocked = true
				break
		if not already_unlocked and skill_bar != null:
			for slot_spell in skill_bar.slots.values():
				if slot_spell != null and (slot_spell == sp or slot_spell.ability_name == sp.ability_name):
					already_unlocked = true
					break
		if not already_unlocked:
			locked.append(sp)
	return locked

## Vérifie si cette récompense est éligible pour être proposée au joueur
func is_eligible(player: CharacterBody3D, _pnj: Node = null) -> bool:
	if player == null:
		return false
		
	match reward_type:
		RewardType.SKILL_POINTS:
			return _get_skill_tree(player) != null
			
		RewardType.RANDOM_SPELL:
			return not _get_locked_spells(player).is_empty()
			
		RewardType.RANDOM_EQUIPMENT:
			return true
			
		RewardType.UPGRADE_WEAPON_ILVL:
			var equip_comp = player.get_node_or_null("EquipmentComponent") as EquipmentComponent
			if equip_comp == null:
				equip_comp = player.find_child("EquipmentComponent", true, false) as EquipmentComponent
			if equip_comp != null:
				if equip_comp.equipped_items.get("main_hand") is WeaponItem or equip_comp.equipped_items.get("second_weapon") is WeaponItem:
					return true
			var inv_comp = player.get_node_or_null("InventoryComponent") as InventoryComponent
			if inv_comp == null:
				inv_comp = player.find_child("InventoryComponent", true, false) as InventoryComponent
			if inv_comp != null:
				for slot in inv_comp.slots:
					if slot["item"] != null and slot["item"] is WeaponItem:
						return true
			return false
			
		RewardType.UPGRADE_ITEM_RARITY:
			var equip_comp = player.get_node_or_null("EquipmentComponent") as EquipmentComponent
			if equip_comp == null:
				equip_comp = player.find_child("EquipmentComponent", true, false) as EquipmentComponent
			if equip_comp != null:
				for slot_name in equip_comp.equipped_items.keys():
					var it = equip_comp.equipped_items[slot_name]
					if it != null and it is EquipmentItem and it.rarity != ItemData.Rarity.UNIQUE and it.rarity < ItemData.Rarity.LEGENDARY:
						return true
			var inv_comp = player.get_node_or_null("InventoryComponent") as InventoryComponent
			if inv_comp == null:
				inv_comp = player.find_child("InventoryComponent", true, false) as InventoryComponent
			if inv_comp != null:
				for slot in inv_comp.slots:
					var it = slot["item"]
					if it != null and it is EquipmentItem and it.rarity != ItemData.Rarity.UNIQUE and it.rarity < ItemData.Rarity.LEGENDARY:
						return true
			return false
			
		RewardType.HEAL_PERCENT:
			var health_comp = player.get_node_or_null("HealthComponent") as HealthComponent
			if health_comp == null:
				health_comp = player.find_child("HealthComponent", true, false) as HealthComponent
			if health_comp == null:
				return false
			var max_hp = health_comp.stats_component.get_stat_value("max_health") if health_comp.stats_component else health_comp._known_max_health
			return health_comp.current_health < (max_hp - 0.5)
			
		_:
			return true

## Applique l'effet de la récompense au joueur.
## Appelle on_complete lorsque la récompense est effectivement accordée.
func apply_reward(player: CharacterBody3D, pnj: Node = null, on_complete: Callable = Callable()) -> void:
	if player == null:
		push_error("RewardData: Impossible d'appliquer la récompense, player est null.")
		return
		
	match reward_type:
		RewardType.SKILL_POINTS:
			_apply_skill_points(player, on_complete)
		RewardType.RANDOM_SPELL:
			_apply_random_spell(player, on_complete)
		RewardType.RANDOM_EQUIPMENT:
			_apply_random_equipment(player, pnj, on_complete)
		RewardType.UPGRADE_WEAPON_ILVL:
			_apply_upgrade_weapon_ilvl(player, pnj, on_complete)
		RewardType.UPGRADE_ITEM_RARITY:
			_apply_upgrade_item_rarity(player, pnj, on_complete)
		RewardType.HEAL_PERCENT:
			_apply_heal_percent(player, on_complete)
		_:
			push_warning("RewardData: Type de récompense non géré -> " + str(reward_type))
			if on_complete.is_valid():
				on_complete.call()

func _apply_skill_points(player: CharacterBody3D, on_complete: Callable) -> void:
	var skill_tree = _get_skill_tree(player)
	if skill_tree != null and "available_skill_points" in skill_tree:
		skill_tree.available_skill_points += skill_points_amount
		print("[RewardData] +", skill_points_amount, " points de talent accordés au joueur.")
	else:
		push_warning("[RewardData] SkillTreeComponent introuvable sur le joueur.")
		return
		
	if on_complete.is_valid():
		on_complete.call()

func _apply_random_spell(player: CharacterBody3D, on_complete: Callable) -> void:
	var spellbook_ui = _get_spellbook_ui(player)
	if spellbook_ui == null:
		push_warning("[RewardData] SpellBookUI introuvable sur le joueur.")
		return
		
	var locked_spells = _get_locked_spells(player)
	if not locked_spells.is_empty():
		var picked_spell = locked_spells.pick_random()
		spellbook_ui.unlock_spell(picked_spell)
		print("[RewardData] Nouveau sort débloqué -> ", picked_spell.ability_name)
	else:
		print("[RewardData] Tous les sorts sont déjà débloqués.")
		
	if on_complete.is_valid():
		on_complete.call()

func _apply_random_equipment(player: CharacterBody3D, pnj: Node, on_complete: Callable) -> void:
	var bases: Array[EquipmentItem] = []
	if target_item_type >= 0:
		bases = GameData.get_bases_by_type(target_item_type as ItemData.ItemType)
	elif target_item_type == -2 or exclude_weapons:
		for b in GameData.get_all_bases():
			if b != null and not (b is WeaponItem) and b.item_type != ItemData.ItemType.main_hand:
				bases.append(b)
	else:
		bases = GameData.get_all_bases()
		
	if (exclude_weapons or target_item_type == -2) and not bases.is_empty():
		var filtered: Array[EquipmentItem] = []
		for b in bases:
			if b != null and not (b is WeaponItem) and b.item_type != ItemData.ItemType.main_hand:
				filtered.append(b)
		bases = filtered
		
	if bases.is_empty():
		push_warning("[RewardData] Aucune base disponible dans GameData pour ce filtre.")
		return
		
	var base_item = bases.pick_random()
	var camp_ilvl = pnj.camp_ilvl if (pnj != null and "camp_ilvl" in pnj) else 1
	var new_item = ItemGenerator.generate_with_chances(base_item, maxi(1, camp_ilvl), rarity_weights)
	
	if new_item != null:
		var inv = player.get_node_or_null("InventoryComponent") as InventoryComponent
		if inv == null:
			inv = player.find_child("InventoryComponent", true, false) as InventoryComponent
			
		if inv != null:
			var remaining = inv.add_item(new_item, 1)
			if remaining > 0:
				var item_dict = inv.pack_item(new_item)
				inv.rpc_id(1, "_rpc_spawn_bag", item_dict, remaining)
				print("[RewardData] Inventaire plein : équipement déposé au sol devant le joueur -> ", new_item.item_name)
			else:
				print("[RewardData] Nouvel équipement ajouté : ", new_item.item_name, " (ilvl ", new_item.ilvl, ", rareté ", ItemData.Rarity.keys()[new_item.rarity], ")")
		else:
			push_warning("[RewardData] InventoryComponent introuvable sur le joueur.")
			return
			
	if on_complete.is_valid():
		on_complete.call()

func _apply_upgrade_weapon_ilvl(player: CharacterBody3D, pnj: Node, on_complete: Callable) -> void:
	var camp_ilvl = pnj.camp_ilvl if (pnj != null and "camp_ilvl" in pnj) else 1
	var inv_ui = player.get_node_or_null("InventoryUI") as InventoryUI
	if inv_ui == null:
		inv_ui = player.find_child("InventoryUI", true, false) as InventoryUI
		
	if inv_ui != null:
		var filter_cb = func(item: ItemData) -> bool:
			return item is WeaponItem
			
		var select_cb = func(chosen_item: ItemData) -> void:
			if not (chosen_item is WeaponItem):
				return
				
			var weapon = chosen_item as WeaponItem
			var equip_comp = player.get_node_or_null("EquipmentComponent") as EquipmentComponent
			if equip_comp == null:
				equip_comp = player.find_child("EquipmentComponent", true, false) as EquipmentComponent
				
			var is_equipped = false
			var equipped_slot = ""
			if equip_comp != null:
				for slot in equip_comp.equipped_items.keys():
					if equip_comp.equipped_items[slot] == weapon:
						is_equipped = true
						equipped_slot = slot
						break
						
			var target_ilvl = camp_ilvl if weapon.ilvl < camp_ilvl else weapon.ilvl + 1
			if is_equipped and equip_comp != null:
				if equipped_slot != "second_weapon":
					equip_comp._remove_item_stats(weapon)
				ItemGenerator.scale_item_to_ilvl(weapon, target_ilvl)
				if equipped_slot != "second_weapon":
					equip_comp._apply_item_stats(weapon)
				equip_comp.equipment_changed.emit(equipped_slot, weapon)
			else:
				ItemGenerator.scale_item_to_ilvl(weapon, target_ilvl)
				var inv_comp = player.get_node_or_null("InventoryComponent") as InventoryComponent
				if inv_comp == null:
					inv_comp = player.find_child("InventoryComponent", true, false) as InventoryComponent
				if inv_comp != null:
					inv_comp.inventory_changed.emit()
					
			print("[RewardData] Arme '", weapon.item_name, "' améliorée à l'ilvl ", target_ilvl)
			if on_complete.is_valid():
				on_complete.call()
				
		var cancel_cb = func() -> void:
			print("[RewardData] Amélioration d'arme annulée par le joueur.")
			if is_instance_valid(pnj) and pnj.has_method("_open_reward_window"):
				pnj.call_deferred("_open_reward_window", player)
			
		inv_ui.open_for_item_selection("Choose a weapon to upgrade (increases its ilvl)", filter_cb, select_cb, cancel_cb)
	else:
		# Fallback direct si l'interface n'est pas trouvée
		var equip_comp = player.get_node_or_null("EquipmentComponent") as EquipmentComponent
		if equip_comp == null:
			equip_comp = player.find_child("EquipmentComponent", true, false) as EquipmentComponent
			
		var weapon: WeaponItem = null
		var is_equipped = false
		var equipped_slot = "main_hand"
		
		if equip_comp != null and equip_comp.equipped_items.get("main_hand") is WeaponItem:
			weapon = equip_comp.equipped_items["main_hand"] as WeaponItem
			is_equipped = true
			equipped_slot = "main_hand"
		elif equip_comp != null and equip_comp.equipped_items.get("second_weapon") is WeaponItem:
			weapon = equip_comp.equipped_items["second_weapon"] as WeaponItem
			is_equipped = true
			equipped_slot = "second_weapon"
			
		if weapon == null:
			var inv_comp = player.get_node_or_null("InventoryComponent") as InventoryComponent
			if inv_comp == null:
				inv_comp = player.find_child("InventoryComponent", true, false) as InventoryComponent
			if inv_comp != null:
				for slot in inv_comp.slots:
					if slot["item"] != null and slot["item"] is WeaponItem:
						weapon = slot["item"] as WeaponItem
						break
						
		if weapon != null:
			var target_ilvl = camp_ilvl if weapon.ilvl < camp_ilvl else weapon.ilvl + 1
			if is_equipped and equip_comp != null:
				if equipped_slot != "second_weapon":
					equip_comp._remove_item_stats(weapon)
				ItemGenerator.scale_item_to_ilvl(weapon, target_ilvl)
				if equipped_slot != "second_weapon":
					equip_comp._apply_item_stats(weapon)
				equip_comp.equipment_changed.emit(equipped_slot, weapon)
			else:
				ItemGenerator.scale_item_to_ilvl(weapon, target_ilvl)
				var inv_comp = player.get_node_or_null("InventoryComponent") as InventoryComponent
				if inv_comp != null:
					inv_comp.inventory_changed.emit()
			print("[RewardData] Arme '", weapon.item_name, "' améliorée à l'ilvl ", target_ilvl)
			if on_complete.is_valid():
				on_complete.call()

func _apply_upgrade_item_rarity(player: CharacterBody3D, pnj: Node, on_complete: Callable) -> void:
	var inv_ui = player.get_node_or_null("InventoryUI") as InventoryUI
	if inv_ui == null:
		inv_ui = player.find_child("InventoryUI", true, false) as InventoryUI
		
	if inv_ui != null:
		var filter_cb = func(item: ItemData) -> bool:
			return item is EquipmentItem and item.rarity != ItemData.Rarity.UNIQUE and item.rarity < ItemData.Rarity.LEGENDARY
			
		var select_cb = func(chosen_item: ItemData) -> void:
			if not (chosen_item is EquipmentItem):
				return
				
			var eq_item = chosen_item as EquipmentItem
			var equip_comp = player.get_node_or_null("EquipmentComponent") as EquipmentComponent
			if equip_comp == null:
				equip_comp = player.find_child("EquipmentComponent", true, false) as EquipmentComponent
				
			var is_equipped = false
			var equipped_slot = ""
			if equip_comp != null:
				for slot in equip_comp.equipped_items.keys():
					if equip_comp.equipped_items[slot] == eq_item:
						is_equipped = true
						equipped_slot = slot
						break
						
			if is_equipped and equip_comp != null and equipped_slot != "second_weapon":
				equip_comp._remove_item_stats(eq_item)
				
			var success = ItemGenerator.upgrade_item_rarity(eq_item)
			
			if is_equipped and equip_comp != null:
				if equipped_slot != "second_weapon":
					equip_comp._apply_item_stats(eq_item)
				equip_comp.equipment_changed.emit(equipped_slot, eq_item)
			else:
				var inv_comp = player.get_node_or_null("InventoryComponent") as InventoryComponent
				if inv_comp == null:
					inv_comp = player.find_child("InventoryComponent", true, false) as InventoryComponent
				if inv_comp != null:
					inv_comp.inventory_changed.emit()
					
			if success and on_complete.is_valid():
				on_complete.call()
				
		var cancel_cb = func() -> void:
			print("[RewardData] Sélection d'amélioration annulée par le joueur.")
			if is_instance_valid(pnj) and pnj.has_method("_open_reward_window"):
				pnj.call_deferred("_open_reward_window", player)
			
		inv_ui.open_for_item_selection("Choose a piece of gear to upgrade (Normal, Magic, or Rare)", filter_cb, select_cb, cancel_cb)
	else:
		push_warning("[RewardData] InventoryUI introuvable pour la sélection interactive.")

func _apply_heal_percent(player: CharacterBody3D, on_complete: Callable) -> void:
	var health_comp = player.get_node_or_null("HealthComponent") as HealthComponent
	if health_comp == null:
		health_comp = player.find_child("HealthComponent", true, false) as HealthComponent
		
	if health_comp != null:
		var max_hp = health_comp.stats_component.get_stat_value("max_health") if health_comp.stats_component else health_comp._known_max_health
		var heal_amount = max_hp * heal_percent
		health_comp.heal(heal_amount)
		print("[RewardData] Joueur soigné de ", int(heal_amount), " PV (", int(heal_percent * 100), "% de ses PV max).")
	else:
		push_warning("[RewardData] HealthComponent introuvable sur le joueur.")
		
	if on_complete.is_valid():
		on_complete.call()
