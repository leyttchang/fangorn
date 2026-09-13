extends SceneTree
func _init():
    var f = FileAccess.open("res://util_methods.txt", FileAccess.WRITE)
    for m in ClassDB.class_get_method_list("Terrain3DUtil"):
        f.store_line(str(m))
    f.close()
    quit()
