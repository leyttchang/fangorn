with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

new_code = """@export_category("UI & Données")
@export var analyze_skill_deck: bool = false :
	set(val):
		analyze_skill_deck = false
		if Engine.is_editor_hint() and val == true:
			_print_deck_statistics()
			
func _print_deck_statistics() -> void:
	print("\\n=======================================================")
	print("📊 ANALYSE DU SKILL DECK (", skill_deck.size(), " Noeuds)")
	print("=======================================================")
	
	var stats = {
		"MINOR": {"barb": 0, "mage": 0, "duel": 0, "barb_mage": 0, "mage_duel": 0, "duel_barb": 0, "all_3": 0, "hybrid_exclusive": 0},
		"NOTABLE": {"barb": 0, "mage": 0, "duel": 0, "barb_mage": 0, "mage_duel": 0, "duel_barb": 0, "all_3": 0, "hybrid_exclusive": 0},
		"KEYSTONE": {"barb": 0, "mage": 0, "duel": 0, "barb_mage": 0, "mage_duel": 0, "duel_barb": 0, "all_3": 0, "hybrid_exclusive": 0}
	}
	
	for skill in skill_deck:
		if skill == null: continue
		var type_str = "MINOR"
		if skill.node_type == 1: type_str = "NOTABLE"
		elif skill.node_type == 2: type_str = "KEYSTONE"
		
		if skill.is_hybrid_exclusive:
			stats[type_str]["hybrid_exclusive"] += 1
			continue
			
		var b = skill.zone_barbarian_multiplier > 0.0
		var m = skill.zone_mage_multiplier > 0.0
		var d = skill.zone_duelist_multiplier > 0.0
		
		if b and not m and not d: stats[type_str]["barb"] += 1
		elif not b and m and not d: stats[type_str]["mage"] += 1
		elif not b and not m and d: stats[type_str]["duel"] += 1
		elif b and m and not d: stats[type_str]["barb_mage"] += 1
		elif not b and m and d: stats[type_str]["mage_duel"] += 1
		elif b and not m and d: stats[type_str]["duel_barb"] += 1
		elif b and m and d: stats[type_str]["all_3"] += 1
		
	for type in ["MINOR", "NOTABLE", "KEYSTONE"]:
		print("\\n--- ", type, "S ---")
		print(" - Exclusif BARBARE : ", stats[type]["barb"])
		print(" - Exclusif MAGE    : ", stats[type]["mage"])
		print(" - Exclusif DUELIST : ", stats[type]["duel"])
		print(" - 2 Zones (Barb+Mage) : ", stats[type]["barb_mage"])
		print(" - 2 Zones (Mage+Duel) : ", stats[type]["mage_duel"])
		print(" - 2 Zones (Duel+Barb) : ", stats[type]["duel_barb"])
		print(" - 3 Zones (ANY)       : ", stats[type]["all_3"])
		print(" - HYBRID Exclusif     : ", stats[type]["hybrid_exclusive"])
		
	print("=======================================================\\n")
"""

content = content.replace('@export_category("UI & Donn\u01f8es")', new_code)
content = content.replace('@export_category("UI & Données")', new_code)
content = content.replace('@export_category("UI & Donnes")', new_code)
content = content.replace('@export_category("UI & Donn\xc3\xa9es")', new_code)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Added analyze_skill_deck to generator_test.gd")
