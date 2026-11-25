class_name SpellLineageGraph
extends Control

signal node_clicked(ability: AbilityData)

class GraphNodeEntry:
	var ability: AbilityData
	var rect: Rect2
	var tier_col: int = 0
	var is_unlocked: bool = false
	var is_ready_to_evolve: bool = false
	var is_selected: bool = false

class GraphEdge:
	var from_ab: AbilityData
	var to_ab: AbilityData
	var unlocked: bool = false
	var ready: bool = false

var _nodes: Array[GraphNodeEntry] = []
var _edges: Array[GraphEdge] = []
var _hovered_ab: AbilityData = null


func clear_graph() -> void:
	_nodes.clear()
	_edges.clear()
	_hovered_ab = null
	queue_redraw()


func build_for_ability(
	selected_ability: AbilityData,
	all_spells: Array[AbilityData],
	spellbook: Node
) -> void:
	_nodes.clear()
	_edges.clear()
	_hovered_ab = null

	if selected_ability == null:
		queue_redraw()
		return

	# Remonte jusqu'à la racine de lignée (Tier I ou sort parent)
	var roots: Array[AbilityData] = _find_lineage_roots(selected_ability, all_spells)
	if roots.is_empty():
		roots.append(selected_ability)

	var columns: Dictionary = { 1: [], 2: [], 3: [] }
	var visited: Dictionary = {}
	var raw_edges: Array[Array] = []

	var queue: Array[AbilityData] = roots.duplicate()
	while not queue.is_empty():
		var cur: AbilityData = queue.pop_front()
		if cur == null:
			continue
		var cid: String = cur.get_effective_id()
		if visited.has(cid):
			continue
		visited[cid] = cur

		var col_idx: int = clampi(cur.tier, 1, 3)
		(columns[col_idx] as Array).append(cur)

		for child_ab: AbilityData in cur.evolutions:
			if child_ab == null:
				continue
			raw_edges.append([cur, child_ab])
			if not visited.has(child_ab.get_effective_id()):
				queue.append(child_ab)

	# Calcul des coordonnées (Colonnes Tier I -> Tier II -> Tier III)
	var active_cols: Array[int] = []
	for t_idx: int in [1, 2, 3]:
		if not (columns[t_idx] as Array).is_empty():
			active_cols.append(t_idx)

	var w: float = maxf(size.x, 420.0)
	var h: float = maxf(size.y, 185.0)
	var max_rows_any: int = 1
	for t_check: int in active_cols:
		max_rows_any = maxi(max_rows_any, (columns[t_check] as Array).size())
	var side_px: float = 58.0
	if max_rows_any == 3:
		side_px = 46.0
	elif max_rows_any >= 4:
		side_px = 38.0
	var node_size: Vector2 = Vector2(side_px, side_px)
	var pos_map: Dictionary = {}

	var col_count: int = maxi(1, active_cols.size())
	for c_pos: int in range(active_cols.size()):
		var t_key: int = active_cols[c_pos]
		var list_in_col: Array = columns[t_key] as Array
		var x_center: float = w * 0.5
		if col_count == 2:
			x_center = lerpf(w * 0.26, w * 0.74, float(c_pos))
		elif col_count >= 3:
			x_center = lerpf(w * 0.17, w * 0.83, float(c_pos) / float(col_count - 1))

		var row_count: int = list_in_col.size()
		for r_idx: int in range(row_count):
			var ab: AbilityData = list_in_col[r_idx] as AbilityData
			var y_center: float = h * 0.48
			if row_count > 1:
				var max_span: float = maxf(40.0, h - (side_px + 20.0))
				var desired_step: float = side_px + 14.0
				var span: float = minf(max_span, float(row_count - 1) * desired_step)
				y_center = (h * 0.48) - span * 0.5 + (span * float(r_idx) / float(row_count - 1))

			var entry: GraphNodeEntry = GraphNodeEntry.new()
			entry.ability = ab
			entry.tier_col = t_key
			entry.rect = Rect2(Vector2(x_center, y_center) - node_size * 0.5, node_size)
			entry.is_selected = (ab.get_effective_id() == selected_ability.get_effective_id())
			if spellbook != null:
				if spellbook.has_method("has_spell"):
					entry.is_unlocked = bool(spellbook.call("has_spell", ab))
				if spellbook.has_method("can_unlock_any_parent_to"):
					entry.is_ready_to_evolve = bool(spellbook.call("can_unlock_any_parent_to", ab))
			_nodes.append(entry)
			pos_map[ab.get_effective_id()] = entry

	for pair: Array in raw_edges:
		var p_ab: AbilityData = pair[0] as AbilityData
		var c_ab: AbilityData = pair[1] as AbilityData
		var edge: GraphEdge = GraphEdge.new()
		edge.from_ab = p_ab
		edge.to_ab = c_ab
		if spellbook != null:
			var p_owned: bool = bool(spellbook.call("has_spell", p_ab)) if spellbook.has_method("has_spell") else false
			var c_owned: bool = bool(spellbook.call("has_spell", c_ab)) if spellbook.has_method("has_spell") else false
			edge.unlocked = p_owned and c_owned
			if not edge.unlocked and spellbook.has_method("can_unlock_evolution"):
				edge.ready = bool(spellbook.call("can_unlock_evolution", p_ab, c_ab))
		_edges.append(edge)

	queue_redraw()


static func _find_lineage_roots(target: AbilityData, all_spells: Array[AbilityData]) -> Array[AbilityData]:
	var parents_map: Dictionary = {}
	for ab: AbilityData in all_spells:
		if ab == null:
			continue
		for child_ab: AbilityData in ab.evolutions:
			if child_ab == null:
				continue
			var cid: String = child_ab.get_effective_id()
			if not parents_map.has(cid):
				parents_map[cid] = []
			(parents_map[cid] as Array).append(ab)

	var roots: Array[AbilityData] = []
	var visited: Dictionary = {}
	var stack: Array[AbilityData] = [target]
	while not stack.is_empty():
		var cur: AbilityData = stack.pop_back()
		var id_key: String = cur.get_effective_id()
		if visited.has(id_key):
			continue
		visited[id_key] = true
		if parents_map.has(id_key):
			var p_list: Array = parents_map[id_key] as Array
			for p_var: Variant in p_list:
				var p_ab: AbilityData = p_var as AbilityData
				if p_ab != null:
					stack.append(p_ab)
		else:
			roots.append(cur)
	return roots


func _find_node_entry(ab: AbilityData) -> GraphNodeEntry:
	if ab == null:
		return null
	var target_id: String = ab.get_effective_id()
	for n: GraphNodeEntry in _nodes:
		if n.ability.get_effective_id() == target_id:
			return n
	return null


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var prev_hov: AbilityData = _hovered_ab
		_hovered_ab = null
		for n: GraphNodeEntry in _nodes:
			if n.rect.has_point(mm.position):
				_hovered_ab = n.ability
				break
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hovered_ab != null else Control.CURSOR_ARROW
		if prev_hov != _hovered_ab:
			queue_redraw()

	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			for n: GraphNodeEntry in _nodes:
				if n.rect.has_point(mb.position):
					node_clicked.emit(n.ability)
					accept_event()
					return


func _draw() -> void:
	var bg_rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(bg_rect, Color(0.05, 0.06, 0.08, 0.78), true)
	draw_rect(bg_rect, Color(0.32, 0.30, 0.24, 0.65), false, 1.5)

	if _nodes.is_empty():
		var font_empty: Font = ThemeDB.fallback_font
		draw_string(
			font_empty,
			Vector2(18.0, size.y * 0.54),
			"Select a spell on the left to inspect its evolution lineage.",
			HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 36.0,
			14,
			Color(0.62, 0.60, 0.56, 0.85)
		)
		return

	# 1. Lignes de filiation (Courbes cubiques ou segments orthogonaux)
	for e: GraphEdge in _edges:
		var n_from: GraphNodeEntry = _find_node_entry(e.from_ab)
		var n_to: GraphNodeEntry = _find_node_entry(e.to_ab)
		if n_from == null or n_to == null:
			continue
		var p1: Vector2 = Vector2(n_from.rect.end.x, n_from.rect.get_center().y)
		var p2: Vector2 = Vector2(n_to.rect.position.x, n_to.rect.get_center().y)
		var mid_x: float = (p1.x + p2.x) * 0.5

		var line_col: Color = Color(0.28, 0.30, 0.36, 0.85)
		var line_w: float = 2.5
		if e.unlocked:
			line_col = Color(0.92, 0.76, 0.34, 0.95)
			line_w = 3.2
		elif e.ready:
			line_col = Color(0.42, 0.95, 0.62, 0.95)
			line_w = 3.2

		draw_line(p1, Vector2(mid_x, p1.y), line_col, line_w, true)
		draw_line(Vector2(mid_x, p1.y), Vector2(mid_x, p2.y), line_col, line_w, true)
		draw_line(Vector2(mid_x, p2.y), p2, line_col, line_w, true)

	# 2. Nœuds de sorts
	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font

	for n: GraphNodeEntry in _nodes:
		var r: Rect2 = n.rect
		var fill_col: Color = Color(0.10, 0.11, 0.14, 0.96) if n.is_unlocked else Color(0.05, 0.05, 0.07, 0.95)
		draw_rect(r, fill_col, true)

		if n.ability.icon != null:
			var icon_r: Rect2 = r.grow(-5.0)
			var icon_mod: Color = Color.WHITE if n.is_unlocked else (Color(0.75, 0.85, 0.78, 0.85) if n.is_ready_to_evolve else Color(0.38, 0.40, 0.46, 0.72))
			draw_texture_rect(n.ability.icon, icon_r, false, icon_mod)

		var border_col: Color = Color(0.32, 0.34, 0.40, 0.9)
		var border_w: float = 2.0
		if n.is_selected:
			border_col = Color(1.0, 0.86, 0.38, 1.0)
			border_w = 3.0
		elif n.is_ready_to_evolve:
			border_col = Color(0.38, 0.96, 0.60, 1.0)
			border_w = 2.6
		elif n.is_unlocked:
			border_col = Color(0.76, 0.64, 0.34, 0.92)
		elif _hovered_ab == n.ability:
			border_col = Color(0.68, 0.74, 0.86, 0.95)

		draw_rect(r, border_col, false, border_w)

		var tier_txt: String = "T%d" % n.ability.tier
		draw_string(font, r.position + Vector2(4.0, 13.0), tier_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.86, 0.55, 0.95))

		var name_col: Color = Color(0.94, 0.90, 0.80, 0.98) if n.is_unlocked else Color(0.66, 0.68, 0.74, 0.92)
		draw_string(
			font,
			Vector2(r.get_center().x - 58.0, r.end.y + 15.0),
			n.ability.ability_name,
			HORIZONTAL_ALIGNMENT_CENTER,
			116.0,
			12,
			name_col
		)
