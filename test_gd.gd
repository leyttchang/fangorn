extends SceneTree
func _init():
    var file = FileAccess.open("res://test_out.txt", FileAccess.WRITE)
    file.store_line("Hello")
    file.close()
    quit()
