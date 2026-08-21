# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/character/enemie/dumb/dumb.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''		if p.is_in_group("Player"):
			target = p
			break''', '''		if p.is_in_group("Player"):
			target = p
			_target_update_timer = 0.0 # On reset le verrouillage d'aggro
			break''')

content = content.replace('''			if pl.get_multiplayer_authority() == caster_id:
				target = pl
				break''', '''			if pl.get_multiplayer_authority() == caster_id:
				target = pl
				_target_update_timer = 0.0 # On reset le verrouillage d'aggro
				break''')

content = content.replace('''	# Mise  jour de la cible rgulirement si on n'a pas pris de dgts rcemment
	_target_update_timer += delta
	if _target_update_timer > 2.0:
		_target_update_timer = 0.0
		_update_closest_target()''', '''	# Verrouillage de la cible pendant 15s
	_target_update_timer += delta
	
	# On cherche une nouvelle cible si :
	# 1. a fait 15 secondes qu'on suit le mme gars
	# 2. On n'a pas de cible
	# 3. La cible a t dtruite / dconnecte
	if _target_update_timer > 15.0 or target == null or not is_instance_valid(target):
		_target_update_timer = 0.0
		_update_closest_target()''')

with open('Y:/Fangorn/fangorn/character/enemie/dumb/dumb.gd', 'w', encoding='utf-8') as f:
    f.write(content)
