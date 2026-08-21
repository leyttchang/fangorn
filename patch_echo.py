# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''	# On desactive la hitbox pour que ce soit juste un visuel !
	var hitbox = spell_instance.get_node_or_null("HitboxComponent")
	if hitbox != null:
		hitbox.queue_free()''', '''	# On desactive la hitbox pour que ce soit juste un visuel !
	var attack_comp = spell_instance.get_node_or_null("AttackComponent")
	if attack_comp != null:
		attack_comp.queue_free()''')

with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Skill bar echo patched")
