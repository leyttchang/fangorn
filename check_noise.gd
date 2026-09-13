extends SceneTree

func _init():
	var methods = ClassDB.class_get_method_list("Noise")
	for m in methods:
		print("Noise method: ", m.name)
		
	var f_methods = ClassDB.class_get_method_list("FastNoiseLite")
	for m in f_methods:
		print("FastNoiseLite method: ", m.name)
		
	quit()
