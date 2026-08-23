import os

path = 'Y:/Fangorn/fangorn/character/dummy.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Change timer_label height
content = content.replace('timer_label.position.y = 2.5', 'timer_label.position.y = 3.2')

# Change dps_label height
content = content.replace('dps_label.position.y = 2.5', 'dps_label.position.y = 3.2')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
