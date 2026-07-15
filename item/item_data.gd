class_name ItemData
extends Resource

# --- IDENTITÉ ---
@export var id: String = "item_id_unique"
@export var item_name: String = "Nouvel Objet"
@export_multiline var description: String = "Description de l'objet."
@export var icon: Texture2D

# --- CATÉGORISATION ---
enum ItemType { WEAPON, ARMOR, CONSUMABLE, RING, MATERIAL }
@export var item_type: ItemType = ItemType.MATERIAL

# 2. Catégorisation du style de l'arme (pour l'AnimationPlayer)
enum WeaponStyle { AXE, SWORD, DAGGER, MACE, SPEAR }
@export var weapon_style: WeaponStyle = WeaponStyle.AXE

# --- INVENTAIRE ---
@export var is_stackable: bool = false
@export var max_stack: int = 99
