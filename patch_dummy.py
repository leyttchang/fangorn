import os, re

path = 'Y:/Fangorn/fangorn/character/dummy.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the text spawning logic
old_logic = '''\tvar text_instance = damage_text_scene.instantiate()
\tadd_child(text_instance)
\ttext_instance.position.y = 1.0 
\ttext_instance.animate(amount)'''

new_logic = '''\tif is_instance_valid(_active_text):
\t\t_active_text.add_damage(amount)
\telse:
\t\t_active_text = damage_text_scene.instantiate()
\t\tadd_child(_active_text)
\t\t_active_text.position.y = 1.0 
\t\t_active_text.start_animation(amount)'''

content = content.replace(old_logic, new_logic)

# Add _active_text variable
content = content.replace('var timer_label: Label3D', 'var timer_label: Label3D\nvar _active_text: Label3D = null')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
