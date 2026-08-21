# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''@export var knockback_component: KnockbackComponent # NOUVEAU

func _ready() -> void:''', '''@export var knockback_component: KnockbackComponent # NOUVEAU

signal hit_received(attack: AttackComponent)

func _ready() -> void:''')

content = content.replace('''	if health_component != null:
		health_component.take_damage(attack.damage)''', '''	if health_component != null:
		health_component.take_damage(attack.damage)
		
	hit_received.emit(attack)''')

with open('Y:/Fangorn/fangorn/components/hitbox_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
