import os

path = 'Y:/Fangorn/fangorn/components/status_effect_componant.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Patch apply_effect -> _internal_apply_effect and add RPCs
new_apply = '''# --- MULTIJOUEUR : APPLY ---
func apply_effect(data: StatusEffectData, duration: float) -> void:
\tif data == null: return
\tif data.resource_path.is_empty():
\t\tpush_error("StatusEffectData n'a pas de resource_path! (Sauvegarde-le en .tres)")
\t\treturn
\t\t
\tif is_multiplayer_authority():
\t\t_apply_effect_broadcast.rpc(data.resource_path, duration)
\telse:
\t\t_request_apply_effect.rpc_id(1, data.resource_path, duration)

@rpc("any_peer", "call_remote", "reliable")
func _request_apply_effect(effect_path: String, duration: float) -> void:
\tif not is_multiplayer_authority(): return
\t_apply_effect_broadcast.rpc(effect_path, duration)

@rpc("authority", "call_local", "reliable")
func _apply_effect_broadcast(effect_path: String, duration: float) -> void:
\tvar data = load(effect_path) as StatusEffectData
\tif data != null:
\t\t_internal_apply_effect(data, duration)

func _internal_apply_effect(data: StatusEffectData, duration: float) -> void:'''
content = content.replace('func apply_effect(data: StatusEffectData, duration: float) -> void:', new_apply)

# 2. Patch remove_effect -> _internal_remove_effect and add RPCs
new_remove = '''# --- MULTIJOUEUR : REMOVE ---
func remove_effect(effect_id: String) -> void:
\tif is_multiplayer_authority():
\t\t_remove_effect_broadcast.rpc(effect_id)
\telse:
\t\t_request_remove_effect.rpc_id(1, effect_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_remove_effect(effect_id: String) -> void:
\tif not is_multiplayer_authority(): return
\t_remove_effect_broadcast.rpc(effect_id)

@rpc("authority", "call_local", "reliable")
func _remove_effect_broadcast(effect_id: String) -> void:
\t_internal_remove_effect(effect_id)

func _internal_remove_effect(effect_id: String) -> void:'''
content = content.replace('func remove_effect(effect_id: String) -> void:', new_remove)

# 3. Patch _process for Authority-only logic
old_process = '''\t\t# Ticks de degats (DoT)
\t\tif eff.data.tick_damage > 0.0 and eff.data.tick_interval > 0.0:
\t\t\teff.next_tick_time -= delta
\t\t\tif eff.next_tick_time <= 0.0:
\t\t\t\teff.next_tick_time = eff.data.tick_interval
\t\t\t\tif health_component != null and health_component.has_method("take_damage"):
\t\t\t\t\t# Envoi en degats bruts pour eviter l'armure si on veut, ou normal
\t\t\t\t\thealth_component.take_damage(eff.data.tick_damage)
\t\t
\t\t# Duree
\t\teff.time_remaining -= delta
\t\tif eff.time_remaining <= 0.0:
\t\t\tremove_effect(key)'''

new_process = '''\t\t# Ticks de degats (DoT)
\t\tif eff.data.tick_damage > 0.0 and eff.data.tick_interval > 0.0:
\t\t\teff.next_tick_time -= delta
\t\t\tif eff.next_tick_time <= 0.0:
\t\t\t\teff.next_tick_time = eff.data.tick_interval
\t\t\t\tif is_multiplayer_authority(): # ONLY HOST INFLIGE DEGATS
\t\t\t\t\tif health_component != null and health_component.has_method("take_damage"):
\t\t\t\t\t\thealth_component.take_damage(eff.data.tick_damage)
\t\t
\t\t# Duree
\t\teff.time_remaining -= delta
\t\tif eff.time_remaining <= 0.0:
\t\t\tif is_multiplayer_authority(): # ONLY HOST DECIDE DE LA FIN
\t\t\t\tremove_effect(key)'''
content = content.replace(old_process, new_process)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Patch OK !")
