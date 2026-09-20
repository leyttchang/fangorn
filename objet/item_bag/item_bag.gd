@tool
extends RigidBody3D

@export var bag_scale: float = 1.0:
	set(value):
		bag_scale = max(0.1, value) # Empecher une taille negative ou 0
		_update_scale()

@export var item_data: Resource = null:
	set(value):
		item_data = value
		if item_data != null and "rarity" in item_data:
			rarity = item_data.rarity
		else:
			_update_vfx()

@export var item_amount: int = 1

@export_category("Rareté & VFX")
## Rareté de l'objet (-1 = caché, 0 = Commun, 1 = Magique, 2 = Rare, 3 = Légendaire, 4 = Unique)
@export var rarity: int = -1:
	set(value):
		rarity = value
		_update_vfx()

## Référence vers le nœud VFX actuellement allumé
var active_vfx: Node3D = null

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
	if item_data != null and "rarity" in item_data and rarity == -1:
		rarity = item_data.rarity
	_update_vfx()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	_keep_vfx_upright()

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	_keep_vfx_upright()

## Force le VFX actif à rester droit vers le haut dans le monde réel même si le sac roule
func _keep_vfx_upright() -> void:
	if active_vfx != null and is_instance_valid(active_vfx):
		active_vfx.global_basis = Basis.IDENTITY

## Active uniquement le VFX correspondant à la rareté et masque tous les autres
func _update_vfx() -> void:
	if not is_inside_tree(): return
	
	# Mapping rareté -> nœud VFX
	# 0: COMMON, 1: MAGIC, 2: RARE, 3: LEGENDARY, 4: UNIQUE
	var vfx_map = {
		0: get_node_or_null("Vfx_normal_loot"),
		1: get_node_or_null("Vfx_magic_loot"),
		2: get_node_or_null("Vfx_rare_loot"),
		3: get_node_or_null("Vfx_legendary_loot"),
		4: get_node_or_null("Vfx_unique_loot")
	}
	
	# Par défaut, masquer tous les VFX
	for key in vfx_map:
		var node = vfx_map[key]
		if node != null:
			node.visible = false
			
	active_vfx = null
	
	# Activer le bon VFX si la rareté est reconnue
	if rarity in vfx_map:
		active_vfx = vfx_map[rarity]
		if active_vfx != null:
			active_vfx.visible = true
			_keep_vfx_upright()

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
