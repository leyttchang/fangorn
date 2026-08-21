# -*- coding: utf-8 -*-

def patch_chest(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    old_code = '''		visible = false
		var interact = get_node_or_null("InteractionComponent")
		if interact:
			interact.queue_free()'''
			
    new_code = '''		visible = false
		var interact = get_node_or_null("InteractionComponent")
		if interact:
			interact.queue_free()
		
		# On supprime l'obstacle physique LOCALEMENT
		# Ca ne le supprimera PAS pour les autres joueurs !
		var static_body = get_node_or_null("StaticBody3D")
		if static_body:
			static_body.queue_free()'''

    if 'static_body.queue_free()' not in content:
        content = content.replace(old_code, new_code)
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

patch_chest('Y:/Fangorn/fangorn/objet/chest/chest.gd')
patch_chest('Y:/Fangorn/fangorn/objet/chest/Skill_chest.gd')
print("Collisions patched")
