@tool
extends SceneTree

func _init():
	var path = "res://character/enemie/Scout/scout_anim_tree.tres"
	var sm = load(path) as AnimationNodeStateMachine
	if sm == null:
		quit()
		return
		
	# Reduce all xfade times
	for i in range(sm.get_transition_count()):
		var t = sm.get_transition(i)
		if t.xfade_time > 0.1:
			t.xfade_time = 0.1
		elif t.xfade_time < 0.025 and t.xfade_time > 0.0:
			t.xfade_time = 0.025
		# Let's just set the attack transitions manually
		var from = sm.get_transition_from(i)
		var to = sm.get_transition_to(i)
		
		# For attacks ending
		if from in ["attaque", "standing_mele_downward", "heavy_weapon_swing"]:
			t.xfade_time = 0.1
			
		# For attacks starting
		if to in ["attaque", "standing_mele_downward", "heavy_weapon_swing"]:
			t.xfade_time = 0.05
			
		# Idle <-> Run
		if (from == "idle" and to == "run") or (from == "run" and to == "idle"):
			t.xfade_time = 0.1
			
	ResourceSaver.save(sm, path)
	print("Success")
	quit()
