class_name VisualEquipmentManager
extends Node

# Les liens vers tes autres nœuds
@export var equipment_component: EquipmentComponent
@export var main_droite: Marker3D

func _ready() -> void:
	if equipment_component != null:
		# On écoute quand l'équipement change !
		equipment_component.equipment_changed.connect(_on_equipment_changed)

func _on_equipment_changed(slot_name: String, item: ItemData) -> void:
	# On ne réagit que si c'est la main droite
	if slot_name == "main_hand":
		
		# 1. On détruit l'ancienne arme (s'il y en a une)
		for child in main_droite.get_children():
			child.queue_free()
			
		# 2. Si on a juste déséquipé (mains nues), on s'arrête là
		if item == null or item.get("weapon_scene") == null:
			return
			
		# 3. On crée la nouvelle arme 3D
		var weapon_instance = item.weapon_scene.instantiate()
		
		# 4. L'INJECTION MAGIQUE DES STATS :
		# C'est ici qu'on donne le fichier .tres à la scène 3D vide !
		if weapon_instance is Weapon:
			weapon_instance.weapon_stats = item
			
		# 5. On l'attache physiquement à la main
		main_droite.add_child(weapon_instance)
