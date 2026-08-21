# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/health_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('func take_damage(raw_damage: float) -> void:', 'func take_damage(raw_damage: float) -> void:\\n\\tprint("TAKE DAMAGE CALLED! ", raw_damage)')

with open('Y:/Fangorn/fangorn/components/health_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Print added to take_damage")
