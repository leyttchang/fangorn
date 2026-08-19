with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add export
old_export = """@export_category("UI & Données")"""
new_export = """@export_category("UI & Données")
@export var show_node_stats: bool = true :
	set(val):
		show_node_stats = val
		generate_tree()"""
content = content.replace(old_export, new_export)

# 2. Add if condition
old_canvas = """	# Créer un CanvasLayer pour que le label reste à l'écran même en cas de pan/zoom
	var canvas_layer = CanvasLayer.new()
	canvas_layer.add_child(stats_label)
	add_child(canvas_layer)"""

new_canvas = """	if show_node_stats:
		# Créer un CanvasLayer pour que le label reste à l'écran même en cas de pan/zoom
		var canvas_layer = CanvasLayer.new()
		canvas_layer.add_child(stats_label)
		add_child(canvas_layer)"""
content = content.replace(old_canvas, new_canvas)

with open("Y:/Fangorn/fangorn/passive_skill_tree/generator_test.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Added toggle for stats")
