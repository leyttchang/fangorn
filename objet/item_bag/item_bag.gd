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
var _sleep_settle_timer: float = 0.0

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
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
	else:
		if not sleeping_state_changed.is_connected(_on_sleeping_state_changed):
			sleeping_state_changed.connect(_on_sleeping_state_changed)
	_update_scale()
	if item_data != null and "rarity" in item_data and rarity == -1:
		rarity = item_data.rarity
	_update_vfx()

func _on_sleeping_state_changed() -> void:
	if Engine.is_editor_hint():
		return
	if not sleeping:
		_sleep_settle_timer = 0.0
		if active_vfx != null:
			set_process(true)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_keep_vfx_upright()
	if sleeping:
		_sleep_settle_timer += delta
		if _sleep_settle_timer >= 0.25:
			set_process(false)
	else:
		_sleep_settle_timer = 0.0

## Force le VFX actif à rester droit vers le haut dans le monde réel même si le sac roule
func _keep_vfx_upright() -> void:
	if active_vfx != null and is_instance_valid(active_vfx):
		active_vfx.global_basis = Basis.IDENTITY

func _set_vfx_node_state(node: Node3D, is_active: bool) -> void:
	if node == null:
		return
	node.visible = is_active
	if Engine.is_editor_hint():
		return
	node.process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED
	for child in node.find_children("*", "AnimationPlayer", true, false):
		var ap := child as AnimationPlayer
		if ap == null:
			continue
		if is_active:
			if ap.has_animation("anim"):
				if not ap.is_playing() or ap.current_animation != "anim":
					ap.play("anim")
			elif not ap.autoplay.is_empty() and ap.has_animation(ap.autoplay):
				if not ap.is_playing():
					ap.play(ap.autoplay)
			else:
				for anim_name in ap.get_animation_list():
					if anim_name != &"RESET":
						if not ap.is_playing():
							ap.play(anim_name)
						break
		else:
			ap.stop()

## Active uniquement le VFX correspondant à la rareté et désactive complètement les 4 autres
func _update_vfx() -> void:
	if not is_inside_tree():
		return

	# Mapping rareté -> nœud VFX
	# 0: COMMON, 1: MAGIC, 2: RARE, 3: LEGENDARY, 4: UNIQUE
	var vfx_nodes: Array[Node3D] = [
		get_node_or_null("Vfx_normal_loot") as Node3D,
		get_node_or_null("Vfx_magic_loot") as Node3D,
		get_node_or_null("Vfx_rare_loot") as Node3D,
		get_node_or_null("Vfx_legendary_loot") as Node3D,
		get_node_or_null("Vfx_unique_loot") as Node3D
	]

	active_vfx = null
	for i in range(vfx_nodes.size()):
		var node: Node3D = vfx_nodes[i]
		if node == null:
			continue
		if i == rarity:
			active_vfx = node
		else:
			_set_vfx_node_state(node, false)

	if active_vfx != null:
		_set_vfx_node_state(active_vfx, true)
		_keep_vfx_upright()
		if not Engine.is_editor_hint():
			_sleep_settle_timer = 0.0
			set_process(true)
	elif not Engine.is_editor_hint():
		set_process(false)

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
