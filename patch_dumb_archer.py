# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''func actor_setup() -> void:
	await get_tree().physics_frame
	target = get_tree().get_first_node_in_group("Player")
	change_state(State.IDLE)''', '''func actor_setup() -> void:
	await get_tree().physics_frame
	_update_closest_target()
	change_state(State.IDLE)
	
	# On s'abonne au signal pour l'aggro si on se fait taper
	var hitbox = find_child("HitboxComponent*", true, false)
	if hitbox != null:
		hitbox.hit_received.connect(_on_hit_received)

func _on_hit_received(attack: AttackComponent) -> void:
	if not is_multiplayer_authority(): return
	if current_state == State.DEAD: return
	
	# On remonte l'arbre pour trouver le lanceur
	var p = attack.get_parent()
	while p != null:
		if p.is_in_group("Player"):
			target = p
			break
		p = p.get_parent()
		
	# Si l'attaque vient d'un sort
	if p == null and attack.has_meta("caster_authority"):
		var caster_id = attack.get_meta("caster_authority")
		var players = get_tree().get_nodes_in_group("Player")
		for pl in players:
			if pl.get_multiplayer_authority() == caster_id:
				target = pl
				break

var _target_update_timer: float = 0.0

func _update_closest_target() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	if players.is_empty():
		target = null
		return
		
	var closest = null
	var min_dist = 999999.0
	for p in players:
		var d = global_position.distance_squared_to(p.global_position)
		if d < min_dist:
			min_dist = d
			closest = p
			
	target = closest''')

content = content.replace('''func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return

	if not is_on_floor():''', '''func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return

	# Mise  jour de la cible rgulirement si on n'a pas pris de dgts rcemment
	_target_update_timer += delta
	if _target_update_timer > 2.0:
		_target_update_timer = 0.0
		_update_closest_target()

	if not is_on_floor():''')

with open('Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd', 'w', encoding='utf-8') as f:
    f.write(content)
