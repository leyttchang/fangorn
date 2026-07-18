class_name EquipmentItem
extends ItemData

@export_category("Bonus de Stats")
# J'ai ajouté toutes les clés manquantes pour qu'elles correspondent à ton _ready()
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
