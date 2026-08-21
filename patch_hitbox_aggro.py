# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''signal hit_received(attack: AttackComponent)

func _ready() -> void:''', '''signal hit_received(attack: AttackComponent)
signal aggro_requested(attacker: Node3D) # NOUVEAU SIGNAL RESEAU

func _ready() -> void:''')

content = content.replace('''	if health_component != null:
		health_component.take_damage(attack.damage)
		
	hit_received.emit(attack)
		
	# 2. On calcule et applique le recul''', '''	if health_component != null:
		health_component.take_damage(attack.damage)
		
	hit_received.emit(attack)
	
	# NOUVEAU : On gre l'aggro en rseau
	var attacker_id = 0
	var p = attack.get_parent()
	while p != null:
		if p.is_in_group("Player"):
			attacker_id = p.get_multiplayer_authority()
			break
		p = p.get_parent()
		
	if attacker_id == 0 and attack.has_meta("caster_authority"):
		attacker_id = attack.get_meta("caster_authority")
		
	if attacker_id != 0:
		if get_parent().is_multiplayer_authority():
			_apply_aggro(attacker_id)
		else:
			rpc_id(get_parent().get_multiplayer_authority(), "_rpc_notify_aggro", attacker_id)
		
	# 2. On calcule et applique le recul''')

content += '''

func _apply_aggro(attacker_id: int) -> void:
	var players = get_tree().get_nodes_in_group("Player")
	for pl in players:
		if pl.get_multiplayer_authority() == attacker_id:
			aggro_requested.emit(pl)
			break

@rpc("any_peer", "call_local", "reliable")
func _rpc_notify_aggro(attacker_id: int) -> void:
	if get_parent().is_multiplayer_authority():
		_apply_aggro(attacker_id)
'''

with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
