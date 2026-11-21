class_name FireEnchantEffectData
extends StatusEffectData

## StatusEffectData d'enchantement Feu pour les monstres (Totem de Feu, élites, etc.) :
## - Affiche des particules de feu autour du monstre (via `enemie_effect`)
## - Laisse une traînée de feu au sol derrière le monstre lorsqu'il se déplace, infligeant un DoT au joueur qui marche dessus
## - Donne aux attaques du monstre une chance d'enflammer le joueur avec l'effet `burn.tres` existant

@export_group("Traînée de Feu (Sol)")
## Scène de flaque de feu instanciée derrière le monstre (placeholder remplaçable à tout moment)
@export var trail_patch_scene: PackedScene
## Optionnel : scène purement visuelle pour remplacer uniquement le VFX placeholder tout en gardant la hitbox et le DoT
@export var trail_custom_vfx_scene: PackedScene
## Distance horizontale (en mètres) parcourue par le monstre avant de déposer une nouvelle flaque de feu
@export var trail_step_distance: float = 0.85
## Léger recul (en mètres) derrière la direction de déplacement pour que la traînée apparaisse sous ses talons
@export var trail_behind_offset: float = 0.40
## Rayon (en mètres) de chaque zone de feu de la traînée
@export var trail_radius: float = 0.95
## Durée de vie (en secondes) de chaque flaque de feu au sol
@export var trail_duration: float = 4.0
## Dégâts de feu infligés par tick au joueur qui marche/reste dans la traînée (réduits par sa fire_resistance)
@export var trail_tick_damage: float = 5.0
## Intervalle en secondes entre deux ticks de dégâts sur la traînée de feu
@export var trail_tick_interval: float = 0.40
## Nombre maximal de flaques actives simultanément par monstre
@export var max_patches_per_mob: int = 16

@export_group("Attaques Enflammées (Brûlure)")
## Effet de statut de brûlure existant appliqué au joueur quand une attaque l'enflamme
@export var burn_status_effect: StatusEffectData = preload("res://scripts/status_effects/burn/burn.tres")
## Probabilité (0.0 à 1.0) qu'une attaque du monstre enflamme le joueur
@export_range(0.0, 1.0) var burn_chance_on_hit: float = 0.35
## Durée en secondes de l'effet de brûlure appliqué au joueur
@export var burn_duration: float = 5.0


func on_apply(target: Node, _component: Node, _is_refresh: bool) -> void:
	var mob := target as Node3D
	if mob == null or mob.get_tree() == null:
		return
	if FireEnchantCoordinator.is_mob_invalid_or_dead(mob):
		return
	var coord := FireEnchantCoordinator.get_or_create(mob.get_tree(), self)
	if coord != null:
		coord.register_mob(mob, self)


func on_remove(target: Node, _component: Node) -> void:
	var mob := target as Node3D
	if mob == null or mob.get_tree() == null:
		return
	var host_parent: Node = mob.get_tree().current_scene if mob.get_tree().current_scene != null else mob.get_tree().root
	if host_parent == null:
		return
	var coord := host_parent.get_node_or_null(FireEnchantCoordinator.COORDINATOR_NODE_NAME) as FireEnchantCoordinator
	if coord != null and is_instance_valid(coord):
		coord.unregister_mob(mob)


func on_process(target: Node, component: Node, _delta: float, _time_remaining: float, _total_duration: float) -> void:
	var mob := target as Node3D
	if mob == null or component == null:
		return
	# Retire immédiatement l'effet et l'aura de particules dès que le monstre meurt (sans attendre la disparition du cadavre)
	if FireEnchantCoordinator.is_mob_invalid_or_dead(mob):
		if not component.multiplayer.has_multiplayer_peer() or component.is_multiplayer_authority():
			component.call_deferred("remove_effect", effect_id)
