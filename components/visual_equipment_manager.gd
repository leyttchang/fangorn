class_name VisualEquipmentManager
extends Node

# Les liens vers tes autres noeuds
@export var equipment_component: EquipmentComponent
@export var main_droite: Marker3D

var _is_ready_finished: bool = false

func _ready() -> void:
	if equipment_component != null:
		# On ecoute quand l'equipement change !
		equipment_component.equipment_changed.connect(_on_equipment_changed)
		if multiplayer.has_multiplayer_peer() and get_parent().is_multiplayer_authority():
			multiplayer.peer_connected.connect(_on_peer_connected)
			
	# On attend la fin de l'initialisation pour eviter d'envoyer un RPC au spawn
	call_deferred("_set_ready_finished")

func _set_ready_finished() -> void:
	_is_ready_finished = true

func _on_equipment_changed(slot_name: String, item: ItemData) -> void:
	# On ne reagit que si c'est la main droite
	if slot_name == "main_hand":
		# Envoi reseau ! On evite de le faire au tout debut car l'arme est deja equipee localement par le _ready() de Player.gd
		if _is_ready_finished and multiplayer.has_multiplayer_peer() and get_parent().is_multiplayer_authority():
			var path = ""
			if item != null and item.get("weapon_scene") != null:
				path = item.weapon_scene.resource_path
			rpc("_rpc_update_visual_weapon", path)
		
		# 1. On detruit l'ancienne arme (s'il y en a une)
		for child in main_droite.get_children():
			if not child is WeaponImpactComponent and child.name != "weapon_impact_componant":
				child.queue_free()
			
		# 2. Si on a juste desequipe (mains nues), on s'arrete la
		if item == null or item.get("weapon_scene") == null:
			return
			
		# 3. On cree la nouvelle arme 3D
		var weapon_instance = item.weapon_scene.instantiate()
		
		# 4. L'INJECTION MAGIQUE DES STATS :
		# C'est ici qu'on donne le fichier .tres a la scene 3D vide !
		if weapon_instance is Weapon:
			weapon_instance.weapon_stats = item
			
		# 5. On l'attache physiquement a la main
		main_droite.add_child(weapon_instance)

# ==========================================
# GESTION RESEAU DE L'APPARENCE DE L'ARME
# ==========================================
@rpc("any_peer", "call_remote", "reliable")
func _rpc_update_visual_weapon(resource_path: String) -> void:
	# 1. On detruit l'ancienne arme
	for child in main_droite.get_children():
		if not child is WeaponImpactComponent and child.name != "weapon_impact_componant":
			child.queue_free()
		
	# 2. Si mains nues
	if resource_path == "":
		return
		
	# 3. On charge la scene envoyee par le reseau
	var weapon_scene = load(resource_path)
	if weapon_scene == null:
		return
		
	# 4. On cree la nouvelle arme 3D
	var weapon_instance = weapon_scene.instantiate()
	
	# Pas besoin de weapon_stats pour le visuel des autres joueurs
	# (car leur AttackComponent sera desactive de toute facon)
		
	main_droite.add_child(weapon_instance)

func _on_peer_connected(peer_id: int) -> void:
	if equipment_component != null:
		var item = equipment_component.equipped_items.get("main_hand")
		var path = ""
		if item != null and item.get("weapon_scene") != null:
			path = item.weapon_scene.resource_path
		rpc_id(peer_id, "_rpc_update_visual_weapon", path)
