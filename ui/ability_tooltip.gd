class_name AbilityTooltip
extends PanelContainer

@export var title_label: Label
@export var description_label: Label
@export var stats_label: RichTextLabel

var _ability: AbilityData = null


func _ready() -> void:
	if _ability != null:
		_refresh_display()


func setup(ability: AbilityData) -> void:
	_ability = ability
	if _ability != null:
		_refresh_display()


func _refresh_display() -> void:
	if _ability == null:
		return

	var is_magic: bool = (_ability.category == AbilityData.AbilityCategory.MAGIC)
	var local_player: Node = _find_local_player() if is_magic else null
	var is_owned: bool = false
	var cur_lvl: int = 1
	var cur_xp: int = 0

	if is_magic and local_player != null:
		var spellbook: Node = local_player.get_node_or_null("SpellBook_UI")
		if spellbook == null:
			spellbook = local_player.find_child("SpellBook_UI", true, false)

		if spellbook != null:
			if spellbook.has_method("has_spell"):
				is_owned = bool(spellbook.call("has_spell", _ability))
			if is_owned:
				if spellbook.has_method("get_spell_level"):
					cur_lvl = maxi(1, int(spellbook.call("get_spell_level", _ability)))
				if spellbook.has_method("get_spell_xp"):
					cur_xp = maxi(0, int(spellbook.call("get_spell_xp", _ability)))
		else:
			var skill_bar: Node = local_player.get_node_or_null("SkillBarComponent")
			if skill_bar == null:
				skill_bar = local_player.find_child("SkillBarComponent", true, false)
			if skill_bar != null and skill_bar.has_method("get_spell_level_for"):
				is_owned = true
				cur_lvl = maxi(1, int(skill_bar.call("get_spell_level_for", _ability)))

	if title_label != null:
		if is_magic:
			var roman: String = _tier_to_roman(_ability.tier)
			if is_owned:
				if cur_lvl >= _ability.max_spell_level:
					title_label.text = "%s  [Tier %s • MAX]" % [_ability.ability_name, roman]
				else:
					title_label.text = "%s  [Tier %s • Lv.%d]" % [_ability.ability_name, roman, cur_lvl]
			else:
				title_label.text = "%s  [Tier %s]" % [_ability.ability_name, roman]
		else:
			title_label.text = _ability.ability_name

	if description_label != null:
		description_label.text = _ability.description

	if stats_label == null:
		return

	var base_stats: String = resolve_base_tooltip_text(_ability)
	if base_stats.is_empty():
		base_stats = "[color=gray]Missing tooltip file. Use TooltipGenerator to create it.[/color]"

	if is_magic and local_player != null:
		var header_line: String = _build_magic_mastery_header(_ability, is_owned, cur_lvl, cur_xp)
		stats_label.text = header_line + "\n" + base_stats
	else:
		stats_label.text = base_stats


static func _build_magic_mastery_header(
	ability: AbilityData,
	is_owned: bool,
	cur_lvl: int,
	cur_xp: int
) -> String:
	var max_lvl: int = maxi(1, ability.max_spell_level)
	if not is_owned:
		return "[color=#9aa4b8][b]Unlearned[/b]  •  Max Mastery Lv.%d[/color]" % max_lvl

	var pwr_pct: int = int(roundf((ability.get_level_power_multiplier(cur_lvl) - 1.0) * 100.0))
	var cd_pct: int = int(roundf((1.0 - ability.get_level_cooldown_multiplier(cur_lvl)) * 100.0))

	if cur_lvl >= max_lvl:
		return "[color=#ffd95e][b]Mastery:[/b] Level %d/%d (MAX)[/color]  •  [color=#7be89c]+%d%% Power, -%d%% CD[/color]" % [
			cur_lvl,
			max_lvl,
			pwr_pct,
			cd_pct
		]

	var req_xp: int = ability.get_xp_for_next_level(cur_lvl)
	if cur_lvl > 1:
		return "[color=#e8d28a][b]Mastery:[/b] Level %d/%d (%d/%d XP)[/color]  •  [color=#7be89c]+%d%% Power, -%d%% CD[/color]" % [
			cur_lvl,
			max_lvl,
			cur_xp,
			req_xp,
			pwr_pct,
			cd_pct
		]

	return "[color=#e8d28a][b]Mastery:[/b] Level 1/%d (%d/%d XP)[/color]" % [max_lvl, cur_xp, req_xp]


static func resolve_base_tooltip_text(ability: AbilityData) -> String:
	if ability.custom_tooltip != null and not ability.custom_tooltip.generated_text.is_empty():
		return ability.custom_tooltip.generated_text

	var original_path: String = ability.resource_path
	if original_path.is_empty():
		return ""

	var tooltip_path: String = original_path.get_base_dir() + "/" + original_path.get_file().get_basename() + "_tooltip.tres"
	if ResourceLoader.exists(tooltip_path):
		var tooltip_res: Resource = ResourceLoader.load(tooltip_path)
		var tooltip_data: SpellTooltipData = tooltip_res as SpellTooltipData
		if tooltip_data != null and not tooltip_data.generated_text.is_empty():
			return tooltip_data.generated_text

	return ""


func _find_local_player() -> Node:
	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree == null:
		return null

	var players: Array[Node] = tree.get_nodes_in_group("Player")
	var fallback: Node = null
	for p: Node in players:
		if p == null or not is_instance_valid(p):
			continue
		if fallback == null:
			fallback = p
		if p.is_multiplayer_authority():
			return p
	return fallback


static func _tier_to_roman(tier_val: int) -> String:
	match tier_val:
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		_:
			return str(maxi(1, tier_val))
