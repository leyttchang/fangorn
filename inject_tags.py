import os
import re

directory = "Y:/Fangorn/fangorn/passive_skill_tree/ressource_node"

# Tags mappings
# "Life", "Mana", "Armor", "Physical", "Fire", "Ice", "Lightning", "Elemental", "Speed", "Attack", "Magic", "Utility"
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
    "Utility": 2048
}

def analyze_tags(text):
    text_lower = text.lower()
    flags = 0
    
    # Life
    if "health" in text_lower or "life" in text_lower: flags |= TAGS["Life"]
    # Mana
    if "mana" in text_lower: flags |= TAGS["Mana"]
    # Armor
    if "armor" in text_lower or "defence" in text_lower or "defense" in text_lower: flags |= TAGS["Armor"]
    # Physical
    if "physical" in text_lower or "brutality" in text_lower: flags |= TAGS["Physical"]
    # Fire
    if "fire" in text_lower: 
        flags |= TAGS["Fire"]
        flags |= TAGS["Elemental"]
    # Ice
    if "ice" in text_lower or "cold" in text_lower or "frost" in text_lower: 
        flags |= TAGS["Ice"]
        flags |= TAGS["Elemental"]
    # Lightning
    if "lightning" in text_lower or "shock" in text_lower: 
        flags |= TAGS["Lightning"]
        flags |= TAGS["Elemental"]
    # Elemental (explicit)
    if "elemental" in text_lower or "elementalist" in text_lower: flags |= TAGS["Elemental"]
    # Speed
    if "movement_speed" in text_lower or "movement speed" in text_lower: flags |= TAGS["Speed"]
    # Attack
    if "attack" in text_lower or "melee" in text_lower: flags |= TAGS["Attack"]
    # Magic
    if "magic" in text_lower or "spell" in text_lower or "casting" in text_lower or "cast speed" in text_lower: flags |= TAGS["Magic"]
    # Utility
    if "area" in text_lower or "knockback" in text_lower or "cooldown" in text_lower or "cd_red" in text_lower: flags |= TAGS["Utility"]
    
    return flags

for root, _, files in os.walk(directory):
    for f in files:
        if f.endswith(".tres"):
            filepath = os.path.join(root, f)
            with open(filepath, "r", encoding="utf-8") as file:
                content = file.read()
                
            # If tags is already present, remove it to overwrite
            content = re.sub(r"^tags\s*=\s*\d+\n", "", content, flags=re.MULTILINE)
            
            flags = analyze_tags(content)
            
            # Inject tags under script = ExtResource
            if "script = ExtResource" in content:
                content = re.sub(
                    r"(script\s*=\s*ExtResource\([^\)]+\)\n)",
                    f"\\1tags = {flags}\n",
                    content,
                    count=1
                )
            
            with open(filepath, "w", encoding="utf-8") as file:
                file.write(content)
                
print("Tags injected in all .tres files")
