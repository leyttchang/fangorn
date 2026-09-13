extends SceneTree
func _init():
    var f = FileAccess.open("res://methods.txt", FileAccess.WRITE)
    var methods = ClassDB.class_get_method_list("Terrain3DData")
    for m in methods:
        f.store_line(str(m))
    f.close()
    quit()
