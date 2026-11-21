class_name EnchantTotem
extends Node3D

signal totem_activated(player: Node3D)
signal totem_completed(element: String)
signal totem_reward_claimed(reward_dict: Dictionary, player: CharacterBody3D)

enum UIStyleMode {
	USE_GLOBAL_SETTING, ## Suit SettingsManager.ui_style (Menu Options)
	FORCE_MORIA_D2,     ## Force le style Pierre de la Moria / Diablo II
	FORCE_CLASSIC       ## Force l'ancien style Classique
}

@export_group("Configuration du Totem")
## Élément associé à ce totem (transmis au Boss Final et utilisé pour filtrer le Sort et l'Attaque de récompense)
@export_enum("arcane", "lightning", "fire", "ice") var totem_element: String = "arcane"

## Niveau d'objet (ilvl) du totem et de l'arme Légendaire+ proposée en récompense (synchronisé avec `mob_spawner.encounter_level`, min 1)
@export var totem_ilvl: int = 1

## Nœud enfant propre à l'élément du totem (ex: arcane_totem, lightning_totem, fire_totem, ice_totem)
@export var element_node: Node3D

## AnimationPlayer des VFX du totem (joue l'animation "end" à l'activation du combat)
@export var vfx_anim: AnimationPlayer

## Spawner de monstres lié au totem ou à l'arène
@export var mob_spawner: MobRaycastSpawner

## Si vrai, le combat du totem ne peut être déclenché qu'une seule fois
@export var one_shot: bool = true

@export_group("Textes d'Interaction")
## Texte affiché avant l'activation du combat
@export var prompt_activate: String = "Press [E] to challenge the Totem"
## Texte affiché une fois tous les monstres du totem vaincus
@export var prompt_reward_ready: String = "Press [E] to claim the Totem's blessing"
## Texte affiché après que le joueur a réclamé sa récompense
@export var prompt_reward_claimed: String = "The purified Totem slumbers"

@export_group("Interface de Récompenses")
## Choix du style visuel (par défaut suit le réglage global SettingsManager)
@export var ui_style_mode: UIStyleMode = UIStyleMode.USE_GLOBAL_SETTING
## Scène d'interface Moria / Diablo II
@export var d2_reward_ui_scene: PackedScene = preload("res://map/encounters/pnj_buff_choice/reward_choice_ui_d2.tscn")
## Scène d'interface Classique
@export var reward_ui_scene: PackedScene = preload("res://map/encounters/pnj_buff_choice/reward_choice_ui.tscn")

@onready var interaction_component: InteractionComponent = $InteractionComponent if has_node("InteractionComponent") else null

var is_activated: bool = false
var is_completed: bool = false
var reward_claimed_local: bool = false

var _initial_interaction_layer: int = 32
var _player_offered_choices: Dictionary = {}
var _claimed_players: Dictionary = {}
var _active_ui: CanvasLayer = null
var _blessing_light_tween: Tween = null


func _ready() -> void:
	add_to_group("EnchantTotem")
	totem_element = _resolve_totem_element()
	totem_ilvl = get_effective_ilvl()

	if interaction_component != null:
		if interaction_component.collision_layer != 0:
			_initial_interaction_layer = interaction_component.collision_layer
		_set_interaction_enabled(true, _get_formatted_activate_prompt())


func _exit_tree() -> void:
	if _blessing_light_tween != null and _blessing_light_tween.is_valid():
		_blessing_light_tween.kill()
		_blessing_light_tween = null


func _resolve_totem_element() -> String:
	var hint: String = ""
	if element_node != null:
		hint += element_node.name.to_lower() + " "
	if not scene_file_path.is_empty():
		hint += scene_file_path.get_file().to_lower()

	if "lightning" in hint or "thunder" in hint or "eclair" in hint:
		return "lightning"
	if "fire" in hint or "feu" in hint or "flame" in hint:
		return "fire"
	if "ice" in hint or "frost" in hint or "glace" in hint:
		return "ice"
	if "arcane" in hint:
		return "arcane"
	return totem_element


## Résout l'ilvl effectif du totem (synchronisé avec `mob_spawner.encounter_level`, `EnchantArena`, ou `SmartSpawner` en mode Vagues, min 1)
func get_effective_ilvl() -> int:
	var best_ilvl: int = maxi(1, totem_ilvl)
	if mob_spawner != null and mob_spawner.encounter_level > best_ilvl:
		best_ilvl = mob_spawner.encounter_level
	var parent_arena: Node = get_parent()
	if parent_arena != null and "totem_ilvl" in parent_arena:
		var arena_lvl: int = int(parent_arena.get("totem_ilvl"))
		if arena_lvl > best_ilvl:
			best_ilvl = arena_lvl
	if best_ilvl <= 1 and is_inside_tree() and get_tree() != null:
		if GameData.current_game_mode == GameData.GameMode.WAVE:
			var spawners: Array[Node] = get_tree().get_nodes_in_group("SmartSpawner")
			if not spawners.is_empty() and "current_wave" in spawners[0]:
				var wave_num: int = int(spawners[0].get("current_wave"))
				if wave_num > 0:
					best_ilvl = maxi(best_ilvl, int(float(wave_num) / 1.5))
	return maxi(1, best_ilvl)


# =========================================================================
# INTERACTION JOUEUR (PHASE 1 : ACTIVATION  |  PHASE 3 : RÉCOMPENSE)
# =========================================================================

## Appelé automatiquement par InteractionComponent quand le joueur appuie sur E
func use(player: Node3D) -> void:
	interact(player)


func interact(player: Node3D) -> void:
	# Phase 3 : Le combat du totem est terminé -> ouverture du choix de récompense
	if is_completed:
		var player_body: CharacterBody3D = player as CharacterBody3D
		if player_body == null:
			return
		if multiplayer.has_multiplayer_peer() and not player_body.is_multiplayer_authority():
			return
		if _has_player_claimed(player_body):
			_refresh_prompt_text(prompt_reward_claimed)
			return
		_open_reward_window(player_body)
		return

	# Combat en cours (activé mais pas encore complété) -> aucune interaction possible
	if is_activated and one_shot:
		return

	# Phase 1 : Activation du combat du totem
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
	totem_element = _resolve_totem_element()
	totem_ilvl = get_effective_ilvl()

	var player: Node3D = get_node_or_null(player_path) as Node3D if not player_path.is_empty() else null

	# Désactive complètement l'interaction pendant toute la durée du combat
	if one_shot:
		_set_interaction_enabled(false, "")

	# 1. Comportement commun à TOUS les totems peu importe l'élément
	_on_common_totem_activated(player)

	# 2. Relais vers le nœud spécifique à l'élément (ex: lightning_totem, arcane_totem, fire_totem, ice_totem)
	if element_node != null and element_node.has_method("on_totem_activated"):
		element_node.call("on_totem_activated", player, self)

	totem_activated.emit(player)


## Logique commune de lancement du combat
func _on_common_totem_activated(player: Node3D) -> void:
	_play_vfx_end_animation()

	if mob_spawner != null:
		if mob_spawner.encounter_level < totem_ilvl:
			mob_spawner.encounter_level = totem_ilvl

		# Sur le serveur (ou en solo), on écoute la défaite de tous les monstres pour valider le totem
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
			if not mob_spawner.all_mobs_defeated.is_connected(_on_spawner_all_mobs_defeated):
				mob_spawner.all_mobs_defeated.connect(_on_spawner_all_mobs_defeated, CONNECT_ONE_SHOT)

		var spawned: Array[Node3D] = mob_spawner.spawn_mobs()
		if player != null and is_instance_valid(player):
			mob_spawner.alert_all_mobs(player)

		# Sécurité : si aucun monstre n'était configuré dans un test, valider immédiatement côté serveur
		if (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()) and spawned.is_empty() and mob_spawner.get_alive_mobs_count() == 0:
			call_deferred("_on_spawner_all_mobs_defeated")
	else:
		# Si un totem est posé isolément sans spawner dans une scène de test, valider côté serveur
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
			call_deferred("_on_spawner_all_mobs_defeated")


# =========================================================================
# PHASE 2 : FIN DU COMBAT & RÉACTIVATION DE L'INTERACTION DE RÉCOMPENSE
# =========================================================================

func _on_spawner_all_mobs_defeated() -> void:
	if is_completed:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var elem: String = _resolve_totem_element()
	var resolved_ilvl: int = get_effective_ilvl()
	if multiplayer.has_multiplayer_peer():
		_rpc_mark_totem_completed.rpc(elem, resolved_ilvl)
	else:
		_rpc_mark_totem_completed(elem, resolved_ilvl)


@rpc("authority", "call_local", "reliable")
func _rpc_mark_totem_completed(elem: String, resolved_ilvl: int = 1) -> void:
	if is_completed:
		return
	is_completed = true
	totem_element = elem
	totem_ilvl = maxi(1, resolved_ilvl)

	GameData.register_completed_totem(elem, get_tree())
	if element_node != null and element_node.has_method("on_totem_completed"):
		element_node.call("on_totem_completed", self)

	# Réactive l'interaction sur les clients qui n'ont pas encore réclamé leur récompense
	if not reward_claimed_local:
		_set_interaction_enabled(true, _get_formatted_reward_prompt())
		_set_blessing_visual_active(true)
	else:
		_set_interaction_enabled(true, prompt_reward_claimed)

	totem_completed.emit(elem)


# =========================================================================
# PHASE 3 : INTERFACE DE CHOIX & ATTRIBUTION DE LA RÉCOMPENSE PAR JOUEUR
# =========================================================================

func _get_player_key(player: CharacterBody3D) -> int:
	if player == null:
		return 0
	if multiplayer.has_multiplayer_peer():
		return player.get_multiplayer_authority()
	return player.get_instance_id()


func _has_player_claimed(player: CharacterBody3D) -> bool:
	if reward_claimed_local and (not multiplayer.has_multiplayer_peer() or (player != null and player.is_multiplayer_authority())):
		return true
	var p_key: int = _get_player_key(player)
	return bool(_claimed_players.get(p_key, false))


func _get_selected_ui_scene() -> PackedScene:
	var use_d2: bool = true
	match ui_style_mode:
		UIStyleMode.FORCE_MORIA_D2:
			use_d2 = true
		UIStyleMode.FORCE_CLASSIC:
			use_d2 = false
		UIStyleMode.USE_GLOBAL_SETTING:
			if get_tree() != null and get_tree().root != null and get_tree().root.has_node("SettingsManager"):
				var sm: Node = get_tree().root.get_node("SettingsManager")
				if "ui_style" in sm:
					use_d2 = (int(sm.get("ui_style")) == 1)
	if use_d2 and d2_reward_ui_scene != null:
		return d2_reward_ui_scene
	return reward_ui_scene


func _open_reward_window(player: CharacterBody3D) -> void:
	if player == null or _has_player_claimed(player):
		return
	if is_instance_valid(_active_ui):
		return

	var scene_to_open: PackedScene = _get_selected_ui_scene()
	if scene_to_open == null:
		push_error("EnchantTotem (%s): aucune scène d'interface de récompense configurée !" % name)
		return

	var ui_mgr: Node = player.get_node_or_null("UI_manager")
	if ui_mgr != null and "current_state" in ui_mgr and int(ui_mgr.get("current_state")) != 0 and ui_mgr.has_method("close_all_ui"):
		ui_mgr.call("close_all_ui")

	var eff_ilvl: int = get_effective_ilvl()
	var p_key: int = _get_player_key(player)
	var choices: Array[RewardData] = []

	if _player_offered_choices.has(p_key) and _player_offered_choices[p_key] is Array:
		var raw_arr: Array = _player_offered_choices[p_key] as Array
		var cached_typed: Array[RewardData] = []
		for entry: Variant in raw_arr:
			var rd_entry: RewardData = entry as RewardData
			if rd_entry != null:
				cached_typed.append(rd_entry)
		choices = TotemRewardData.refresh_cached_choices_for_player(cached_typed, player, totem_element, eff_ilvl)
	if choices.is_empty():
		choices = TotemRewardData.build_totem_choices_for_player(player, totem_element, eff_ilvl)
	_player_offered_choices[p_key] = choices

	if choices.is_empty():
		print("EnchantTotem (%s): aucun choix disponible pour %s." % [name, player.name])
		return

	var ui_instance: CanvasLayer = scene_to_open.instantiate() as CanvasLayer
	if ui_instance == null or not ui_instance.has_method("open_rewards"):
		push_error("EnchantTotem (%s): impossible d'instancier l'UI de récompense !" % name)
		return

	_active_ui = ui_instance
	player.add_child(ui_instance)
	ui_instance.call("open_rewards", choices, player, self)
	_customize_reward_ui_header(ui_instance, eff_ilvl)


func _customize_reward_ui_header(ui_instance: CanvasLayer, eff_ilvl: int) -> void:
	if ui_instance == null:
		return
	var elem_upper: String = totem_element.to_upper()
	if "title_label" in ui_instance:
		var t_lbl: Label = ui_instance.get("title_label") as Label
		if t_lbl != null:
			t_lbl.text = "%s TOTEM'S BLESSING" % elem_upper
	if "subtitle_label" in ui_instance:
		var s_lbl: Label = ui_instance.get("subtitle_label") as Label
		if s_lbl != null:
			s_lbl.text = "Claim one %s offering forged at Item Level %d" % [totem_element.capitalize(), eff_ilvl]


## Appelé automatiquement par `RewardChoiceUID2` / `RewardChoiceUI` quand le joueur valide une stèle / carte
func apply_reward(reward_item: Variant, player: CharacterBody3D) -> void:
	if player == null or _has_player_claimed(player):
		return

	var rd: RewardData = reward_item as RewardData
	if rd == null:
		return

	var p_key: int = _get_player_key(player)
	print("EnchantTotem (%s): application de la récompense '%s' sur %s" % [name, rd.title, player.name])
	rd.apply_reward(player, self, func() -> void:
		_claimed_players[p_key] = true
		_player_offered_choices.erase(p_key)

		if not multiplayer.has_multiplayer_peer() or player.is_multiplayer_authority():
			reward_claimed_local = true
			_refresh_prompt_text(prompt_reward_claimed)
			_set_blessing_visual_active(false)

		var signal_dict: Dictionary = {
			"id": rd.id,
			"title": rd.title,
			"element": totem_element,
			"ilvl": get_effective_ilvl()
		}
		totem_reward_claimed.emit(signal_dict, player)
		print("EnchantTotem (%s): récompense '%s' accordée et verrouillée pour %s." % [name, rd.title, player.name])
	)


# =========================================================================
# GESTION DE L'INTERACTION COMPONENT & RETOUR VISUEL POST-COMBAT
# =========================================================================

func _get_formatted_activate_prompt() -> String:
	if prompt_activate == "Press [E] to challenge the Totem":
		return "Press [E] to challenge the %s Totem" % totem_element.capitalize()
	return prompt_activate


func _get_formatted_reward_prompt() -> String:
	if prompt_reward_ready == "Press [E] to claim the Totem's blessing":
		return "Press [E] to claim the %s Totem's blessing" % totem_element.capitalize()
	return prompt_reward_ready


func _set_interaction_enabled(enabled: bool, text: String) -> void:
	if interaction_component == null:
		interaction_component = get_node_or_null("InteractionComponent") as InteractionComponent
	if interaction_component == null:
		return

	var col_shape: CollisionShape3D = interaction_component.get_node_or_null("CollisionShape3D") as CollisionShape3D

	if enabled:
		interaction_component.prompt_text = text
		if interaction_component.prompt_label != null:
			interaction_component.prompt_label.text = text
		interaction_component.collision_layer = _initial_interaction_layer if _initial_interaction_layer != 0 else 32
		interaction_component.monitoring = true
		interaction_component.monitorable = true
		interaction_component.visible = true
		if col_shape != null:
			col_shape.set_deferred("disabled", false)
	else:
		interaction_component.hide_prompt()
		interaction_component.collision_layer = 0
		interaction_component.monitoring = false
		interaction_component.monitorable = false
		interaction_component.visible = false
		if col_shape != null:
			col_shape.set_deferred("disabled", true)


func _refresh_prompt_text(new_text: String) -> void:
	if interaction_component == null:
		return
	interaction_component.prompt_text = new_text
	if interaction_component.prompt_label != null:
		interaction_component.prompt_label.text = new_text


func _play_vfx_end_animation() -> void:
	if vfx_anim != null and vfx_anim.has_animation(&"end"):
		vfx_anim.play(&"end")


## Allume une lueur élémentaire apaisée et une légère lévitation quand la récompense attend le joueur,
## puis éteint doucement le halo une fois la bénédiction réclamée.
func _set_blessing_visual_active(active: bool) -> void:
	if _blessing_light_tween != null and _blessing_light_tween.is_valid():
		_blessing_light_tween.kill()
		_blessing_light_tween = null

	if vfx_anim != null and vfx_anim.is_playing():
		vfx_anim.stop()

	var sculptor: TotemSculptor = get_node_or_null("TotemSculptor") as TotemSculptor
	if sculptor != null:
		sculptor.set_blessing_state(active)

	var vfx_container: Node = vfx_anim.get_parent() if vfx_anim != null else null
	var omni_light: OmniLight3D = null
	if vfx_container != null:
		omni_light = vfx_container.get_node_or_null("OmniLight3D") as OmniLight3D
	if omni_light == null:
		omni_light = find_child("OmniLight3D", true, false) as OmniLight3D

	if vfx_container != null:
		for child: Node in vfx_container.get_children():
			var gpu_part: GPUParticles3D = child as GPUParticles3D
			if gpu_part == null:
				continue
			if active:
				# On laisse vacum_particles éteint pour conserver une aura purifiée et calme
				if String(gpu_part.name) == "vacum_particles":
					gpu_part.amount_ratio = 0.0
				else:
					gpu_part.emitting = true
					gpu_part.amount_ratio = 0.35
			else:
				gpu_part.amount_ratio = 0.0

	if omni_light != null:
		if active:
			omni_light.omni_range = 4.2
			omni_light.light_energy = maxf(omni_light.light_energy, 0.08)
			_blessing_light_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_blessing_light_tween.tween_property(omni_light, "light_energy", 0.42, 1.35)
			_blessing_light_tween.tween_property(omni_light, "light_energy", 0.18, 1.35)
		else:
			_blessing_light_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_blessing_light_tween.tween_property(omni_light, "light_energy", 0.0, 0.55)
