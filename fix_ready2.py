import re

def fix(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # regex to replace from _ready() to the actual code
    content = re.sub(r'func _ready\(\) -> void:.*?(?=# === AUTO-CHARGEMENT|# Auto-chargement)', r'func _ready() -> void:\n\t', content, flags=re.DOTALL)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

fix('Y:/Fangorn/fangorn/objet/chest/chest.gd')
fix('Y:/Fangorn/fangorn/objet/chest/Skill_chest.gd')
print("Fixed")
