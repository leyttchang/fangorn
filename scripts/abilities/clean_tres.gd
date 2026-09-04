@tool
extends SceneTree

func _init():
    var dir = DirAccess.open("res://scripts/abilities")
    if dir:
        _scan_and_save("res://scripts/abilities")
    quit()
    
func _scan_and_save(path: String):
    var dir = DirAccess.open(path)
    if not dir: return
    dir.list_dir_begin()
    var file = dir.get_next()
    while file != "":
        if file != "." and file != "..":
            var full_path = path + "/" + file
            if dir.current_is_dir():
                _scan_and_save(full_path)
            elif file.ends_with(".tres") and not file.ends_with("_tooltip.tres"):
                var res = ResourceLoader.load(full_path)
                if res is AbilityData:
                    ResourceSaver.save(res, full_path)
                    print("Nettoye: ", full_path)
        file = dir.get_next()
