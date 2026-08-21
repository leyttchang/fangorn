# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/health_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()
content = content.replace('print("TAKE DAMAGE CALLED! ", raw_damage)\\n\\t', '')
content = content.replace('print("TAKE DAMAGE CALLED! ", raw_damage)\n\t', '')
with open('Y:/Fangorn/fangorn/components/health_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)

with open('Y:/Fangorn/fangorn/components/knockback_componant.gd', 'r', encoding='utf-8') as f:
    content = f.read()
content = content.replace('print("APPLY KNOCKBACK CALLED! Force: ", raw_knockback_force)\\n\\t', '')
content = content.replace('print("APPLY KNOCKBACK CALLED! Force: ", raw_knockback_force)\n\t', '')
with open('Y:/Fangorn/fangorn/components/knockback_componant.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Prints removed")
