extends SceneTree

func _init():
    var files = ["stand", "walk", "death", "aim_recoil", "standing_draw_arrow", "aim_overdraw"]
    for f in files:
        var path = "res://character/enemie/dumb_archer/" + f + ".res"
        var anim = ResourceLoader.load(path)
        if anim:
            ResourceSaver.save(anim, "res://character/enemie/dumb_archer/" + f + ".tres")
            print("Saved ", f)
    quit()
