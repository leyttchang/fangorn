@tool
extends SceneTree

func _init():
    var data = load("res://scripts/status_effects/Warcry/Warcry_effect.tres") as StatusEffectData
    print("Array size: ", data.stat_modifiers.size())
    for mod in data.stat_modifiers:
        if mod == null:
            print("NULL")
        else:
            print("Stat: ", mod.stat_name, " = ", mod.value)
    quit()
