# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

lines = content.split('\n')
for i, line in enumerate(lines):
    if 'func _execute_ability' in line:
        for j in range(i, min(i+40, len(lines))):
            print(lines[j])
        break
