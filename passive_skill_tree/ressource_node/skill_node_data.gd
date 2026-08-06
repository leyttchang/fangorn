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
@export var weight: int = 1 # Plus il est élevé, plus il apparaît loin du centre

@export_category("Effets")
@export var stats_bonuses: Array[StatModifierData] = []

# Utilisé uniquement par les KEYSTONES pour déclencher des mécaniques de jeu spécifiques
# Exemple: "mind_over_matter", "blood_magic"
@export var gameplay_effect_id: String = ""
