# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/fire_arrow.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''	if is_instance_valid(self) and not _has_impacted:
		queue_free()''', '''	if is_instance_valid(self) and not _has_impacted:
		if multiplayer.is_server():
			queue_free()''')

content = content.replace('''	if is_instance_valid(self):
		queue_free()''', '''	if is_instance_valid(self):
		if multiplayer.is_server():
			queue_free()''')

with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/fire_arrow.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Fire arrow queue_free patched")
