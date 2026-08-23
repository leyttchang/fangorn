import os
import re

path = 'Y:/Fangorn/fangorn/old_skillbar.gd'
if os.path.exists(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove the class_name declaration
    content = re.sub(r'class_name SkillBarComponent\n', '', content)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Patched old_skillbar.gd")
