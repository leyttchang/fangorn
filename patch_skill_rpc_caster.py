# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''	if spell_instance.has_method("execute"):
		spell_instance.execute(get_parent(), {})''', '''	if spell_instance.has_method("execute"):
		# On cherche le VRAI lanceur dans l'arbre
		var real_caster = get_tree().root.get_node_or_null("game/Players/" + str(caster_id))
		if real_caster == null:
			real_caster = get_parent() # Fallback au cas o
		spell_instance.execute(real_caster, {})''')

with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
