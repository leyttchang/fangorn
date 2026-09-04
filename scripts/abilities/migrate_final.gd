@tool
extends EditorScript

func _run():
	print("Migration finale du Tooltip...")

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
			
			# On copie le weapon_damage_multiplier global dans CHAQUE attaque 
			# (comme ca le joueur verra directement "+ XX% Weapon Damage" sur son ecran)
			if "tooltip_attacks" in res and "weapon_damage_multiplier" in res:
				for atk in res.tooltip_attacks:
					if atk.weapon_damage_multiplier == 0.0:
						atk.weapon_damage_multiplier = res.weapon_damage_multiplier
						
					if atk.status_effect_chance == 0.0:
						atk.status_effect_chance = 1.0
						
			ResourceSaver.save(res, path)
			print("Mis a jour: " + path)
			
	print("Termine avec succes ! Relance la scene et tu verras ton Weapon Damage !")
