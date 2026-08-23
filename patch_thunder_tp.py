import os

path = 'Y:/Fangorn/fangorn/scripts/abilities/thunder_slash/thunder_slash.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# On supprime le bloc de re-alignement global en haut de on_mid_cast_event
old_top = '''func on_mid_cast_event(event_name: String) -> void:
\t# Re-aligner le sort avec le joueur pile au moment ou le coup part (valable pour TOUS les coups)
\tif is_instance_valid(caster):
\t\tglobal_position = caster.global_position
\t\t
\t\tvar cam = caster.get_node_or_null("Camera3D")
\t\tif cam != null:
\t\t\tglobal_transform.basis = cam.global_transform.basis
\t\telse:
\t\t\tglobal_transform.basis = caster.global_transform.basis'''

new_top = '''func on_mid_cast_event(event_name: String) -> void:'''
content = content.replace(old_top, new_top)

# Pour slash_1
old_s1 = '''\tif event_name == "slash_1":
\t\tvar slash_anim = $slash_1/AnimationPlayer'''
new_s1 = '''\tif event_name == "slash_1":
\t\t# On aligne UNIQUEMENT slash_1 sur le joueur
\t\tif is_instance_valid(caster):
\t\t\t$slash_1.global_position = caster.global_position
\t\t\tvar cam = caster.get_node_or_null("Camera3D")
\t\t\tif cam != null:
\t\t\t\t$slash_1.global_transform.basis = cam.global_transform.basis
\t\t\telse:
\t\t\t\t$slash_1.global_transform.basis = caster.global_transform.basis
\t\t
\t\tvar slash_anim = $slash_1/AnimationPlayer'''
content = content.replace(old_s1, new_s1)

# Pour slash_2
old_s2 = '''\telif event_name == "slash_2":
\t\tvar slash_anim = $slash_2/AnimationPlayer'''
new_s2 = '''\telif event_name == "slash_2":
\t\t# On aligne UNIQUEMENT slash_2 sur le joueur
\t\tif is_instance_valid(caster):
\t\t\t$slash_2.global_position = caster.global_position
\t\t\tvar cam = caster.get_node_or_null("Camera3D")
\t\t\tif cam != null:
\t\t\t\t$slash_2.global_transform.basis = cam.global_transform.basis
\t\t\telse:
\t\t\t\t$slash_2.global_transform.basis = caster.global_transform.basis
\t\t
\t\tvar slash_anim = $slash_2/AnimationPlayer'''
content = content.replace(old_s2, new_s2)

content = content.replace('$', '$')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
