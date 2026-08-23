import os

path = 'Y:/Fangorn/fangorn/scripts/abilities/thunder_slash/thunder_slash.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Pour slash_1
old_s1 = '''\t\t\t$slash_1.visible = true
\t\t\tvar attack_comp = $slash_1.get_node_or_null("AttackComponent")'''
new_s1 = '''\t\t\t$slash_1.visible = true
\t\t\t
\t\t\t# On calcule les degats AVANT d'activer la hitbox !
\t\t\tvar scaling_comp = $SpellScalingComponent
\t\t\tif scaling_comp != null:
\t\t\t\tscaling_comp.on_execute(caster, {})
\t\t\t
\t\t\tvar attack_comp = $slash_1.get_node_or_null("AttackComponent")'''
content = content.replace(old_s1, new_s1)

# Pour slash_2
old_s2 = '''\t\t\t$slash_2.visible = true
\t\t\tvar attack_comp = $slash_2.get_node_or_null("AttackComponent")'''
new_s2 = '''\t\t\t$slash_2.visible = true
\t\t\t
\t\t\t# On calcule les degats AVANT d'activer la hitbox !
\t\t\tvar scaling_comp = $SpellScalingComponent2
\t\t\tif scaling_comp != null:
\t\t\t\tscaling_comp.on_execute(caster, {})
\t\t\t
\t\t\tvar attack_comp = $slash_2.get_node_or_null("AttackComponent")'''
content = content.replace(old_s2, new_s2)

content = content.replace('$', '$')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
