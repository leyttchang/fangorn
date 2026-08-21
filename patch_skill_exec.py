# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('var spell_instance = ability.ability_scene.instantiate()\\n\\t\\tget_tree().root.add_child(spell_instance)', '''var spell_instance = ability.ability_scene.instantiate()
		get_tree().root.add_child(spell_instance)
		
		# On donne l'autorit de ce sort au joueur qui l'a lanc
		spell_instance.set_multiplayer_authority(get_parent().get_multiplayer_authority(), true)
''')
content = content.replace('var spell_instance = ability.ability_scene.instantiate()\n\t\tget_tree().root.add_child(spell_instance)', '''var spell_instance = ability.ability_scene.instantiate()
		get_tree().root.add_child(spell_instance)
		
		# On donne l'autorit de ce sort au joueur qui l'a lanc
		spell_instance.set_multiplayer_authority(get_parent().get_multiplayer_authority(), true)
''')

with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
