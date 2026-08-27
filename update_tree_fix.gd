@tool
extends SceneTree

func _init():
	var path = "res://character/enemie/Scout/scout_anim_tree.tres"
	var sm = load(path) as AnimationNodeStateMachine
	if sm == null:
		quit()
		return
		
	# Update all transitions to at least ENABLED, and remove old AUTO transitions for attacks
	for i in range(sm.get_transition_count()):
		var t = sm.get_transition(i)
		if t.advance_mode == AnimationNodeStateMachineTransition.ADVANCE_MODE_DISABLED:
			t.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
			
	# Remove old run/strafe transitions from attacks so they only return to idle
	var trans_to_remove = []
	for i in range(sm.get_transition_count()):
		var from = sm.get_transition_from(i)
		var to = sm.get_transition_to(i)
		if from in ["attaque", "standing_mele_downward", "heavy_weapon_swing"]:
			if to in ["run", "strafe"]:
				trans_to_remove.append([from, to])
				
	for pair in trans_to_remove:
		sm.remove_transition(pair[0], pair[1])
			
	ResourceSaver.save(sm, path)
	print("Success")
	quit()
