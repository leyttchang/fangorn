# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/objet/pic.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''[node name="AttackComponent" parent="." unique_id=63324796 instance=ExtResource("1_463g8")]
collision_layer = 16
collision_mask = 10
damage = 25.0''', '''[node name="AttackComponent" parent="." unique_id=63324796 instance=ExtResource("1_463g8")]
collision_layer = 16
collision_mask = 10
damage = 25.0
knockback_force = 0.0''')

with open('Y:/Fangorn/fangorn/objet/pic.tscn', 'w', encoding='utf-8') as f:
    f.write(content)
print("Spike knockback removed")
