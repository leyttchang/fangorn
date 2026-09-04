@tool
extends SceneTree

func _init():
    var path = "res://scripts/abilities/thunder_slash/thunder_slash.tres"
    var res = ResourceLoader.load(path)
    for atk in res.tooltip_attacks:
        atk.weapon_damage_multiplier = 0.0
    ResourceSaver.save(res, path)
    quit()
