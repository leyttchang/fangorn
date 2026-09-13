extends SceneTree

func _init():
	var t = ClassDB.class_get_method_list("Terrain3DStorage")
	for m in t:
		if "clear" in m.name or "remove" in m.name or "region" in m.name:
			print("Storage: ", m.name)
			
	var t2 = ClassDB.class_get_method_list("Terrain3DData")
	for m in t2:
		if "clear" in m.name or "remove" in m.name or "region" in m.name:
			print("Data: ", m.name)
			
	quit()
