@tool
class_name SkillChest
extends Node3D

## Petite Stèle de Compétences (remplace tous les anciens coffres de sorts `Skill_chest.tscn`).
## Au clic sur [F], ouvre l'écran de sélection de la Moria (`reward_choice_ui_d2.tscn`)
## proposant 3 compétences distinctes non encore débloquées par le joueur.

signal skill_stele_claimed(reward_dict: Dictionary, player: CharacterBody3D)

@export_group("Pool de Compétences")
## Liste des compétences éligibles (si vide, charge automatiquement toutes les compétences de GameData)
@export var all_possible_spells: Array[AbilityData] = []
@export_range(1, 3, 1) var choices_count: int = 3

@export_group("Interface de la Moria")
@export var d2_reward_ui_scene: PackedScene = preload("res://map/encounters/pnj_buff_choice/reward_choice_ui_d2.tscn")
@export var stele_header_title: String = "ANCIENT SKILL STELE"
@export var stele_header_subtitle: String = "Choose one inscribed skill to awaken"

@export_group("Textes d'Interaction")
@export var prompt_ready: String = "Press [F] to read the Skill Stele"
@export var prompt_claimed: String = "The ancient stele rests silent"
@export var prompt_all_mastered: String = "All ancient skills are already mastered"

@export_group("Actions (Éditeur)")
@export var rebuild_stele_now: bool = false:
	set(val):
		rebuild_stele_now = false
		if is_inside_tree():
			if Engine.is_editor_hint():
				SkillSteleMeshes.clear_caches()
			_rebuild_visuals()

@onready var interaction_component: InteractionComponent = $InteractionComponent if has_node("InteractionComponent") else null

var is_open: bool = false
var reward_claimed_local: bool = false
var player_in_range: CharacterBody3D = null

var _visual_root: Node3D = null
var _rune_mat: StandardMaterial3D = null
var _stele_light: OmniLight3D = null
var _stele_motes: GPUParticles3D = null
var _pulse_time: float = 0.0

var _player_offered_choices: Dictionary = {}
var _claimed_players: Dictionary = {}
var _active_ui: CanvasLayer = null


func _ready() -> void:
	_rebuild_visuals()
	if Engine.is_editor_hint():
		set_process(false)
		return

	if all_possible_spells.is_empty():
		_auto_load_default_spells()

	_refresh_prompt_text(prompt_ready)
	set_process(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or reward_claimed_local:
		set_process(false)
		return
	_pulse_time += delta
	var wave: float = 0.5 + 0.5 * sin(_pulse_time * 2.1)
	if _rune_mat != null:
		_rune_mat.emission_energy_multiplier = lerpf(1.10, 1.85, wave)
	if _stele_light != null and is_instance_valid(_stele_light):
		_stele_light.light_energy = lerpf(0.95, 1.45, wave)


func _rebuild_visuals() -> void:
	if _visual_root != null and is_instance_valid(_visual_root):
		remove_child(_visual_root)
		_visual_root.queue_free()
	var old_vis: Node = get_node_or_null("SteleVisual")
	if old_vis != null:
		remove_child(old_vis)
		old_vis.queue_free()

	var built: Dictionary = SkillSteleMeshes.build_stele_visual_root("SteleVisual")
	_visual_root = built.get("root") as Node3D
	_rune_mat = built.get("rune_material") as StandardMaterial3D
	_stele_light = built.get("light") as OmniLight3D
	_stele_motes = built.get("motes") as GPUParticles3D
	if _visual_root != null:
		add_child(_visual_root)


func _auto_load_default_spells() -> void:
	var droppable: Array[AbilityData] = GameData.get_droppable_skills(0.14)
	for spell_res: AbilityData in droppable:
		if spell_res != null:
			all_possible_spells.append(spell_res)


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


## Appelé par InteractionComponent quand le joueur appuie sur [E]
func use(player: Node3D) -> void:
	var body: CharacterBody3D = player as CharacterBody3D
	if body == null:
		return
	interact(body)


func interact(player: CharacterBody3D) -> void:
	if player == null:
		return
	if multiplayer.has_multiplayer_peer() and not player.is_multiplayer_authority():
		return

	player_in_range = player

	if _has_player_claimed(player):
		_refresh_prompt_text(prompt_claimed)
		return

	_open_stele_selection_window(player)


func open_chest() -> void:
	if player_in_range != null:
		interact(player_in_range)


func _open_stele_selection_window(player: CharacterBody3D) -> void:
	if is_instance_valid(_active_ui):
		return
	if d2_reward_ui_scene == null:
		push_error("SkillChest (Stele): scène UI de la Moria introuvable !")
		return

	var ui_mgr: Node = player.get_node_or_null("UI_manager")
	if ui_mgr != null and "current_state" in ui_mgr and int(ui_mgr.get("current_state")) != 0 and ui_mgr.has_method("close_all_ui"):
		ui_mgr.call("close_all_ui")

	if all_possible_spells.is_empty():
		_auto_load_default_spells()

	var p_key: int = _get_player_key(player)
	var choices: Array[RewardData] = []

	if _player_offered_choices.has(p_key) and _player_offered_choices[p_key] is Array:
		var raw_arr: Array = _player_offered_choices[p_key] as Array
		var cached_typed: Array[RewardData] = []
		for entry: Variant in raw_arr:
			var rd_entry: RewardData = entry as RewardData
			if rd_entry != null:
				cached_typed.append(rd_entry)
		choices = SkillSteleRewardData.refresh_cached_choices_for_player(cached_typed, player, all_possible_spells, choices_count)

	if choices.is_empty():
		choices = SkillSteleRewardData.build_skill_choices_for_player(player, all_possible_spells, choices_count)

	_player_offered_choices[p_key] = choices

	if choices.is_empty():
		print("[SkillStele] Le joueur maîtrise déjà toutes les compétences disponibles !")
		_refresh_prompt_text(prompt_all_mastered)
		return

	var ui_instance: CanvasLayer = d2_reward_ui_scene.instantiate() as CanvasLayer
	if ui_instance == null or not ui_instance.has_method("open_rewards"):
		push_error("SkillChest (Stele): impossible d'instancier l'écran de sélection de la Moria !")
		return

	_active_ui = ui_instance
	player.add_child(ui_instance)
	ui_instance.call("open_rewards", choices, player, self)
	_customize_moria_header(ui_instance)


func _customize_moria_header(ui_instance: CanvasLayer) -> void:
	if ui_instance == null:
		return
	if "title_label" in ui_instance:
		var t_lbl: Label = ui_instance.get("title_label") as Label
		if t_lbl != null:
			t_lbl.text = stele_header_title
	if "subtitle_label" in ui_instance:
		var s_lbl: Label = ui_instance.get("subtitle_label") as Label
		if s_lbl != null:
			s_lbl.text = stele_header_subtitle


## Appelé automatiquement par `RewardChoiceUID2` lorsque le joueur choisit l'une des 3 compétences
func apply_reward(reward_item: Variant, player: CharacterBody3D) -> void:
	if player == null or _has_player_claimed(player):
		return

	var rd: RewardData = reward_item as RewardData
	if rd == null:
		return

	var p_key: int = _get_player_key(player)
	rd.apply_reward(player, self, func() -> void:
		_claimed_players[p_key] = true
		_player_offered_choices.erase(p_key)

		if not multiplayer.has_multiplayer_peer() or player.is_multiplayer_authority():
			is_open = true
			reward_claimed_local = true
			_refresh_prompt_text(prompt_claimed)
			_dim_stele_after_claim()

		var info: Dictionary = {
			"id": rd.id,
			"title": rd.title
		}
		skill_stele_claimed.emit(info, player)
	)


func _dim_stele_after_claim() -> void:
	set_process(false)
	if _stele_motes != null and is_instance_valid(_stele_motes):
		_stele_motes.emitting = false
	var tw: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _rune_mat != null:
		tw.tween_property(_rune_mat, "emission_energy_multiplier", 0.08, 0.65)
		tw.tween_property(_rune_mat, "albedo_color", Color(0.46, 0.50, 0.56, 1.0), 0.65)
	if _stele_light != null and is_instance_valid(_stele_light):
		tw.tween_property(_stele_light, "light_energy", 0.0, 0.65)


func _refresh_prompt_text(new_text: String) -> void:
	if interaction_component == null:
		interaction_component = get_node_or_null("InteractionComponent") as InteractionComponent
	if interaction_component == null:
		return
	interaction_component.prompt_text = new_text
	if interaction_component.prompt_label != null:
		interaction_component.prompt_label.text = new_text
