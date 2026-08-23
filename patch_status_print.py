import os

path = 'Y:/Fangorn/fangorn/components/status_effect_componant.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('if data.overlay_material != null and not is_local_player:', 'if data.overlay_material != null and not is_local_player:\n\t\tprint("Application du shader " + str(data.overlay_material) + " sur " + str(get_parent().name))')
content = content.replace('func apply_effect(data: StatusEffectData, duration: float) -> void:', 'func apply_effect(data: StatusEffectData, duration: float) -> void:\n\tprint("Tentative application status : " + str(data.effect_id))')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
