# -*- coding: utf-8 -*-

# 1. Restore the AttackComponent on the spell echo (so the Server can detect spell hits!)
with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''	# On desactive la hitbox pour que ce soit juste un visuel !
	var attack_comp = spell_instance.get_node_or_null("AttackComponent")
	if attack_comp != null:
		attack_comp.queue_free()''', '')

with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)


# 2. Update HitboxComponent to ONLY accept hits if it is the authority!
with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

old_receive = '''func receive_hit(attack: AttackComponent) -> void:
	# 1. On applique les dgts'''

new_receive = '''func receive_hit(attack: AttackComponent) -> void:
	# REGLE D'OR DU RESEAU : Seul l'ordinateur qui GERE cette entit a le droit de valider le coup !
	if not get_parent().is_multiplayer_authority():
		return
		
	# 1. On applique les dgts'''

if 'REGLE D\\'OR DU RESEAU' not in content:
    content = content.replace(old_receive, new_receive)
    with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'w', encoding='utf-8') as f:
        f.write(content)


# 3. Remove the RPC forwards from HealthComponent (since the authority handles it itself now)
with open('Y:/Fangorn/fangorn/components/health_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

import re
content = re.sub(r'func take_damage\(raw_damage: float\) -> void:.*?if owner\.is_multiplayer_authority\(\):', '''func take_damage(raw_damage: float) -> void:
	if not owner.is_multiplayer_authority(): return
	if true:''', content, flags=re.DOTALL)

content = re.sub(r'else:\n\t\trpc_id\(owner\.get_multiplayer_authority\(\), "_rpc_take_damage", raw_damage\)\n\t\treturn', '', content)

with open('Y:/Fangorn/fangorn/components/health_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)

# 4. Remove the RPC forwards from KnockbackComponent
with open('Y:/Fangorn/fangorn/components/knockback_componant.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''	if final_force >= minimum_force_threshold:
		if target_body.is_multiplayer_authority():
			_apply_physics(push_direction, final_force)
		else:
			rpc_id(target_body.get_multiplayer_authority(), "_rpc_apply_physics", push_direction, final_force)''', '''	if final_force >= minimum_force_threshold:
		if target_body.is_multiplayer_authority():
			_apply_physics(push_direction, final_force)''')

with open('Y:/Fangorn/fangorn/components/knockback_componant.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Double damage architecture completely fixed")
