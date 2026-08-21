# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/knockback_componant.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('func apply_knockback(push_direction: Vector3, raw_knockback_force: float) -> void:', 'func apply_knockback(push_direction: Vector3, raw_knockback_force: float) -> void:\\n\\tprint("APPLY KNOCKBACK CALLED! Force: ", raw_knockback_force)')

with open('Y:/Fangorn/fangorn/components/knockback_componant.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Print added to knockback")
