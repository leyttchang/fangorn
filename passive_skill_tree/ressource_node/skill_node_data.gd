class_name SkillNodeData
extends Resource

enum NodeType { MINOR, NOTABLE, KEYSTONE }
enum Zone { ANY, BARBARIAN, MAGE, DUELIST, HYBRID_BARB_MAGE, HYBRID_MAGE_DUEL, HYBRID_DUEL_BARB }

@export_category("Informations Principales")
@export var node_id: String = ""
@export var node_name: String = "Nouvelle Compétence"
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_category("Placement et Type")
@export var node_type: NodeType = NodeType.MINOR
@export var max_occurrences: int = 1 # Nombre de fois max que ce nœud peut apparaître dans l'arbre

@export_category("Probabilités d'apparition (Poids)")
@export_range(0.0, 1000.0) var base_spawn_weight: float = 100.0 # Poids global du nœud (Rareté)

@export_group("Multiplicateurs par Zone")
@export_range(0.0, 1.0) var zone_barbarian_multiplier: float = 1.0
@export_range(0.0, 1.0) var zone_mage_multiplier: float = 1.0
@export_range(0.0, 1.0) var zone_duelist_multiplier: float = 1.0

@export_group("Zones Hybrides (Exclusif)")
@export var is_hybrid_exclusive: bool = false
@export var spawn_in_barb_mage: bool = false
@export var spawn_in_mage_duel: bool = false
@export var spawn_in_duel_barb: bool = false

@export_group("Multiplicateurs par Tier")
@export_range(0.0, 1.0) var tier_1_multiplier: float = 1.0 # 1.0 = 100% du poids, 0.0 = interdit
@export_range(0.0, 1.0) var tier_2_multiplier: float = 0.0
@export_range(0.0, 1.0) var tier_3_multiplier: float = 0.0

@export_category("Effets")
@export_category("Thèmes (Clustering)")
@export_flags("Life", "Mana", "Armor", "Physical", "Fire", "Ice", "Lightning", "Elemental", "Speed", "Attack", "Magic", "Utility", "Area") var tags: int = 0


@export var stats_bonuses: Array[StatModifierData] = []

# Utilisé uniquement par les KEYSTONES pour déclencher des mécaniques de jeu spécifiques
# Exemple: "mind_over_matter", "blood_magic"
@export var gameplay_effect_id: String = ""
