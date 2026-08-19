import re

with open("Y:/Fangorn/fangorn/components/spell_componants/spell_scaling_component.gd", "r", encoding="utf-8") as f:
    content = f.read()

pattern = re.compile(r"# 2\. CALCUL ADDITIF DES MULTIPLICATEURS.*?(?=\t\t# On applique les d)", re.DOTALL)

new_chunk = """# 2. CALCUL PROPORTIONNEL DES ELEMENTS (CHUNKS)
		# ====================================================
		if caster_stats != null:
			var tags_count = 0
			if scales_with_physical: tags_count += 1
			if scales_with_magic: tags_count += 1
			if scales_with_aoe_damage: tags_count += 1
			if scales_with_fire: tags_count += 1
			if scales_with_ice: tags_count += 1
			if scales_with_lightning: tags_count += 1
			
			if tags_count > 0:
				var scaled_damage = 0.0
				var chunk_size = final_damage / float(tags_count)
				
				if scales_with_physical:
					scaled_damage += chunk_size * caster_stats.get_stat_value("physical_damage")
				if scales_with_magic:
					var magic_stat = caster_stats.get_stat_value("magic_damage")
					if magic_stat == 0.0: magic_stat = 1.0 
					scaled_damage += chunk_size * magic_stat
				if scales_with_aoe_damage:
					scaled_damage += chunk_size * caster_stats.get_stat_value("aoe_damage")
				if scales_with_fire:
					scaled_damage += chunk_size * caster_stats.get_stat_value("fire_damage")
				if scales_with_ice:
					scaled_damage += chunk_size * caster_stats.get_stat_value("ice_damage")
				if scales_with_lightning:
					scaled_damage += chunk_size * caster_stats.get_stat_value("lightning_damage")
					
				final_damage = scaled_damage
		
"""

content = re.sub(pattern, new_chunk, content)

with open("Y:/Fangorn/fangorn/components/spell_componants/spell_scaling_component.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated spell damage calculation")
