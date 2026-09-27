class_name ItemGenerator
extends RefCounted

## Fonction principale pour générer un équipement ou une arme
static func generate_equipment(base: EquipmentItem, ilvl: int, rarity: ItemData.Rarity, all_possible_affixes: Array[AffixData]) -> EquipmentItem:
	# 0. Vérification du drop Unique
	var is_unique_roll = false
	if base.possible_uniques.size() > 0:
		for drop_data in base.possible_uniques:
			if drop_data.unique_item != null and randf() <= drop_data.drop_chance:
				base = drop_data.unique_item
				rarity = ItemData.Rarity.UNIQUE
				is_unique_roll = true
				break

	# 1. Dupliquer la base pour avoir une instance unique
	var new_item: EquipmentItem = base.duplicate(true)
	new_item.original_base_path = base.resource_path
	new_item.stat_bonuses = base.stat_bonuses.duplicate(true) # Sécurité pour les Dictionnaires
	new_item.innate_stats = {}
	new_item.affix_stats = {}
	new_item.rarity = rarity
	new_item.ilvl = ilvl
	
	var ilvl_multiplier = 1.0 + (ilvl * 0.1) # Option A: +10% de puissance par niveau
	
	var percent_stats = GameData.PERCENT_STATS
	
	# 2. Roll des stats intrinsèques de base (Equipment)
	for stat_name in new_item.base_stat_ranges.keys():
		var range_vec: Vector2 = new_item.base_stat_ranges[stat_name]
		if range_vec.y > 0 or range_vec.x > 0: # S'il y a une range définie (au lieu de 0,0)
			var roll = randf_range(range_vec.x, range_vec.y) * ilvl_multiplier
			var is_percent = percent_stats.has(stat_name)
			var snapped_roll = snapped(roll, 0.01) if is_percent else round(roll)
			
			new_item.stat_bonuses[stat_name] = snapped_roll
			new_item.innate_stats[stat_name] = snapped_roll
		else:
			# FIX: Si l'utilisateur a rentré une stat fixe directement (ex: arme unique), on scale aussi !
			if new_item.stat_bonuses.has(stat_name) and new_item.stat_bonuses[stat_name] != 0.0:
				var fixed_val = new_item.stat_bonuses[stat_name] * ilvl_multiplier
				var is_percent = percent_stats.has(stat_name)
				var snapped_val = snapped(fixed_val, 0.01) if is_percent else round(fixed_val)
				new_item.stat_bonuses[stat_name] = snapped_val
				new_item.innate_stats[stat_name] = snapped_val
			
	# 2b. Roll des dégâts et vitesse si c'est une arme
	if new_item is WeaponItem:
		var weapon = new_item as WeaponItem
		if weapon.damage_range.y > 0 or weapon.damage_range.x > 0:
			var dmg_roll = randf_range(weapon.damage_range.x, weapon.damage_range.y) * ilvl_multiplier
			weapon.base_damage = round(dmg_roll)
		elif weapon.base_damage > 0:
			weapon.base_damage = round(weapon.base_damage * ilvl_multiplier)
			
		if weapon.attack_speed_range.y > 0 or weapon.attack_speed_range.x > 0:
			# L'attack speed scale généralement beaucoup moins dans les ARPG
			var as_mult = 1.0 + (ilvl * 0.02) 
			var as_roll = randf_range(weapon.attack_speed_range.x, weapon.attack_speed_range.y) * as_mult
			weapon.base_attack_speed = snapped(as_roll, 0.01)
		elif weapon.base_attack_speed > 0:
			var as_mult = 1.0 + (ilvl * 0.02) 
			weapon.base_attack_speed = snapped(weapon.base_attack_speed * as_mult, 0.01)
			
	# 3. Déterminer le nombre d'affixes bonus selon la rareté
	var num_affixes = 0
	match rarity:
		ItemData.Rarity.COMMON: num_affixes = 0
		ItemData.Rarity.MAGIC: num_affixes = 1
		ItemData.Rarity.RARE: num_affixes = 2
		ItemData.Rarity.LEGENDARY: num_affixes = 3 # On laisse de la place pour les légendaires plus tard
		ItemData.Rarity.UNIQUE: num_affixes = 0 # Les uniques ont des stats fixes, pas d'affixes aléatoires
		
	# 4. Filtrer les affixes valides
	var valid_affixes: Array[AffixData] = []
	if num_affixes > 0:
		# On collecte les chemins des affixes exclus pour comparer par path (resource_path)
		# et pas par référence — car duplicate(true) crée de nouvelles instances qui ne matchent pas avec ==
		var excluded_paths: Array[String] = []
		for excl in new_item.excluded_affixes:
			if excl != null and excl.resource_path != "":
				excluded_paths.append(excl.resource_path)
		
		for affix in all_possible_affixes:
			# Ignorer les affixes sans stat_name valide (évite les slots fantômes)
			if affix.stat_name == "":
				push_warning("ItemGenerator: affix '" + affix.affix_name + "' n'a pas de stat_name défini, ignoré.")
				continue
			# Exclure par path au lieu de référence
			if not excluded_paths.has(affix.resource_path):
				valid_affixes.append(affix)
	
	# On charge la courbe de probabilité
	var roll_curve: Curve = load("res://components/stats/affix_roll_curve.tres")
	
	if num_affixes > 0 and valid_affixes.size() > 0:
		# 5. Tirer les affixes aléatoires
		# IMPORTANT : on travaille sur une copie locale pour ne PAS mélanger le tableau
		# static _all_affixes partagé dans GameData (sinon le cache est corrompu pour tous les appels suivants)
		var shuffled = valid_affixes.duplicate()
		shuffled.shuffle()
		
		var used_stat_names: Array[String] = []
		var picked = 0
		
		for chosen_affix in shuffled:
			if picked >= num_affixes:
				break
			
			var stat_name = chosen_affix.stat_name
			
			if used_stat_names.has(stat_name):
				print("[ItemGen]   SKIP (doublon stat_name): ", chosen_affix.affix_name, " (", stat_name, ")")
				continue
			used_stat_names.append(stat_name)
			
			# Calcul du budget (multiplicateur) de cette base d'équipement pour cet affixe
			var equipment_budget = new_item.global_affix_multiplier
			if new_item.specific_affix_multipliers.has(stat_name):
				equipment_budget *= new_item.specific_affix_multipliers[stat_name]
				
			# Tirage avec la courbe de probabilité (Algorithme du Rejet)
			var roll_t = 0.0
			if roll_curve != null:
				while true:
					var x = randf()
					var y = randf()
					if y <= roll_curve.sample(x):
						roll_t = x
						break
			else:
				roll_t = randf()
				
			var affix_roll = lerp(chosen_affix.min_roll, chosen_affix.max_roll, roll_t) * ilvl_multiplier * equipment_budget
			var is_percent = percent_stats.has(stat_name)
			var is_float = GameData.FLOAT_STATS.has(stat_name)
			
			var snapped_affix = 0.0
			if is_percent:
				snapped_affix = snapped(affix_roll, 0.01)
			elif is_float:
				snapped_affix = snapped(affix_roll, 0.1)
			else:
				snapped_affix = round(affix_roll)
				# Anti-bug: Si l'arrondi entier donne 0 mais roll positif, forcer 1
				if snapped_affix == 0.0 and affix_roll > 0.001:
					snapped_affix = 1.0
			
			print("[ItemGen]   PICKED: ", chosen_affix.affix_name, " (", stat_name, ") = ", snapped_affix, " (raw: ", affix_roll, ")")
			
			# Ajouter le bonus aux stats (additionne par dessus la stat de base)
			if new_item.stat_bonuses.has(stat_name):
				new_item.stat_bonuses[stat_name] += snapped_affix
			else:
				new_item.stat_bonuses[stat_name] = snapped_affix
				
			# Ajouter au dictionnaire d'affichage
			if new_item.affix_stats.has(stat_name):
				new_item.affix_stats[stat_name] += snapped_affix
			else:
				new_item.affix_stats[stat_name] = snapped_affix
			
			picked += 1
			
	return new_item

## Tire une rareté selon un dictionnaire de poids (ex: { ItemData.Rarity.RARE: 75, ItemData.Rarity.LEGENDARY: 25 })
static func roll_rarity(rarity_weights: Dictionary = {}) -> ItemData.Rarity:
	if rarity_weights.is_empty():
		rarity_weights = {
			ItemData.Rarity.COMMON: 40.0,
			ItemData.Rarity.MAGIC: 35.0,
			ItemData.Rarity.RARE: 20.0,
			ItemData.Rarity.LEGENDARY: 5.0
		}
	
	var total_weight: float = 0.0
	for w in rarity_weights.values():
		total_weight += float(w)
		
	if total_weight <= 0.0:
		return ItemData.Rarity.COMMON
		
	var roll = randf() * total_weight
	var cumulative: float = 0.0
	for r in rarity_weights.keys():
		cumulative += float(rarity_weights[r])
		if roll <= cumulative:
			return r as ItemData.Rarity
			
	return ItemData.Rarity.COMMON

## Génère un équipement à partir d'une base (ou base aléatoire si null) avec rareté pondérée et test Unique
static func generate_with_chances(base: EquipmentItem = null, ilvl: int = 1, rarity_weights: Dictionary = {}, all_affixes: Array[AffixData] = []) -> EquipmentItem:
	if base == null:
		var all_bases = GameData.get_all_bases()
		if all_bases.is_empty():
			push_error("ItemGenerator: Aucune base disponible dans GameData.")
			return null
		base = all_bases.pick_random()
		
	if all_affixes.is_empty():
		all_affixes = GameData.get_all_affixes()
		
	var target_rarity = roll_rarity(rarity_weights)
	return generate_equipment(base, ilvl, target_rarity, all_affixes)

## Fait évoluer le niveau d'un équipement vers target_ilvl en augmentant proportionnellement ses stats
## intrinsèques, dégâts/vitesse d'arme et rolls d'affixes (+10% par ilvl, +2% vitesse d'attaque)
## sans jamais reroller les stats, préservant ainsi la qualité relative exacte des tirages d'origine.
static func scale_item_to_ilvl(item: EquipmentItem, target_ilvl: int) -> void:
	if item == null or target_ilvl <= item.ilvl:
		return
		
	var old_ilvl = item.ilvl
	var old_mult = 1.0 + (old_ilvl * 0.1)
	var new_mult = 1.0 + (target_ilvl * 0.1)
	var scale_ratio = new_mult / old_mult
	
	var old_as_mult = 1.0 + (old_ilvl * 0.02)
	var new_as_mult = 1.0 + (target_ilvl * 0.02)
	var as_scale_ratio = new_as_mult / old_as_mult
	
	var percent_stats = GameData.PERCENT_STATS
	var float_stats = GameData.FLOAT_STATS
	
	# Mise à l'échelle des dégâts et de la vitesse de frappe pour une arme
	if item is WeaponItem:
		var weapon = item as WeaponItem
		weapon.base_damage = max(1.0, round(weapon.base_damage * scale_ratio))
		weapon.base_attack_speed = snapped(weapon.base_attack_speed * as_scale_ratio, 0.01)
		
	# Mise à l'échelle des stats intrinsèques (armure de base, vie, dégâts plats de base, etc.)
	for stat_name in item.innate_stats.keys():
		var val = item.innate_stats[stat_name] * scale_ratio
		if percent_stats.has(stat_name):
			val = snapped(val, 0.01)
		elif float_stats.has(stat_name):
			val = snapped(val, 0.1)
		else:
			val = round(val)
		item.innate_stats[stat_name] = val
		
	# Mise à l'échelle des affixes
	for stat_name in item.affix_stats.keys():
		var val = item.affix_stats[stat_name] * scale_ratio
		if percent_stats.has(stat_name):
			val = snapped(val, 0.01)
		elif float_stats.has(stat_name):
			val = snapped(val, 0.1)
		else:
			val = round(val)
		item.affix_stats[stat_name] = val
		
	# Recalcul de stat_bonuses
	for stat_name in item.stat_bonuses.keys():
		var has_innate = item.innate_stats.has(stat_name)
		var has_affix = item.affix_stats.has(stat_name)
		if has_innate or has_affix:
			item.stat_bonuses[stat_name] = item.innate_stats.get(stat_name, 0.0) + item.affix_stats.get(stat_name, 0.0)
		elif item.stat_bonuses[stat_name] != 0.0:
			var val = item.stat_bonuses[stat_name] * scale_ratio
			if percent_stats.has(stat_name):
				val = snapped(val, 0.01)
			elif float_stats.has(stat_name):
				val = snapped(val, 0.1)
			else:
				val = round(val)
			item.stat_bonuses[stat_name] = val
			
	item.ilvl = target_ilvl
	print("[ItemGen] Arme/Équipement '", item.item_name, "' mis à niveau : ilvl ", old_ilvl, " -> ", target_ilvl, " (ratio: x", snapped(scale_ratio, 0.01), ")")

## Fait monter un objet d'un palier de rareté (Normal -> Magique -> Rare -> Légendaire)
## en lui ajoutant 1 nouvel affixe tiré selon son ilvl, sans reroll des stats existantes
## et sans doublon de type de stat.
static func upgrade_item_rarity(item: EquipmentItem, all_possible_affixes: Array[AffixData] = []) -> bool:
	if item == null:
		return false
	if item.rarity == ItemData.Rarity.UNIQUE or item.rarity >= ItemData.Rarity.LEGENDARY:
		print("[ItemGen] Impossible d'améliorer la rareté d'un objet déjà Unique ou Légendaire.")
		return false
		
	if all_possible_affixes.is_empty():
		all_possible_affixes = GameData.get_all_affixes()
		
	var next_rarity: ItemData.Rarity
	match item.rarity:
		ItemData.Rarity.COMMON:
			next_rarity = ItemData.Rarity.MAGIC
		ItemData.Rarity.MAGIC:
			next_rarity = ItemData.Rarity.RARE
		ItemData.Rarity.RARE:
			next_rarity = ItemData.Rarity.LEGENDARY
		_:
			return false
			
	# Filtrer les affixes valides : exclure ceux déjà sur l'item et ceux interdits par la base
	var excluded_paths: Array[String] = []
	for excl in item.excluded_affixes:
		if excl != null and excl.resource_path != "":
			excluded_paths.append(excl.resource_path)
			
	var existing_stats: Array[String] = []
	for stat in item.affix_stats.keys():
		existing_stats.append(stat)
		
	var valid_affixes: Array[AffixData] = []
	for affix in all_possible_affixes:
		if affix == null or affix.stat_name == "":
			continue
		if excluded_paths.has(affix.resource_path):
			continue
		if existing_stats.has(affix.stat_name):
			continue
		valid_affixes.append(affix)
		
	if valid_affixes.is_empty():
		push_warning("ItemGenerator: Aucun affixe valide disponible pour améliorer la rareté de l'objet.")
		return false
		
	var chosen_affix = valid_affixes.pick_random()
	var stat_name = chosen_affix.stat_name
	
	# Tirage de la valeur du nouvel affixe selon l'ilvl de l'objet et la courbe de probabilité
	var ilvl_multiplier = 1.0 + (item.ilvl * 0.1)
	var equipment_budget = item.global_affix_multiplier
	if item.specific_affix_multipliers.has(stat_name):
		equipment_budget *= item.specific_affix_multipliers[stat_name]
		
	var roll_curve: Curve = load("res://components/stats/affix_roll_curve.tres")
	var roll_t = 0.0
	if roll_curve != null:
		while true:
			var x = randf()
			var y = randf()
			if y <= roll_curve.sample(x):
				roll_t = x
				break
	else:
		roll_t = randf()
		
	var affix_roll = lerp(chosen_affix.min_roll, chosen_affix.max_roll, roll_t) * ilvl_multiplier * equipment_budget
	var percent_stats = GameData.PERCENT_STATS
	var float_stats = GameData.FLOAT_STATS
	
	var snapped_affix = 0.0
	if percent_stats.has(stat_name):
		snapped_affix = snapped(affix_roll, 0.01)
	elif float_stats.has(stat_name):
		snapped_affix = snapped(affix_roll, 0.1)
	else:
		snapped_affix = round(affix_roll)
		if snapped_affix == 0.0 and affix_roll > 0.001:
			snapped_affix = 1.0
			
	if item.stat_bonuses.has(stat_name):
		item.stat_bonuses[stat_name] += snapped_affix
	else:
		item.stat_bonuses[stat_name] = snapped_affix
		
	item.affix_stats[stat_name] = snapped_affix
	var old_rarity = item.rarity
	item.rarity = next_rarity
	
	print("[ItemGen] Montée en rareté réussie pour '", item.item_name, "' : ", ItemData.Rarity.keys()[old_rarity], " -> ", ItemData.Rarity.keys()[next_rarity], " (Nouvel affixe: +", stat_name, " ", snapped_affix, ")")
	return true
