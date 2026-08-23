import os

path = 'Y:/Fangorn/fangorn/components/hitbox_component.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_logic = '''\t\tvar status_comp = get_parent().get_node_or_null("StatusEffectComponent")
\t\t# Tenter avec l'orthographe actuelle
\t\tif status_comp == null: status_comp = get_parent().get_node_or_null("StatusEffectComponant")
\t\tif status_comp != null and status_comp.has_method("apply_effect"):
\t\t\tfor app in attack.status_effects_to_apply:'''

new_logic = '''\t\tvar status_comp = null
\t\tfor child in get_parent().get_children():
\t\t\tif child is StatusEffectComponent:
\t\t\t\tstatus_comp = child
\t\t\t\tbreak
\t\t
\t\tif status_comp != null and status_comp.has_method("apply_effect"):
\t\t\tfor app in attack.status_effects_to_apply:'''

content = content.replace(old_logic, new_logic)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
