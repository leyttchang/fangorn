import os

def patch_enemy(path, has_attack_shape=True):
    if not os.path.exists(path):
        return
        
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # On ajoute la verification de l'action_speed au debut du physics_process
    old_phys = '''func _physics_process(delta: float) -> void:
\tif not is_multiplayer_authority(): return'''
    
    secu_hitbox = '''\t\t# Securite pour la hitbox
\t\tif attack_shape != null and not attack_shape.disabled:
\t\t\tattack_shape.disabled = true''' if has_attack_shape else ''

    new_phys = f'''func _physics_process(delta: float) -> void:
\tif not is_multiplayer_authority(): return
\t
\tvar action_speed = 1.0
\tif stats_component != null:
\t\taction_speed = max(0.0, stats_component.get_stat_value("action_speed"))
\t\t
\t# --- STUN TOTAL ---
\tif action_speed <= 0.0:
\t\tif not is_on_floor():
\t\t\tvelocity.y -= gravity * delta
\t\tvelocity.x = move_toward(velocity.x, 0, 10.0 * delta)
\t\tvelocity.z = move_toward(velocity.z, 0, 10.0 * delta)
\t\tmove_and_slide()
\t\t
\t\t# On fige l'arbre d'animation !
\t\tif anim_tree.active:
\t\t\tanim_tree.active = false
\t\t
{secu_hitbox}
\t\treturn
\t\t
\tif not anim_tree.active:
\t\tanim_tree.active = true'''

    if 'action_speed = max(0.0' not in content:
        content = content.replace(old_phys, new_phys)

    # Modify speed calculation
    old_speed = 'var current_speed = base_movement_speed * stats_component.get_stat_value("movement_speed")'
    new_speed = 'var current_speed = base_movement_speed * stats_component.get_stat_value("movement_speed") * action_speed'
    
    content = content.replace(old_speed, new_speed)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

patch_enemy('Y:/Fangorn/fangorn/character/enemie/dumb/dumb.gd', True)
patch_enemy('Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd', False)

print("Ennemis mis a jour avec action_speed !")
