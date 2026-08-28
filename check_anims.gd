extends SceneTree
func _init():
	print(">>> CHECKING SCENE")
	var scene = load("res://character/enemie/creep/creep.tscn").instantiate()
	var anim_player = scene.get_node_or_null("goblin/AnimationPlayer")
	print(">>> PLAYER FOUND: ", anim_player)
	if anim_player:
		for lib_name in anim_player.get_animation_library_list():
			print(">>> LIB: ", lib_name)
			var lib = anim_player.get_animation_library(lib_name)
			for anim_name in lib.get_animation_list():
				print(">>> ANIM: ", anim_name)
	quit()
