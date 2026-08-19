with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add Export
export_insertion = """@export_category("Zones & Hybrides")
@export var hybrid_zone_width_degrees: float = 20.0 :
	set(val):
		hybrid_zone_width_degrees = val
		queue_redraw()

@export_category("UI & Données")"""
content = content.replace("@export_category(\"UI & Données\")", export_insertion)


# 2. Update _get_zone
old_get_zone = """func _get_zone(pos: Vector2) -> int:
	var angle = pos.angle() 
	if angle >= -PI/2.0 and angle < PI/6.0:
		return SkillNodeData.Zone.MAGE
	if angle >= PI/6.0 and angle < 5.0*PI/6.0:
		return SkillNodeData.Zone.DUELIST
	return SkillNodeData.Zone.BARBARIAN"""

new_get_zone = """func _get_zone(pos: Vector2) -> int:
	var angle = pos.angle() 
	var hybrid_rad = deg_to_rad(hybrid_zone_width_degrees) / 2.0
	
	var bound_mage_barb = -PI/2.0
	var bound_duel_mage = PI/6.0
	var bound_barb_duel = 5.0*PI/6.0
	
	if abs(angle - bound_mage_barb) <= hybrid_rad:
		return SkillNodeData.Zone.HYBRID_BARB_MAGE
	if abs(angle - bound_duel_mage) <= hybrid_rad:
		return SkillNodeData.Zone.HYBRID_MAGE_DUEL
	if abs(angle - bound_barb_duel) <= hybrid_rad:
		return SkillNodeData.Zone.HYBRID_DUEL_BARB
		
	if angle >= bound_mage_barb and angle < bound_duel_mage:
		return SkillNodeData.Zone.MAGE
	if angle >= bound_duel_mage and angle < bound_barb_duel:
		return SkillNodeData.Zone.DUELIST
	return SkillNodeData.Zone.BARBARIAN"""
content = content.replace(old_get_zone, new_get_zone)


# 3. Update _draft_skill multiplier
old_zone_mult = """		# Vérifier la zone
		var zone_mult = 1.0
		if zone == SkillNodeData.Zone.MAGE:
			zone_mult = skill.zone_mage_multiplier
		elif zone == SkillNodeData.Zone.DUELIST:
			zone_mult = skill.zone_duelist_multiplier
		elif zone == SkillNodeData.Zone.BARBARIAN:
			zone_mult = skill.zone_barbarian_multiplier"""

new_zone_mult = """		# Vérifier la zone
		var zone_mult = 0.0
		if skill.is_hybrid_exclusive:
			if zone == SkillNodeData.Zone.HYBRID_BARB_MAGE and skill.spawn_in_barb_mage:
				zone_mult = 1.0
			elif zone == SkillNodeData.Zone.HYBRID_MAGE_DUEL and skill.spawn_in_mage_duel:
				zone_mult = 1.0
			elif zone == SkillNodeData.Zone.HYBRID_DUEL_BARB and skill.spawn_in_duel_barb:
				zone_mult = 1.0
			else:
				zone_mult = 0.0
		else:
			if zone == SkillNodeData.Zone.MAGE:
				zone_mult = skill.zone_mage_multiplier
			elif zone == SkillNodeData.Zone.DUELIST:
				zone_mult = skill.zone_duelist_multiplier
			elif zone == SkillNodeData.Zone.BARBARIAN:
				zone_mult = skill.zone_barbarian_multiplier
			elif zone == SkillNodeData.Zone.HYBRID_BARB_MAGE:
				zone_mult = max(skill.zone_barbarian_multiplier, skill.zone_mage_multiplier)
			elif zone == SkillNodeData.Zone.HYBRID_MAGE_DUEL:
				zone_mult = max(skill.zone_mage_multiplier, skill.zone_duelist_multiplier)
			elif zone == SkillNodeData.Zone.HYBRID_DUEL_BARB:
				zone_mult = max(skill.zone_duelist_multiplier, skill.zone_barbarian_multiplier)"""
content = content.replace(old_zone_mult, new_zone_mult)


# 4. Update _draw
old_draw_lines = """	var angle1 = -PI / 2.0
	var angle2 = angle1 + (TAU / 3.0)
	var angle3 = angle1 + (TAU * 2.0 / 3.0)
	
	var dir1 = Vector2(cos(angle1), sin(angle1)) * tree_radius
	var dir2 = Vector2(cos(angle2), sin(angle2)) * tree_radius
	var dir3 = Vector2(cos(angle3), sin(angle3)) * tree_radius
	
	draw_line(center_offset, center_offset + dir1, Color(1, 1, 1, 0.3), 1.0, true)
	draw_line(center_offset, center_offset + dir2, Color(1, 1, 1, 0.3), 1.0, true)
	draw_line(center_offset, center_offset + dir3, Color(1, 1, 1, 0.3), 1.0, true)"""

new_draw_lines = """	var hybrid_rad = deg_to_rad(hybrid_zone_width_degrees) / 2.0
	for angle in [-PI / 2.0, PI / 6.0, 5.0 * PI / 6.0]:
		var dir_mid = Vector2(cos(angle), sin(angle)) * tree_radius
		var dir_left = Vector2(cos(angle - hybrid_rad), sin(angle - hybrid_rad)) * tree_radius
		var dir_right = Vector2(cos(angle + hybrid_rad), sin(angle + hybrid_rad)) * tree_radius
		
		# Ligne centrale (optionnelle, fine)
		draw_line(center_offset, center_offset + dir_mid, Color(1, 1, 1, 0.1), 1.0, true)
		# Frontières de la zone hybride
		draw_line(center_offset, center_offset + dir_left, Color(1, 1, 0, 0.4), 2.0, true)
		draw_line(center_offset, center_offset + dir_right, Color(1, 1, 0, 0.4), 2.0, true)"""
content = content.replace(old_draw_lines, new_draw_lines)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Updated generator_test.gd for hybrid zones")
