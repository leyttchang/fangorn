@tool
extends EditorScript

func _run():
	print("Mise a jour des ressources TooltipAttackStats...")

	var updates = {
		"res://scripts/abilities/fireball/Fireball.tres": [
			{ "attack_name": "Impact", "base_damage": 100.0, "is_aoe": false, "can_headshot": true, "knockback_force": 10.0, "phys_ratio": 0.0, "fire_ratio": 1.0 },
			{ "attack_name": "Explosion", "base_damage": 50.0, "is_aoe": true, "can_headshot": false, "knockback_force": 9.0, "phys_ratio": 0.0, "fire_ratio": 1.0 }
		],
		"res://scripts/abilities/thunder_slash/thunder_slash.tres": [
			{ "attack_name": "Slash 1", "base_damage": 25.0, "is_aoe": false, "can_headshot": false, "knockback_force": 0.5, "phys_ratio": 0.5, "lightning_ratio": 0.5 },
			{ "attack_name": "Slash 2", "base_damage": 25.0, "is_aoe": false, "can_headshot": false, "knockback_force": 5.0, "phys_ratio": 0.5, "lightning_ratio": 0.5 }
		],
		"res://scripts/abilities/Ice Crash/IceCrash.tres": [
			{ "attack_name": "Impact", "base_damage": 10.0, "is_aoe": true, "can_headshot": false, "knockback_force": 15.0, "phys_ratio": 0.5, "ice_ratio": 0.5 }
		],
		"res://scripts/abilities/ice_nova/IceNova.tres": [
			{ "attack_name": "Nova", "base_damage": 60.0, "is_aoe": true, "can_headshot": false, "knockback_force": 0.0, "phys_ratio": 0.0, "ice_ratio": 1.0 }
		],
		"res://scripts/abilities/chain_lightning/chain_lightning.tres": [
			{ "attack_name": "Foudre", "base_damage": 100.0, "is_aoe": false, "can_headshot": false, "knockback_force": 1.0, "phys_ratio": 0.0, "lightning_ratio": 1.0 }
		],
		"res://scripts/abilities/flaming_stab/flaming_stab.tres": [
			{ "attack_name": "Estoc", "base_damage": 10.0, "is_aoe": false, "can_headshot": true, "knockback_force": 15.0, "phys_ratio": 0.5, "fire_ratio": 0.5 }
		],
		"res://scripts/abilities/lightning_strike/LightningStrike.tres": [
			{ "attack_name": "Foudre", "base_damage": 100.0, "is_aoe": true, "can_headshot": false, "knockback_force": 0.0, "phys_ratio": 0.0, "lightning_ratio": 1.0 }
		],
		"res://scripts/abilities/magic_shot/MagicShot.tres": [
			{ "attack_name": "Projectile", "base_damage": 30.0, "is_aoe": false, "can_headshot": true, "knockback_force": 2.0, "phys_ratio": 1.0, "fire_ratio": 0.0 }
		],
		"res://scripts/abilities/Burning_ground/BurningGround.tres": [
			{ "attack_name": "Brulure au sol", "base_damage": 1.0, "is_aoe": true, "can_headshot": false, "knockback_force": 0.0, "phys_ratio": 0.0, "fire_ratio": 1.0 }
		]
	}
	
	for path in updates.keys():
		if ResourceLoader.exists(path):
			var res = ResourceLoader.load(path)
			if not "tooltip_attacks" in res:
				print("Erreur: Le script ability_data.gd n'a pas encore ete recharge par Godot. Relance l'editeur.")
				continue
				
			var arr: Array[TooltipAttackStats] = []
			
			for atk_data in updates[path]:
				var ts = TooltipAttackStats.new()
				ts.attack_name = atk_data["attack_name"]
				ts.base_damage = atk_data["base_damage"]
				ts.is_aoe = atk_data["is_aoe"]
				ts.can_headshot = atk_data["can_headshot"]
				ts.knockback_force = atk_data["knockback_force"]
				ts.phys_ratio = atk_data.get("phys_ratio", 0.0)
				ts.fire_ratio = atk_data.get("fire_ratio", 0.0)
				ts.ice_ratio = atk_data.get("ice_ratio", 0.0)
				ts.lightning_ratio = atk_data.get("lightning_ratio", 0.0)
				arr.append(ts)
				
			res.tooltip_attacks = arr
			ResourceSaver.save(res, path)
			print("Mis a jour: " + path)
		else:
			print("Introuvable: " + path)
			
	print("Termine avec succes ! Tes fichiers .tres sont prets.")
