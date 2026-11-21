class_name ArcaneEnchantEffectData
extends StatusEffectData

## StatusEffectData d'enchantement d'Arcane pour les monstres (Totem d'Arcane, élites, etc.) :
## - Affiche de légères lueurs/étincelles violettes en orbite sur chaque monstre enchanté via `enemie_effect`
## - Périodiquement (`spawn_interval`, désynchronisé dès l'apparition), fait apparaître une `ArcaneFlare` à 1 PV
## - Plafonne le nombre d'orbes simultanées par monstre (`max_flares_per_monster = 2`) et globalement
## - Chaque orbe naît avec une vitesse aléatoire (`flare_speed_min`..`flare_speed_max`) et accélère lentement au fil du temps

@export_group("Cadence & Échelonnement des Flares")
@export_range(1.5, 45.0, 0.5, "suffix:s") var spawn_interval: float = 10.0
@export_range(0.0, 10.0, 0.1, "suffix:s") var spawn_interval_jitter: float = 1.2
@export_range(0.2, 20.0, 0.1, "suffix:s") var initial_delay_min: float = 1.2
@export_range(0.5, 30.0, 0.1, "suffix:s") var initial_delay_max: float = 9.5
## Plafond simultané d'orbes d'arcane actives par monstre enchanté
@export_range(1, 10, 1) var max_flares_per_monster: int = 2
@export_range(1, 50, 1) var max_global_active_flares: int = 18
@export_range(0.0, 120.0, 1.0, "suffix:m") var trigger_player_range: float = 38.0

@export_group("Paramètres de l'ArcaneFlare")
## Vitesse initiale minimale d'une orbe à son apparition (en m/s)
@export_range(0.5, 15.0, 0.1, "suffix:m/s") var flare_speed_min: float = 2.6
## Vitesse initiale maximale d'une orbe à son apparition (en m/s — certaines partent déjà plus vite que les monstres à 4.5 m/s)
@export_range(0.5, 18.0, 0.1, "suffix:m/s") var flare_speed_max: float = 5.2
## Accélération progressive de l'orbe au fil du temps (en m/s²)
@export_range(0.0, 5.0, 0.05, "suffix:m/s²") var flare_acceleration: float = 0.35
## Vitesse plafond maximale atteignable par l'orbe (en m/s)
@export_range(1.0, 25.0, 0.1, "suffix:m/s") var flare_max_speed: float = 8.5
@export_range(1.0, 200.0, 1.0) var flare_damage: float = 18.0
@export_range(2.0, 60.0, 0.5, "suffix:s") var flare_lifetime: float = 22.0
@export_range(0.2, 12.0, 0.1, "suffix:rad/s") var flare_turn_speed: float = 2.6
@export_range(0.0, 25.0, 0.5) var flare_knockback: float = 4.0
@export var flare_scene: PackedScene = preload("res://scripts/status_effects/arcane_enchant/arcane_flare.tscn")

func on_apply(target: Node, _component: Node, _is_refresh: bool) -> void:
	if target == null or not is_instance_valid(target):
		return
	var mob: Node3D = target as Node3D
	if mob == null or mob.get_tree() == null:
		return
	if ArcaneEnchantCoordinator.is_mob_invalid_or_dead(mob):
		return
	var coord: ArcaneEnchantCoordinator = ArcaneEnchantCoordinator.get_or_create(mob.get_tree(), self)
	if coord != null:
		coord.register_mob(mob)

func on_remove(target: Node, _component: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var mob: Node3D = target as Node3D
	if mob == null or mob.get_tree() == null:
		return
	var host_parent: Node = mob.get_tree().current_scene if mob.get_tree().current_scene != null else mob.get_tree().root
	if host_parent == null:
		return
	var coord: ArcaneEnchantCoordinator = host_parent.get_node_or_null(ArcaneEnchantCoordinator.COORDINATOR_NODE_NAME) as ArcaneEnchantCoordinator
	if coord != null and is_instance_valid(coord):
		coord.unregister_mob(mob)

func on_process(target: Node, component: Node, _delta: float, _time_remaining: float, _total_duration: float) -> void:
	if target == null or not is_instance_valid(target) or component == null or not is_instance_valid(component):
		return
	var mob: Node3D = target as Node3D
	if mob == null:
		return
	# Retirer immédiatement l'effet et l'aura dès que le monstre meurt (sans attendre les 3s du cadavre)
	if ArcaneEnchantCoordinator.is_mob_invalid_or_dead(mob):
		if not component.multiplayer.has_multiplayer_peer() or component.is_multiplayer_authority():
			component.call_deferred("remove_effect", effect_id)
