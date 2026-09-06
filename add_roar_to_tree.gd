extends SceneTree

func _init():
	var tree_path = "res://character/enemie/ogre_boss/ogre_boss_anim_tree.tres"
	var anim_tree = ResourceLoader.load(tree_path) as AnimationNodeStateMachine
	if anim_tree:
		# Ajouter le node
		var anim_node = AnimationNodeAnimation.new()
		anim_node.animation = "anim/roar"
		anim_tree.add_node("roar", anim_node)
		
		# Transitions
		var t_idle_roar = AnimationNodeStateMachineTransition.new()
		t_idle_roar.xfade_time = 0.1
		anim_tree.add_transition("idle", "roar", t_idle_roar)
		
		var t_walk_roar = AnimationNodeStateMachineTransition.new()
		t_walk_roar.xfade_time = 0.1
		anim_tree.add_transition("walk", "roar", t_walk_roar)
		
		var t_roar_idle = AnimationNodeStateMachineTransition.new()
		t_roar_idle.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		t_roar_idle.xfade_time = 0.2
		anim_tree.add_transition("roar", "idle", t_roar_idle)
		
		var t_roar_death = AnimationNodeStateMachineTransition.new()
		t_roar_death.xfade_time = 0.1
		anim_tree.add_transition("roar", "death", t_roar_death)
		
		ResourceSaver.save(anim_tree, tree_path)
		print("SUCCESS: Roar ajoute a l'anim tree !")
	else:
		print("ERROR: Impossible de charger l'anim tree")
	
	quit()
