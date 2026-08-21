# -*- coding: utf-8 -*-
import re

for filepath in ['Y:/Fangorn/fangorn/character/enemie/dumb/dumb.gd', 'Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd']:
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    new_func = '''func _on_hit_received(attack: AttackComponent) -> void:
	if not is_multiplayer_authority(): return
	if current_state == State.DEAD: return
	
	var new_target = null
	
	# On remonte l'arbre pour trouver le lanceur
	var p = attack.get_parent()
	while p != null:
		if p.is_in_group("Player"):
			new_target = p
			break
		p = p.get_parent()
		
	# Si l'attaque vient d'un sort
	if p == null and attack.has_meta("caster_authority"):
		var caster_id = attack.get_meta("caster_authority")
		var players = get_tree().get_nodes_in_group("Player")
		for pl in players:
			if pl.get_multiplayer_authority() == caster_id:
				new_target = pl
				break
				
	if new_target != null:
		_change_target_delayed(new_target)

func _change_target_delayed(new_target: Node3D) -> void:
	await get_tree().create_timer(1.0).timeout
	# Si le monstre est mort ou effac pendant ce temps, on annule
	if not is_instance_valid(self) or current_state == State.DEAD: return
	
	target = new_target
	_target_update_timer = 0.0

var _target_update_timer: float = 0.0'''

    # We need to replace the old _on_hit_received and var _target_update_timer
    # Use regex to find the block
    pattern = re.compile(r'func _on_hit_received\(.*?var _target_update_timer: float = 0\.0', re.DOTALL)
    content = pattern.sub(new_func, content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
