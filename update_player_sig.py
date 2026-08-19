with open("Y:/Fangorn/fangorn/character/player.gd", "r", encoding="utf-8") as f:
    content = f.read()

# Add signal after the first line (extends CharacterBody3D)
if "signal player_hit_enemy" not in content:
    content = content.replace("extends CharacterBody3D", "extends CharacterBody3D\n\nsignal player_hit_enemy")

with open("Y:/Fangorn/fangorn/character/player.gd", "w", encoding="utf-8") as f:
    f.write(content)
print("Added signal to player.gd")
