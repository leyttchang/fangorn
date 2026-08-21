# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''var spell_instance = ability.ability_scene.instantiate()
		get_tree().root.add_child(spell_instance)
		
		# On donne l'autorit de ce sort au joueur qui l'a lanc
		spell_instance.set_multiplayer_authority(get_parent().get_multiplayer_authority(), true)''', '''var spell_instance = ability.ability_scene.instantiate()
		
		# On donne l'autorit du sort AVANT le add_child pour que le _ready() de l'AttackComponent le voit
		spell_instance.set_multiplayer_authority(get_parent().get_multiplayer_authority(), true)
		
		get_tree().root.add_child(spell_instance)''')

with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
