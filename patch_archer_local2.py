# -*- coding: utf-8 -*-
import re

with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd', 'r', encoding='utf-8') as f:
    content = f.read()

new_func = '''func fire_arrow() -> void:
	if arrow_scene == null: return
		
	var new_arrow = arrow_scene.instantiate()
	get_tree().root.add_child(new_arrow, true)
	
	if not multiplayer.is_server():
		var attack_comp = new_arrow.get_node_or_null("AttackComponent")
		if attack_comp:
			attack_comp.queue_free()
			
	new_arrow.execute(self, {})'''

# replace from "func fire_arrow" to the next "# ===" or next func
content = re.sub(r'func fire_arrow\(\) -> void:.*?(?=\n\n# ==========================================================)', new_func, content, flags=re.DOTALL)

with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Archer patched via regex")
