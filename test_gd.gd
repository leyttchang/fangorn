extends SceneTree
func _init():
    var anim = ResourceLoader.load("res://character/enemie/dumb_archer/aim_recoil.res") as Animation
    if anim:
        ResourceSaver.save(anim, "res://character/enemie/dumb_archer/aim_recoil.tres")
        print("Saved")
    quit()
