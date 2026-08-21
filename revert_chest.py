# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/objet/chest/chest.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''	if chest_inventory.is_empty():
		queue_free()''', '''	if chest_inventory.is_empty():
		visible = false
		var interact = get_node_or_null("InteractionComponent")
		if interact:
			interact.queue_free()''')

with open('Y:/Fangorn/fangorn/objet/chest/chest.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Item chest hide patched")
