import os
import re
import csv

directory = "Y:/Fangorn/fangorn/passive_skill_tree/ressource_node"
output_file = "C:/Users/ley-a/.gemini/antigravity/brain/07938edb-a257-49cc-9db4-a671c85b3837/skill_nodes_export.csv"

TAG_MAPPING = {
    1: "Life", 2: "Mana", 4: "Armor", 8: "Physical", 16: "Fire",
    32: "Ice", 64: "Lightning", 128: "Elemental", 256: "Speed",
    512: "Attack", 1024: "Magic", 2048: "Utility", 4096: "Area"
}

def decode_tags(tags_int):
    tags = []
    for val, name in TAG_MAPPING.items():
        if (tags_int & val) != 0:
            tags.append(name)
    return ", ".join(tags)

def extract_value(pattern, text, default):
    match = re.search(pattern, text)
    if match:
        return match.group(1).strip('"')
    return default

def get_subresources(content):
    # Dictionary mapping subresource ID to its parsed properties
    sub_res = {}
    blocks = content.split("\n\n")
    for block in blocks:
        if block.startswith("[sub_resource type=\"Resource\" id=\""):
            res_id = re.search(r'id="([^"]+)"', block).group(1)
            stat_name = extract_value(r'stat_name\s*=\s*"?([^"\n]+)"?', block, "")
            value = extract_value(r'value\s*=\s*([-\d.]+)', block, "0.0")
            mod_type = extract_value(r'mod_type\s*=\s*(\d)', block, "0")
            if stat_name:
                sub_res[res_id] = f"{stat_name}:{value}:{mod_type}"
    return sub_res

rows = []
headers = [
    "Filename", "Node ID", "Node Name", "Description", "Icon Path", "Node Type",
    "Max Occurrences", "Base Spawn Weight", 
    "Zone Barbarian", "Zone Mage", "Zone Duelist",
    "Tier 1", "Tier 2", "Tier 3",
    "Is Hybrid", "Barb/Mage", "Mage/Duelist", "Duelist/Barb",
    "Tags", "Gameplay Effect ID", "Stats Bonuses"
]

node_type_map = {"0": "MINOR", "1": "NOTABLE", "2": "KEYSTONE"}

for root, _, files in os.walk(directory):
    for f in files:
        if f.endswith(".tres"):
            filepath = os.path.join(root, f)
            with open(filepath, "r", encoding="utf-8") as file:
                content = file.read()
                
            # Basic info
            node_id = extract_value(r'node_id\s*=\s*"([^"]+)"', content, "")
            node_name = extract_value(r'node_name\s*=\s*"([^"]+)"', content, "")
            # Description can be multiline, but normally in one line with "\n". 
            # If actual multiline, regex might fail. Let's use a robust match for strings.
            desc_match = re.search(r'description\s*=\s*"([^"]*)"', content, re.DOTALL)
            description = desc_match.group(1).replace('\n', ' ') if desc_match else ""
            
            # Find icon path from ext_resource
            icon_id = extract_value(r'icon\s*=\s*ExtResource\("([^"]+)"\)', content, "")
            icon_path = ""
            if icon_id:
                icon_path_match = re.search(rf'\[ext_resource type="Texture2D".*?path="([^"]+)".*?id="{icon_id}"\]', content)
                if icon_path_match:
                    icon_path = icon_path_match.group(1)
            
            # Numbers / Bools
            node_type = extract_value(r'node_type\s*=\s*(\d)', content, "0")
            node_type_str = node_type_map.get(node_type, "UNKNOWN")
            
            max_occ = extract_value(r'max_occurrences\s*=\s*(\d+)', content, "1")
            spawn_weight = extract_value(r'base_spawn_weight\s*=\s*([-\d.]+)', content, "100.0")
            
            z_barb = extract_value(r'zone_barbarian_multiplier\s*=\s*([-\d.]+)', content, "1.0")
            z_mage = extract_value(r'zone_mage_multiplier\s*=\s*([-\d.]+)', content, "1.0")
            z_duel = extract_value(r'zone_duelist_multiplier\s*=\s*([-\d.]+)', content, "1.0")
            
            t1 = extract_value(r'tier_1_multiplier\s*=\s*([-\d.]+)', content, "1.0")
            t2 = extract_value(r'tier_2_multiplier\s*=\s*([-\d.]+)', content, "0.0")
            t3 = extract_value(r'tier_3_multiplier\s*=\s*([-\d.]+)', content, "0.0")
            
            is_hybrid = extract_value(r'is_hybrid_exclusive\s*=\s*(true|false)', content, "false")
            h_barb_mage = extract_value(r'spawn_in_barb_mage\s*=\s*(true|false)', content, "false")
            h_mage_duel = extract_value(r'spawn_in_mage_duel\s*=\s*(true|false)', content, "false")
            h_duel_barb = extract_value(r'spawn_in_duel_barb\s*=\s*(true|false)', content, "false")
            
            tags_int = int(extract_value(r'tags\s*=\s*(\d+)', content, "0"))
            tags_str = decode_tags(tags_int)
            
            effect_id = extract_value(r'gameplay_effect_id\s*=\s*"([^"]+)"', content, "")
            
            # Stats Bonuses
            sub_res = get_subresources(content)
            stats_list = []
            stats_match = re.search(r'stats_bonuses\s*=\s*Array\[.*?\]\(\[(.*?)\]\)', content)
            if stats_match:
                # e.g. SubResource("Resource_0"), SubResource("Resource_1")
                refs = re.findall(r'SubResource\("([^"]+)"\)', stats_match.group(1))
                for ref in refs:
                    if ref in sub_res:
                        stats_list.append(sub_res[ref])
                        
            stats_str = " | ".join(stats_list)
            
            rows.append([
                f, node_id, node_name, description, icon_path, node_type_str,
                max_occ, spawn_weight, z_barb, z_mage, z_duel, t1, t2, t3,
                is_hybrid, h_barb_mage, h_mage_duel, h_duel_barb,
                tags_str, effect_id, stats_str
            ])

# Sort by Node Type then by Filename
rows.sort(key=lambda x: (x[5], x[0]))

with open(output_file, "w", newline='', encoding="utf-8") as csvfile:
    writer = csv.writer(csvfile, delimiter=',')
    writer.writerow(headers)
    writer.writerows(rows)

print(f"Exported to {output_file}")
