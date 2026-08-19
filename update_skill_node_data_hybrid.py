with open("Y:/Fangorn/fangorn/passive_skill_tree/ressource_node/skill_node_data.gd", "r", encoding="utf-8") as f:
    content = f.read()

# Update Zone enum
content = content.replace(
    "enum Zone { ANY, BARBARIAN, MAGE, DUELIST }",
    "enum Zone { ANY, BARBARIAN, MAGE, DUELIST, HYBRID_BARB_MAGE, HYBRID_MAGE_DUEL, HYBRID_DUEL_BARB }"
)

# Add Hybrid group before Multiplicateurs par Tier
hybrid_group = """
@export_group("Zones Hybrides (Exclusif)")
@export var is_hybrid_exclusive: bool = false
@export var spawn_in_barb_mage: bool = false
@export var spawn_in_mage_duel: bool = false
@export var spawn_in_duel_barb: bool = false

@export_group("Multiplicateurs par Tier")"""

content = content.replace("\n@export_group(\"Multiplicateurs par Tier\")", hybrid_group)

with open("Y:/Fangorn/fangorn/passive_skill_tree/ressource_node/skill_node_data.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated skill_node_data.gd with Hybrid zones")
