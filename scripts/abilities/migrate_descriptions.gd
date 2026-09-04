@tool
extends EditorScript

func _run():
    print("Mise a jour des descriptions des sorts...")

    var descriptions = {
        "res://scripts/abilities/fireball/Fireball.tres": "Hurls a fiery projectile that explodes on impact, dealing fire damage to all nearby enemies.",
        "res://scripts/abilities/chain_lightning/chain_lightning.tres": "Unleashes a bolt of lightning that leaps between up to 3 enemies, dealing heavy lightning damage.",
        "res://scripts/abilities/thunder_slash/thunder_slash.tres": "A two-part melee attack infused with lightning, capable of staggering enemies with its sheer force.",
        "res://scripts/abilities/Ice Crash/IceCrash.tres": "Slams the ground to create a massive shockwave of ice, damaging enemies in a large area.",
        "res://scripts/abilities/ice_nova/IceNova.tres": "Emits a pulse of freezing energy around the caster.",
        "res://scripts/abilities/flaming_stab/flaming_stab.tres": "A fast and deadly thrust with a flaming weapon. Can hit vital spots.",
        "res://scripts/abilities/lightning_strike/LightningStrike.tres": "Calls down a bolt of lightning from the sky onto the target area.",
        "res://scripts/abilities/magic_shot/MagicShot.tres": "Fires a concentrated bolt of arcane energy.",
        "res://scripts/abilities/Burning_ground/BurningGround.tres": "Ignites the ground, continuously burning enemies who stand in the area."
    }
    
    var effects = {
        "res://scripts/abilities/fireball/Fireball.tres": [null, {"name": "Burn", "dur": 3.0}],
        "res://scripts/abilities/Ice Crash/IceCrash.tres": [{"name": "Freeze", "dur": 2.5}],
        "res://scripts/abilities/ice_nova/IceNova.tres": [{"name": "Chill", "dur": 4.0}],
        "res://scripts/abilities/chain_lightning/chain_lightning.tres": [{"name": "Shock", "dur": 2.0}]
    }

    for path in descriptions.keys():
        if ResourceLoader.exists(path):
            var res = ResourceLoader.load(path)
            res.description = descriptions[path]
            
            if effects.has(path):
                var eff_list = effects[path]
                if "tooltip_attacks" in res:
                    for i in range(min(eff_list.size(), res.tooltip_attacks.size())):
                        if eff_list[i] != null:
                            res.tooltip_attacks[i].status_effect_name = eff_list[i]["name"]
                            res.tooltip_attacks[i].status_effect_duration = eff_list[i]["dur"]
                            
            ResourceSaver.save(res, path)
            print("Mis a jour: " + path)
            
    print("Termine avec succes !")
