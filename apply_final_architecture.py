# -*- coding: utf-8 -*-

# 1. AttackComponent.gd
with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()
if 'var is_active_for_network: bool = true' not in content:
    content = content.replace('var hit_entities: Array[Area3D] = []', '''var hit_entities: Array[Area3D] = []
var is_active_for_network: bool = true''')
    content = content.replace('func _ready() -> void:', '''func _ready() -> void:
	var p = get_parent()
	while p != null:
		if p is CharacterBody3D:
			is_active_for_network = p.is_multiplayer_authority()
			break
		p = p.get_parent()
	if p == null:
		is_active_for_network = multiplayer.is_server()
''')
    content = content.replace('func _on_area_entered(area: Area3D) -> void:', '''func _on_area_entered(area: Area3D) -> void:
	if not is_active_for_network: return''')
    with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'w', encoding='utf-8') as f:
        f.write(content)

# 2. HitboxComponent.gd
with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()
content = content.replace('''	# REGLE D'OR DU RESEAU : Seul l'ordinateur qui GERE cette entit a le droit de valider le coup !
	if not get_parent().is_multiplayer_authority():
		return''', '')
with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)

# 3. HealthComponent.gd
with open('Y:/Fangorn/fangorn/components/health_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()
content = content.replace('''	# SEUL L'ORDINATEUR QUI GERE CETTE ENTITE PEUT DECIDER QU'ELLE PREND DES DEGATS !
	if not owner.is_multiplayer_authority():
		return''', '''	# Si ce n'est pas nous qui grons cette entit, on transmet l'info au ple propritaire
	if not owner.is_multiplayer_authority():
		rpc_id(owner.get_multiplayer_authority(), "_rpc_take_damage", raw_damage)
		return''')
content = content.replace('damage_taken.emit(final_damage)', '''damage_taken.emit(final_damage)
	rpc("_rpc_broadcast_damage", final_damage)''')
content = content.replace('func _ready() -> void:', '''@rpc("any_peer", "call_local", "reliable")
func _rpc_take_damage(raw_damage: float) -> void:
	if owner.is_multiplayer_authority():
		take_damage(raw_damage)

@rpc("authority", "call_remote", "reliable")
func _rpc_broadcast_damage(final_damage: float) -> void:
	damage_taken.emit(final_damage)

func _ready() -> void:''')
with open('Y:/Fangorn/fangorn/components/health_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)

# 4. KnockbackComponent.gd
with open('Y:/Fangorn/fangorn/components/knockback_componant.gd', 'r', encoding='utf-8') as f:
    content = f.read()
content = content.replace('''	if final_force >= minimum_force_threshold:
		_apply_physics(push_direction, final_force)''', '''	if final_force >= minimum_force_threshold:
		if target_body.is_multiplayer_authority():
			_apply_physics(push_direction, final_force)
		else:
			rpc_id(target_body.get_multiplayer_authority(), "_rpc_apply_physics", push_direction, final_force)''')
content = content.replace('func _apply_physics(push_direction: Vector3, final_force: float) -> void:', '''@rpc("any_peer", "call_local", "reliable")
func _rpc_apply_physics(push_direction: Vector3, final_force: float) -> void:
	_apply_physics(push_direction, final_force)

func _apply_physics(push_direction: Vector3, final_force: float) -> void:''')
with open('Y:/Fangorn/fangorn/components/knockback_componant.gd', 'w', encoding='utf-8') as f:
    f.write(content)

# 5. ContinuousAttackComponent.gd
with open('Y:/Fangorn/fangorn/components/continuous_attack_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()
content = content.replace('attack_component.hit_entities.erase(area)', '# attack_component.hit_entities.erase(area)')
with open('Y:/Fangorn/fangorn/components/continuous_attack_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)

print("Architecture restored AND FIXED")
