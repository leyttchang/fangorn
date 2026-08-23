import os

path = 'Y:/Fangorn/fangorn/scripts/status_effects/chill_effect_data.gd'
if os.path.exists(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    old = 'if is_refresh and freeze_effect != null:'
    new = 'if is_refresh and freeze_effect != null and component.is_multiplayer_authority():'
    
    if old in content:
        content = content.replace(old, new)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print("Chill Effect Data patched for MP!")
