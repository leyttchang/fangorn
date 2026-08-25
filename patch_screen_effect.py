import re

with open('Y:/Fangorn/fangorn/scripts/status_effects/Warcry/warcry_screen_effect.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

# Add the script to the scene
ext_script = '[ext_resource type="Script" path="res://scripts/status_effects/Warcry/warcry_screen_effect.gd" id="2_script"]'

# find where to insert ext_resource
content = content.replace('[ext_resource type="Shader"', ext_script + '\n[ext_resource type="Shader"')

# attach script to root node
content = content.replace('[node name="warcry_screenEffect" type="Node3D" unique_id=1391122572]', '[node name="warcry_screenEffect" type="Node3D" unique_id=1391122572]\nscript = ExtResource("2_script")')

with open('Y:/Fangorn/fangorn/scripts/status_effects/Warcry/warcry_screen_effect.tscn', 'w', encoding='utf-8') as f:
    f.write(content)
print("Attached script to scene")
