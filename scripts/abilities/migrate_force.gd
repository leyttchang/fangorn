@tool
extends SceneTree

const TooltipAttackStatsCls = preload("res://scripts/abilities/tooltip_attack_stats.gd")
const AbilityDataCls = preload("res://scripts/abilities/ability_data.gd")

func _init():
    var paths = [
        "res://scripts/abilities/fireball/Fireball.tres",
        "res://scripts/abilities/chain_lightning/chain_lightning.tres",
        "res://scripts/abilities/thunder_slash/thunder_slash.tres",
        "res://scripts/abilities/Ice Crash/IceCrash.tres",
        "res://scripts/abilities/ice_nova/IceNova.tres",
        "res://scripts/abilities/flaming_stab/flaming_stab.tres",
        "res://scripts/abilities/lightning_strike/LightningStrike.tres",
        "res://scripts/abilities/magic_shot/MagicShot.tres",
        "res://scripts/abilities/Burning_ground/BurningGround.tres"
    ]
    
    for path in paths:
        if ResourceLoader.exists(path):
            var res = ResourceLoader.load(path)
            
            if res != null and "tooltip_attacks" in res:
                var changed = false
                for atk in res.tooltip_attacks:
                    if atk == null:
                        continue
                    
                    if "weapon_damage_multiplier" in res:
                        atk.weapon_damage_multiplier = res.weapon_damage_multiplier
                    
                    if atk.status_effect_chance == 0.0:
                        atk.status_effect_chance = 1.0
                    
                    changed = true
                        
                if changed:
                    ResourceSaver.save(res, path)
                    print("Mis a jour: " + path)
            
    quit()
