# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('cast_started.emit(casting_ability.ability_name, required_cast_time)', '''cast_started.emit(casting_ability.ability_name, required_cast_time)
		var vfx_path = ""
		if "cast_vfx_scene" in casting_ability and casting_ability.cast_vfx_scene != null:
			vfx_path = casting_ability.cast_vfx_scene.resource_path
		rpc("_rpc_play_casting_vfx", casting_ability.anim_name, vfx_path, play_speed)''')

content = content.replace('func _reset_casting(is_canceled: bool = false) -> void:', '''func _reset_casting(is_canceled: bool = false) -> void:
	var rec_anim = ""
	if not is_canceled and casting_ability != null and casting_ability.anim_name != "":
		rec_anim = casting_ability.anim_name + "_recovery"
	rpc("_rpc_stop_casting_vfx", rec_anim)
''')

with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("RPC calls injected")
