import os

path = 'Y:/Fangorn/fangorn/ui/damage_text.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

old_logic = '''\tif new_pos != Vector3.ZERO:
\t\tglobal_position.x = new_pos.x
\t\tglobal_position.z = new_pos.z'''

new_logic = '''\tif new_pos != Vector3.ZERO:
\t\tvar pos_tween = create_tween()
\t\tpos_tween.set_parallel(true)
\t\t# Le texte glisse de facon elastique et tres rapide vers la nouvelle position
\t\tpos_tween.tween_property(self, "global_position:x", new_pos.x, 0.15).set_ease(Tween.EASE_OUT)
\t\tpos_tween.tween_property(self, "global_position:z", new_pos.z, 0.15).set_ease(Tween.EASE_OUT)'''

content = content.replace(old_logic, new_logic)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
