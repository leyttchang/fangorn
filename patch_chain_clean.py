import os, re

path = 'Y:/Fangorn/fangorn/scripts/abilities/chain_lightning/chain_lightning.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the two print statements
content = re.sub(r'\t+print\(".*?Chain Lightning: Multiplicateur AoE = .*?\n', '', content)
content = re.sub(r'\t+print\(".*?Chain Lightning a touche .*?\n', '', content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
