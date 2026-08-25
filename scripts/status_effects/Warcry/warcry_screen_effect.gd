extends Node3D

func _ready() -> void:
	# On attend 1 frame pour etre sur que tout est bien initialise
	await get_tree().process_frame
	
	var cam = get_viewport().get_camera_3d()
	if cam != null:
		# 1. On se detache des pieds du joueur
		get_parent().remove_child(self)
		
		# 2. On s'attache directement a la camera !
		cam.add_child(self)
		
		# 3. On se place PILE devant l'ecran (z = -1)
		position = Vector3(0, 0, -1)
		rotation = Vector3.ZERO
		
		# On agrandit un peu le Quad pour etre sur qu'il couvre tout l'ecran
		scale = Vector3(5, 5, 5)
