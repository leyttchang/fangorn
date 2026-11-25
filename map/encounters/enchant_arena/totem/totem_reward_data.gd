class_name TotemRewardData
extends RewardData

## Ressource dynamique de récompense des Totems Élémentaires.
## Hérite de `RewardData` pour s'intégrer nativement et sans modification dans
## `reward_choice_ui_d2.tscn` (style Moria / Diablo II) et `reward_choice_ui.tscn` (style Classique).

enum TotemChoiceKind {
	LEGENDARY_WEAPON,
	ELEMENTAL_SPELL,
	ELEMENTAL_ATTACK
}

const SUPPORTED_ELEMENTS: Array[String] = ["arcane", "lightning", "fire", "ice"]

var totem_choice_kind: TotemChoiceKind = TotemChoiceKind.LEGENDARY_WEAPON
var totem_element: String = "arcane"
var totem_ilvl: int = 1
var pre_rolled_weapon: WeaponItem = null
var pre_rolled_ability: AbilityData = null

## Cache statique (resource_path -> élément normalisé : "fire", "ice", "lightning", "arcane", ou "" si sans élément)
static var _ability_element_cache: Dictionary = {}


# =========================================================================
# CLASSIFICATION STRICTE DES COMPÉTENCES (SPELL vs ATTACK & ÉLÉMENT)
# =========================================================================

## Vrai si la compétence est une Attaque martiale (`SkillScalingType.ATTACK` ou `AbilityCategory.WEAPON_ATTACK`)
static func is_attack_ability(ability: AbilityData) -> bool:
	if ability == null:
		return false
	if ability.skill_type == AbilityData.SkillScalingType.ATTACK or ability.category == AbilityData.AbilityCategory.WEAPON_ATTACK:
		return true
	var eff_id: String = ability.get_effective_id()
	return eff_id in ["prismatic_blade", "thunder_aspect", "flaming_stab", "thunder_slash", "ice_crash", "leap_slam", "cleave"]


## Vrai si la compétence est un Sort (`SkillScalingType.SPELL` et non `WEAPON_ATTACK`)
static func is_spell_ability(ability: AbilityData) -> bool:
	if ability == null:
		return false
	return not is_attack_ability(ability)


## Détermine l'élément strict d'une compétence parmi `"fire"`, `"ice"`, `"lightning"`, `"arcane"`.
## Renvoie `""` pour toute compétence purement physique, utilitaire ou sans élément (ex: Dash, Warcry, Light Pillar),
## garantissant qu'elle ne puisse JAMAIS être proposée par un Totem.
static func resolve_ability_element(ability: AbilityData) -> String:
	if ability == null:
		return ""

	var cache_key: String = ability.resource_path if not ability.resource_path.is_empty() else str(ability.get_instance_id())
	if _ability_element_cache.has(cache_key):
		return str(_ability_element_cache[cache_key])

	var resolved: String = _inspect_ability_element_uncached(ability)
	_ability_element_cache[cache_key] = resolved
	return resolved


static func _inspect_ability_element_uncached(ability: AbilityData) -> String:
	# 1. Support futur si un champ explicite `element` est ajouté sur AbilityData
	if "element" in ability:
		var raw_elem: String = _normalize_element_token(str(ability.get("element")))
		if not raw_elem.is_empty():
			return raw_elem

	# 1b. Table explicite pour les sorts/attaques procéduraux (dont les noeuds d'attaque sont créés au runtime)
	var eff_id: String = ability.get_effective_id()
	match eff_id:
		"ember_bolt", "cinder_trail", "fireball", "dragons_breath", "burning_ground", "blazing_stride", "immolation_aura", "living_bomb", "flaming_stab":
			return "fire"
		"glacial_shell", "frost_pulse", "glacial_ram", "frostmirror_aegis", "ice_nova", "ice_spikes", "ice_path", "ice_crash":
			return "ice"
		"crackling_arc", "spark_step", "chain_lightning", "lodestone_beam", "living_lightning", "stormwire", "lightning_strike", "thunder_slash", "thunder_aspect":
			return "lightning"
		"creeping_roots", "kinetic_bolt", "grasping_briars", "sylvan_grapple", "singularity_orb", "magic_shot", "prismatic_blade":
			return "arcane"
		"dash", "warcry", "warcry_ability", "leap_slam", "cleave":
			return ""

	if ability.ability_scene == null:
		return ""

	var scene_inst: Node = ability.ability_scene.instantiate()
	if scene_inst == null:
		return ""

	var has_combat_payload: bool = false
	var elem_flags: Dictionary = {
		"fire": false,
		"ice": false,
		"lightning": false,
		"arcane": false
	}

	_scan_ability_scene_nodes(scene_inst, elem_flags)
	has_combat_payload = bool(elem_flags.get("_has_combat_payload", false))
	scene_inst.free()

	# Exclure strictement les compétences utilitaires sans impact de combat ni buff (ex: Dash, Light Pillar)
	if not has_combat_payload:
		return ""

	var cast_vfx_elem: String = ""
	if ability.cast_vfx_scene != null and not ability.cast_vfx_scene.resource_path.is_empty():
		cast_vfx_elem = _infer_element_from_vfx_path(ability.cast_vfx_scene.resource_path)

	var matched_elements: Array[String] = []
	for elem_name: String in ["fire", "ice", "lightning", "arcane"]:
		if bool(elem_flags.get(elem_name, false)):
			matched_elements.append(elem_name)

	# Cas 1 : Un unique élément détecté dans les ratios de dégâts / statuts / buffs (ex: Fireball, Ice Crash, Thunder Aspect...)
	if matched_elements.size() == 1:
		return matched_elements[0]

	# Cas 2 : Compétence chromatique / multi-élémentaire (ex: Prismatic Blade : +Fire/+Ice/+Lightning avec VFX d'incantation Arcane)
	if matched_elements.size() > 1:
		if not cast_vfx_elem.is_empty():
			return cast_vfx_elem
		return "arcane"

	# Cas 3 : Aucun ratio feu/glace/foudre mais payload de combat réel (ex: Magic Shot -> Spell arcanique à VFX arcane_casting_vfx)
	if not cast_vfx_elem.is_empty():
		return cast_vfx_elem

	var lower_hint: String = (ability.ability_name + " " + ability.resource_path.get_file()).to_lower()
	if "arcane" in lower_hint or (is_spell_ability(ability) and "magic" in lower_hint):
		return "arcane"

	# Sinon c'est une compétence purement physique / martiale sans élément (ex: Warcry) -> exclue !
	return ""


static func _scan_ability_scene_nodes(node: Node, elem_flags: Dictionary) -> void:
	if node == null:
		return

	if node is SpellScalingComponent:
		var scaling: SpellScalingComponent = node as SpellScalingComponent
		if scaling.attack_component != null:
			elem_flags["_has_combat_payload"] = true
		if scaling.fire_ratio > 0.001:
			elem_flags["fire"] = true
		if scaling.ice_ratio > 0.001:
			elem_flags["ice"] = true
		if scaling.lightning_ratio > 0.001:
			elem_flags["lightning"] = true

	if node is AttackComponent:
		var atk: AttackComponent = node as AttackComponent
		elem_flags["_has_combat_payload"] = true
		for app: StatusEffectApplication in atk.status_effects_to_apply:
			if app != null and app.effect != null:
				_mark_element_from_status_effect(app.effect, elem_flags)

	if "buff_data" in node:
		var b_data: StatusEffectData = node.get("buff_data") as StatusEffectData
		if b_data != null:
			elem_flags["_has_combat_payload"] = true
			_mark_element_from_status_effect(b_data, elem_flags)

	for child: Node in node.get_children():
		_scan_ability_scene_nodes(child, elem_flags)


static func _mark_element_from_status_effect(effect: StatusEffectData, elem_flags: Dictionary) -> void:
	if effect == null:
		return
	var id_low: String = effect.effect_id.to_lower()
	if "burn" in id_low or "fire" in id_low or "ignite" in id_low:
		elem_flags["fire"] = true
	if "chill" in id_low or "freeze" in id_low or "ice" in id_low or "frost" in id_low:
		elem_flags["ice"] = true
	if "shock" in id_low or "lightning" in id_low or "thunder" in id_low:
		elem_flags["lightning"] = true
	if "arcane" in id_low:
		elem_flags["arcane"] = true

	for mod: StatModifierData in effect.stat_modifiers:
		if mod == null:
			continue
		var s_name: String = mod.stat_name.to_lower()
		if "fire_damage" in s_name:
			elem_flags["fire"] = true
		elif "ice_damage" in s_name:
			elem_flags["ice"] = true
		elif "lightning_damage" in s_name:
			elem_flags["lightning"] = true
		elif "magic_damage" in s_name or "arcane_damage" in s_name:
			elem_flags["arcane"] = true


static func _infer_element_from_vfx_path(vfx_path: String) -> String:
	var fname: String = vfx_path.get_file().to_lower()
	if "arcane" in fname:
		return "arcane"
	if "fire" in fname or "flame" in fname:
		return "fire"
	if "ice" in fname or "frost" in fname:
		return "ice"
	if "lightning" in fname or "thunder" in fname:
		return "lightning"
	return ""


static func _normalize_element_token(raw: String) -> String:
	var low: String = raw.strip_edges().to_lower()
	if low in ["arcane", "magic"]:
		return "arcane"
	if low in ["lightning", "thunder", "electric"]:
		return "lightning"
	if low in ["fire", "flame"]:
		return "fire"
	if low in ["ice", "frost", "cold"]:
		return "ice"
	return ""


# =========================================================================
# GÉNÉRATION DES 3 CHOIX DU TOTEM PAR JOUEUR
# =========================================================================

## Vérifie si le joueur possède déjà une compétence (dans son SpellBookUI ou équipée sur sa SkillBarComponent)
static func is_ability_unlocked_by_player(player: Node, ability: AbilityData) -> bool:
	if player == null or ability == null:
		return false

	var helper := TotemRewardData.new()
	var spellbook_ui: SpellBookUI = helper._get_spellbook_ui(player)
	var skill_bar: SkillBarComponent = helper._get_skill_bar(player)

	if spellbook_ui != null:
		for unlocked: AbilityData in spellbook_ui.unlocked_spells:
			if unlocked != null and (unlocked == ability or unlocked.ability_name == ability.ability_name):
				return true

	if skill_bar != null:
		for slot_val: Variant in skill_bar.slots.values():
			var slot_spell: AbilityData = slot_val as AbilityData
			if slot_spell != null and (slot_spell == ability or slot_spell.ability_name == ability.ability_name):
				return true

	return false


## Retourne toutes les compétences verrouillées pour ce joueur correspondant exactement à l'élément et au type demandé
static func get_locked_elemental_abilities(player: Node, element: String, want_attack: bool) -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	var norm_elem: String = _normalize_element_token(element)
	if norm_elem.is_empty():
		return result

	var all_abilities: Array[AbilityData] = GameData.get_all_non_evolution_skills()
	for ab: AbilityData in all_abilities:
		if ab == null or ab.is_evolution_only:
			continue
		if want_attack and not is_attack_ability(ab):
			continue
		if not want_attack and not is_spell_ability(ab):
			continue
		if resolve_ability_element(ab) != norm_elem:
			continue
		if is_ability_unlocked_by_player(player, ab):
			continue
		result.append(ab)

	return result


## Construit jusqu'à 3 choix de récompenses pour le joueur sur ce Totem :
## 1) Arme Légendaire+ (LEGENDARY ou UNIQUE) pré-tirée au `totem_ilvl`
## 2) Sort (`Spell`) de l'élément du totem non encore débloqué
## 3) Attaque (`Attack`) de l'élément du totem non encore débloquée
static func build_totem_choices_for_player(player: CharacterBody3D, element: String, ilvl: int) -> Array[RewardData]:
	var choices: Array[RewardData] = []
	var norm_elem: String = _normalize_element_token(element)
	if norm_elem.is_empty():
		norm_elem = "arcane"
	var effective_ilvl: int = maxi(1, ilvl)

	# Carte 1 : Arme Légendaire+ au ilvl du Totem
	var weapon_card: TotemRewardData = _create_legendary_weapon_card(norm_elem, effective_ilvl)
	if weapon_card != null:
		choices.append(weapon_card)

	# Carte 2 : Sort (Spell) de l'élément du Totem
	var spell_card: TotemRewardData = _create_elemental_ability_card(player, norm_elem, effective_ilvl, false)
	if spell_card != null:
		choices.append(spell_card)

	# Carte 3 : Attaque (Attack) de l'élément du Totem
	var attack_card: TotemRewardData = _create_elemental_ability_card(player, norm_elem, effective_ilvl, true)
	if attack_card != null:
		choices.append(attack_card)

	return choices


## Rafraîchit une liste de choix mémorisée (si le joueur a fermé avec Échap, débloqué le sort ailleurs, puis rouvert)
static func refresh_cached_choices_for_player(cached: Array[RewardData], player: CharacterBody3D, element: String, ilvl: int) -> Array[RewardData]:
	var refreshed: Array[RewardData] = []
	var norm_elem: String = _normalize_element_token(element)
	if norm_elem.is_empty():
		norm_elem = "arcane"
	var effective_ilvl: int = maxi(1, ilvl)

	for rd: RewardData in cached:
		var trd: TotemRewardData = rd as TotemRewardData
		if trd == null:
			continue
		match trd.totem_choice_kind:
			TotemChoiceKind.LEGENDARY_WEAPON:
				refreshed.append(trd)
			TotemChoiceKind.ELEMENTAL_SPELL:
				if trd.pre_rolled_ability != null and not is_ability_unlocked_by_player(player, trd.pre_rolled_ability):
					refreshed.append(trd)
				else:
					var replacement_spell: TotemRewardData = _create_elemental_ability_card(player, norm_elem, effective_ilvl, false)
					if replacement_spell != null:
						refreshed.append(replacement_spell)
			TotemChoiceKind.ELEMENTAL_ATTACK:
				if trd.pre_rolled_ability != null and not is_ability_unlocked_by_player(player, trd.pre_rolled_ability):
					refreshed.append(trd)
				else:
					var replacement_atk: TotemRewardData = _create_elemental_ability_card(player, norm_elem, effective_ilvl, true)
					if replacement_atk != null:
						refreshed.append(replacement_atk)

	return refreshed


static func _create_legendary_weapon_card(element: String, effective_ilvl: int) -> TotemRewardData:
	var weapon_bases: Array[WeaponItem] = _get_eligible_weapon_bases()
	if weapon_bases.is_empty():
		push_warning("[TotemRewardData] Aucune base WeaponItem trouvée dans GameData !")
		return null

	var chosen_base: WeaponItem = weapon_bases[randi_range(0, weapon_bases.size() - 1)]
	# En passant Rarity.LEGENDARY, ItemGenerator teste d'abord `possible_uniques` (chance d'Unique),
	# et garantit sinon une arme Légendaire à 3 affixes scalée sur `effective_ilvl`.
	var generated_eq: EquipmentItem = ItemGenerator.generate_equipment(
		chosen_base,
		effective_ilvl,
		ItemData.Rarity.LEGENDARY,
		GameData.get_all_affixes()
	)
	var rolled_weapon: WeaponItem = generated_eq as WeaponItem
	if rolled_weapon == null:
		return null

	var card := TotemRewardData.new()
	card.totem_choice_kind = TotemChoiceKind.LEGENDARY_WEAPON
	card.totem_element = element
	card.totem_ilvl = effective_ilvl
	card.pre_rolled_weapon = rolled_weapon

	card.id = "totem_legendary_weapon"
	card.reward_type = RewardData.RewardType.RANDOM_EQUIPMENT
	card.target_item_type = ItemData.ItemType.main_hand
	card.title = rolled_weapon.item_name
	card.description = _format_weapon_card_description(rolled_weapon)
	card.icon = rolled_weapon.icon
	card.button_text = "Claim Weapon"
	card.card_color = (
		Color(0.85, 0.35, 0.12, 1.0)
		if rolled_weapon.rarity == ItemData.Rarity.UNIQUE
		else Color(1.0, 0.55, 0.12, 1.0)
	)
	return card


static func _create_elemental_ability_card(player: CharacterBody3D, element: String, effective_ilvl: int, want_attack: bool) -> TotemRewardData:
	var pool: Array[AbilityData] = get_locked_elemental_abilities(player, element, want_attack)
	if pool.is_empty():
		return null

	var picked_ability: AbilityData = pool[randi_range(0, pool.size() - 1)]
	var card := TotemRewardData.new()
	card.totem_choice_kind = TotemChoiceKind.ELEMENTAL_ATTACK if want_attack else TotemChoiceKind.ELEMENTAL_SPELL
	card.totem_element = element
	card.totem_ilvl = effective_ilvl
	card.pre_rolled_ability = picked_ability

	card.id = "totem_element_attack" if want_attack else "totem_element_spell"
	# Sur l'UI Moria D2, RANDOM_SPELL donne la teinte bleu runique et UPGRADE_WEAPON_ILVL donne l'ambre forgé martial
	card.reward_type = RewardData.RewardType.UPGRADE_WEAPON_ILVL if want_attack else RewardData.RewardType.RANDOM_SPELL
	card.title = picked_ability.ability_name
	card.description = _format_ability_card_description(picked_ability, element, want_attack)
	card.icon = picked_ability.icon
	card.button_text = "Learn Attack" if want_attack else "Learn Spell"
	card.card_color = get_element_ui_color(element)
	return card


static func _get_eligible_weapon_bases() -> Array[WeaponItem]:
	var all_main_hand: Array[EquipmentItem] = GameData.get_bases_by_type(ItemData.ItemType.main_hand)
	var non_starter: Array[WeaponItem] = []
	var all_weapons: Array[WeaponItem] = []

	for b: EquipmentItem in all_main_hand:
		var w: WeaponItem = b as WeaponItem
		if w == null:
			continue
		all_weapons.append(w)
		if w.id != "starting_sword":
			non_starter.append(w)

	if not non_starter.is_empty():
		return non_starter
	return all_weapons


# =========================================================================
# FORMATAGE LISIBLE DES CARTES (TEXTE BRUT SANS BBCODE POUR LABEL STELE D2)
# =========================================================================

static func get_element_ui_color(element: String) -> Color:
	match _normalize_element_token(element):
		"fire":
			return Color(1.0, 0.45, 0.16, 1.0)
		"ice":
			return Color(0.42, 0.84, 1.0, 1.0)
		"lightning":
			return Color(0.95, 0.84, 0.30, 1.0)
		_:
			return Color(0.82, 0.48, 1.0, 1.0)


static func _format_weapon_card_description(weapon: WeaponItem) -> String:
	var rarity_label: String = "Unique" if weapon.rarity == ItemData.Rarity.UNIQUE else "Legendary"
	var lines: Array[String] = []
	lines.append("%s Weapon • iLvl %d" % [rarity_label, weapon.ilvl])
	lines.append("Dmg: %d  |  Speed: %.2f/s" % [int(round(weapon.base_damage)), weapon.base_attack_speed])

	var stat_lines: Array[String] = []
	if not weapon.affix_stats.is_empty():
		for key_var: Variant in weapon.affix_stats.keys():
			var stat_key: String = str(key_var)
			var val: float = float(weapon.affix_stats[stat_key])
			if absf(val) > 0.0001:
				stat_lines.append(_format_single_stat_line(stat_key, val))
	elif not weapon.innate_stats.is_empty():
		for key_var: Variant in weapon.innate_stats.keys():
			var stat_key: String = str(key_var)
			var val: float = float(weapon.innate_stats[stat_key])
			if absf(val) > 0.0001:
				stat_lines.append(_format_single_stat_line(stat_key, val))

	var max_stat_lines: int = mini(3, stat_lines.size())
	for i: int in range(max_stat_lines):
		lines.append(stat_lines[i])

	if max_stat_lines == 0 and not weapon.description.strip_edges().is_empty():
		lines.append(_shorten_plain_text(weapon.description, 75))

	return "\n".join(lines)


static func _format_single_stat_line(stat_key: String, val: float) -> String:
	var nice_name: String = _prettify_stat_name(stat_key)
	if GameData.PERCENT_STATS.has(stat_key):
		var pct: int = int(round(val * 100.0))
		var sign_pct: String = "+" if pct >= 0 else ""
		return "%s%d%% %s" % [sign_pct, pct, nice_name]
	if GameData.FLOAT_STATS.has(stat_key):
		var snapped_f: float = snappedf(val, 0.1)
		var sign_f: String = "+" if snapped_f >= 0.0 else ""
		return "%s%.1f %s" % [sign_f, snapped_f, nice_name]
	var rounded_i: int = int(round(val))
	var sign_i: String = "+" if rounded_i >= 0 else ""
	return "%s%d %s" % [sign_i, rounded_i, nice_name]


static func _prettify_stat_name(stat_key: String) -> String:
	match stat_key:
		"cd_red":
			return "Cooldown Red."
		"area_of_effect":
			return "Area of Effect"
		"max_health":
			return "Max Health"
		"max_mana":
			return "Max Mana"
		"mana_regen":
			return "Mana Regen"
		"flat_physical_damage":
			return "Flat Phys. Dmg"
		"flat_fire_damage":
			return "Flat Fire Dmg"
		"flat_ice_damage":
			return "Flat Ice Dmg"
		"flat_lightning_damage":
			return "Flat Lightning Dmg"
		_:
			return stat_key.replace("_", " ").capitalize()


static func _format_ability_card_description(ability: AbilityData, element: String, is_attack: bool) -> String:
	var elem_title: String = _normalize_element_token(element).capitalize()
	var kind_title: String = "Attack" if is_attack else "Spell"
	var header: String = "%s %s • CD %.0fs | Mana %.0f" % [
		elem_title,
		kind_title,
		ability.cooldown,
		ability.mana_cost
	]
	var body: String = _shorten_plain_text(ability.description, 105)
	if body.is_empty():
		return header
	return header + "\n" + body


static func _shorten_plain_text(raw_text: String, max_chars: int) -> String:
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


# =========================================================================
# APPLICATION DE LA RÉCOMPENSE CHOISIE AU JOUEUR
# =========================================================================

func is_eligible(player: CharacterBody3D, _pnj: Node = null) -> bool:
	if player == null:
		return false
	match totem_choice_kind:
		TotemChoiceKind.LEGENDARY_WEAPON:
			return pre_rolled_weapon != null
		TotemChoiceKind.ELEMENTAL_SPELL, TotemChoiceKind.ELEMENTAL_ATTACK:
			return pre_rolled_ability != null and not is_ability_unlocked_by_player(player, pre_rolled_ability)
	return false


func apply_reward(player: CharacterBody3D, _pnj: Node = null, on_complete: Callable = Callable()) -> void:
	if player == null:
		push_error("[TotemRewardData] Impossible d'appliquer la récompense : player est null.")
		return

	match totem_choice_kind:
		TotemChoiceKind.LEGENDARY_WEAPON:
			_grant_preroll_weapon(player, on_complete)
		TotemChoiceKind.ELEMENTAL_SPELL, TotemChoiceKind.ELEMENTAL_ATTACK:
			_grant_preroll_ability(player, on_complete)


func _grant_preroll_weapon(player: CharacterBody3D, on_complete: Callable) -> void:
	if pre_rolled_weapon == null:
		push_warning("[TotemRewardData] Aucune arme pré-tirée disponible.")
		return

	var inv: InventoryComponent = player.get_node_or_null("InventoryComponent") as InventoryComponent
	if inv == null:
		inv = player.find_child("InventoryComponent", true, false) as InventoryComponent
	if inv == null:
		push_warning("[TotemRewardData] InventoryComponent introuvable sur le joueur.")
		return

	var weapon_copy: WeaponItem = pre_rolled_weapon.duplicate(true) as WeaponItem
	if weapon_copy == null:
		weapon_copy = pre_rolled_weapon
	weapon_copy.original_base_path = pre_rolled_weapon.original_base_path
	weapon_copy.innate_stats = pre_rolled_weapon.innate_stats.duplicate(true)
	weapon_copy.affix_stats = pre_rolled_weapon.affix_stats.duplicate(true)
	weapon_copy.stat_bonuses = pre_rolled_weapon.stat_bonuses.duplicate(true)

	var remaining: int = inv.add_item(weapon_copy, 1)
	if remaining > 0:
		var item_dict: Dictionary = inv.pack_item(weapon_copy)
		if player.multiplayer.has_multiplayer_peer():
			inv.rpc_id(1, "_rpc_spawn_bag", item_dict, remaining)
		else:
			inv._rpc_spawn_bag(item_dict, remaining)
		print("[TotemRewardData] Inventaire plein : arme déposée au sol -> %s (iLvl %d)" % [weapon_copy.item_name, weapon_copy.ilvl])
	else:
		var rarity_str: String = str(ItemData.Rarity.keys()[weapon_copy.rarity])
		print("[TotemRewardData] Arme accordée au joueur : %s (%s, iLvl %d)" % [weapon_copy.item_name, rarity_str, weapon_copy.ilvl])

	if on_complete.is_valid():
		on_complete.call()


func _grant_preroll_ability(player: CharacterBody3D, on_complete: Callable) -> void:
	if pre_rolled_ability == null:
		push_warning("[TotemRewardData] Aucune compétence pré-tirée disponible.")
		return

	var spellbook_ui: SpellBookUI = _get_spellbook_ui(player)
	if spellbook_ui == null:
		push_warning("[TotemRewardData] SpellBookUI introuvable sur le joueur.")
		return

	if is_ability_unlocked_by_player(player, pre_rolled_ability):
		var want_atk: bool = (totem_choice_kind == TotemChoiceKind.ELEMENTAL_ATTACK)
		var fallback_pool: Array[AbilityData] = get_locked_elemental_abilities(player, totem_element, want_atk)
		if not fallback_pool.is_empty():
			pre_rolled_ability = fallback_pool[randi_range(0, fallback_pool.size() - 1)]
		else:
			print("[TotemRewardData] Toutes les compétences de cette catégorie/élément sont déjà débloquées.")
			if on_complete.is_valid():
				on_complete.call()
			return

	spellbook_ui.unlock_spell(pre_rolled_ability)
	var kind_str: String = "Attaque" if totem_choice_kind == TotemChoiceKind.ELEMENTAL_ATTACK else "Sort"
	print("[TotemRewardData] %s élémentaire (%s) débloqué(e) -> %s" % [kind_str, totem_element, pre_rolled_ability.ability_name])

	if on_complete.is_valid():
		on_complete.call()
