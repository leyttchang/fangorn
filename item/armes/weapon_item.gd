class_name WeaponItem
extends EquipmentItem

# On ajoute une information pour savoir comment on s'en équipe
enum WeaponSlot { ONE_HAND, TWO_HAND }
@export var equip_slot: WeaponSlot = WeaponSlot.ONE_HAND

# Les stats qu'on avait déjà codées
@export var base_damage: float = 15.0
@export var base_attack_speed: float = 1.0 
# La scène 3D (le visuel) qui devra apparaître dans la main du joueur
@export var weapon_scene: PackedScene

func _init() -> void:
	# Par défaut, quand tu créeras une arme, elle se mettra automatiquement 
	# dans la bonne catégorie pour l'inventaire !
	item_type = ItemType.main_hand
