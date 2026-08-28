@tool
extends SceneTree
func _init():
	var scene = load("res://character/enemie/creep/creep.tscn").instantiate()
	var anim_player = AnimationPlayer.new()
	anim_player.name = "CreepAnimPlayer"
	anim_player.root_node = NodePath("../goblin")
	
	var lib = AnimationLibrary.new()
	lib.add_animation("crouching_walk", load("res://assets/3D_models/body/goblin/crouching_walk.res"))
	lib.add_animation("run_fast", load("res://assets/3D_models/body/goblin/run_fast.res"))
	lib.add_animation("stab", load("res://assets/3D_models/body/goblin/stab.res"))
	
	anim_player.add_animation_library("", lib)
	scene.add_child(anim_player)
	anim_player.owner = scene
	
	# Update the AnimationTree to point to the new player
	var anim_tree = scene.get_node("AnimationTree")
	anim_tree.anim_player = NodePath("../CreepAnimPlayer")
	
	var packed = PackedScene.new()
	packed.pack(scene)
	ResourceSaver.save(packed, "res://character/enemie/creep/creep.tscn")
	print(">>> DONE FIXING CREEP")
	quit()
