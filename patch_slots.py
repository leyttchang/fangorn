import re

with open('Y:/Fangorn/fangorn/ui/inventaire/inventory_ui.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''[node name="equipment_weapon_2" parent="MainPanel/equipe" unique_id=1527176722 instance=ExtResource("3_sitvp")]
layout_mode = 1
anchors_preset = 15''',
'''[node name="equipment_weapon_2" parent="MainPanel/equipe" unique_id=1527176722 instance=ExtResource("3_sitvp")]
layout_mode = 1
anchors_preset = 15
slot_name = "off_hand"'''
)

content = content.replace(
'''[node name="equipment_slot_gloves" parent="MainPanel/equipe" unique_id=322234812 instance=ExtResource("3_sitvp")]
layout_mode = 1
anchors_preset = 15''',
'''[node name="equipment_slot_gloves" parent="MainPanel/equipe" unique_id=322234812 instance=ExtResource("3_sitvp")]
layout_mode = 1
anchors_preset = 15
slot_name = "hands"'''
)

with open('Y:/Fangorn/fangorn/ui/inventaire/inventory_ui.tscn', 'w', encoding='utf-8') as f:
    f.write(content)
