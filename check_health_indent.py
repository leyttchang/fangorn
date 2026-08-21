# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/health_component.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if line.startswith('func _on_stat_changed'):
        print(f"Line {i+1}: {repr(line)}")
        break
