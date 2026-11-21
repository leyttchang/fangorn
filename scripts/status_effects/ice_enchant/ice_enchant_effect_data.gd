class_name IceEnchantEffectData
extends StatusEffectData

## StatusEffectData d'enchantement de Glace pour les monstres (Totem de Glace, élites, etc.) :
## - Affiche une aura glaciale continue (brume + flocons en orbite) sur chaque monstre enchanté via `enemie_effect`
## - Périodiquement (`nova_interval`), le monstre émet une petite Ice Nova autour de lui (`nova_scene`)
## - Cette nova n'inflige AUCUN dégât, mais applique un effet de slow cumulable (`player_slow_effect`) au joueur

@export_group("Cadence & Portée de la Petite Ice Nova")
## Intervalle moyen en secondes entre deux petites novas de glace par monstre
@export_range(1.0, 15.0, 0.1) var nova_interval: float = 3.8
## Légère variation aléatoire autour de `nova_interval` pour désynchroniser naturellement les monstres
@export_range(0.0, 3.0, 0.05) var nova_interval_jitter: float = 0.45
## Délai minimal avant la toute première nova après l'apparition du monstre
@export_range(0.3, 10.0, 0.1) var initial_delay_min: float = 1.2
## Délai maximal avant la toute première nova après l'apparition du monstre
@export_range(0.5, 12.0, 0.1) var initial_delay_max: float = 3.6
## Rayon de la petite nova de glace autour du monstre (en mètres, contre 10m pour l'Ice Nova du joueur)
@export_range(1.5, 12.0, 0.1) var nova_radius: float = 4.2
## Distance maximale d'un joueur vivant pour qu'un monstre déclenche ses novas (0 = déclenche même à l'autre bout de la carte)
@export_range(0.0, 80.0, 0.5) var trigger_player_range: float = 26.0

@export_group("Effet de Ralentissement & Scène VFX")
## Scène de la petite Ice Nova (utilise les VFX d'ice_nova sans dégâts)
@export var nova_scene: PackedScene = preload("res://scripts/status_effects/ice_enchant/monster_ice_nova.tscn")
## Effet de statut de slow cumulable appliqué au joueur touché par chaque nova
@export var player_slow_effect: StatusEffectData = preload("res://scripts/status_effects/ice_enchant/ice_nova_slow.tres")
## Durée du slow appliqué / rafraîchi à chaque nova touchant le joueur (en secondes)
@export_range(1.0, 20.0, 0.25) var slow_duration: float = 5.0

func on_apply(target: Node, _component: Node, _is_refresh: bool) -> void:
	var mob := target as Node3D
	if mob == null or mob.get_tree() == null:
		return
	if IceEnchantCoordinator.is_mob_invalid_or_dead(mob):
		return
	var coord := IceEnchantCoordinator.get_or_create(mob.get_tree(), self)
	if coord != null:
		coord.register_mob(mob)

func on_remove(target: Node, _component: Node) -> void:
	var mob := target as Node3D
	if mob == null or mob.get_tree() == null:
		return
	var host_parent: Node = mob.get_tree().current_scene if mob.get_tree().current_scene != null else mob.get_tree().root
	if host_parent == null:
		return
	var coord := host_parent.get_node_or_null(IceEnchantCoordinator.COORDINATOR_NODE_NAME) as IceEnchantCoordinator
	if coord != null and is_instance_valid(coord):
		coord.unregister_mob(mob)

func on_process(target: Node, component: Node, _delta: float, _time_remaining: float, _total_duration: float) -> void:
	var mob := target as Node3D
	if mob == null or component == null:
		return
	# Retirer immédiatement l'effet et l'aura dès que le monstre meurt (sans attendre les 3s du cadavre)
	if IceEnchantCoordinator.is_mob_invalid_or_dead(mob):
		if not component.multiplayer.has_multiplayer_peer() or component.is_multiplayer_authority():
			component.call_deferred("remove_effect", effect_id)
