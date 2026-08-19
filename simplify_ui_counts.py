with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

old_counts_dict = """	var counts = {
		SkillNodeData.Zone.MAGE: {0: 0, 1: 0, 2: 0},
		SkillNodeData.Zone.BARBARIAN: {0: 0, 1: 0, 2: 0},
		SkillNodeData.Zone.DUELIST: {0: 0, 1: 0, 2: 0},
		SkillNodeData.Zone.HYBRID_BARB_MAGE: {0: 0, 1: 0, 2: 0},
		SkillNodeData.Zone.HYBRID_MAGE_DUEL: {0: 0, 1: 0, 2: 0},
		SkillNodeData.Zone.HYBRID_DUEL_BARB: {0: 0, 1: 0, 2: 0}
	}"""
new_counts_dict = """	var counts = {
		SkillNodeData.Zone.MAGE: {0: 0, 1: 0, 2: 0},
		SkillNodeData.Zone.BARBARIAN: {0: 0, 1: 0, 2: 0},
		SkillNodeData.Zone.DUELIST: {0: 0, 1: 0, 2: 0}
	}"""
content = content.replace(old_counts_dict, new_counts_dict)

old_loop_logic = """		if skill != null:
			var strict_zone = _get_zone(points[i])
			var hybrid_zone = _get_hybrid_zone(points[i])
			var zone = hybrid_zone if hybrid_zone != SkillNodeData.Zone.ANY else strict_zone
			if counts.has(zone):
				counts[zone][skill.node_type] += 1"""
new_loop_logic = """		if skill != null:
			var strict_zone = _get_zone(points[i])
			if counts.has(strict_zone):
				counts[strict_zone][skill.node_type] += 1"""
content = content.replace(old_loop_logic, new_loop_logic)

old_print_array = """	var zones_to_print = [
		{"name": "MAGE", "id": SkillNodeData.Zone.MAGE},
		{"name": "BARBARE", "id": SkillNodeData.Zone.BARBARIAN},
		{"name": "DUELISTE", "id": SkillNodeData.Zone.DUELIST},
		{"name": "HYBRIDE BARB-MAGE", "id": SkillNodeData.Zone.HYBRID_BARB_MAGE},
		{"name": "HYBRIDE MAGE-DUEL", "id": SkillNodeData.Zone.HYBRID_MAGE_DUEL},
		{"name": "HYBRIDE DUEL-BARB", "id": SkillNodeData.Zone.HYBRID_DUEL_BARB}
	]"""
new_print_array = """	var zones_to_print = [
		{"name": "MAGE", "id": SkillNodeData.Zone.MAGE},
		{"name": "BARBARE", "id": SkillNodeData.Zone.BARBARIAN},
		{"name": "DUELISTE", "id": SkillNodeData.Zone.DUELIST}
	]"""
content = content.replace(old_print_array, new_print_array)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Simplified UI counts")
