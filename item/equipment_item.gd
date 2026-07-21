class_name EquipmentItem
extends ItemData

@export_category("Bonus de Stats - Résultat Final")
@export var stat_bonuses: Dictionary = {
	"max_health": 0.0,
	"armor": 0.0,
	"physical_damage": 0.0,
	"magic_damage": 0.0,
	"attack_speed": 0.0,
	"cd_red": 0.0,
	"area_of_effect": 0.0,
	"movement_speed": 0.0,
	"knockback_power": 0.0,
	"knockback_resistance": 0.0,
	"casting_speed": 0.0
}

# --- POUR L'AFFICHAGE DU TOOLTIP UNIQUEMENT ---
var innate_stats: Dictionary = {}
var affix_stats: Dictionary = {}


@export_category("Génération ARPG - Blueprint")
@export var base_stat_ranges: Dictionary = {
	"max_health": Vector2(0, 0),
	"armor": Vector2(0, 0),
	"physical_damage": Vector2(0, 0),
	"magic_damage": Vector2(0, 0),
	"attack_speed": Vector2(0, 0),
	"cd_red": Vector2(0, 0),
	"area_of_effect": Vector2(0, 0),
	"movement_speed": Vector2(0, 0),
	"knockback_power": Vector2(0, 0),
	"knockback_resistance": Vector2(0, 0),
	"casting_speed": Vector2(0, 0)
}

@export_category("Génération ARPG - Affixes")
@export var excluded_affixes: Array[AffixData] = []

@export_group("Puissance des Affixes")
## Multiplie la valeur de TOUS les affixes tirés sur cet objet (ex: 2.0 pour un Plastron, 0.5 pour des Bottes)
@export var global_affix_multiplier: float = 1.0
## Multiplie la valeur d'un affixe spécifique. Clé = nom de la stat (ex: "max_health"), Valeur = multiplicateur (ex: 2.0)
@export var specific_affix_multipliers: Dictionary = {}
