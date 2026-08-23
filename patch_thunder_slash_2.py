import os

path = 'Y:/Fangorn/fangorn/scripts/abilities/thunder_slash/thunder_slash.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_event = '''func on_mid_cast_event(event_name: String) -> void:
\tif event_name == "slash_1":
\t\tif anim_player.has_animation("slash_1"):
\t\t\tanim_player.stop()
\t\t\tanim_player.play("slash_1")
\t\t\tprint("Thunderslash : slash_1 est joue depuis le sort !")
\telif event_name == "slash_2":
\t\tprint("Thunderslash : deuxieme coup !")'''

new_event = '''func on_mid_cast_event(event_name: String) -> void:
\tif event_name == "slash_1":
\t\tvar slash_anim = $slash_1/AnimationPlayer
\t\tif slash_anim != null:
\t\t\tslash_anim.stop()
\t\t\tslash_anim.play("slash_1") # Ou le nom de ton animation d'apparition
\t\t\tprint("Thunderslash : Animation du slash_1 declenchee !")
\t\t\t
\t\t\t# Optionnel : si le slash etait cache (visible = false), on l'affiche ici :
\t\t\t$slash_1.visible = true
\t\t\t
\t\t\t# Optionnel : on reactive l'AttackComponent s'il etait desactive
\t\t\tvar attack_comp = $slash_1.get_node_or_null("AttackComponent")
\t\t\tif attack_comp != null:
\t\t\t\tattack_comp.set_deferred("monitoring", true)
\t\t\t\tattack_comp.set_deferred("monitorable", true)

\telif event_name == "slash_2":
\t\tprint("Thunderslash : deuxieme coup (a configurer) !")'''

content = content.replace(old_event, new_event)
content = content.replace('$', '$')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
