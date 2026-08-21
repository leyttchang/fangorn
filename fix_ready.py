# -*- coding: utf-8 -*-
def restore_ready(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    new_lines = []
    skip = False
    for line in lines:
        if line.startswith('func _ready() -> void:'):
            new_lines.append(line)
            skip = True
        elif skip and line.strip() == 'if possible_bases.is_empty():':
            skip = False
            new_lines.append(line)
        elif skip and line.strip() == '# Auto-chargement des sorts si l\\'array est vide dans l\\'inspecteur':
            skip = False
            new_lines.append(line)
        elif not skip:
            new_lines.append(line)
            
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

restore_ready('Y:/Fangorn/fangorn/objet/chest/chest.gd')
restore_ready('Y:/Fangorn/fangorn/objet/chest/Skill_chest.gd')
print("Ready functions restored")
