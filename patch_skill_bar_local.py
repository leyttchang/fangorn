import os

path = 'Y:/Fangorn/fangorn/components/skill_bar_component.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_local = '''\t\t\t\t\t\t\tcurrent_complex_spell_instance = spell_instance
\t\t\t\t\t\t\tspell_instance.global_position = get_parent().global_position
\t\t\t\t\t\t\tif spell_instance.has_method("start_complex_cast"):
\t\t\t\t\t\t\t\tspell_instance.start_complex_cast(get_parent())'''
new_local = '''\t\t\t\t\t\t\tcurrent_complex_spell_instance = spell_instance
\t\t\t\t\t\t\tspell_instance.global_position = get_parent().global_position
\t\t\t\t\t\t\t
\t\t\t\t\t\t\t# Transmission de l'autorite locale pour les degats
\t\t\t\t\t\t\tvar auth = get_parent().get_multiplayer_authority()
\t\t\t\t\t\t\tfor child in spell_instance.find_children("AttackComponent*", "Area3D", true, false):
\t\t\t\t\t\t\t\tchild.set_meta("caster_authority", auth)
\t\t\t\t\t\t\t
\t\t\t\t\t\t\tif spell_instance.has_method("start_complex_cast"):
\t\t\t\t\t\t\t\tspell_instance.start_complex_cast(get_parent())'''
content = content.replace(old_local, new_local)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
