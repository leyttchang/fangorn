# -*- coding: utf-8 -*-
import os

def patch_spawner(filepath, func_name):
    if not os.path.exists(filepath): return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    insert = f'''func {func_name}
	if not multiplayer.is_server(): return
'''
    # We replace the func definition but only if we haven't already added the check
    if 'if not multiplayer.is_server(): return' not in content:
        content = content.replace(f'func {func_name}', insert)
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

patch_spawner('Y:/Fangorn/fangorn/character/enemie/dumb/dumb_spawner.gd', '_on_spawn_timer_timeout() -> void:')
patch_spawner('Y:/Fangorn/fangorn/character/enemie/smart_spawner/smart_spawner.gd', '_on_spawn_timer_timeout() -> void:')
patch_spawner('Y:/Fangorn/fangorn/objet/chest/chest_spawner.gd', '_on_timer_timeout() -> void:')

def patch_monster_ai(filepath):
    if not os.path.exists(filepath): return
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    insert = '''func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
'''
    if 'if not is_multiplayer_authority(): return' not in content and 'func _physics_process(delta: float) -> void:' in content:
        content = content.replace('func _physics_process(delta: float) -> void:', insert)
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

patch_monster_ai('Y:/Fangorn/fangorn/character/enemie/dumb/dumb.gd')
patch_monster_ai('Y:/Fangorn/fangorn/character/enemie/dumb_archer/dumb_archer.gd')

print('All AI and spawners patched')
