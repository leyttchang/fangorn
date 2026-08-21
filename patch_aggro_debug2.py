# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/character/enemie/dumb/dumb.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''	# On s'abonne au signal pour l'aggro si on se fait taper
	var hitbox = find_child("HitboxComponent*", true, false)
	if hitbox != null:
		hitbox.hit_received.connect(_on_hit_received)''', '''	# On s'abonne au signal pour l'aggro si on se fait taper
	var hitbox = find_child("HitboxComponent*", true, false)
	if hitbox != null:
		hitbox.hit_received.connect(_on_hit_received)
		print("[AGGRO SETUP] Hitbox trouve et connecte sur ", name)
	else:
		push_error("[AGGRO SETUP] HitboxComponent INTROUVABLE sur ", name)''')

with open('Y:/Fangorn/fangorn/character/enemie/dumb/dumb.gd', 'w', encoding='utf-8') as f:
    f.write(content)
