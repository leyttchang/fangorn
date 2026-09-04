@tool
extends SceneTree

func _init():
    var effects = {
        "res://scripts/abilities/fireball/Fireball.tres": [null, {"name": "Burn", "dur": 3.0, "chance": 1.0}],
        "res://scripts/abilities/Ice Crash/IceCrash.tres": [{"name": "Freeze", "dur": 2.5, "chance": 0.5}],
        "res://scripts/abilities/ice_nova/IceNova.tres": [{"name": "Chill", "dur": 4.0, "chance": 1.0}],
        "res://scripts/abilities/chain_lightning/chain_lightning.tres": [{"name": "Shock", "dur": 2.0, "chance": 1.0}]
    }

    for path in effects.keys():
        if ResourceLoader.exists(path):
            var res = ResourceLoader.load(path)
            var eff_list = effects[path]
            if "tooltip_attacks" in res:
                var changed = false
                for i in range(min(eff_list.size(), res.tooltip_attacks.size())):
                    if eff_list[i] != null:
                        var atk = res.tooltip_attacks[i]
                        atk.status_effect_name = eff_list[i]["name"]
                        atk.status_effect_duration = eff_list[i]["dur"]
                        atk.status_effect_chance = eff_list[i]["chance"]
                        changed = true
                if changed:
                    ResourceSaver.save(res, path)
                    print("Status ajoute a : " + path)
                    
    quit()
