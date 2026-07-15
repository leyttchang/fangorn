class_name EquipmentSlot
extends Panel

# Le nom de l'emplacement qu'on veut surveiller (par défaut la main droite)
@export var slot_name: String = "main_hand" 

# On a besoin du lien vers l'EquipmentComponent du joueur
@export var equipment_component: EquipmentComponent

@onready var icon_rect: TextureRect = $Icon

func _ready() -> void:
	if equipment_component != null:
		# 1. On branche nos oreilles sur le composant d'équipement
		equipment_component.equipment_changed.connect(_on_equipment_changed)
		
		# 2. On affiche l'arme de départ (si le joueur a déjà un objet au lancement du jeu)
		var starting_item = equipment_component.equipped_items[slot_name]
		_update_visual(starting_item)
	else:
		push_warning("EquipmentSlot : Il manque le EquipmentComponent sur la case " + slot_name)

# Cette fonction est appelée automatiquement dès qu'une arme est équipée/déséquipée
func _on_equipment_changed(changed_slot_name: String, item: ItemData) -> void:
	# Si l'équipement qui a changé correspond à NOTRE case (ex: "main_hand")
	if changed_slot_name == slot_name:
		_update_visual(item)

# Fonction pour changer l'image
func _update_visual(item: ItemData) -> void:
	if item == null:
		icon_rect.texture = null # Case vide
	else:
		icon_rect.texture = item.icon # On affiche l'icône de l'arme
