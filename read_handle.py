# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

lines = content.split('\n')
start = False
for line in lines:
    if 'func _handle_inputs' in line:
        start = True
    if start:
        print(line)
        if 'func _handle_targeting' in line:
            break
