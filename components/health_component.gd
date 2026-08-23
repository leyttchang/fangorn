class_name HealthComponent
extends Node

# --- SIGNAUX ---
signal health_changed(current_health: float, max_health: float)
signal died
signal damage_taken(amount: float)

# --- DPENDANCES ---
@export var stats_component: StatsComponent

# --- NOUVEAUTS ARMURE ---
# La courbe de rduction qu'on va glisser dans l'inspecteur
# La valeur d'armure maximale prvue par ton graphique (l'axe X = 1.0)

var current_health: float
var _known_max_health: float # NOUVEAU : On mmorise l'ancienne limite
var has_cheat_death: bool = false

func _ready() -> void:
	if stats_component == null:
		push_error("HealthComponent sur " + get_parent().name + " : StatsComponent manquant !")
		return
		

	# Au dbut du jeu, le personnage a toute sa vie et on mmorise son maximum
	_known_max_health = stats_component.get_stat_value("max_health")
	current_health = _known_max_health
	
	# On branche nos oreilles sur le StatsComponent !
	stats_component.stat_changed.connect(_on_stat_changed)

# Fonction appele quand une arme ou un sort touche ce personnage
func take_damage(raw_damage: float) -> void:

	if not owner.is_multiplayer_authority():
		# Ce n'est pas mon entite ! Je demande au proprietaire d'appliquer les degats
		rpc_id(owner.get_multiplayer_authority(), "_rpc_take_damage", raw_damage)
		return
	if current_health <= 0:
		return
		
	# Armure et resistances calculees dans HitboxComponent
	var final_damage = max(0.1, raw_damage)
	
	# 4. On applique les dgts
	current_health -= final_damage
	damage_taken.emit(final_damage)
	rpc("_rpc_broadcast_damage", final_damage)
	
	# On s'assure que la vie ne descend pas en dessous de zro
	# --- MCANIQUE CHEAT DEATH (Ignore Death) ---
	if current_health <= 0 and has_cheat_death:
		has_cheat_death = false
		var max_hp_cheat = stats_component.get_stat_value("max_health")
		current_health = max_hp_cheat * 0.25

	current_health = max(current_health, 0.0)
	
	# 5. On prvient le reste du jeu que la vie a chang
	var max_hp = stats_component.get_stat_value("max_health")
	health_changed.emit(current_health, max_hp)
	
	# 6. On vrifie si le personnage est mort
	if current_health == 0:
		# NOUVEAU : Rcompense d'XP si applicable
		var xp = stats_component.get_stat_value("xp_reward")
		if xp > 0:
			var player = get_tree().get_first_node_in_group("Player")
				
			if player != null and player != get_parent():
				var lvl_comp = player.get_node_or_null("lvl_component") as LevelComponent
				if lvl_comp != null:
					lvl_comp.add_xp(int(xp))
					
		died.emit()

# =========================================================
# L'COUTE DES STATS EN TEMPS REL (Armure, Buffs, etc.)
# =========================================================
func _on_stat_changed(stat_name: String, new_value: float) -> void:
	if stat_name == "max_health":
		# On calcule combien de vie max on vient de gagner (ou perdre)
		var difference = new_value - _known_max_health
		
		# Si on gagne de la vie max (ex: on quipe l'armure de 10 000 PV)
		if difference > 0:
			current_health += difference # On soigne le joueur du montant gagn
			
		# Si on perd de la vie max (ex: on retire l'armure)
		# On s'assure juste que la vie actuelle ne dpasse pas le nouveau plafond
		current_health = min(current_health, new_value)
		
		# On met  jour notre mmoire pour la prochaine fois
		_known_max_health = new_value
		
		# On met  jour l'interface !
		health_changed.emit(current_health, new_value)

# --- FONCTIONS POUR LE BLOOD MAGIC (RENOUNCEMENT) ---
func pay_health_cost(amount: float) -> void:
	current_health -= amount
	# --- MCANIQUE CHEAT DEATH (Ignore Death) ---
	if current_health <= 0 and has_cheat_death:
		has_cheat_death = false
		var max_hp_cheat = stats_component.get_stat_value("max_health")
		current_health = max_hp_cheat * 0.25

	current_health = max(current_health, 0.0)
	var max_hp = stats_component.get_stat_value("max_health")
	health_changed.emit(current_health, max_hp)

func heal(amount: float) -> void:
	var max_hp = stats_component.get_stat_value("max_health")
	current_health += amount
	current_health = min(current_health, max_hp)
	health_changed.emit(current_health, max_hp)


@rpc("authority", "call_remote", "reliable")
func _rpc_broadcast_damage(final_damage: float) -> void:
	damage_taken.emit(final_damage)

@rpc("any_peer", "call_local", "reliable")
func _rpc_take_damage(raw_damage: float) -> void:
	if owner.is_multiplayer_authority():
		take_damage(raw_damage)
