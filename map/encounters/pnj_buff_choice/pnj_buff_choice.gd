class_name PnjBuffChoice
extends StaticBody3D

signal pnj_unlocked
signal reward_claimed_signal(reward_dict: Dictionary, player: CharacterBody3D)

@export_category("État du PNJ")
## Si vrai, le PNJ est considéré comme délivré de sa cage
@export var is_freed: bool = false:
	set(val):
		is_freed = val
		_update_interaction_prompt()

## Si vrai, la récompense a déjà été accordée au joueur
@export var reward_claimed: bool = false:
	set(val):
		reward_claimed = val
		if not val:
			_player_offered_choices.clear()
		_update_interaction_prompt()

@export_category("Paramètres de Camp & Récompenses")
## Niveau d'objet de base associé à ce camp / cette zone
@export var camp_ilvl: int = 1

## Dossier contenant toutes les ressources de récompenses .tres
@export_dir var rewards_folder: String = "res://map/encounters/pnj_buff_choice/reward_resource"

## Récompenses additionnelles manuelles configurables dans l'inspecteur
@export var custom_rewards_pool: Array[RewardData] = []

@export_category("Textes d'Interaction")
## Text displayed when approaching while cage is locked
@export var prompt_locked: String = "Imprisoned Survivor (Defeat the guards to free)"
## Text displayed when approaching after opening the cage
@export var prompt_freed: String = "Press [E] to choose your blessing"
## Text displayed once the reward has already been claimed
@export var prompt_claimed: String = "The survivor salutes you with gratitude"

enum UIStyleMode {
	USE_GLOBAL_SETTING, ## Suit SettingsManager.ui_style (Menu Options)
	FORCE_MORIA_D2,     ## Force le style Pierre de la Moria / Diablo II
	FORCE_CLASSIC       ## Force l'ancien style Classique
}

@export_category("Interface de Récompenses")
## Choix du style visuel (par défaut suit le réglage global SettingsManager)
@export var ui_style_mode: UIStyleMode = UIStyleMode.USE_GLOBAL_SETTING
## Nouvelle scène d'interface Moria / Diablo II (pierre fissurée, racines noircies & bas-reliefs)
@export var d2_reward_ui_scene: PackedScene = preload("res://map/encounters/pnj_buff_choice/reward_choice_ui_d2.tscn")
## Ancienne scène d'interface conservée intacte
@export var reward_ui_scene: PackedScene = preload("res://map/encounters/pnj_buff_choice/reward_choice_ui.tscn")

@export_category("Actions (Inspecteur / Test)")
## Coche cette case pour simuler la libération du PNJ immédiatement
@export var test_unlock_now: bool = false:
	set(val):
		test_unlock_now = false
		unlock_pnj()

@onready var interaction_component: InteractionComponent = $InteractionComponent if has_node("InteractionComponent") else null

var _cached_rewards: Array[RewardData] = []
var _player_offered_choices: Dictionary = {}
var _active_ui: CanvasLayer = null

func _ready() -> void:
	_update_interaction_prompt()
	_load_reward_resources()

## Charge toutes les ressources .tres du dossier reward_resource (compatible éditeur et build exporté PCK)
func _load_reward_resources() -> void:
	_cached_rewards.clear()
	
	var loaded_paths: Dictionary = {}
	var files = ResourceLoader.list_directory(rewards_folder)
	for file_name in files:
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var res_path = rewards_folder.path_join(file_name)
			var res = load(res_path)
			if res is RewardData and not loaded_paths.has(res_path):
				loaded_paths[res_path] = true
				_cached_rewards.append(res)
				
	if _cached_rewards.is_empty():
		var dir = DirAccess.open(rewards_folder)
		if dir != null:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					var clean_name = file_name.trim_suffix(".remap")
					if clean_name.ends_with(".tres") or clean_name.ends_with(".res"):
						var res_path = rewards_folder.path_join(clean_name)
						var res = load(res_path)
						if res is RewardData and not loaded_paths.has(res_path):
							loaded_paths[res_path] = true
							_cached_rewards.append(res)
				file_name = dir.get_next()
			dir.list_dir_end()
			
	for extra in custom_rewards_pool:
		if extra != null and not _cached_rewards.has(extra):
			_cached_rewards.append(extra)
			
	print("PnjBuffChoice (", name, ") : ", _cached_rewards.size(), " reward resources loaded.")

## Méthode publique pour libérer le PNJ (à connecter au signal 'all_mobs_defeated' du spawner)
func unlock_pnj() -> void:
	if is_freed:
		return
	is_freed = true
	print("PnjBuffChoice (", name, ") : The NPC is freed!")
	pnj_unlocked.emit()

## Méthode appelée automatiquement par l'InteractionComponent quand le joueur appuie sur E
func interact(player: CharacterBody3D) -> void:
	if not is_freed:
		print("PnjBuffChoice : The NPC is still locked in the cage.")
		if interaction_component:
			interaction_component.prompt_text = prompt_locked
			interaction_component.show_prompt()
		return
		
	if reward_claimed:
		print("PnjBuffChoice : The reward has already been claimed.")
		if interaction_component:
			interaction_component.prompt_text = prompt_claimed
			interaction_component.show_prompt()
		return
		
	_open_reward_window(player)

func _get_selected_ui_scene() -> PackedScene:
	var use_d2 := true
	match ui_style_mode:
		UIStyleMode.FORCE_MORIA_D2:
			use_d2 = true
		UIStyleMode.FORCE_CLASSIC:
			use_d2 = false
		UIStyleMode.USE_GLOBAL_SETTING:
			if get_tree() != null and get_tree().root != null and get_tree().root.has_node("SettingsManager"):
				var sm = get_tree().root.get_node("SettingsManager")
				if "ui_style" in sm:
					use_d2 = (int(sm.ui_style) == 1)
	if use_d2 and d2_reward_ui_scene != null:
		return d2_reward_ui_scene
	return reward_ui_scene

## Ouvre l'interface des 3 choix pour le joueur
func _open_reward_window(player: CharacterBody3D) -> void:
	if reward_claimed:
		return
	if is_instance_valid(_active_ui):
		return
	var scene_to_open := _get_selected_ui_scene()
	if scene_to_open == null:
		push_error("PnjBuffChoice : Aucune scène d'interface de récompense configurée !")
		return
		
	if player != null:
		var ui_mgr = player.get_node_or_null("UI_manager")
		if ui_mgr != null and "current_state" in ui_mgr and ui_mgr.current_state != 0 and ui_mgr.has_method("close_all_ui"):
			ui_mgr.close_all_ui()
		
	var player_key = player.get_instance_id() if player != null else 0
	if not _player_offered_choices.has(player_key) or _player_offered_choices[player_key].is_empty():
		_player_offered_choices[player_key] = _pick_random_choices(3, player)
		
	var choices = _player_offered_choices[player_key]
	if choices.is_empty():
		print("PnjBuffChoice : Aucun choix disponible pour ce joueur.")
		return
		
	var ui_instance = scene_to_open.instantiate() as CanvasLayer
	if ui_instance == null or not ui_instance.has_method("open_rewards"):
		push_error("PnjBuffChoice : Impossible d'instancier l'UI de récompense !")
		return
		
	_active_ui = ui_instance
	if player != null:
		player.add_child(ui_instance)
	else:
		get_tree().root.add_child(ui_instance)
	ui_instance.open_rewards(choices, player, self)

## Pioche 'count' récompenses uniques éligibles parmi les ressources disponibles
func _pick_random_choices(count: int, player: CharacterBody3D) -> Array:
	if _cached_rewards.is_empty():
		_load_reward_resources()
		
	# Filtrer par éligibilité pour le joueur actuel
	var eligible_pool: Array[RewardData] = []
	for reward in _cached_rewards:
		if reward != null and reward.is_eligible(player, self):
			eligible_pool.append(reward)
			
	if eligible_pool.is_empty():
		push_warning("PnjBuffChoice : Aucune récompense éligible trouvée !")
		return []
		
	# Tirage pondéré sans doublon
	var picked: Array[RewardData] = []
	var pool_copy = eligible_pool.duplicate()
	var needed = mini(count, pool_copy.size())
	
	for _i in range(needed):
		var total_weight: float = 0.0
		for r in pool_copy:
			total_weight += max(0.01, r.weight)
			
		var roll = randf() * total_weight
		var cumulative: float = 0.0
		var chosen_index = 0
		
		for idx in range(pool_copy.size()):
			cumulative += max(0.01, pool_copy[idx].weight)
			if roll <= cumulative:
				chosen_index = idx
				break
				
		picked.append(pool_copy[chosen_index])
		pool_copy.remove_at(chosen_index)
		
	return picked

## Applique l'effet concret de la récompense choisie au joueur
func apply_reward(reward_item: Variant, player: CharacterBody3D) -> void:
	if reward_claimed:
		return
	if reward_item is RewardData:
		var rd = reward_item as RewardData
		print("PnjBuffChoice : Application de la récompense RewardData '", rd.title, "' sur ", player.name)
		rd.apply_reward(player, self, func():
			reward_claimed = true
			_player_offered_choices.clear()
			var dict = { "id": rd.id, "title": rd.title }
			reward_claimed_signal.emit(dict, player)
			print("PnjBuffChoice : Récompense '", rd.title, "' validée et verrouillée.")
		)
	elif typeof(reward_item) == TYPE_DICTIONARY:
		# Fallback rétrocompatible
		var reward_dict = reward_item as Dictionary
		var reward_id = reward_dict.get("id", "")
		print("PnjBuffChoice : Application récompense dictionnaire legacy '", reward_id, "'")
		match reward_id:
			"skill_point":
				var st = player.get_node_or_null("Skill_tree_comp")
				if st == null:
					st = player.find_child("SkillTreeComponent", true, false)
				if st != null and "available_skill_points" in st:
					st.available_skill_points += 2
			"heal_buff":
				var hc = player.find_child("HealthComponent", true, false) as HealthComponent
				if hc != null:
					hc.heal(hc._known_max_health * 0.25)
			_:
				pass
		reward_claimed = true
		_player_offered_choices.clear()
		reward_claimed_signal.emit(reward_dict, player)

func _update_interaction_prompt() -> void:
	if interaction_component == null:
		interaction_component = get_node_or_null("InteractionComponent") as InteractionComponent
	if interaction_component == null:
		return
		
	if not is_freed:
		interaction_component.prompt_text = prompt_locked
	elif reward_claimed:
		interaction_component.prompt_text = prompt_claimed
	else:
		interaction_component.prompt_text = prompt_freed
