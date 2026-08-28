@tool
extends RigidBody3D

@export var bag_scale: float = 1.0:
	set(value):
		bag_scale = max(0.1, value) # Empecher une taille negative ou 0
		_update_scale()

@export var item_data: Resource = null
@export var item_amount: int = 1

func _update_scale() -> void:
	if not is_inside_tree(): return
	
	if has_node("bag_mesh"):
		$bag_mesh.scale = Vector3(bag_scale, bag_scale, bag_scale)
		
	# On applique le scale sur le NOEUD CollisionShape (autorise de facon uniforme), 
	# sans modifier la ressource de base qui est partagee !
	if has_node("CollisionShape3D"):
		$CollisionShape3D.scale = Vector3(bag_scale, bag_scale, bag_scale)
		
	if has_node("InteractionComponent"):
		$InteractionComponent.scale = Vector3(bag_scale, bag_scale, bag_scale)

func _ready() -> void:
	_update_scale()

func interact(player: Node3D) -> void:
	# Le client demande au serveur de ramasser
	rpc_id(1, "_rpc_request_pickup", player.get_path())

@rpc("any_peer", "call_local", "reliable")
func _rpc_request_pickup(player_path: NodePath) -> void:
	if not multiplayer.is_server(): return
	
	# Le serveur verifie l'existance de l'objet
	if item_data == null:
		queue_free()
		return
		
	var player = get_node_or_null(player_path)
	if player != null:
		var inv = player.get_node_or_null("InventoryComponent")
		if inv != null:
			# On envoie les donnees de l'objet au client qui a ramasse
			var item_dict = inv.pack_item(item_data)
			var target_peer = player.get_multiplayer_authority()
			inv.rpc_id(target_peer, "_rpc_receive_pickup", item_dict, item_amount)
			print("[ITEM BAG] Le serveur valide le ramassage pour : ", player.name)
	
	queue_free()
