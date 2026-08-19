with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

old_logic = """		else:
			if zone == SkillNodeData.Zone.MAGE:
				zone_mult = skill.zone_mage_multiplier
			elif zone == SkillNodeData.Zone.DUELIST:
				zone_mult = skill.zone_duelist_multiplier
			elif zone == SkillNodeData.Zone.BARBARIAN:
				zone_mult = skill.zone_barbarian_multiplier
			elif zone == SkillNodeData.Zone.HYBRID_BARB_MAGE:
				zone_mult = max(skill.zone_barbarian_multiplier, skill.zone_mage_multiplier)
			elif zone == SkillNodeData.Zone.HYBRID_MAGE_DUEL:
				zone_mult = max(skill.zone_mage_multiplier, skill.zone_duelist_multiplier)
			elif zone == SkillNodeData.Zone.HYBRID_DUEL_BARB:
				zone_mult = max(skill.zone_duelist_multiplier, skill.zone_barbarian_multiplier)"""

new_logic = """		else:
			if zone == SkillNodeData.Zone.MAGE:
				zone_mult = skill.zone_mage_multiplier
			elif zone == SkillNodeData.Zone.DUELIST:
				zone_mult = skill.zone_duelist_multiplier
			elif zone == SkillNodeData.Zone.BARBARIAN:
				zone_mult = skill.zone_barbarian_multiplier
			else:
				# Les nœuds normaux ne peuvent PAS spawn dans la zone hybride
				zone_mult = 0.0"""

content = content.replace(old_logic, new_logic)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated generator logic to exclude normal nodes from hybrid zones")
