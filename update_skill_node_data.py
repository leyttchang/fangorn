with open("Y:/Fangorn/fangorn/passive_skill_tree/ressource_node/skill_node_data.gd", "r", encoding="utf-8") as f:
    content = f.read()

injection = """@export_category("Effets")
@export_category("Thèmes (Clustering)")
@export_flags("Life", "Mana", "Armor", "Physical", "Fire", "Ice", "Lightning", "Elemental", "Speed", "Attack", "Magic", "Utility") var tags: int = 0

"""
content = content.replace("@export_category(\"Effets\")", injection)

with open("Y:/Fangorn/fangorn/passive_skill_tree/ressource_node/skill_node_data.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated skill_node_data.gd")
