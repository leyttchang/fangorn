import os

path = 'Y:/Fangorn/fangorn/scripts/abilities/thunder_slash/thunder_slash.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_event = '''\t\t# Re-aligner le sort avec le joueur pile au moment ou le coup part
\t\tif is_instance_valid(caster):
\t\t\tglobal_transform.basis = caster.global_transform.basis
\t\t\tglobal_position = caster.global_position'''

new_event = '''\t\t# Re-aligner le sort avec le joueur pile au moment ou le coup part
\t\tif is_instance_valid(caster):
\t\t\tglobal_position = caster.global_position
\t\t\t
\t\t\t# Si le joueur a une Camera3D (pour gerer la vue haut/bas)
\t\t\tvar cam = caster.get_node_or_null("Camera3D")
\t\t\tif cam != null:
\t\t\t\tglobal_transform.basis = cam.global_transform.basis
\t\t\telse:
\t\t\t\tglobal_transform.basis = caster.global_transform.basis'''

content = content.replace(old_event, new_event)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
