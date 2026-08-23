import os

path = 'Y:/Fangorn/fangorn/scripts/abilities/thunder_slash/thunder_slash.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_event = '''func on_mid_cast_event(event_name: String) -> void:
\tif event_name == "slash_1":'''

new_event = '''func on_mid_cast_event(event_name: String) -> void:
\tif event_name == "slash_1":
\t\t# Re-aligner le sort avec le joueur pile au moment ou le coup part
\t\tif is_instance_valid(caster):
\t\t\tglobal_transform.basis = caster.global_transform.basis
\t\t\tglobal_position = caster.global_position'''

content = content.replace(old_event, new_event)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
