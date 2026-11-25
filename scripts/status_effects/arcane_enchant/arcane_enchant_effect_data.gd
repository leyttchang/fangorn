class_name ArcaneEnchantEffectData
extends StatusEffectData

## StatusEffectData d'enchantement d'Arcane pour les monstres (Totem d'Arcane, élites, etc.) :
## - Affiche de légères lueurs violettes en orbite sur chaque monstre enchanté via `enemie_effect`
## - Périodiquement (`spawn_interval`, désynchronisé dès l'apparition), fait apparaître une `ArcaneFlare` à 1 PV
## - Zéro `on_process` par frame : écoute directement le signal `died` du `HealthComponent`

@export_group("Cadence & Échelonnement des Flares")
@export_range(1.5, 45.0, 0.5, "suffix:s") var spawn_interval: float = 10.5
@export_range(0.0, 10.0, 0.1, "suffix:s") var spawn_interval_jitter: float = 1.4
@export_range(0.2, 20.0, 0.1, "suffix:s") var initial_delay_min: float = 1.4
@export_range(0.5, 30.0, 0.1, "suffix:s") var initial_delay_max: float = 9.8
## Plafond simultané d'orbes d'arcane actives par monstre enchanté
@export_range(1, 10, 1) var max_flares_per_monster: int = 1
@export_range(1, 50, 1) var max_global_active_flares: int = 12
@export_range(0.0, 120.0, 1.0, "suffix:m") var trigger_player_range: float = 38.0

@export_group("Paramètres de l'ArcaneFlare")
@export_range(0.5, 15.0, 0.1, "suffix:m/s") var flare_speed_min: float = 2.6
@export_range(0.5, 18.0, 0.1, "suffix:m/s") var flare_speed_max: float = 5.2
@export_range(0.0, 5.0, 0.05, "suffix:m/s²") var flare_acceleration: float = 0.35
@export_range(1.0, 25.0, 0.01, "suffix:m/s") var flare_max_speed: float = 7.22
@export_range(1.0, 200.0, 1.0) var flare_damage: float = 18.0
@export_range(2.0, 60.0, 0.5, "suffix:s") var flare_lifetime: float = 20.0
@export_range(0.2, 12.0, 0.1, "suffix:rad/s") var flare_turn_speed: float = 2.6
@export_range(0.0, 25.0, 0.5) var flare_knockback: float = 4.0
@export var flare_scene: PackedScene = preload("res://scripts/status_effects/arcane_enchant/arcane_flare.tscn")

func on_apply(target: Node, component: Node, _is_refresh: bool) -> void:
	if target == null or not is_instance_valid(target):
		return
	var mob: Node3D = target as Node3D
	if mob == null or mob.get_tree() == null:
		return
	if ArcaneEnchantCoordinator.is_mob_invalid_or_dead(mob):
		return

	# Retrait événementiel immédiat à la mort du monstre (zéro polling par frame)
	if component != null and is_instance_valid(component):
		var hc: HealthComponent = mob.get_node_or_null("HealthComponent") as HealthComponent
		if hc != null:
			var eff_id_copy: String = effect_id
			var comp_weak: WeakRef = weakref(component)
			var on_died_cb: Callable = func() -> void:
				var comp_ref: Node = comp_weak.get_ref() as Node
				if comp_ref != null and is_instance_valid(comp_ref):
					if not comp_ref.multiplayer.has_multiplayer_peer() or comp_ref.is_multiplayer_authority():
						comp_ref.call_deferred("remove_effect", eff_id_copy)
			if not hc.died.is_connected(on_died_cb):
				hc.died.connect(on_died_cb, CONNECT_ONE_SHOT)

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
