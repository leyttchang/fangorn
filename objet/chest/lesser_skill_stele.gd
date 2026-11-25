@tool
class_name LesserSkillStele
extends Node3D

## Petite Stèle de Compétences Tier I (inspirée de `SkillChest`, plus compacte avec 2 runes jumelles).
## Permet de choisir entre 1 Attaque (Tier I) et 1 Sort (Tier I obligatoire, 0% Tier II).
## Peut être scellée tant que son petit groupe de gardiens est en vie.

signal lesser_stele_claimed(reward_dict: Dictionary, player: CharacterBody3D)
signal lesser_stele_unsealed

@export_group("État du Sceau")
@export var is_unsealed: bool = true:
	set(val):
		var changed: bool = (is_unsealed != val)
		is_unsealed = val
		if is_inside_tree():
			_apply_seal_visual_state(changed)

@export_group("Interface de la Moria")
@export var d2_reward_ui_scene: PackedScene = preload("res://map/encounters/pnj_buff_choice/reward_choice_ui_d2.tscn")
@export var stele_header_title: String = "LESSER SKILL STELE"
@export var stele_header_subtitle: String = "Choose one Tier I Attack or Tier I Spell to awaken"

@export_group("Textes d'Interaction")
@export var prompt_sealed: String = "Sealed Lesser Stele (Defeat the nearby guards)"
@export var prompt_ready: String = "Press [F] to read the Lesser Skill Stele"
@export var prompt_claimed: String = "The lesser stele rests silent"
@export var prompt_all_mastered: String = "All Tier I skills are already mastered"

@export_group("Actions (Éditeur)")
@export var rebuild_stele_now: bool = false:
	set(val):
		rebuild_stele_now = false
		if is_inside_tree():
			if Engine.is_editor_hint():
				SkillSteleMeshes.clear_caches()
			_rebuild_visuals()

@onready var interaction_component: InteractionComponent = $InteractionComponent if has_node("InteractionComponent") else null

const COLOR_RUNE_SEALED_ALBEDO := Color(0.66, 0.44, 0.34, 1.0)
const COLOR_RUNE_SEALED_EMISSION := Color(0.85, 0.32, 0.14, 1.0)
const COLOR_LIGHT_SEALED := Color(0.88, 0.38, 0.18, 1.0)

const COLOR_RUNE_READY_ALBEDO := Color(0.95, 0.88, 0.72, 1.0)
const COLOR_RUNE_READY_EMISSION := Color(0.96, 0.74, 0.38, 1.0)
const COLOR_LIGHT_READY := Color(0.96, 0.80, 0.50, 1.0)

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

	_apply_seal_visual_state(false)
	set_process(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or reward_claimed_local:
		set_process(false)
		return
	_pulse_time += delta
	if is_unsealed:
		var wave: float = 0.5 + 0.5 * sin(_pulse_time * 2.25)
		if _rune_mat != null:
			_rune_mat.emission_energy_multiplier = lerpf(1.05, 1.80, wave)
		if _stele_light != null and is_instance_valid(_stele_light):
			_stele_light.light_energy = lerpf(0.85, 1.35, wave)
	else:
		var seal_wave: float = 0.5 + 0.5 * sin(_pulse_time * 1.45)
		if _rune_mat != null:
			_rune_mat.emission_energy_multiplier = lerpf(0.32, 0.62, seal_wave)
		if _stele_light != null and is_instance_valid(_stele_light):
			_stele_light.light_energy = lerpf(0.28, 0.52, seal_wave)


func _rebuild_visuals() -> void:
	if _visual_root != null and is_instance_valid(_visual_root):
		remove_child(_visual_root)
		_visual_root.queue_free()
	var old_vis: Node = get_node_or_null("LesserSteleVisual")
	if old_vis != null:
		remove_child(old_vis)
		old_vis.queue_free()

	var built: Dictionary = SkillSteleMeshes.build_lesser_stele_visual_root("LesserSteleVisual")
	_visual_root = built.get("root") as Node3D
	_rune_mat = built.get("rune_material") as StandardMaterial3D
	_stele_light = built.get("light") as OmniLight3D
	_stele_motes = built.get("motes") as GPUParticles3D
	if _visual_root != null:
		add_child(_visual_root)
	if not Engine.is_editor_hint():
		_apply_seal_visual_state(false)


func _apply_seal_visual_state(animate_flash: bool) -> void:
	if reward_claimed_local:
		_refresh_prompt_text(prompt_claimed)
		return

	if is_unsealed:
		_refresh_prompt_text(prompt_ready)
		if _stele_motes != null and is_instance_valid(_stele_motes):
			_stele_motes.emitting = true
		if _rune_mat != null:
			_rune_mat.albedo_color = COLOR_RUNE_READY_ALBEDO
			_rune_mat.emission = COLOR_RUNE_READY_EMISSION
		if _stele_light != null and is_instance_valid(_stele_light):
			_stele_light.light_color = COLOR_LIGHT_READY
		if animate_flash and not Engine.is_editor_hint() and is_inside_tree():
			if _rune_mat != null:
				_rune_mat.emission_energy_multiplier = 3.2
			if _stele_light != null and is_instance_valid(_stele_light):
				_stele_light.light_energy = 2.6
			lesser_stele_unsealed.emit()
		set_process(not Engine.is_editor_hint())
	else:
		_refresh_prompt_text(prompt_sealed)
		if _stele_motes != null and is_instance_valid(_stele_motes):
			_stele_motes.emitting = false
		if _rune_mat != null:
			_rune_mat.albedo_color = COLOR_RUNE_SEALED_ALBEDO
			_rune_mat.emission = COLOR_RUNE_SEALED_EMISSION
			_rune_mat.emission_energy_multiplier = 0.45
		if _stele_light != null and is_instance_valid(_stele_light):
			_stele_light.light_color = COLOR_LIGHT_SEALED
			_stele_light.light_energy = 0.40
		set_process(not Engine.is_editor_hint())


func unseal() -> void:
	if is_unsealed:
		return
	is_unsealed = true


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

	if not is_unsealed:
		_refresh_prompt_text(prompt_sealed)
		return

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
		push_error("LesserSkillStele: scène UI de la Moria introuvable !")
		return

	var ui_mgr: Node = player.get_node_or_null("UI_manager")
	if ui_mgr != null and "current_state" in ui_mgr and int(ui_mgr.get("current_state")) != 0 and ui_mgr.has_method("close_all_ui"):
		ui_mgr.call("close_all_ui")

	var p_key: int = _get_player_key(player)
	var choices: Array[RewardData] = []

	if _player_offered_choices.has(p_key) and _player_offered_choices[p_key] is Array:
		var raw_arr: Array = _player_offered_choices[p_key] as Array
		var cached_typed: Array[RewardData] = []
		for entry: Variant in raw_arr:
			var rd_entry: RewardData = entry as RewardData
			if rd_entry != null:
				cached_typed.append(rd_entry)
		choices = SkillSteleRewardData.refresh_tier1_attack_or_spell_choices(cached_typed, player)

	if choices.is_empty():
		choices = SkillSteleRewardData.build_tier1_attack_or_spell_choices(player)

	_player_offered_choices[p_key] = choices

	if choices.is_empty():
		print("[LesserSkillStele] Le joueur maîtrise déjà toutes les compétences Tier I !")
		_refresh_prompt_text(prompt_all_mastered)
		return

	var ui_instance: CanvasLayer = d2_reward_ui_scene.instantiate() as CanvasLayer
	if ui_instance == null or not ui_instance.has_method("open_rewards"):
		push_error("LesserSkillStele: impossible d'instancier l'écran de sélection de la Moria !")
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


func apply_reward(reward_item: Variant, player: CharacterBody3D) -> void:
	if player == null or not is_unsealed or _has_player_claimed(player):
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
		lesser_stele_claimed.emit(info, player)
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
