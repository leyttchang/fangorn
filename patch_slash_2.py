import os

path = 'Y:/Fangorn/fangorn/scripts/abilities/thunder_slash/thunder_slash.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

parts = content.split('func on_mid_cast_event(event_name: String) -> void:')
before = parts[0]
after_parts = parts[1].split('func execute(player: Node3D, target_data: Dictionary) -> void:')
after = 'func execute(player: Node3D, target_data: Dictionary) -> void:' + after_parts[1]

new_func = '''func on_mid_cast_event(event_name: String) -> void:
\t# Re-aligner le sort avec le joueur pile au moment ou le coup part (valable pour TOUS les coups)
\tif is_instance_valid(caster):
\t\tglobal_position = caster.global_position
\t\t
\t\tvar cam = caster.get_node_or_null("Camera3D")
\t\tif cam != null:
\t\t\tglobal_transform.basis = cam.global_transform.basis
\t\telse:
\t\t\tglobal_transform.basis = caster.global_transform.basis

\tif event_name == "slash_1":
\t\tvar slash_anim = $slash_1/AnimationPlayer
\t\tif slash_anim != null:
\t\t\tslash_anim.stop()
\t\t\tslash_anim.play("cast") 
\t\t\tprint("Thunderslash : Animation du slash_1 declenchee !")
\t\t\t$slash_1.visible = true
\t\t\tvar attack_comp = $slash_1.get_node_or_null("AttackComponent")
\t\t\tif attack_comp != null:
\t\t\t\tattack_comp.set_deferred("monitoring", true)
\t\t\t\tattack_comp.set_deferred("monitorable", true)

\telif event_name == "slash_2":
\t\tvar slash_anim = $slash_2/AnimationPlayer
\t\tif slash_anim != null:
\t\t\tslash_anim.stop()
\t\t\tslash_anim.play("cast") 
\t\t\tprint("Thunderslash : Animation du slash_2 declenchee !")
\t\t\t$slash_2.visible = true
\t\t\tvar attack_comp = $slash_2.get_node_or_null("AttackComponent")
\t\t\tif attack_comp != null:
\t\t\t\tattack_comp.set_deferred("monitoring", true)
\t\t\t\tattack_comp.set_deferred("monitorable", true)

'''

final_content = before + new_func + after
final_content = final_content.replace('$', '$')

with open(path, 'w', encoding='utf-8') as f:
    f.write(final_content)
