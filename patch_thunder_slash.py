import os

path = 'Y:/Fangorn/fangorn/scripts/abilities/thunder_slash/thunder_slash.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_start = '''func start_complex_cast(player: Node3D) -> void:
\tcaster = player'''

new_start = '''func start_complex_cast(player: Node3D) -> void:
\tcaster = player
\t# On s'oriente dans la meme direction que le joueur pour que les projectiles partent droit devant !
\tglobal_transform.basis = player.global_transform.basis'''

content = content.replace(old_start, new_start)

# On va aussi allonger le timer de destruction pour eviter que les eclair disparaissent en vol
old_exec = '''\tawait get_tree().create_timer(2.0).timeout
\tqueue_free()'''

new_exec = '''\t# On attend assez longtemps pour laisser les eclairs voyager (ex: 5 secondes)
\tawait get_tree().create_timer(5.0).timeout
\tqueue_free()'''

content = content.replace(old_exec, new_exec)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Patch OK !")
