extends SceneTree
func _init():
	print("Checking RenderingServer...")
	var rs = RenderingServer
	for method in rs.get_method_list():
		if "directional" in method.name or "shadow" in method.name:
			print(method.name)
	quit()
