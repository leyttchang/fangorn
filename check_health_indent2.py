# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/health_component.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i in range(70, 110):
    if i < len(lines):
        line = lines[i]
        repr_line = repr(line)
        print(f"{i+1}: {repr_line}")
