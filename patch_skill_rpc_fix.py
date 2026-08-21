# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''	var attack_comp = spell_instance.get_node_or_null("AttackComponent")
	if attack_comp == null:
		attack_comp = spell_instance.find_child("AttackComponent*", true, false)
	if attack_comp != null:
		attack_comp.is_active_for_network = false
		
	get_tree().root.add_child(spell_instance)''', '''	get_tree().root.add_child(spell_instance)
	
	# IMPORTANT : On modifie is_active_for_network APRES le add_child() 
	# sinon la fonction _ready() de l'AttackComponent r-crase la valeur et la remet  True chez le Host !
	var attack_comp = spell_instance.get_node_or_null("AttackComponent")
	if attack_comp == null:
		attack_comp = spell_instance.find_child("AttackComponent*", true, false)
	if attack_comp != null:
		attack_comp.is_active_for_network = false''')

with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
