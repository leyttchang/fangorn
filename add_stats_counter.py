with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

injection = """
	# 5. Compter les noeuds et afficher les stats
	var counts = {
		SkillNodeData.Zone.MAGE: {0: 0, 1: 0, 2: 0},
		SkillNodeData.Zone.BARBARIAN: {0: 0, 1: 0, 2: 0},
		SkillNodeData.Zone.DUELIST: {0: 0, 1: 0, 2: 0},
		SkillNodeData.Zone.HYBRID_BARB_MAGE: {0: 0, 1: 0, 2: 0},
		SkillNodeData.Zone.HYBRID_MAGE_DUEL: {0: 0, 1: 0, 2: 0},
		SkillNodeData.Zone.HYBRID_DUEL_BARB: {0: 0, 1: 0, 2: 0}
	}
	
	for i in range(points.size()):
		var skill = node_skills.get(i, null)
		if skill != null:
			var strict_zone = _get_zone(points[i])
			var hybrid_zone = _get_hybrid_zone(points[i])
			var zone = hybrid_zone if hybrid_zone != SkillNodeData.Zone.ANY else strict_zone
			if counts.has(zone):
				counts[zone][skill.node_type] += 1
				
	var stats_text = "STATS DES NOEUDS :\n\n"
	
	var zones_to_print = [
		{"name": "MAGE", "id": SkillNodeData.Zone.MAGE},
		{"name": "BARBARE", "id": SkillNodeData.Zone.BARBARIAN},
		{"name": "DUELISTE", "id": SkillNodeData.Zone.DUELIST},
		{"name": "HYBRIDE BARB-MAGE", "id": SkillNodeData.Zone.HYBRID_BARB_MAGE},
		{"name": "HYBRIDE MAGE-DUEL", "id": SkillNodeData.Zone.HYBRID_MAGE_DUEL},
		{"name": "HYBRIDE DUEL-BARB", "id": SkillNodeData.Zone.HYBRID_DUEL_BARB}
	]
	
	for z in zones_to_print:
		var z_counts = counts[z.id]
		if z_counts[0] > 0 or z_counts[1] > 0 or z_counts[2] > 0:
			stats_text += "[ " + z.name + " ]\n"
			stats_text += "  Mineurs: " + str(z_counts[0]) + "\n"
			stats_text += "  Notables: " + str(z_counts[1]) + "\n"
			stats_text += "  Keystones: " + str(z_counts[2]) + "\n\n"
			
	var stats_label = Label.new()
	stats_label.text = stats_text
	stats_label.position = Vector2(20, 20)
	stats_label.add_theme_font_size_override("font_size", 20)
	stats_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	stats_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	stats_label.add_theme_constant_override("outline_size", 6)
	
	# Créer un CanvasLayer pour que le label reste à l'écran même en cas de pan/zoom
	var canvas_layer = CanvasLayer.new()
	canvas_layer.add_child(stats_label)
	add_child(canvas_layer)

	# 6. Initialisation des états
"""

# Insert the code just before "_init_tree_states"
# Since _init_tree_states is called via call_deferred, we can find it
old_code = """	# 4. Initialisation des états (Seul le centre est UNLOCKED, ses voisins sont AVAILABLE)"""

content = content.replace(old_code, injection + "\t# 4. Initialisation des états")

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Added stats counter")
