import re

with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove _handle_inputs() from _process
content = content.replace('State.IDLE:\n\t\t\t_handle_inputs()', 'State.IDLE:\n\t\t\tpass')
content = content.replace('State.SELECTED:\n\t\t\t_handle_selected()\n\t\t\t_handle_inputs()', 'State.SELECTED:\n\t\t\t_handle_selected()')

# Change func _handle_inputs() to func _unhandled_input(event: InputEvent) -> void:
old_handle_inputs = '''func _handle_inputs() -> void:
	for action in slots.keys():
		if Input.is_action_just_pressed(action):'''

new_unhandled_input = '''func _unhandled_input(event: InputEvent) -> void:
	if not get_parent().is_multiplayer_authority(): return
	if current_state != State.IDLE and current_state != State.SELECTED: return
	
	for action in slots.keys():
		if event.is_action_pressed(action):'''

content = content.replace(old_handle_inputs, new_unhandled_input)

# Wait, if we changed it, what about set_input_as_handled?
# It's better to just leave it as is but it will consume the event, or InteractionComponent will consume it.
# If InteractionComponent consumes it, _unhandled_input in SkillBarComponent WILL NEVER FIRE!
# Because InteractionComponent is a child of the world/chest, which gets the event first!

with open('Y:/Fangorn/fangorn/components/skill_bar_component.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patched skill_bar_component.gd")
