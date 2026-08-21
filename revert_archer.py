# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd', 'r', encoding='utf-8') as f:
    content = f.read()

import re
old_func_pattern = r'func fire_arrow\(\) -> void:.*?(?=\n\n# ==========================================================)'
new_func = '''func fire_arrow() -> void:
	if not multiplayer.is_server(): return
	if arrow_scene == null: return
		
	var new_arrow = arrow_scene.instantiate()
	get_tree().current_scene.get_node("NetworkObjects").add_child(new_arrow, true)
	new_arrow.execute(self, {})'''

content = re.sub(old_func_pattern, new_func, content, flags=re.DOTALL)

with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Archer reverted to server only")
