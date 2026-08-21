# -*- coding: utf-8 -*-
import os

# 1. Restore the HitboxComponent to its pure state
with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''	# REGLE D'OR DU RESEAU : Seul l'ordinateur qui GERE cette entit a le droit de valider le coup !
	if not get_parent().is_multiplayer_authority():
		return''', '')

with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)

# 2. Modify AttackComponent to support is_active_for_network
with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

if 'var is_active_for_network: bool = true' not in content:
    content = content.replace('var hit_entities: Array[Area3D] = []', '''var hit_entities: Array[Area3D] = []
var is_active_for_network: bool = true''')
    
    content = content.replace('func _ready() -> void:', '''func _ready() -> void:
	var p = get_parent()
	while p != null:
		if p is CharacterBody3D:
			is_active_for_network = p.is_multiplayer_authority()
			break
		p = p.get_parent()
	# Si ce n'est pas attach un personnage, on vrifie si c'est un projectile gr par le serveur
	if p == null and multiplayer.is_server():
		is_active_for_network = true
''')

    content = content.replace('func _on_area_entered(area: Area3D) -> void:', '''func _on_area_entered(area: Area3D) -> void:
	if not is_active_for_network: return''')
    
    with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'w', encoding='utf-8') as f:
        f.write(content)


# 3. Modify SkillBarComponent to explicitly set is_active_for_network on echoes
with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

if 'attack_comp.is_active_for_network = false' not in content:
    content = content.replace('''	# On desactive la hitbox pour que ce soit juste un visuel !
	var hitbox = spell_instance.get_node_or_null("HitboxComponent")
	if hitbox != null:
		hitbox.queue_free()''', '''	# L'echo visuel ne doit surtout pas infliger de dgts
	var attack_comp = spell_instance.get_node_or_null("AttackComponent")
	if attack_comp != null:
		attack_comp.is_active_for_network = false''')
		
    with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'w', encoding='utf-8') as f:
        f.write(content)

print("AttackComponent Instigator architecture applied")
