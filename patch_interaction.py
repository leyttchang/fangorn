# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/interaction_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

old_entered = '''func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		player_in_range = body as CharacterBody3D
		if prompt_label != null:
			prompt_label.text = prompt_text
			prompt_label.show()'''

new_entered = '''func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		player_in_range = body as CharacterBody3D
		# On n'affiche le texte que si C'EST NOTRE JOUEUR !
		if player_in_range.is_multiplayer_authority() and prompt_label != null:
			prompt_label.text = prompt_text
			prompt_label.show()'''

content = content.replace(old_entered, new_entered)

with open('Y:/Fangorn/fangorn/components/interaction_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Interaction label patched")
