import os
import re

directory = "Y:/Fangorn/fangorn/passive_skill_tree/ressource_node"

TAGS = {
    "Life": 1,
    "Mana": 2,
    "Armor": 4,
    "Physical": 8,
    "Fire": 16,
    "Ice": 32,
    "Lightning": 64,
    "Elemental": 128,
    "Speed": 256,
    "Attack": 512,
    "Magic": 1024,
    "Utility": 2048,
    "Area": 4096
}

def analyze_tags(text):
    text_lower = text.lower()
    flags = 0
    
    if "health" in text_lower or "life" in text_lower: flags |= TAGS["Life"]
    if "mana" in text_lower: flags |= TAGS["Mana"]
    if "armor" in text_lower or "defence" in text_lower or "defense" in text_lower: flags |= TAGS["Armor"]
    if "physical" in text_lower or "brutality" in text_lower: flags |= TAGS["Physical"]
    if "fire" in text_lower: 
        flags |= TAGS["Fire"]
        flags |= TAGS["Elemental"]
    if "ice" in text_lower or "cold" in text_lower or "frost" in text_lower: 
        flags |= TAGS["Ice"]
        flags |= TAGS["Elemental"]
    if "lightning" in text_lower or "shock" in text_lower: 
        flags |= TAGS["Lightning"]
        flags |= TAGS["Elemental"]
    if "elemental" in text_lower or "elementalist" in text_lower: flags |= TAGS["Elemental"]
    if "movement_speed" in text_lower or "movement speed" in text_lower or "vitesse" in text_lower: flags |= TAGS["Speed"]
    if "attack" in text_lower or "melee" in text_lower or "attaque" in text_lower: flags |= TAGS["Attack"]
    if "magic" in text_lower or "spell" in text_lower or "casting" in text_lower or "cast speed" in text_lower or "sort" in text_lower: flags |= TAGS["Magic"]
    if "knockback" in text_lower or "cooldown" in text_lower or "cd_red" in text_lower: flags |= TAGS["Utility"]
    if "area" in text_lower or "aoe" in text_lower: flags |= TAGS["Area"]
    
    return flags

for root, _, files in os.walk(directory):
    for f in files:
        if f.endswith(".tres"):
            filepath = os.path.join(root, f)
            with open(filepath, "r", encoding="utf-8") as file:
                content = file.read()
                
            flags = analyze_tags(content)
            
            # Replace existing tags value inside [resource] block
            parts = content.split("[resource]")
            if len(parts) == 2:
                resource_part = parts[1]
                resource_part = re.sub(
                    r"^tags\s*=\s*\d+",
                    f"tags = {flags}",
                    resource_part,
                    flags=re.MULTILINE
                )
                content = parts[0] + "[resource]" + resource_part
            
            with open(filepath, "w", encoding="utf-8") as file:
                file.write(content)
                
print("Tags correctly updated with Area tag")
