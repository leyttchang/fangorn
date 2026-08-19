with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    lines = f.readlines()

out_lines = []
for line in lines:
    if line.startswith("@export var num_nodes"):
        out_lines.append("## Nombre total de nœuds de l'arbre.\n")
    elif line.startswith("@export var tree_radius"):
        out_lines.append("## Taille globale de l'arbre (rayon en pixels).\n")
    elif line.startswith("@export var min_node_distance"):
        out_lines.append("## Espace minimum entre deux nœuds (empêche les superpositions).\n")
    elif line.startswith("@export_range(1.0, 10.0) var minor_match_multiplier"):
        out_lines.append("## Force avec laquelle le système tente de placer un Mineur sur un chemin normal.\n## (Mettre à 100.0+ pour forcer).\n")
    elif line.startswith("@export_range(1.0, 10.0) var notable_match_multiplier"):
        out_lines.append("## Force avec laquelle le système tente de placer un Notable sur un Carrefour (3+ connexions).\n## (Mettre à 100.0+ pour forcer).\n")
    elif line.startswith("@export_range(1.0, 10.0) var keystone_match_multiplier"):
        out_lines.append("## Force avec laquelle le système tente de placer une Keystone sur une Impasse.\n## (Mettre à 100.0+ pour forcer).\n")
    elif line.startswith("@export_range(0.0, 10.0) var tag_match_multiplier_per_tag_minor"):
        out_lines.append("## Force d'infection : Multiplicateur de thème quand le voisin est un MINEUR.\n")
    elif line.startswith("@export_range(0.0, 20.0) var tag_match_multiplier_per_tag_notable"):
        out_lines.append("## Force d'infection : Multiplicateur de thème quand le voisin est un NOTABLE.\n")
    elif line.startswith("@export_range(0.0, 20.0) var tag_match_multiplier_per_tag_keystone"):
        out_lines.append("## Force d'infection : Multiplicateur de thème quand le voisin est une KEYSTONE.\n")
    elif line.startswith("@export_range(0.0, 1.0) var hybrid_penalty_multiplier"):
        out_lines.append("## Réduit les chances des nœuds normaux dans les zones frontières (laissant la place aux Hybrides Exclusifs).\n")
    elif line.startswith("@export_range(0.0, 10.0) var dead_end_keystone_multiplier_per_depth"):
        out_lines.append("## Plus une impasse est longue, plus une Keystone a de chance d'apparaître au bout.\n")
    elif line.startswith("@export var dead_end_minor_cutoff_depth"):
        out_lines.append("## Interdit l'apparition de nœuds Mineurs sur les X dernières cases d'une très longue impasse.\n")
    elif line.startswith("@export var analyze_skill_deck"):
        out_lines.append("## Cochez pour générer un rapport complet du contenu du Skill Deck dans la console (Output).\n")
        
    out_lines.append(line)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.writelines(out_lines)
print("Added doc comments")
