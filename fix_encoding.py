import os
import glob

def clean_file(filepath):
    # Try reading as utf-16 first (FF FE)
    try:
        with open(filepath, 'r', encoding='utf-16') as f:
            content = f.read()
    except Exception:
        # Fallback to utf-8 or cp1252
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
        except Exception:
            with open(filepath, 'r', encoding='cp1252', errors='ignore') as f:
                content = f.read()

    # Remove BOMs and weird chars
    content = content.replace('\uFEFF', '').replace('\uFFFE', '')
    
    # Strip all non-ascii characters (accents) just to be absolutely safe
    clean_content = "".join(c if ord(c) < 128 else "" for c in content)

    # Write back as pure UTF-8 without BOM
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(clean_content)

files_to_check = [
    'components/health_component.gd',
    'components/hitbox_component.gd',
    'components/StatsComponent.gd',
    'scripts/stats/entity_stats.gd',
    'passive_skill_tree/ressource_node/stat_modifier_data.gd',
    'components/spell_componants/explosion-after_hit_after_hit.gd',
    'components/spell_componants/spell_scaling_component.gd',
]

for file in files_to_check:
    full_path = os.path.join('Y:/Fangorn/fangorn', file)
    if os.path.exists(full_path):
        clean_file(full_path)
        print(f"Cleaned {file}")
