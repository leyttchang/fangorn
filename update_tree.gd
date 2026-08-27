@tool
extends SceneTree

func _init():
	var path = "res://character/enemie/Scout/scout_anim_tree.tres"
	var sm = load(path) as AnimationNodeStateMachine
	if sm == null:
		print("Failed to load state machine")
		quit()
		return
		
	# Add idle animation node
	if not sm.has_node("idle"):
		var idle_node = AnimationNodeAnimation.new()
		idle_node.animation = "anim/idle"
		sm.add_node("idle", idle_node, Vector2(100, 100))
		
	# Helper to add transition
	var add_trans = func(from: String, to: String, xfade: float, mode: int):
		if sm.has_transition(from, to):
			var t = sm.get_transition(sm.find_transition(from, to))
			t.xfade_time = xfade
		else:
			var t = AnimationNodeStateMachineTransition.new()
			t.xfade_time = xfade
			t.switch_mode = mode
			if from == "Start" or mode == AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END:
				t.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
			sm.add_transition(from, to, t)
			
	# Update Start to go to idle instead of run
	if sm.has_transition("Start", "run"):
		sm.remove_transition("Start", "run")
	add_trans.call("Start", "idle", 0.0, AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE)
	
	# Idle <-> Run
	add_trans.call("idle", "run", 0.2, AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE)
	add_trans.call("run", "idle", 0.2, AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE)
	
	# Idle <-> Strafe
	add_trans.call("idle", "strafe", 0.2, AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE)
	add_trans.call("strafe", "idle", 0.2, AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE)
	
	# Idle -> Attacks
	add_trans.call("idle", "attaque", 0.1, AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE)
	add_trans.call("idle", "standing_mele_downward", 0.1, AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE)
	add_trans.call("idle", "heavy_weapon_swing", 0.1, AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE)
	
	# Attacks -> Idle
	add_trans.call("attaque", "idle", 0.3, AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END)
	add_trans.call("standing_mele_downward", "idle", 0.3, AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END)
	add_trans.call("heavy_weapon_swing", "idle", 0.3, AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END)

	# Update existing transitions to have xfade
	var update_trans = func(from, to, xfade):
		if sm.has_transition(from, to):
			var idx = sm.find_transition(from, to)
			sm.get_transition(idx).xfade_time = xfade
			
	update_trans.call("run", "attaque", 0.1)
	update_trans.call("attaque", "run", 0.3)
	update_trans.call("run", "standing_mele_downward", 0.1)
	update_trans.call("standing_mele_downward", "run", 0.3)
	update_trans.call("run", "heavy_weapon_swing", 0.1)
	update_trans.call("heavy_weapon_swing", "run", 0.3)
	
	update_trans.call("strafe", "attaque", 0.1)
	update_trans.call("attaque", "strafe", 0.3)
	update_trans.call("strafe", "standing_mele_downward", 0.1)
	update_trans.call("standing_mele_downward", "strafe", 0.3)
	update_trans.call("strafe", "heavy_weapon_swing", 0.1)
	update_trans.call("heavy_weapon_swing", "strafe", 0.3)
	
	ResourceSaver.save(sm, path)
	print("Success")
	quit()
