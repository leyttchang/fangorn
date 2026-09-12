class_name UniqueWeaponItem
extends WeaponItem

@export_category("Propriétés d'Objet Unique")
@export var unique_effect_script: GDScript
@export var unique_model_scene: PackedScene

func _init() -> void:
	super()
	rarity = Rarity.UNIQUE
