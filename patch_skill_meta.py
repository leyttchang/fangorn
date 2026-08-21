# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''		# On ne change pas l'autorit du mesh pour ne pas le casser !
		# On passera l'autorit via target_data pour l'AttackComponent
		target_data["caster_authority"] = get_parent().get_multiplayer_authority()
		
		get_tree().root.add_child(spell_instance)''', '''		# On ne change pas l'autorit du mesh pour ne pas le casser (les shaders dtestent a) !
		# On glisse juste l'identit du lanceur dans l'AttackComponent
		var attack_comp = spell_instance.get_node_or_null("AttackComponent")
		if attack_comp == null:
			attack_comp = spell_instance.find_child("AttackComponent*", true, false)
		if attack_comp != null:
			attack_comp.set_meta("caster_authority", get_parent().get_multiplayer_authority())
			
		get_tree().root.add_child(spell_instance)''')

with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
