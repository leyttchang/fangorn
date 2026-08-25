import re

with open('Y:/Fangorn/fangorn/character/player.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

# We want to remove the layout overrides for "equipe".
# The block starts with [node name="equipe" parent="InventoryUI/MainPanel"
# and ends before the next [node
pattern = r'(\[node name="equipe" parent="InventoryUI/MainPanel"[\s\S]*?\])\n(layout_mode = 0\nanchors_preset = 0\nanchor_top = 0\.0\nanchor_right = 0\.0\nanchor_bottom = 0\.0\noffset_left = 0\.0\noffset_top = 0\.0\noffset_right = 500\.0\noffset_bottom = 300\.0\ngrow_horizontal = 1\ngrow_vertical = 1\n)'

new_content = re.sub(pattern, r'\1\n', content)

with open('Y:/Fangorn/fangorn/character/player.tscn', 'w', encoding='utf-8') as f:
    f.write(new_content)
print("Patched!")
