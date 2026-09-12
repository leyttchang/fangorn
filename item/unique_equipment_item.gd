class_name UniqueEquipmentItem
extends EquipmentItem

@export_category("Propriétés d'Objet Unique")
@export var unique_effect_script: GDScript
@export var unique_model_scene: PackedScene

func _init() -> void:
	rarity = Rarity.UNIQUE
