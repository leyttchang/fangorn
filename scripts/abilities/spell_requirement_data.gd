@tool
class_name SpellRequirementData
extends Resource

enum ReqType {
	PASSIVE_TAG_POINTS,
	PASSIVE_KEYSTONE,
	PLAYER_STAT_MIN,
	PLAYER_LEVEL_MIN,
	TOTEM_COMPLETED,
	OWNED_SPELL
}

const TAG_NAMES: Array[String] = [
	"Life", "Mana", "Armor", "Physical", "Fire", "Ice",
	"Lightning", "Elemental", "Speed", "Attack", "Magic", "Utility", "Area"
]

const PERCENT_STAT_NAMES: Array[String] = [
	"attack_speed",
	"cd_red",
	"area_of_effect",
	"movement_speed",
	"casting_speed",
	"physical_damage",
	"magic_damage",
	"arcane_damage",
	"fire_damage",
	"ice_damage",
	"lightning_damage",
	"knockback_power"
]

static var _game_data_script: GDScript = null

@export var req_type: ReqType = ReqType.PASSIVE_TAG_POINTS
@export var custom_label: String = ""

@export_group("Passive Tree Tags (PASSIVE_TAG_POINTS)")
@export_flags("Life", "Mana", "Armor", "Physical", "Fire", "Ice", "Lightning", "Elemental", "Speed", "Attack", "Magic", "Utility", "Area") var passive_tag_mask: int = 0
@export var min_points: int = 3

@export_group("Passive Keystone (PASSIVE_KEYSTONE)")
@export var keystone_id: String = ""

@export_group("Player Stat (PLAYER_STAT_MIN)")
@export var stat_name: String = "magic_damage"
@export var min_value: float = 1.25

@export_group("Player Level (PLAYER_LEVEL_MIN)")
@export var min_level: int = 5

@export_group("Elemental Totem (TOTEM_COMPLETED)")
@export var totem_element: String = ""
@export var min_totem_count: int = 1

@export_group("Secondary Spell (OWNED_SPELL)")
@export var required_spell_name: String = ""
@export var min_spell_level: int = 1


static func _get_game_data() -> GDScript:
	if _game_data_script == null:
		_game_data_script = load("res://scripts/globals/game_data.gd") as GDScript
	return _game_data_script


static func _query_totem_count(elem_key: String) -> int:
	var gd: GDScript = _get_game_data()
	if gd == null:
		return 0
	if elem_key.is_empty():
		if gd.has_method("get_completed_totems_list"):
			var arr: Array = gd.call("get_completed_totems_list") as Array
			return arr.size()
		return 0
	if gd.has_method("get_completed_totem_count"):
		return int(gd.call("get_completed_totem_count", elem_key))
	return 0


func is_met(player: Node) -> bool:
	if player == null:
		return false

	match req_type:
		ReqType.PASSIVE_TAG_POINTS:
			var st: Node = _find_skill_tree(player)
			if st == null or not st.has_method("get_allocated_points_with_tags"):
				return false
			return int(st.call("get_allocated_points_with_tags", passive_tag_mask)) >= min_points

		ReqType.PASSIVE_KEYSTONE:
			var st_k: Node = _find_skill_tree(player)
			if st_k == null or not st_k.has_method("has_keystone_allocated"):
				return false
			return bool(st_k.call("has_keystone_allocated", keystone_id))

		ReqType.PLAYER_STAT_MIN:
			var stats: Node = player.find_child("StatsComponent", true, false)
			if stats == null or not stats.has_method("get_stat_value"):
				return false
			var cur_val: float = float(stats.call("get_stat_value", stat_name))
			return cur_val + 0.0001 >= min_value

		ReqType.PLAYER_LEVEL_MIN:
			var lvl: Node = player.get_node_or_null("lvl_component")
			if lvl == null:
				lvl = player.find_child("lvl_component", true, false)
			if lvl == null or not ("current_level" in lvl):
				return false
			return int(lvl.get("current_level")) >= min_level

		ReqType.TOTEM_COMPLETED:
			var elem_key: String = totem_element.strip_edges().to_lower()
			return _query_totem_count(elem_key) >= min_totem_count

		ReqType.OWNED_SPELL:
			var sb: Node = player.get_node_or_null("SpellBook_UI")
			if sb == null:
				sb = player.find_child("SpellBook_UI", true, false)
			if sb == null:
				return false
			if sb.has_method("has_spell_at_level"):
				return bool(sb.call("has_spell_at_level", required_spell_name, min_spell_level))
			return false

	return false


func get_description(player: Node = null) -> String:
	if not custom_label.strip_edges().is_empty():
		return custom_label.strip_edges()

	match req_type:
		ReqType.PASSIVE_TAG_POINTS:
			var tag_str: String = _format_tag_mask(passive_tag_mask)
			var cur_pts: int = 0
			if player != null:
				var st: Node = _find_skill_tree(player)
				if st != null and st.has_method("get_allocated_points_with_tags"):
					cur_pts = int(st.call("get_allocated_points_with_tags", passive_tag_mask))
			return "Allocate %d %s passive points (%d/%d)" % [min_points, tag_str, cur_pts, min_points]

		ReqType.PASSIVE_KEYSTONE:
			var k_nice: String = keystone_id.replace("_", " ").capitalize()
			return "Keystone allocated: %s" % k_nice

		ReqType.PLAYER_STAT_MIN:
			var stat_nice: String = stat_name.replace("_", " ").capitalize()
			if stat_name in PERCENT_STAT_NAMES:
				var req_pct: int = int(roundf((min_value - 1.0) * 100.0))
				var cur_pct: int = 0
				if player != null:
					var stats: Node = player.find_child("StatsComponent", true, false)
					if stats != null and stats.has_method("get_stat_value"):
						cur_pct = int(roundf((float(stats.call("get_stat_value", stat_name)) - 1.0) * 100.0))
				return "Reach +%d%% %s (Current: %+d%%)" % [req_pct, stat_nice, cur_pct]
			return "Reach %.0f %s" % [min_value, stat_nice]

		ReqType.PLAYER_LEVEL_MIN:
			var cur_lvl: int = 1
			if player != null:
				var lvl: Node = player.get_node_or_null("lvl_component")
				if lvl != null and ("current_level" in lvl):
					cur_lvl = int(lvl.get("current_level"))
			return "Character Level %d (%d/%d)" % [min_level, cur_lvl, min_level]

		ReqType.TOTEM_COMPLETED:
			var elem_key: String = totem_element.strip_edges().to_lower()
			var cnt: int = _query_totem_count(elem_key)
			if elem_key.is_empty():
				return "Purify %d Elemental Totem(s) (%d/%d)" % [min_totem_count, cnt, min_totem_count]
			return "Purify %d %s Totem(s) (%d/%d)" % [min_totem_count, elem_key.capitalize(), cnt, min_totem_count]

		ReqType.OWNED_SPELL:
			if min_spell_level > 1:
				return "Master %s (Lv.%d)" % [required_spell_name, min_spell_level]
			return "Unlock %s" % required_spell_name

	return "Special Unlock Requirement"


static func _find_skill_tree(player: Node) -> Node:
	var direct: Node = player.get_node_or_null("Skill_tree_comp")
	if direct != null:
		return direct
	return player.find_child("Skill_tree_comp", true, false)


static func _format_tag_mask(mask: int) -> String:
	if mask == 0:
		return "Any"
	var parts: Array[String] = []
	for i: int in range(TAG_NAMES.size()):
		if (mask & (1 << i)) != 0:
			parts.append(TAG_NAMES[i])
	if parts.is_empty():
		return "Tagged"
	return "/".join(parts)
