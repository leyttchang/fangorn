import os

def revert_enemy(path):
    if not os.path.exists(path):
        return
        
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    new_phys = '''func _physics_process(delta: float) -> void:
\tif not is_multiplayer_authority(): return
\t
\tvar status = get_node_or_null("status_effect_componant")
\tif status == null: status = get_node_or_null("StatusEffectComponent")
\tif status != null and status.has_effect("freeze"):
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
\t\t# Securite pour la hitbox
\t\tif attack_shape != null and not attack_shape.disabled:
\t\t\tattack_shape.disabled = true
\t\treturn
\t\t
\tif not anim_tree.active:
\t\tanim_tree.active = true'''

    new_phys_archer = '''func _physics_process(delta: float) -> void:
\tif not is_multiplayer_authority(): return
\t
\tvar status = get_node_or_null("status_effect_componant")
\tif status == null: status = get_node_or_null("StatusEffectComponent")
\tif status != null and status.has_effect("freeze"):
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
\t\treturn
\t\t
\tif not anim_tree.active:
\t\tanim_tree.active = true'''

    old_phys = '''func _physics_process(delta: float) -> void:
\tif not is_multiplayer_authority(): return'''

    if 'status.has_effect("freeze")' in content:
        content = content.replace(new_phys, old_phys)
        content = content.replace(new_phys_archer, old_phys)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

revert_enemy('Y:/Fangorn/fangorn/character/enemie/dumb/dumb.gd')
revert_enemy('Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd')

print("Revert reussi !")
