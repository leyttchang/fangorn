# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''		# On donne l'autorit du sort AVANT le add_child pour que le _ready() de l'AttackComponent le voit
		spell_instance.set_multiplayer_authority(get_parent().get_multiplayer_authority(), true)''', '''		# On ne change pas l'autorit du mesh pour ne pas le casser !
		# On passera l'autorit via target_data pour l'AttackComponent
		target_data["caster_authority"] = get_parent().get_multiplayer_authority()''')

with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
