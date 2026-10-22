class_name EnchantTotem
extends Node3D

signal totem_activated(player: Node3D)

@export_group("Configuration du Totem")
## Nœud enfant propre à l'élément du totem (ex: arcane_totem, fire_totem...)
@export var element_node: Node3D

## AnimationPlayer des VFX du totem (joue l'animation "end" à l'interaction)
@export var vfx_anim: AnimationPlayer

## Spawner de monstres lié au totem ou à l'arène
@export var mob_spawner: MobRaycastSpawner

## Si vrai, le totem ne peut être activé qu'une seule fois
@export var one_shot: bool = true

@onready var interaction_component: InteractionComponent = $InteractionComponent if has_node("InteractionComponent") else null

var is_activated: bool = false

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
	
	# 1. Comportement commun à TOUS les totems peu importe l'élément
	_on_common_totem_activated(player)
	
	# 2. Relais vers le nœud spécifique à l'élément (ex: arcane_totem)
	if element_node != null and element_node.has_method("on_totem_activated"):
		element_node.on_totem_activated(player, self)
	
	totem_activated.emit(player)

## Logique commune à tous les totems
func _on_common_totem_activated(player: Node3D) -> void:
	_play_vfx_end_animation()
	
	if mob_spawner != null:
		mob_spawner.spawn_mobs()
		if player != null and is_instance_valid(player):
			mob_spawner.alert_all_mobs(player)

## Joue l'animation "end" sur l'AnimationPlayer assigné dans l'inspecteur
func _play_vfx_end_animation() -> void:
	if vfx_anim != null and vfx_anim.has_animation(&"end"):
		vfx_anim.play(&"end")
