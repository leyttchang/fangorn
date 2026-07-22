extends SceneTree
func _init():
    var anim = load('res://character/enemie/dumb/punch.res')
    for i in range(anim.get_track_count()):
        print('Track ', i, ': ', anim.track_get_path(i))
    quit()
