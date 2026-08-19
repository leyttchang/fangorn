with open("Y:/Fangorn/fangorn/components/spell_componants/spell_scaling_component.gd", "r", encoding="utf-8") as f:
    content = f.read()

old_logic = """		# ====================================================
		# 2. CALCUL ADDITIF DES MULTIPLICATEURS (%)
		# ====================================================
		var total_multiplier = 1.0 # 100% de base
		
		if caster_stats != null:
			if scales_with_physical:
				total_multiplier += max(0.0, caster_stats.get_stat_value("physical_damage") - 1.0)
			
			if scales_with_magic:
				var magic_stat = caster_stats.get_stat_value("magic_damage")
				# Cas spécial pour la stat magique où 0 dans la database = 1.0 dans le système (à uniformiser un jour)
				if magic_stat == 0.0: magic_stat = 1.0 
				total_multiplier += max(0.0, magic_stat - 1.0)
				
			if scales_with_aoe_damage:
				# Si un jour tu rajoutes 'aoe_damage' dans le entity_stats, il sera pris en compte
				total_multiplier += max(0.0, caster_stats.get_stat_value("aoe_damage") - 1.0)
				
			if scales_with_fire:
				total_multiplier += max(0.0, caster_stats.get_stat_value("fire_damage") - 1.0)
				
			if scales_with_ice:
				total_multiplier += max(0.0, caster_stats.get_stat_value("ice_damage") - 1.0)
				
			if scales_with_lightning:
				total_multiplier += max(0.0, caster_stats.get_stat_value("lightning_damage") - 1.0)
		
		# On applique le gros multiplicateur total
		final_damage *= total_multiplier"""

old_logic_encoded = old_logic.replace("spécial", "sp\u01f8cial").replace("où", "o\u02dc").replace("à", "\u02dc") # Handle Godot encoding glitches safely if needed, actually let's use a regex or clean string slice.

