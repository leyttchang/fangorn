class_name ItemGenerator
extends RefCounted

## Fonction principale pour générer un équipement ou une arme
static func generate_equipment(base: EquipmentItem, ilvl: int, rarity: ItemData.Rarity, all_possible_affixes: Array[AffixData]) -> EquipmentItem:
	# 1. Dupliquer la base pour avoir une instance unique
	var new_item: EquipmentItem = base.duplicate(true)
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
			
	# 2b. Roll des dégâts et vitesse si c'est une arme
	if new_item is WeaponItem:
		var weapon = new_item as WeaponItem
		if weapon.damage_range.y > 0 or weapon.damage_range.x > 0:
			var dmg_roll = randf_range(weapon.damage_range.x, weapon.damage_range.y) * ilvl_multiplier
			weapon.base_damage = round(dmg_roll)
		if weapon.attack_speed_range.y > 0 or weapon.attack_speed_range.x > 0:
			# L'attack speed scale généralement beaucoup moins dans les ARPG
			var as_mult = 1.0 + (ilvl * 0.02) 
			var as_roll = randf_range(weapon.attack_speed_range.x, weapon.attack_speed_range.y) * as_mult
			weapon.base_attack_speed = snapped(as_roll, 0.01)
			
	# 3. Déterminer le nombre d'affixes bonus selon la rareté
	var num_affixes = 0
	match rarity:
		ItemData.Rarity.COMMON: num_affixes = 0
		ItemData.Rarity.MAGIC: num_affixes = 1
		ItemData.Rarity.RARE: num_affixes = 2
		ItemData.Rarity.LEGENDARY: num_affixes = 3 # On laisse de la place pour les légendaires plus tard
		
	# 4. Filtrer les affixes valides
	var valid_affixes: Array[AffixData] = []
	if num_affixes > 0:
		for affix in all_possible_affixes:
			if not new_item.excluded_affixes.has(affix):
				valid_affixes.append(affix)
	
	# On charge la courbe de probabilité
	var roll_curve: Curve = load("res://components/stats/affix_roll_curve.tres")
	
	# Si on a droit à des affixes et qu'on a des affixes valides
	if num_affixes > 0 and valid_affixes.size() > 0:
		# 5. Tirer les affixes aléatoires
		valid_affixes.shuffle() # Mélange pour prendre des affixes au hasard
		for i in range(min(num_affixes, valid_affixes.size())):
			var chosen_affix = valid_affixes[i]
			var stat_name = chosen_affix.stat_name
			
			# Calcul du budget (multiplicateur) de cette base d'équipement pour cet affixe
			var equipment_budget = new_item.global_affix_multiplier
			if new_item.specific_affix_multipliers.has(stat_name):
				equipment_budget *= new_item.specific_affix_multipliers[stat_name]
				
			# Tirage avec la courbe de probabilité (Algorithme du Rejet)
			# Plus la courbe est haute (proche de 1) sur un point X, plus la valeur X a de chances d'être gardée.
			var roll_t = 0.0
			if roll_curve != null:
				while true:
					var x = randf() # Tirage entre 0 et 1 (Le résultat du roll de l'affixe : 0 = min, 1 = max)
					var y = randf() # Tirage de la chance
					if y <= roll_curve.sample(x):
						roll_t = x
						break
			else:
				roll_t = randf() # Si la courbe n'existe pas, on fait du hasard pur
				
			var affix_roll = lerp(chosen_affix.min_roll, chosen_affix.max_roll, roll_t) * ilvl_multiplier * equipment_budget
			var is_percent = percent_stats.has(stat_name)
			var snapped_affix = snapped(affix_roll, 0.01) if is_percent else round(affix_roll)
			
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
				
	return new_item
