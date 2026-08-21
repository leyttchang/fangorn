# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/continuous_attack_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''func _on_area_exited(area: Area3D) -> void:
	if area is HitboxComponent:
		targets_inside -= 1
		attack_component.hit_entities.erase(area)''', '''func _on_area_exited(area: Area3D) -> void:
	if area is HitboxComponent:
		targets_inside -= 1
		# ON NE L'EFFACE PLUS D'ICI ! a empeche de prendre 2 coups de suite en rentrant/sortant en boucle a cause du knockback
		# attack_component.hit_entities.erase(area)''')

with open('Y:/Fangorn/fangorn/components/continuous_attack_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Continuous attack stutter fix applied")
