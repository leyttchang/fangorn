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
