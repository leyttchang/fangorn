# -*- coding: utf-8 -*-
with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Authority protection in _process
content = content.replace('func _process(delta: float) -> void:', '''func _process(delta: float) -> void:
	if not get_parent().is_multiplayer_authority():
		return
''')

# 2. Add the RPC functions at the end of the file
content += '''
# ==========================================
# GESTION RESEAU DES ANIMATIONS DE CAST
# ==========================================
@rpc("any_peer", "call_remote", "unreliable")
func _rpc_play_casting_vfx(anim_name: String, vfx_scene_path: String, play_speed: float) -> void:
	if anim_player != null and anim_name != "":
		if anim_player.has_animation(anim_name):
			anim_player.play(anim_name, -1, play_speed)
	
	if vfx_scene_path != "":
		var vfx_scene = load(vfx_scene_path)
		if vfx_scene != null:
			current_vfx_instance = vfx_scene.instantiate()
			
			# L'cho visuel ne doit surtout pas infliger de dgts
			var attack_comp = current_vfx_instance.get_node_or_null("AttackComponent")
			if attack_comp != null:
				attack_comp.is_active_for_network = false
				
			if cast_vfx_spawn_point != null:
				cast_vfx_spawn_point.add_child(current_vfx_instance)
			else:
				get_parent().add_child(current_vfx_instance)
				
			var vfx_anim = current_vfx_instance.get_node_or_null("VFX_anim")
			if vfx_anim != null:
				var vfx_anim_name = vfx_anim.autoplay
				if vfx_anim_name == "" and vfx_anim.has_animation("default"):
					vfx_anim_name = "default"
					vfx_anim.play("default")
				if vfx_anim_name != "":
					var vfx_length = vfx_anim.get_animation(vfx_anim_name).length
					vfx_anim.speed_scale = vfx_length / (1.0 / play_speed) # Approximation

@rpc("any_peer", "call_remote", "unreliable")
func _rpc_stop_casting_vfx(recovery_anim: String) -> void:
	if current_vfx_instance != null:
		_kill_vfx(current_vfx_instance)
		current_vfx_instance = null
		
	if anim_player != null:
		if recovery_anim != "" and anim_player.has_animation(recovery_anim):
			anim_player.play(recovery_anim)
		else:
			if anim_player.has_animation("RESET"):
				anim_player.play("RESET")
			else:
				anim_player.stop()
'''

with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("SkillBarComponent patched with RPCs")
