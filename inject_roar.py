import re

filepath = r"Y:\Fangorn\fangorn\character\enemie\ogre_boss\ogre_boss_anim_tree.tres"
with open(filepath, 'r') as f:
    content = f.read()

# Add SubResource for roar at the top
sub_res_roar = '[sub_resource type="AnimationNodeAnimation" id="AnimationNodeAnimation_roar"]\nanimation = &"anim/roar"\n'

# Add 4 transitions
trans_22 = '[sub_resource type="AnimationNodeStateMachineTransition" id="AnimationNodeStateMachineTransition_22"]\nxfade_time = 0.1\n'
trans_23 = '[sub_resource type="AnimationNodeStateMachineTransition" id="AnimationNodeStateMachineTransition_23"]\nxfade_time = 0.1\n'
trans_24 = '[sub_resource type="AnimationNodeStateMachineTransition" id="AnimationNodeStateMachineTransition_24"]\nxfade_time = 0.2\nswitch_mode = 2\nadvance_mode = 2\n'
trans_25 = '[sub_resource type="AnimationNodeStateMachineTransition" id="AnimationNodeStateMachineTransition_25"]\nxfade_time = 0.1\n'

# Find the last SubResource definition index
match = list(re.finditer(r'\[sub_resource.*\]', content))[-1]
end_idx = content.find('\n', match.end())
if end_idx == -1: end_idx = len(content)

while end_idx < len(content) and content[end_idx] != '\n':
    end_idx = content.find('\n', end_idx + 1)
while end_idx < len(content) and content[end_idx] == '\n':
    end_idx += 1

# Insert SubResources
new_resources = '\n' + sub_res_roar + '\n' + trans_22 + '\n' + trans_23 + '\n' + trans_24 + '\n' + trans_25 + '\n'

# Inject new resources
content = content[:end_idx] + new_resources + content[end_idx:]

# Inject node into states list
state_str = 'states/roar/node = SubResource("AnimationNodeAnimation_roar")\nstates/roar/position = Vector2(500, -100)\n'
# find states/swing_attack
node_idx = content.find('states/swing_attack/node')
content = content[:node_idx] + state_str + content[node_idx:]

# Inject transitions into transitions array
trans_array_match = re.search(r'transitions = \[(.*?)\]', content)
if trans_array_match:
    trans_array = trans_array_match.group(1)
    new_trans = ', "idle", "roar", SubResource("AnimationNodeStateMachineTransition_22"), "walk", "roar", SubResource("AnimationNodeStateMachineTransition_23"), "roar", "idle", SubResource("AnimationNodeStateMachineTransition_24"), "roar", "death", SubResource("AnimationNodeStateMachineTransition_25")'
    new_trans_array = trans_array + new_trans
    content = content.replace(trans_array_match.group(0), f'transitions = [{new_trans_array}]')

with open(filepath, 'w') as f:
    f.write(content)
print("SUCCESS")
