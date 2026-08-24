extends SceneTree

func _init():
    var anim = ResourceLoader.load("res://character/enemie/dumb_archer/stand.res") as Animation
    if anim:
        for track_idx in anim.get_track_count():
            if anim.track_get_type(track_idx) == Animation.TYPE_POSITION_3D:
                for key_idx in anim.track_get_key_count(track_idx):
                    var pos = anim.track_get_key_value(track_idx, key_idx)
                    anim.track_set_key_value(track_idx, key_idx, pos * 100.0)
        ResourceSaver.save(anim, "res://character/enemie/dumb_archer/stand.res")
        print("SUCCESS")
    else:
        print("FAILED")
    quit()
