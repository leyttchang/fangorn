class_name SkillSteleRewardData
extends RewardData

## Ressource dynamique représentant 1 compétence précise proposée par une Petite Stèle de Compétences
## dans l'interface de sélection de la Moria (`reward_choice_ui_d2.tscn`).

var offered_ability: AbilityData = null
var is_attack_skill: bool = false
var detected_element: String = ""
var strict_tier1_only: bool = false


## Construit jusqu'à `count` (3 par défaut) choix de compétences distinctes non encore débloquées par le joueur.
static func build_skill_choices_for_player(
	player: CharacterBody3D,
	candidate_pool: Array[AbilityData],
	count: int = 3
) -> Array[RewardData]:
	var locked_pool: Array[AbilityData] = get_locked_skills_from_pool(player, candidate_pool)
	if locked_pool.is_empty():
		return []

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var remaining: Array[AbilityData] = locked_pool.duplicate()
	var choices: Array[RewardData] = []
	var target_n: int = mini(maxi(1, count), remaining.size())

	for _i in range(target_n):
		var pick_idx: int = rng.randi_range(0, remaining.size() - 1)
		var picked_ab: AbilityData = remaining[pick_idx]
		remaining.remove_at(pick_idx)
		var card: SkillSteleRewardData = create_card_for_ability(picked_ab)
		if card != null:
			choices.append(card)

	return choices


## Rafraîchit les 3 choix mémorisés si le joueur a fermé la fenêtre (Échap) puis débloqué l'un des sorts ailleurs.
static func refresh_cached_choices_for_player(
	cached: Array[RewardData],
	player: CharacterBody3D,
	candidate_pool: Array[AbilityData],
	count: int = 3
) -> Array[RewardData]:
	var locked_pool: Array[AbilityData] = get_locked_skills_from_pool(player, candidate_pool)
	if locked_pool.is_empty():
		return []

	var kept: Array[RewardData] = []
	var used_names: Dictionary = {}

	for rd: RewardData in cached:
		var srd: SkillSteleRewardData = rd as SkillSteleRewardData
		if srd == null or srd.offered_ability == null:
			continue
		if not TotemRewardData.is_ability_unlocked_by_player(player, srd.offered_ability):
			var ab_key: String = srd.offered_ability.ability_name
			if not used_names.has(ab_key):
				used_names[ab_key] = true
				kept.append(srd)

	if kept.size() < count:
		var extra_candidates: Array[AbilityData] = []
		for ab: AbilityData in locked_pool:
			if ab != null and not used_names.has(ab.ability_name):
				extra_candidates.append(ab)

		var rng := RandomNumberGenerator.new()
		rng.randomize()
		while kept.size() < count and not extra_candidates.is_empty():
			var idx: int = rng.randi_range(0, extra_candidates.size() - 1)
			var next_ab: AbilityData = extra_candidates[idx]
			extra_candidates.remove_at(idx)
			used_names[next_ab.ability_name] = true
			var replacement_card: SkillSteleRewardData = create_card_for_ability(next_ab)
			if replacement_card != null:
				kept.append(replacement_card)

	return kept


static func get_locked_skills_from_pool(player: Node, candidate_pool: Array[AbilityData]) -> Array[AbilityData]:
	var source_list: Array[AbilityData] = candidate_pool if not candidate_pool.is_empty() else GameData.get_droppable_skills(0.14)
	var locked: Array[AbilityData] = []
	var seen_names: Dictionary = {}

	for ab: AbilityData in source_list:
		if ab == null or ab.is_evolution_only:
			continue
		if seen_names.has(ab.ability_name):
			continue
		seen_names[ab.ability_name] = true
		if player != null and TotemRewardData.is_ability_unlocked_by_player(player, ab):
			continue
		locked.append(ab)

	# Si tous les sorts Tier I de la stèle sont déjà possédés, autorise les Rare Drops restants en secours
	if locked.is_empty():
		for ab_rare: AbilityData in GameData.get_all_non_evolution_skills():
			if ab_rare == null or seen_names.has(ab_rare.ability_name):
				continue
			if player != null and TotemRewardData.is_ability_unlocked_by_player(player, ab_rare):
				continue
			locked.append(ab_rare)

	return locked


## Retourne les Attaques Tier I non encore débloquées (strictement Tier 1, hors évolutions et hors Rare Drops Tier 2).
static func get_locked_tier1_attacks(player: Node) -> Array[AbilityData]:
	var primary: Array[AbilityData] = []
	var utility_martial: Array[AbilityData] = []
	var seen_names: Dictionary = {}

	for ab: AbilityData in GameData.get_all_spells():
		if ab == null or ab.is_evolution_only or ab.is_rare_drop or ab.tier != 1:
			continue
		if seen_names.has(ab.ability_name):
			continue
		if player != null and TotemRewardData.is_ability_unlocked_by_player(player, ab):
			continue

		var eff_id: String = ab.get_effective_id()
		if TotemRewardData.is_attack_ability(ab):
			seen_names[ab.ability_name] = true
			primary.append(ab)
		elif eff_id in ["warcry", "warcry_ability"]:
			seen_names[ab.ability_name] = true
			utility_martial.append(ab)

	if not primary.is_empty():
		return primary
	return utility_martial


## Retourne les Sorts Tier I non encore débloqués (strictement Tier 1 obligatoire, 0% Tier 2).
static func get_locked_tier1_spells(player: Node) -> Array[AbilityData]:
	var primary: Array[AbilityData] = []
	var utility_spells: Array[AbilityData] = []
	var seen_names: Dictionary = {}

	for ab: AbilityData in GameData.get_all_spells():
		if ab == null or ab.is_evolution_only or ab.is_rare_drop or ab.tier != 1:
			continue
		if TotemRewardData.is_attack_ability(ab):
			continue
		if seen_names.has(ab.ability_name):
			continue
		if player != null and TotemRewardData.is_ability_unlocked_by_player(player, ab):
			continue

		var eff_id: String = ab.get_effective_id()
		seen_names[ab.ability_name] = true
		if eff_id in ["dash", "warcry", "warcry_ability"]:
			utility_spells.append(ab)
		else:
			primary.append(ab)

	if not primary.is_empty():
		return primary
	return utility_spells


## Construit les 2 choix de la Petite Stèle : [1 Attaque Tier I] et [1 Sort Tier I] (strictement Tier 1).
static func build_tier1_attack_or_spell_choices(player: CharacterBody3D) -> Array[RewardData]:
	var atk_pool: Array[AbilityData] = get_locked_tier1_attacks(player)
	var spell_pool: Array[AbilityData] = get_locked_tier1_spells(player)

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var choices: Array[RewardData] = []
	var used_names: Dictionary = {}

	if not atk_pool.is_empty():
		var atk_idx: int = rng.randi_range(0, atk_pool.size() - 1)
		var picked_atk: AbilityData = atk_pool[atk_idx]
		atk_pool.remove_at(atk_idx)
		used_names[picked_atk.ability_name] = true
		var atk_card: SkillSteleRewardData = create_card_for_ability(picked_atk, true)
		if atk_card != null:
			choices.append(atk_card)

	if not spell_pool.is_empty():
		var valid_spells: Array[AbilityData] = []
		for sp: AbilityData in spell_pool:
			if sp != null and not used_names.has(sp.ability_name):
				valid_spells.append(sp)
		if not valid_spells.is_empty():
			var sp_idx: int = rng.randi_range(0, valid_spells.size() - 1)
			var picked_sp: AbilityData = valid_spells[sp_idx]
			used_names[picked_sp.ability_name] = true
			var sp_card: SkillSteleRewardData = create_card_for_ability(picked_sp, true)
			if sp_card != null:
				choices.append(sp_card)

	# Secours propre si le joueur a déjà maîtrisé toutes les Attaques Tier I (ou tous les Sorts Tier I)
	if choices.size() < 2:
		var remaining_t1: Array[AbilityData] = []
		for ab_rem: AbilityData in atk_pool:
			if ab_rem != null and not used_names.has(ab_rem.ability_name):
				remaining_t1.append(ab_rem)
		for sp_rem: AbilityData in spell_pool:
			if sp_rem != null and not used_names.has(sp_rem.ability_name):
				remaining_t1.append(sp_rem)
		while choices.size() < 2 and not remaining_t1.is_empty():
			var r_idx: int = rng.randi_range(0, remaining_t1.size() - 1)
			var next_t1: AbilityData = remaining_t1[r_idx]
			remaining_t1.remove_at(r_idx)
			used_names[next_t1.ability_name] = true
			var extra_card: SkillSteleRewardData = create_card_for_ability(next_t1, true)
			if extra_card != null:
				choices.append(extra_card)

	return choices


## Rafraîchit les 2 choix mémorisés de la Petite Stèle sans autoriser de reroll gratuit ni jamais glisser vers du Tier 2.
static func refresh_tier1_attack_or_spell_choices(
	cached: Array[RewardData],
	player: CharacterBody3D
) -> Array[RewardData]:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var refreshed: Array[RewardData] = []
	var used_names: Dictionary = {}

	for rd: RewardData in cached:
		var srd: SkillSteleRewardData = rd as SkillSteleRewardData
		if srd == null or srd.offered_ability == null:
			continue
		if srd.offered_ability.tier == 1 and not srd.offered_ability.is_rare_drop and not srd.offered_ability.is_evolution_only:
			if not TotemRewardData.is_ability_unlocked_by_player(player, srd.offered_ability):
				var ab_key: String = srd.offered_ability.ability_name
				if not used_names.has(ab_key):
					used_names[ab_key] = true
					srd.strict_tier1_only = true
					refreshed.append(srd)
					continue

		# Remplacer dans la même catégorie (Attaque Tier I ou Sort Tier I)
		var same_pool: Array[AbilityData] = (
			get_locked_tier1_attacks(player)
			if srd.is_attack_skill
			else get_locked_tier1_spells(player)
		)
		var filtered: Array[AbilityData] = []
		for cand: AbilityData in same_pool:
			if cand != null and not used_names.has(cand.ability_name):
				filtered.append(cand)
		if not filtered.is_empty():
			var pick: AbilityData = filtered[rng.randi_range(0, filtered.size() - 1)]
			used_names[pick.ability_name] = true
			var repl: SkillSteleRewardData = create_card_for_ability(pick, true)
			if repl != null:
				refreshed.append(repl)

	if refreshed.is_empty():
		return build_tier1_attack_or_spell_choices(player)

	return refreshed


static func create_card_for_ability(ability: AbilityData, enforce_tier1: bool = false) -> SkillSteleRewardData:
	if ability == null:
		return null

	var is_atk: bool = TotemRewardData.is_attack_ability(ability)
	var elem: String = TotemRewardData.resolve_ability_element(ability)

	var card := SkillSteleRewardData.new()
	card.offered_ability = ability
	card.is_attack_skill = is_atk
	card.detected_element = elem
	card.strict_tier1_only = enforce_tier1

	# Identifiant dédié hors table fixe pour afficher directement l'icône de la compétence sur la stèle D2
	card.id = "stele_skill_choice"
	card.reward_type = RewardData.RewardType.UPGRADE_WEAPON_ILVL if is_atk else RewardData.RewardType.RANDOM_SPELL
	card.title = ability.ability_name
	card.icon = ability.icon
	card.description = _format_skill_stele_description(ability, elem, is_atk)
	card.button_text = "Inscribe Attack" if is_atk else "Inscribe Spell"
	card.card_color = (
		TotemRewardData.get_element_ui_color(elem)
		if not elem.is_empty()
		else Color(0.78, 0.74, 0.62, 1.0)
	)
	return card


static func _format_skill_stele_description(ability: AbilityData, elem: String, is_atk: bool) -> String:
	var kind_str: String = "Attack" if is_atk else "Spell"
	var prefix_str: String = kind_str
	if not elem.is_empty():
		prefix_str = "%s %s" % [elem.capitalize(), kind_str]
	elif is_atk:
		prefix_str = "Martial Attack"
	else:
		prefix_str = "Arcane / Utility Spell"

	var header: String = "%s • CD %.0fs | Mana %.0f" % [
		prefix_str,
		ability.cooldown,
		ability.mana_cost
	]
	var body: String = _shorten_text(ability.description, 108)
	if body.is_empty():
		return header
	return header + "\n" + body


static func _shorten_text(raw_text: String, max_chars: int) -> String:
	var clean: String = raw_text.strip_edges().replace("\n", " ")
	if clean.length() <= max_chars:
		return clean
	var dot_idx: int = clean.find(". ")
	if dot_idx >= 35 and dot_idx + 1 <= max_chars:
		return clean.substr(0, dot_idx + 1)
	var clipped: String = clean.substr(0, max_chars - 3)
	var last_space: int = clipped.rfind(" ")
	if last_space > 25:
		clipped = clipped.substr(0, last_space)
	return clipped.rstrip(".,;:") + "..."


func is_eligible(player: CharacterBody3D, _pnj: Node = null) -> bool:
	if player == null or offered_ability == null:
		return false
	return not TotemRewardData.is_ability_unlocked_by_player(player, offered_ability)


func apply_reward(player: CharacterBody3D, _pnj: Node = null, on_complete: Callable = Callable()) -> void:
	if player == null or offered_ability == null:
		push_warning("[SkillSteleRewardData] Impossible d'appliquer la compétence (player ou ability null).")
		return

	var spellbook_ui: SpellBookUI = _get_spellbook_ui(player)
	if spellbook_ui == null:
		push_error("[SkillSteleRewardData] SpellBookUI introuvable sur le joueur.")
		return

	var ability_to_grant: AbilityData = offered_ability
	if TotemRewardData.is_ability_unlocked_by_player(player, ability_to_grant):
		var fallback: Array[AbilityData] = []
		if strict_tier1_only:
			fallback = get_locked_tier1_attacks(player) if is_attack_skill else get_locked_tier1_spells(player)
			if fallback.is_empty():
				fallback = get_locked_tier1_spells(player) if is_attack_skill else get_locked_tier1_attacks(player)
		else:
			fallback = get_locked_skills_from_pool(player, GameData.get_droppable_skills(0.14))
		if not fallback.is_empty():
			ability_to_grant = fallback[randi_range(0, fallback.size() - 1)]
		else:
			print("[SkillSteleRewardData] Le joueur maîtrise déjà toutes les compétences disponibles.")
			if on_complete.is_valid():
				on_complete.call()
			return

	spellbook_ui.unlock_spell(ability_to_grant)
	print("[SkillStele] Nouvelle compétence gravée débloquée : ", ability_to_grant.ability_name)

	if on_complete.is_valid():
		on_complete.call()
