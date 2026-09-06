@tool
extends EditorScript

func _run():
	var scene_path = "res://character/enemie/ogre_boss/ogre_boss.tscn"
	var packed_scene = ResourceLoader.load(scene_path)
	if not packed_scene:
		print("Failed to load scene")
		return
		
	var root = packed_scene.instantiate()
	var anim_tree = root.get_node_or_null("AnimationTree")
	if not anim_tree:
		print("AnimationTree not found")
		return
		
	anim_tree.anim_player = NodePath("../Stable Sword Outward Slash/AnimationPlayer")
	
	var machine = AnimationNodeStateMachine.new()
	
	var anim_idle = AnimationNodeAnimation.new()
	anim_idle.animation = "flexing_muscle"
	machine.add_node("idle", anim_idle)
	
	var anim_walk = AnimationNodeAnimation.new()
	anim_walk.animation = "Z_run"
	machine.add_node("walk", anim_walk)
	
	var anim_attack = AnimationNodeAnimation.new()
	anim_attack.animation = "sword_swing"
	machine.add_node("attack", anim_attack)
	
	var anim_death = AnimationNodeAnimation.new()
	anim_death.animation = "death"
	machine.add_node("death", anim_death)
	
	var t_start_idle = AnimationNodeStateMachineTransition.new()
	t_start_idle.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	machine.add_transition("Start", "idle", t_start_idle)
	
	var t_idle_walk = AnimationNodeStateMachineTransition.new()
	machine.add_transition("idle", "walk", t_idle_walk)
	var t_walk_idle = AnimationNodeStateMachineTransition.new()
	machine.add_transition("walk", "idle", t_walk_idle)
	
	var t_idle_attack = AnimationNodeStateMachineTransition.new()
	machine.add_transition("idle", "attack", t_idle_attack)
	var t_walk_attack = AnimationNodeStateMachineTransition.new()
	machine.add_transition("walk", "attack", t_walk_attack)
	
	var t_attack_idle = AnimationNodeStateMachineTransition.new()
	t_attack_idle.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	t_attack_idle.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	machine.add_transition("attack", "idle", t_attack_idle)
	
	var t_idle_death = AnimationNodeStateMachineTransition.new()
	machine.add_transition("idle", "death", t_idle_death)
	var t_walk_death = AnimationNodeStateMachineTransition.new()
	machine.add_transition("walk", "death", t_walk_death)
	var t_attack_death = AnimationNodeStateMachineTransition.new()
	machine.add_transition("attack", "death", t_attack_death)
	
	anim_tree.tree_root = machine
	anim_tree.active = true
	
	var new_packed = PackedScene.new()
	new_packed.pack(root)
	ResourceSaver.save(new_packed, scene_path)
	print("Successfully created AnimationTree and saved scene!")
