# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('hit_entities.append(area)\\n\\tprint', 'hit_entities.append(area)\\n\\t\\tprint')
content = content.replace('hit_entities.append(area)\n\tprint', 'hit_entities.append(area)\n\t\tprint')

with open('Y:/Fangorn/fangorn/components/attack_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
