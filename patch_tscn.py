import re

with open('Y:/Fangorn/fangorn/character/enemie/Scout/scout.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

# Add ext_resource at the top of the file
ext_str = '[ext_resource type="AnimationNodeStateMachine" path="res://character/enemie/Scout/scout_anim_tree.tres" id="scout_anim_tree"]\n'

# Find the first line after gd_scene
lines = content.split('\n')
for i, line in enumerate(lines):
    if line.startswith('[ext_resource'):
        lines.insert(i, ext_str.strip())
        break
content = '\n'.join(lines)

# Add tree_root to AnimationTree
anim_tree_pattern = r'(\[node name="AnimationTree" type="AnimationTree"[^\]]*\]\nactive = false\nroot_node = [^\n]+\nanim_player = [^\n]+)'
replacement = r'\1\ntree_root = ExtResource("scout_anim_tree")'
content = re.sub(anim_tree_pattern, replacement, content)

with open('Y:/Fangorn/fangorn/character/enemie/Scout/scout.tscn', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated scout.tscn")
