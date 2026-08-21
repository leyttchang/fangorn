# -*- coding: utf-8 -*-
import os

def patch_file(filepath):
    if not os.path.exists(filepath): return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Only execute on Server
    if 'extends ' in content and 'func _ready' in content and 'multiplayer.is_server()' not in content:
        # We need to ensure spawners only run on the server
        content = content.replace('func _on_spawn_timer_timeout', 'func _on_spawn_timer_timeout') # placeholder

    content = content.replace('get_tree().current_scene.add_child(', 'get_tree().current_scene.get_node("NetworkObjects").add_child(')
    # We must add force_readable_name = true for MultiplayerSpawners!
    content = content.replace('.add_child(new_dumb)', '.add_child(new_dumb, true)')
    content = content.replace('.add_child(enemy_instance)', '.add_child(enemy_instance, true)')
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

patch_file('Y:/Fangorn/fangorn/character/enemie/dumb/dumb_spawner.gd')
patch_file('Y:/Fangorn/fangorn/character/enemie/smart_spawner/smart_spawner.gd')
print('Spawners patched')
