class_name VisualEquipmentManager
extends Node

# Les liens vers tes autres nœuds
@export var equipment_component: EquipmentComponent
@export var main_droite: Marker3D

func _ready() -> void:
	if equipment_component != null:
		# On écoute quand l'équipement change !
		equipment_component.equipment_changed.connect(_on_equipment_changed)
		if multiplayer.has_multiplayer_peer() and get_parent().is_multiplayer_authority():
			multiplayer.peer_connected.connect(_on_peer_connected)

func _on_equipment_changed(slot_name: String, item: ItemData) -> void:
	# On ne réagit que si c'est la main droite
	if slot_name == "main_hand":
		# Envoi r?seau !
		if multiplayer.has_multiplayer_peer() and get_parent().is_multiplayer_authority():
			var path = ""
			if item != null and item.get("weapon_scene") != null:
				path = item.weapon_scene.resource_path
			rpc("_rpc_update_visual_weapon", path)
		
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

# ==========================================
# GESTION RESEAU DE L'APPARENCE DE L'ARME
# ==========================================
@rpc("any_peer", "call_remote", "reliable")
func _rpc_update_visual_weapon(resource_path: String) -> void:
	# 1. On d?truit l'ancienne arme
	for child in main_droite.get_children():
		child.queue_free()
		
	# 2. Si mains nues
	if resource_path == "":
		return
		
	# 3. On charge la scne envoy?e par le r?seau
	var weapon_scene = load(resource_path)
	if weapon_scene == null:
		return
		
	# 4. On cr?e la nouvelle arme 3D
	var weapon_instance = weapon_scene.instantiate()
	
	# Pas besoin de weapon_stats pour le visuel des autres joueurs
	# (car leur AttackComponent sera d?sactiv? de toute faon)
		
	main_droite.add_child(weapon_instance)

func _on_peer_connected(peer_id: int) -> void:
	if equipment_component != null:
		var item = equipment_component.equipped_items.get("main_hand")
		var path = ""
		if item != null and item.get("weapon_scene") != null:
			path = item.weapon_scene.resource_path
		rpc_id(peer_id, "_rpc_update_visual_weapon", path)
