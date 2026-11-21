extends Node3D

@export_group("Enchantement Glace")
## Effet de statut appliqué à tous les monstres spawnés par ce totem (réutilisable ailleurs via StatusEffectComponent)
@export var monster_ice_effect: StatusEffectData = preload("res://scripts/status_effects/ice_enchant/totem_ice_enchant.tres")
## Durée de l'enchantement sur les monstres (quasi-infini : se retire automatiquement dès la mort du monstre)
@export var effect_duration: float = 99999.0

## Appelé par le script parent EnchantTotem (enchant_totem.gd) quand un joueur active le totem
func on_totem_activated(_player: Node3D, totem_root: EnchantTotem) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if totem_root == null or totem_root.mob_spawner == null or monster_ice_effect == null:
		return

	var spawner: MobRaycastSpawner = totem_root.mob_spawner
	if not spawner.mob_spawned.is_connected(_on_spawner_mob_spawned):
		spawner.mob_spawned.connect(_on_spawner_mob_spawned)

	# Laisser 2 frames aux monstres (et au MultiplayerSpawner côté clients) pour terminer leur _ready()
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(spawner):
		return

	for mob: Node3D in spawner.get_alive_mobs():
		_apply_ice_enchant(mob)

func on_totem_completed(totem_root: EnchantTotem) -> void:
	if totem_root != null and totem_root.mob_spawner != null:
		if totem_root.mob_spawner.mob_spawned.is_connected(_on_spawner_mob_spawned):
			totem_root.mob_spawner.mob_spawned.disconnect(_on_spawner_mob_spawned)

func _on_spawner_mob_spawned(mob: Node3D) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_ice_enchant(mob)

func _apply_ice_enchant(mob: Node3D) -> void:
	if mob == null or not is_instance_valid(mob) or mob.is_queued_for_deletion():
		return
	var status_comp: StatusEffectComponent = _find_status_component(mob)
	if status_comp != null:
		status_comp.apply_effect(monster_ice_effect, effect_duration)

func _find_status_component(mob: Node3D) -> StatusEffectComponent:
	for child: Node in mob.get_children():
		if child is StatusEffectComponent:
			return child as StatusEffectComponent
	return mob.find_child("*status_effect*", true, false) as StatusEffectComponent
