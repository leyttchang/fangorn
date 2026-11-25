class_name SpellBookUI
extends CanvasLayer

signal spell_xp_changed(spell_id: String, level: int, current_xp: int, next_xp: int)
signal spell_leveled_up(ability: AbilityData, new_level: int)
signal spell_evolution_unlocked(parent_ability: AbilityData, child_ability: AbilityData)

@export var skill_bar: SkillBarComponent
@export var unlocked_spells: Array[AbilityData] = []

const SLOT_SCENE: PackedScene = preload("res://ui/SpellBook/spell_u_slot.tscn")

@onready var u_grid: GridContainer = %inv_grid
@onready var unlock_btn: Button = find_child("UnlockAllButton", true, false) as Button
@onready var test_lvl_btn: Button = find_child("TestLevelUpButton", true, false) as Button

var spell_levels: Dictionary = {} # spell_id -> int
var spell_xp: Dictionary = {}     # spell_id -> int
var selected_ability: AbilityData = null

# Références Panneau Droit (Inspecteur + Arbre d'Évolution)
var _detail_icon: TextureRect = null
var _detail_name: Label = null
var _detail_tags: Label = null
var _detail_lvl_label: Label = null
var _detail_xp_bar: ProgressBar = null
var _detail_scaling_label: Label = null
var _detail_desc: RichTextLabel = null
var _lineage_graph: SpellLineageGraph = null
var _req_rich_label: RichTextLabel = null
var _evolve_btn: Button = null
var _pending_evolve_parent: AbilityData = null


func _ready() -> void:
	visible = false
	_resolve_player_refs()
	_cache_right_panel_nodes()

	if unlock_btn != null and not unlock_btn.pressed.is_connected(unlock_all_spells):
		unlock_btn.pressed.connect(unlock_all_spells)
	if test_lvl_btn != null and not test_lvl_btn.pressed.is_connected(_on_test_level_up_pressed):
		test_lvl_btn.pressed.connect(_on_test_level_up_pressed)
	if _evolve_btn != null and not _evolve_btn.pressed.is_connected(_on_evolve_button_pressed):
		_evolve_btn.pressed.connect(_on_evolve_button_pressed)
	if _lineage_graph != null and not _lineage_graph.node_clicked.is_connected(_on_lineage_node_clicked):
		_lineage_graph.node_clicked.connect(_on_lineage_node_clicked)

	for ab: AbilityData in unlocked_spells:
		if ab != null:
			_ensure_spell_entry(ab)

	_setup_inventory_slots()
	if selected_ability == null and not unlocked_spells.is_empty():
		select_ability(unlocked_spells[0])
	else:
		_refresh_inspector_panel()


func _resolve_player_refs() -> void:
	if skill_bar == null:
		var p: Node = owner
		while p != null:
			if p is CharacterBody3D and p.is_in_group("Player"):
				skill_bar = p.get_node_or_null("SkillBarComponent") as SkillBarComponent
				break
			p = p.owner if p.owner != null else p.get_parent()
	if skill_bar == null:
		push_error("SpellBookUI : SkillBarComponent manquant.")


func _get_player_node() -> Node:
	if skill_bar != null and skill_bar.get_parent() != null:
		return skill_bar.get_parent()
	var p: Node = owner
	while p != null:
		if p is CharacterBody3D and p.is_in_group("Player"):
			return p
		p = p.owner if p.owner != null else p.get_parent()
	return get_parent()


func _cache_right_panel_nodes() -> void:
	_detail_icon = find_child("DetailIcon", true, false) as TextureRect
	_detail_name = find_child("DetailNameLabel", true, false) as Label
	_detail_tags = find_child("DetailTagsLabel", true, false) as Label
	_detail_lvl_label = find_child("DetailLevelLabel", true, false) as Label
	_detail_xp_bar = find_child("DetailXPBar", true, false) as ProgressBar
	_detail_scaling_label = find_child("DetailScalingLabel", true, false) as Label
	_detail_desc = find_child("DetailStatsRich", true, false) as RichTextLabel
	_lineage_graph = find_child("LineageGraph", true, false) as SpellLineageGraph
	_req_rich_label = find_child("RequirementsRich", true, false) as RichTextLabel
	_evolve_btn = find_child("UnlockEvolutionButton", true, false) as Button


func _resolve_id(ability_or_id: Variant) -> String:
	if ability_or_id is AbilityData:
		return (ability_or_id as AbilityData).get_effective_id()
	elif ability_or_id is String:
		var raw: String = (ability_or_id as String).strip_edges().to_lower()
		for ab: AbilityData in GameData.get_all_spells():
			if ab != null and (ab.get_effective_id() == raw or ab.ability_name.to_lower() == raw):
				return ab.get_effective_id()
		return raw.replace(" ", "_").replace("'", "")
	return ""


func _find_ability_by_id(id_str: String) -> AbilityData:
	for ab: AbilityData in unlocked_spells:
		if ab != null and ab.get_effective_id() == id_str:
			return ab
	for ab_all: AbilityData in GameData.get_all_spells():
		if ab_all != null and ab_all.get_effective_id() == id_str:
			return ab_all
	return null


func _ensure_spell_entry(ability: AbilityData) -> void:
	if ability == null:
		return
	var sid: String = ability.get_effective_id()
	if not spell_levels.has(sid):
		spell_levels[sid] = 1
	if not spell_xp.has(sid):
		spell_xp[sid] = 0


func get_spell_level(ability_or_id: Variant) -> int:
	var sid: String = _resolve_id(ability_or_id)
	if sid.is_empty():
		return 1
	return maxi(1, int(spell_levels.get(sid, 1)))


func get_spell_xp(ability_or_id: Variant) -> int:
	var sid: String = _resolve_id(ability_or_id)
	if sid.is_empty():
		return 0
	return maxi(0, int(spell_xp.get(sid, 0)))


func has_spell(ability_or_name: Variant) -> bool:
	var target_id: String = _resolve_id(ability_or_name)
	if target_id.is_empty():
		return false
	for ab: AbilityData in unlocked_spells:
		if ab != null and ab.get_effective_id() == target_id:
			return true
	return false


func has_spell_at_level(spell_name: String, min_level: int = 1) -> bool:
	var sid: String = _resolve_id(spell_name)
	if not has_spell(sid):
		return false
	return get_spell_level(sid) >= min_level


## Appelé automatiquement par LevelComponent.add_xp(amount) :
## Tous les sorts (MAGIC) équipés dans la barre active reçoivent l'XP gagnée.
func on_player_xp_gained(amount: int) -> void:
	if amount <= 0 or skill_bar == null:
		return

	var awarded_ids: Dictionary = {}
	for slot_key: String in skill_bar.slots.keys():
		var eq_ab: AbilityData = skill_bar.slots[slot_key]
		if eq_ab == null or eq_ab.category != AbilityData.AbilityCategory.MAGIC:
			continue
		var sid: String = eq_ab.get_effective_id()
		if awarded_ids.has(sid):
			continue
		awarded_ids[sid] = true
		add_spell_xp(eq_ab, amount)


## Méthode publique permettant aussi d'injecter de l'XP directement dans un sort spécifique (récompenses, événements, etc.)
func add_spell_xp(ability_or_id: Variant, amount: int) -> bool:
	if amount <= 0:
		return false
	var sid: String = _resolve_id(ability_or_id)
	if sid.is_empty():
		return false

	var ab: AbilityData = ability_or_id as AbilityData if ability_or_id is AbilityData else _find_ability_by_id(sid)
	if ab == null or ab.category != AbilityData.AbilityCategory.MAGIC:
		return false

	_ensure_spell_entry(ab)
	var cur_lvl: int = int(spell_levels[sid])
	if cur_lvl >= ab.max_spell_level:
		return false

	var cur_xp_val: int = int(spell_xp[sid]) + amount
	var leveled: bool = false

	while cur_lvl < ab.max_spell_level:
		var req: int = ab.get_xp_for_next_level(cur_lvl)
		if cur_xp_val >= req:
			cur_xp_val -= req
			cur_lvl += 1
			leveled = true
		else:
			break

	if cur_lvl >= ab.max_spell_level:
		cur_xp_val = 0

	spell_levels[sid] = cur_lvl
	spell_xp[sid] = cur_xp_val

	var next_req: int = 0 if cur_lvl >= ab.max_spell_level else ab.get_xp_for_next_level(cur_lvl)
	spell_xp_changed.emit(sid, cur_lvl, cur_xp_val, next_req)

	if leveled:
		spell_leveled_up.emit(ab, cur_lvl)
		print("[SpellBook] %s leveled up to Lv.%d/%d!" % [ab.ability_name, cur_lvl, ab.max_spell_level])

	if visible:
		_setup_inventory_slots()
		_refresh_inspector_panel()
	return leveled


func are_requirements_met(target_ability: AbilityData) -> bool:
	if target_ability == null:
		return false
	var player: Node = _get_player_node()
	for req: SpellRequirementData in target_ability.unlock_requirements:
		if req != null and not req.is_met(player):
			return false
	return true


func can_unlock_evolution(parent_ability: AbilityData, child_ability: AbilityData) -> bool:
	if parent_ability == null or child_ability == null:
		return false
	if has_spell(child_ability):
		return false
	if not has_spell(parent_ability):
		return false
	if get_spell_level(parent_ability) < parent_ability.max_spell_level:
		return false

	var is_valid_child: bool = false
	for evo: AbilityData in parent_ability.evolutions:
		if evo != null and evo.get_effective_id() == child_ability.get_effective_id():
			is_valid_child = true
			break
	if not is_valid_child:
		return false

	return are_requirements_met(child_ability)


func can_unlock_any_parent_to(child_ability: AbilityData) -> bool:
	return _find_ready_parent_for(child_ability) != null


func _find_ready_parent_for(child_ability: AbilityData) -> AbilityData:
	if child_ability == null or has_spell(child_ability):
		return null
	for p_ab: AbilityData in unlocked_spells:
		if p_ab != null and can_unlock_evolution(p_ab, child_ability):
			return p_ab
	return null


func _find_all_parents_for(child_ability: AbilityData) -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	if child_ability == null:
		return result
	var target_id: String = child_ability.get_effective_id()
	for ab: AbilityData in GameData.get_all_spells():
		if ab == null:
			continue
		for evo: AbilityData in ab.evolutions:
			if evo != null and evo.get_effective_id() == target_id:
				result.append(ab)
				break
	return result


func has_ready_evolution(parent_ability: AbilityData) -> bool:
	if parent_ability == null or not has_spell(parent_ability):
		return false
	if get_spell_level(parent_ability) < parent_ability.max_spell_level:
		return false
	for child_ab: AbilityData in parent_ability.evolutions:
		if child_ab != null and can_unlock_evolution(parent_ability, child_ab):
			return true
	return false


func unlock_evolution(parent_ability: AbilityData, child_ability: AbilityData) -> bool:
	if not can_unlock_evolution(parent_ability, child_ability):
		return false
	var ok: bool = unlock_spell(child_ability)
	if ok:
		spell_evolution_unlocked.emit(parent_ability, child_ability)
		select_ability(child_ability)
	return ok


func unlock_all_spells() -> void:
	var all_spells: Array[AbilityData] = GameData.get_all_spells()
	for spell_res: AbilityData in all_spells:
		if spell_res != null:
			unlock_spell(spell_res)
	_setup_inventory_slots()
	if selected_ability == null and not unlocked_spells.is_empty():
		select_ability(unlocked_spells[0])
	else:
		_refresh_inspector_panel()


func _on_test_level_up_pressed() -> void:
	var target_ab: AbilityData = selected_ability
	if target_ab == null and not unlocked_spells.is_empty():
		target_ab = unlocked_spells[0]
	if target_ab == null or target_ab.category != AbilityData.AbilityCategory.MAGIC:
		return
	var cur_lvl: int = get_spell_level(target_ab)
	if cur_lvl >= target_ab.max_spell_level:
		return
	var needed: int = maxi(1, target_ab.get_xp_for_next_level(cur_lvl) - get_spell_xp(target_ab))
	add_spell_xp(target_ab, needed)


func _on_evolve_button_pressed() -> void:
	if selected_ability == null or _pending_evolve_parent == null:
		return
	unlock_evolution(_pending_evolve_parent, selected_ability)


func _on_lineage_node_clicked(ability: AbilityData) -> void:
	if ability != null:
		select_ability(ability)


func select_ability(ability: AbilityData) -> void:
	selected_ability = ability
	_setup_inventory_slots()
	_refresh_inspector_panel()


func _setup_inventory_slots() -> void:
	if u_grid == null:
		return

	var needed_slots: int = maxi(25, ((unlocked_spells.size() + 4) / 5) * 5)
	while u_grid.get_child_count() < needed_slots:
		var new_slot: Control = SLOT_SCENE.instantiate() as Control
		if new_slot == null:
			break
		new_slot.custom_minimum_size = Vector2(96.0, 96.0)
		u_grid.add_child(new_slot)

	var u_slots: Array[Node] = u_grid.get_children()
	var sel_id: String = selected_ability.get_effective_id() if selected_ability != null else ""

	for i: int in range(u_slots.size()):
		var slot_ctrl: SpellUSlot = u_slots[i] as SpellUSlot
		if slot_ctrl == null:
			continue
		if not slot_ctrl.slot_selected.is_connected(_on_slot_clicked):
			slot_ctrl.slot_selected.connect(_on_slot_clicked)

		if i < unlocked_spells.size() and unlocked_spells[i] != null:
			var ab: AbilityData = unlocked_spells[i]
			_ensure_spell_entry(ab)
			slot_ctrl.is_selected_in_book = (ab.get_effective_id() == sel_id)
			slot_ctrl.set_ability(ab, self)
		else:
			slot_ctrl.is_selected_in_book = false
			slot_ctrl.set_ability(null, self)


func _on_slot_clicked(ab: AbilityData) -> void:
	select_ability(ab)


func _refresh_inspector_panel() -> void:
	if _detail_name == null:
		return

	if selected_ability == null:
		_detail_name.text = "Select a Skill"
		if _detail_icon != null:
			_detail_icon.texture = null
		if _detail_tags != null:
			_detail_tags.text = "Click any skill on the left to view mastery & evolutions"
		if _detail_lvl_label != null:
			_detail_lvl_label.text = ""
		if _detail_xp_bar != null:
			_detail_xp_bar.visible = false
		if _detail_scaling_label != null:
			_detail_scaling_label.text = ""
		if _detail_desc != null:
			_detail_desc.text = ""
		if _lineage_graph != null:
			_lineage_graph.clear_graph()
		if _req_rich_label != null:
			_req_rich_label.text = ""
		if _evolve_btn != null:
			_evolve_btn.visible = false
		return

	var ab: AbilityData = selected_ability
	var owned: bool = has_spell(ab)

	if _detail_icon != null:
		_detail_icon.texture = ab.icon
		_detail_icon.modulate = Color.WHITE if owned else Color(0.55, 0.58, 0.65, 0.9)

	_detail_name.text = ab.ability_name + ("" if owned else "  [LOCKED]")

	if _detail_tags != null:
		if ab.category == AbilityData.AbilityCategory.WEAPON_ATTACK:
			_detail_tags.text = "MARTIAL WEAPON ATTACK"
		else:
			var elem_txt: String = ab.element.to_upper() if not ab.element.is_empty() else "ARCANE"
			var mode_txt: String = "CHANNEL" if ab.target_mode == AbilityData.TargetMode.CHANNEL else ("INSTANT" if ab.cast_time <= 0.0 else ("CAST %.2fs" % ab.cast_time))
			var rare_txt: String = " • [RARE DROP]" if ab.is_rare_drop else ""
			_detail_tags.text = "%s • TIER %d SPELL • %s%s" % [elem_txt, ab.tier, mode_txt, rare_txt]

	if ab.category == AbilityData.AbilityCategory.MAGIC:
		var lvl: int = get_spell_level(ab) if owned else 1
		var is_max: bool = owned and (lvl >= ab.max_spell_level)
		var xp_cur: int = get_spell_xp(ab) if owned else 0
		var xp_req: int = ab.get_xp_for_next_level(lvl)

		if _detail_lvl_label != null:
			if not owned:
				_detail_lvl_label.text = "Unlearned Spell (Starts at Level 1 / %d)" % ab.max_spell_level
			elif is_max:
				_detail_lvl_label.text = "Mastery Level %d / %d — MAX LEVEL REACHED" % [lvl, ab.max_spell_level]
			else:
				_detail_lvl_label.text = "Mastery Level %d / %d  —  %d / %d XP" % [lvl, ab.max_spell_level, xp_cur, xp_req]

		if _detail_xp_bar != null:
			_detail_xp_bar.visible = owned
			_detail_xp_bar.max_value = float(maxi(1, xp_req))
			_detail_xp_bar.value = float(xp_req if is_max else xp_cur)

		if _detail_scaling_label != null:
			var pwr_pct: int = int(roundf((ab.get_level_power_multiplier(lvl) - 1.0) * 100.0))
			var cd_pct: int = int(roundf((1.0 - ab.get_level_cooldown_multiplier(lvl)) * 100.0))
			if not is_max and owned:
				var next_pwr: int = int(roundf((ab.get_level_power_multiplier(lvl + 1) - 1.0) * 100.0))
				_detail_scaling_label.text = "Level Bonus: +%d%% Power, -%d%% Cooldown  (Next Lv: +%d%% Power)" % [pwr_pct, cd_pct, next_pwr]
			else:
				_detail_scaling_label.text = "Level Bonus: +%d%% Power, -%d%% Cooldown" % [pwr_pct, cd_pct]
	else:
		if _detail_lvl_label != null:
			_detail_lvl_label.text = "Scales directly with your equipped weapon & attack stats"
		if _detail_xp_bar != null:
			_detail_xp_bar.visible = false
		if _detail_scaling_label != null:
			_detail_scaling_label.text = ""

	if _detail_desc != null:
		var cost_str: String = ("%.0f + %.1f/s" % [ab.mana_cost, ab.channel_mana_per_sec]) if ab.target_mode == AbilityData.TargetMode.CHANNEL else ("%.0f" % ab.mana_cost)
		var cd_part: String = ("Charges: [b]%d[/b] (%.1fs)" % [ab.max_charges, ab.cooldown]) if ab.max_charges > 1 else ("Cooldown: [b]%.2fs[/b]" % ab.cooldown)
		var summary_bb: String = "[color=#d8c38a]%s   •   Mana: [b]%s[/b]   •   Range: [b]%.0fm[/b][/color]\n" % [cd_part, cost_str, ab.max_range]
		summary_bb += "[color=#cbc8c0]%s[/color]" % ab.description
		var raw_tt: String = AbilityTooltip.resolve_base_tooltip_text(ab)
		if not raw_tt.is_empty():
			var stripped_tt: String = raw_tt
			var nl_idx: int = stripped_tt.find("\n\n")
			if nl_idx != -1:
				stripped_tt = stripped_tt.substr(nl_idx + 2)
			if not stripped_tt.strip_edges().is_empty():
				summary_bb += "\n\n" + stripped_tt.strip_edges()
		_detail_desc.text = summary_bb

	if _lineage_graph != null:
		_lineage_graph.build_for_ability(ab, GameData.get_all_spells(), self)

	_refresh_evolution_requirements_box(ab, owned)


func _refresh_evolution_requirements_box(ab: AbilityData, owned: bool) -> void:
	_pending_evolve_parent = null
	if _req_rich_label == null or _evolve_btn == null:
		return

	if owned:
		if ab.evolutions.is_empty():
			if ab.category == AbilityData.AbilityCategory.WEAPON_ATTACK:
				_req_rich_label.text = "[color=#8c887e]Martial attacks do not use spell evolution branches.[/color]"
			else:
				_req_rich_label.text = "[color=#9c9688]Unlocked! Equip this spell on your bar to level it up. Higher-tier evolutions in the graph will connect here.[/color]"
		else:
			var lvl: int = get_spell_level(ab)
			if lvl < ab.max_spell_level:
				_req_rich_label.text = "[color=#d8c38a]Reach [b]Max Level (Lv.%d)[/b] with %s, then click a Tier %d node above to unlock its evolution![/color]" % [ab.max_spell_level, ab.ability_name, ab.tier + 1]
			else:
				_req_rich_label.text = "[color=#6ef09a][b]%s is Mastered![/b] Click a child evolution node in the lineage tree above to inspect and unlock it.[/color]" % ab.ability_name
		_evolve_btn.visible = false
		return

	# Sort verrouillé inspecté depuis l'arbre de lignée
	var parents: Array[AbilityData] = _find_all_parents_for(ab)
	var player: Node = _get_player_node()
	var lines: Array[String] = []
	lines.append("[b][color=#e6d39a]Unlock Conditions for %s:[/color][/b]" % ab.ability_name)

	if ab.is_rare_drop and parents.is_empty():
		lines.append("[color=#d99bff]• Rare Drop: Discovered from Ancient Skill Steles or Elemental Totems.[/color]")
		_req_rich_label.text = "\n".join(lines)
		_evolve_btn.visible = false
		return

	var ready_parent: AbilityData = null
	for p_ab: AbilityData in parents:
		var p_owned: bool = has_spell(p_ab)
		var p_lvl: int = get_spell_level(p_ab) if p_owned else 0
		var p_maxed: bool = p_owned and (p_lvl >= p_ab.max_spell_level)
		if p_maxed and ready_parent == null:
			ready_parent = p_ab
		var col: String = "#6ef09a" if p_maxed else "#ff756b"
		var mark: String = "✓" if p_maxed else "✗"
		var status_str: String = ("Lv.%d/%d" % [p_lvl, p_ab.max_spell_level]) if p_owned else "Not Unlocked"
		lines.append("[color=%s]%s Master %s to Lv.%d (%s)[/color]" % [col, mark, p_ab.ability_name, p_ab.max_spell_level, status_str])

	var all_extra_met: bool = true
	for req: SpellRequirementData in ab.unlock_requirements:
		if req == null:
			continue
		var met: bool = req.is_met(player)
		if not met:
			all_extra_met = false
		var r_col: String = "#6ef09a" if met else "#ff756b"
		var r_mark: String = "✓" if met else "✗"
		lines.append("[color=%s]%s %s[/color]" % [r_col, r_mark, req.get_description(player)])

	_req_rich_label.text = "\n".join(lines)

	if ready_parent != null and all_extra_met:
		_pending_evolve_parent = ready_parent
		_evolve_btn.visible = true
		_evolve_btn.disabled = false
		_evolve_btn.text = "UNLOCK EVOLUTION: " + ab.ability_name.to_upper()
	else:
		_evolve_btn.visible = true
		_evolve_btn.disabled = true
		_evolve_btn.text = "REQUIREMENTS NOT MET"


func unlock_spell(ability: AbilityData) -> bool:
	if ability == null:
		return false

	if ability.resource_path != "":
		if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
			rpc("_rpc_unlock_spell", ability.resource_path)
		else:
			_rpc_unlock_spell(ability.resource_path)
	else:
		for s: AbilityData in unlocked_spells:
			if s != null and (s == ability or s.ability_name == ability.ability_name):
				return false
		unlocked_spells.append(ability)
		_ensure_spell_entry(ability)
		_setup_inventory_slots()
		_refresh_inspector_panel()
	return true


@rpc("authority", "call_local", "reliable")
func _rpc_unlock_spell(ability_path: String) -> void:
	var ability: AbilityData = load(ability_path) as AbilityData
	if ability == null:
		return

	for s: AbilityData in unlocked_spells:
		if s != null and (s == ability or s.ability_name == ability.ability_name):
			return

	unlocked_spells.append(ability)
	_ensure_spell_entry(ability)
	if selected_ability == null:
		selected_ability = ability
	_setup_inventory_slots()
	_refresh_inspector_panel()


func open_spellbook() -> void:
	_setup_inventory_slots()
	if selected_ability == null and not unlocked_spells.is_empty():
		selected_ability = unlocked_spells[0]
	visible = true
	# Attend un frame de layout si besoin pour que LineageGraph ait sa taille exacte
	call_deferred("_refresh_inspector_panel")


func close_spellbook() -> void:
	visible = false
