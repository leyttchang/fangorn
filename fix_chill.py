import os

path = 'Y:/Fangorn/fangorn/scripts/status_effects/chill_effect_data.gd'
content = '''class_name ChillEffectData
extends StatusEffectData

@export_group("Combo Glace")
@export var freeze_effect: StatusEffectData
@export var freeze_duration: float = 3.0

func on_apply(target: Node, component: Node, is_refresh: bool) -> void:
\t# is_refresh est "vrai" si le monstre avait DEJA le statut Chill
\t
\tif is_refresh and freeze_effect != null:
\t\t# 1. On retire le chill car il va etre gelee
\t\tcomponent.call_deferred("remove_effect", effect_id)
\t\t
\t\t# 2. On applique le Freeze
\t\tcomponent.call_deferred("apply_effect", freeze_effect, freeze_duration)
'''

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
