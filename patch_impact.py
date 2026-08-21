# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/impact_spawner_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''		get_tree().root.add_child(impact_instance)
		impact_instance.global_position = _get_ground_position(get_parent().global_position)''', '''		# --- TRANSMISSION DE L'AUTORITE RESEAU ---
		# On passe l'identit du lanceur de la boule de feu au burning ground
		if attack_component != null and attack_component.has_meta("caster_authority"):
			var impact_attack_comp = impact_instance.get_node_or_null("AttackComponent")
			if impact_attack_comp == null:
				impact_attack_comp = impact_instance.find_child("AttackComponent*", true, false)
			if impact_attack_comp != null:
				impact_attack_comp.set_meta("caster_authority", attack_component.get_meta("caster_authority"))
				
		get_tree().root.add_child(impact_instance)
		impact_instance.global_position = _get_ground_position(get_parent().global_position)''')

with open('Y:/Fangorn/fangorn/impact_spawner_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
