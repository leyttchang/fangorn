import os

path = 'Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old = '''\t\t# Securite pour la hitbox
\t\tif attack_shape != null and not attack_shape.disabled:
\t\t\tattack_shape.disabled = true
\t\treturn'''

new = '''\t\treturn'''

content = content.replace(old, new)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
