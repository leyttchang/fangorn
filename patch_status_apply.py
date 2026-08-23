import os

path_data = 'Y:/Fangorn/fangorn/scripts/status_effects/status_effect_data.gd'
with open(path_data, 'r', encoding='utf-8') as f:
    content_data = f.read()

content_data = content_data.replace('func on_apply(target: Node, component: Node) -> void:', 'func on_apply(target: Node, component: Node, is_refresh: bool) -> void:')
with open(path_data, 'w', encoding='utf-8') as f:
    f.write(content_data)

path_comp = 'Y:/Fangorn/fangorn/components/status_effect_componant.gd'
with open(path_comp, 'r', encoding='utf-8') as f:
    content_comp = f.read()

content_comp = content_comp.replace('data.on_apply(get_parent(), self)', 'data.on_apply(get_parent(), self, false)')
content_comp = content_comp.replace('data.on_apply(get_parent(), self, false)\n\t\treturn', 'data.on_apply(get_parent(), self, true)\n\t\treturn')

with open(path_comp, 'w', encoding='utf-8') as f:
    f.write(content_comp)
