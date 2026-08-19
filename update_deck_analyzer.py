with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

old_loop = """	for type in ["MINOR", "NOTABLE", "KEYSTONE"]:
		print("\\n--- ", type, "S ---")
		print(" - Exclusif BARBARE : ", stats[type]["barb"])
		print(" - Exclusif MAGE    : ", stats[type]["mage"])
		print(" - Exclusif DUELIST : ", stats[type]["duel"])
		print(" - 2 Zones (Barb+Mage) : ", stats[type]["barb_mage"])
		print(" - 2 Zones (Mage+Duel) : ", stats[type]["mage_duel"])
		print(" - 2 Zones (Duel+Barb) : ", stats[type]["duel_barb"])
		print(" - 3 Zones (ANY)       : ", stats[type]["all_3"])
		print(" - HYBRID Exclusif     : ", stats[type]["hybrid_exclusive"])"""

new_loop = """	for type in ["MINOR", "NOTABLE", "KEYSTONE"]:
		var t_barb = stats[type]["barb"] + stats[type]["barb_mage"] + stats[type]["duel_barb"] + stats[type]["all_3"]
		var t_mage = stats[type]["mage"] + stats[type]["barb_mage"] + stats[type]["mage_duel"] + stats[type]["all_3"]
		var t_duel = stats[type]["duel"] + stats[type]["duel_barb"] + stats[type]["mage_duel"] + stats[type]["all_3"]
		
		print("\\n--- ", type, "S ---")
		print(" - Exclusif BARBARE : ", stats[type]["barb"])
		print(" - Exclusif MAGE    : ", stats[type]["mage"])
		print(" - Exclusif DUELIST : ", stats[type]["duel"])
		print(" - 2 Zones (Barb+Mage) : ", stats[type]["barb_mage"])
		print(" - 2 Zones (Mage+Duel) : ", stats[type]["mage_duel"])
		print(" - 2 Zones (Duel+Barb) : ", stats[type]["duel_barb"])
		print(" - 3 Zones (ANY)       : ", stats[type]["all_3"])
		print(" - HYBRID Exclusif     : ", stats[type]["hybrid_exclusive"])
		print("   => TOTAL DISPO EN ZONE BARBARE : ", t_barb)
		print("   => TOTAL DISPO EN ZONE MAGE    : ", t_mage)
		print("   => TOTAL DISPO EN ZONE DUELIST : ", t_duel)"""

content = content.replace(old_loop, new_loop)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated deck analyzer with totals")
