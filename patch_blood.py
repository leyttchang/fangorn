import re

with open('Y:/Fangorn/fangorn/particule/blood/blood_particule.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove queue_free method track from Animation_wbvup
content = re.sub(
    r'tracks/1/type = "method"[\s\S]*?\}\]\n\}',
    '',
    content
)

# Remove autoplay from AnimationPlayer
content = re.sub(
    r'autoplay = &"pft"\n?',
    '',
    content
)

# Add ExtResource for script safely at the top
ext_index = content.find('[ext_resource')
if ext_index != -1:
    content = content[:ext_index] + '[ext_resource type="Script" path="res://particule/blood/blood_particule.gd" id="1_script"]\n' + content[ext_index:]

# Attach script to root node
content = re.sub(
    r'\[node name="blood_particule" type="Node3D"(?: unique_id=\d+)?\]',
    '[node name="blood_particule" type="Node3D" script=ExtResource("1_script")]',
    content
)

with open('Y:/Fangorn/fangorn/particule/blood/blood_particule.tscn', 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)
