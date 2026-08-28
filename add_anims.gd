@tool
extends SceneTree
func _init():
	var scene = load("res://character/enemie/creep/creep.tscn").instantiate()
	var anim_player = scene.get_node("CreepAnimPlayer")
	var lib = anim_player.get_animation_library("")
	
	lib.add_animation("tired_walk", load("res://assets/3D_models/body/goblin/tired_walk.res"))
	lib.add_animation("death", load("res://assets/3D_models/body/goblin/death.res"))
	
	var packed = PackedScene.new()
	packed.pack(scene)
	ResourceSaver.save(packed, "res://character/enemie/creep/creep.tscn")
	print(">>> DONE ADDING ANIMS")
	quit()
