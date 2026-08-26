import re

with open('Y:/Fangorn/fangorn/character/enemie/Scout/scout.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

# We need to find the main CollisionShape3D of the Scout
# It's unique_id=1007176048 (from previous grep) or the one right under the root
pattern = r'(\[node name="CollisionShape3D" type="CollisionShape3D" parent="\."[^\]]*\]\ntransform = Transform3D\([^\n]+\nshape = [^\n]+\n)'

# Let's adjust its transform to have Y = 1.46 (which is half of 2.93)
# The transform line looks like: transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.044816017, 0)
def replace_transform(match):
    text = match.group(1)
    text = re.sub(r'transform = Transform3D\(([^,]+, [^,]+, [^,]+, [^,]+, [^,]+, [^,]+, [^,]+, [^,]+, [^,]+, [^,]+,) [^,]+, ([^)]+)\)', r'transform = Transform3D(\1 1.469, \2)', text)
    return text

new_content = re.sub(pattern, replace_transform, content)

with open('Y:/Fangorn/fangorn/character/enemie/Scout/scout.tscn', 'w', encoding='utf-8') as f:
    f.write(new_content)
    
print("Updated CollisionShape3D offset")
