class_name EnchantTotem
extends Node3D

signal totem_activated(player: Node3D)

@export_group("Configuration du Totem")
## Nœud enfant propre à l'élément du totem (ex: arcane_totem, fire_totem...)
@export var element_node: Node3D

## Spawner de monstres lié au totem ou à l'arène (auto-détecté dans l'arène parente si laissé vide)
@export var mob_spawner: MobRaycastSpawner

## Si vrai, le totem ne peut être activé qu'une seule fois
@export var one_shot: bool = true

@onready var interaction_component: InteractionComponent = $InteractionComponent if has_node("InteractionComponent") else null

var is_activated: bool = false

func _ready() -> void:
	# Détection automatique du nœud élémentaire s'il n'est pas assigné dans l'inspecteur
	if element_node == null:
		for child in get_children():
			if child != interaction_component and child.has_method("on_totem_activated"):
				element_node = child
				break
				
	# Détection automatique du MobRaycastSpawner (en enfant du totem ou dans l'arène parente)
	if mob_spawner == null:
		mob_spawner = _find_mob_spawner()

func _find_mob_spawner() -> MobRaycastSpawner:
	for child in get_children():
		if child is MobRaycastSpawner:
			return child
	var parent_node: Node = get_parent()
	if parent_node != null:
		for sibling in parent_node.get_children():
			if sibling is MobRaycastSpawner:
				return sibling
	return null

## Appelé automatiquement par InteractionComponent quand le joueur appuie sur E
func use(player: Node3D) -> void:
	interact(player)

func interact(player: Node3D) -> void:
	if is_activated and one_shot:
		return
		
	var player_path: NodePath = player.get_path() if player != null else NodePath("")
	if multiplayer.has_multiplayer_peer():
		_rpc_activate_totem.rpc(player_path)
	else:
		_rpc_activate_totem(player_path)

@rpc("any_peer", "call_local", "reliable")
func _rpc_activate_totem(player_path: NodePath) -> void:
	if is_activated and one_shot:
		return
	is_activated = true
	
	var player: Node3D = get_node_or_null(player_path) as Node3D if not player_path.is_empty() else null
	
	# Désactive l'interaction si usage unique
	if one_shot and interaction_component != null:
		interaction_component.hide_prompt()
		interaction_component.monitoring = false
		interaction_component.monitorable = false
		interaction_component.visible = false
	
	# 1. Comportement commun à TOUS les totems peu importe l'élément (spawn des monstres de l'arène, etc.)
	_on_common_totem_activated(player)
	
	# 2. Relais vers le nœud spécifique à l'élément (ex: arcane_totem)
	if element_node != null and element_node.has_method("on_totem_activated"):
		element_node.on_totem_activated(player, self)
	
	totem_activated.emit(player)

## Logique commune à tous les totems (spawn de la vague de monstres via MobRaycastSpawner, etc.)
func _on_common_totem_activated(player: Node3D) -> void:
	if mob_spawner == null:
		mob_spawner = _find_mob_spawner()
	if mob_spawner != null:
		mob_spawner.spawn_mobs()
		if player != null and is_instance_valid(player):
			mob_spawner.alert_all_mobs(player)
