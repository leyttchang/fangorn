extends SceneTree

func _init():
    var f = FileAccess.open("res://anim_out.txt", FileAccess.WRITE)
    var scene = load("res://character/enemie/dumb_archer/Orc_obj.fbx")
    if scene:
        var node = scene.instantiate()
        var anim_player = node.get_node_or_null("AnimationPlayer")
        if anim_player:
            for anim in anim_player.get_animation_list():
                f.store_line(anim)
        else:
            f.store_line("NO ANIM PLAYER")
    else:
        f.store_line("NO SCENE")
    f.close()
    quit()
