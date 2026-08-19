with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add Exports
export_insertion = """@export_category("Equilibrage (Poids & Règles)")
@export_group("Types & Thèmes")
@export_range(1.0, 10.0) var type_match_multiplier: float = 3.0
@export_range(0.0, 10.0) var tag_match_multiplier_per_tag: float = 4.0
@export_group("Zones Hybrides")
@export_range(0.0, 1.0) var hybrid_penalty_multiplier: float = 0.2
@export_group("Impasses (Dead Ends)")
@export_range(0.0, 10.0) var dead_end_keystone_multiplier_per_depth: float = 2.5
@export var dead_end_minor_cutoff_depth: int = 2

@export_category("Zones & Hybrides")"""

content = content.replace("@export_category(\"Zones & Hybrides\")", export_insertion)

# 2. Replace magic numbers in _draft_skill
old_hybrid_penalty = """			# Malus de 500% (x0.2) si on est dans la zone hybride pour laisser la place aux hybrides exclusifs
			if hybrid_zone != SkillNodeData.Zone.ANY:
				zone_mult *= 0.2"""
new_hybrid_penalty = """			# Malus pour laisser la place aux hybrides exclusifs
			if hybrid_zone != SkillNodeData.Zone.ANY:
				zone_mult *= hybrid_penalty_multiplier"""
content = content.replace(old_hybrid_penalty, new_hybrid_penalty)

old_type_match = """		var type_multiplier = 1.0
		if skill.node_type == desired_type:
			type_multiplier = 3.0 # On favorise le type idéal pour cet emplacement, mais sans excès"""
new_type_match = """		var type_multiplier = 1.0
		if skill.node_type == desired_type:
			type_multiplier = type_match_multiplier"""
content = content.replace(old_type_match, new_type_match)

old_dead_end = """		# --- LOGIQUE D'IMPASSE (DEAD ENDS) ---
		if current_dead_end_dist > 0:
			if skill.node_type == SkillNodeData.NodeType.KEYSTONE:
				# Plus l'impasse est longue, plus la keystone est probable
				weight *= (1.0 + float(current_dead_end_dist) * 2.5)
				
			if skill.node_type == SkillNodeData.NodeType.MINOR and current_dead_end_dist > 2:
				# Au delà de 2 de longueur d'impasse, les mineurs tombent à 0
				weight = 0.0"""
new_dead_end = """		# --- LOGIQUE D'IMPASSE (DEAD ENDS) ---
		if current_dead_end_dist > 0:
			if skill.node_type == SkillNodeData.NodeType.KEYSTONE:
				weight *= (1.0 + float(current_dead_end_dist) * dead_end_keystone_multiplier_per_depth)
				
			if skill.node_type == SkillNodeData.NodeType.MINOR and current_dead_end_dist > dead_end_minor_cutoff_depth:
				weight = 0.0"""
content = content.replace(old_dead_end, new_dead_end)

old_tag_match = """				# Compter le nombre de tags en commun (bits à 1)
				var count = 0
				var temp = shared_tags
				while temp > 0:
					count += temp & 1
					temp = temp >> 1
				thematic_multiplier += 4.0 * count # +400% de poids par Tag en commun !"""
new_tag_match = """				# Compter le nombre de tags en commun (bits à 1)
				var count = 0
				var temp = shared_tags
				while temp > 0:
					count += temp & 1
					temp = temp >> 1
				thematic_multiplier += tag_match_multiplier_per_tag * count"""
content = content.replace(old_tag_match, new_tag_match)


with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Extracted magic numbers to inspector exports")
