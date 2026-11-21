class_name LightningEnchantEffectData
extends StatusEffectData

## StatusEffectData d'enchantement Foudre pour les monstres (Totem Lightning, élites, etc.) :
## - Affiche des particules électriques continues sur chaque monstre enchanté (via `enemie_effect`)
## - Toutes les `pulse_interval` secondes, relie les monstres enchantés par une chaîne d'éclairs :
##     1. Petite chaîne fine qui pulse pendant `telegraph_duration` (~1.0s) en suivant leurs mouvements
##     2. Devient d'un coup large pendant `strike_duration` (~0.38s) et inflige `lightning_damage` aux joueurs touchés

@export_group("Chaînes d'Éclairs (Timing & Rebonds)")
## Intervalle en secondes entre deux salves de chaînes d'éclairs
@export var pulse_interval: float = 4.5
## Délai avant la toute première chaîne quand un groupe de monstres reçoit l'enchantement
@export var initial_pulse_delay: float = 2.0
## Distance maximale entre deux monstres enchantés pour qu'un arc se forme (façon Chain Lightning)
@export var bounce_radius: float = 22.0
## Nombre maximal de rebonds successifs par chaîne (évite les rebonds dans tous les sens)
@export var max_bounces_per_chain: int = 6

@export_group("Télégraphe & Décharge (Dégâts)")
## Durée de la petite chaîne qui pulse avant l'impact (en secondes)
@export var telegraph_duration: float = 1.0
## Durée du gros arc large qui inflige les dégâts avant de disparaître (en secondes)
@export var strike_duration: float = 0.38
## Dégâts de foudre infligés au joueur touché (réduits par sa lightning_resistance)
@export var lightning_damage: float = 22.0
## Force de recul appliquée perpendiculairement hors de la chaîne d'éclairs
@export var knockback_force: float = 8.5
## Rayon de collision de l'arc large lors de la décharge (en mètres)
@export var strike_hit_radius: float = 0.45

@export_group("Apparence de la Chaîne")
@export var telegraph_thickness: float = 0.026
@export var strike_thickness: float = 0.165
@export var telegraph_spread: float = 0.11
@export var strike_spread: float = 0.40
@export var segments_count: int = 6
@export var line_material_1: Material
@export var line_material_2: Material
@export var line_material_3: Material
@export var sphere_material: Material
@export var strike_sparks_scene: PackedScene

func on_apply(target: Node, _component: Node, _is_refresh: bool) -> void:
	var mob := target as Node3D
	if mob == null or mob.get_tree() == null:
		return
	if EnchantLightningLink._is_mob_invalid_or_dead(mob):
		return
	var coord := LightningEnchantCoordinator.get_or_create(mob.get_tree(), self)
	if coord != null:
		coord.register_mob(mob)

func on_remove(target: Node, _component: Node) -> void:
	var mob := target as Node3D
	if mob == null or mob.get_tree() == null:
		return
	var host_parent: Node = mob.get_tree().current_scene if mob.get_tree().current_scene != null else mob.get_tree().root
	if host_parent == null:
		return
	var coord := host_parent.get_node_or_null(LightningEnchantCoordinator.COORDINATOR_NODE_NAME) as LightningEnchantCoordinator
	if coord != null and is_instance_valid(coord):
		coord.unregister_mob(mob)

func on_process(target: Node, component: Node, _delta: float, _time_remaining: float, _total_duration: float) -> void:
	var mob := target as Node3D
	if mob == null or component == null:
		return
	# Retirer immédiatement l'effet et les particules dès que le monstre meurt (sans attendre les 3s du cadavre)
	if EnchantLightningLink._is_mob_invalid_or_dead(mob):
		if not component.multiplayer.has_multiplayer_peer() or component.is_multiplayer_authority():
			component.call_deferred("remove_effect", effect_id)
