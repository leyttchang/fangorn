class_name SkillNodeData
extends Resource

enum NodeType { MINOR, NOTABLE, KEYSTONE }
enum Zone { ANY, BARBARIAN, MAGE, DUELIST }

@export_category("Informations Principales")
@export var node_id: String = ""
@export var node_name: String = "Nouvelle Compétence"
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_category("Placement et Type")
@export var node_type: NodeType = NodeType.MINOR
@export var zone: Zone = Zone.ANY
@export var max_occurrences: int = 1 # Nombre de fois max que ce nœud peut apparaître dans l'arbre

@export_category("Probabilités d'apparition (Poids)")
@export_range(0.0, 100.0) var spawn_weight_tier_1: float = 100.0 # Chance relative d'apparaître au Centre
@export_range(0.0, 100.0) var spawn_weight_tier_2: float = 0.0   # Chance relative d'apparaître au Milieu
@export_range(0.0, 100.0) var spawn_weight_tier_3: float = 0.0   # Chance relative d'apparaître à l'Extérieur

@export_category("Effets")
@export var stats_bonuses: Array[StatModifierData] = []

# Utilisé uniquement par les KEYSTONES pour déclencher des mécaniques de jeu spécifiques
# Exemple: "mind_over_matter", "blood_magic"
@export var gameplay_effect_id: String = ""
