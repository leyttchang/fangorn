class_name SkillBarComponent
extends Node

enum State { IDLE, TARGETING, CASTING }
var current_state: State = State.IDLE

# --- SIGNAUX ---
signal spells_updated
signal cast_started(ability_name: String, max_time: float)
signal cast_updated(current_time: float, max_time: float)
signal cast_canceled()
signal cast_finished() # Signal de succès pour la barre d'incantation

@export var slots: Dictionary[String, AbilityData] = {
	"slot_1": null,
	"slot_2": null,
	"slot_3": null,
	"slot_4": null,
	"slot_5": null,
	"slot_6": null
}

@export var raycast: RayCast3D 

var cooldown_timers: Dictionary = {}
var active_ability: AbilityData = null 
var indicator_instance: Node3D = null 

# Variables pour l'incantation
var casting_ability: AbilityData = null
var casting_action: String = ""
var current_cast_time: float = 0.0
var required_cast_time: float = 0.0

@onready var player_stats = get_parent().find_child("StatsComponent", true, false)

func _ready() -> void:
	call_deferred("_emit_initial_update")

func _emit_initial_update() -> void:
	spells_updated.emit()

# ==========================================
# GESTION DE L'INVENTAIRE DES SORTS
# ==========================================
func equip_spell(slot_name: String, ability: AbilityData) -> void:
	if slots.has(slot_name):
		slots[slot_name] = ability
		spells_updated.emit() 
		print("Sort équipé : ", ability.ability_name, " dans ", slot_name)
	else:
		push_error("SkillBarComponent : Impossible d'équiper, le slot '" + slot_name + "' n'existe pas.")

func unequip_spell(slot_name: String) -> void:
	if slots.has(slot_name):
		slots[slot_name] = null
		spells_updated.emit() 
	else:
		push_error("SkillBarComponent : Impossible de déséquiper, le slot '" + slot_name + "' n'existe pas.")

# ==========================================
# LOGIQUE DES COMPÉTENCES ET INPUTS
# ==========================================
func _process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_handle_inputs()
		State.TARGETING:
			_handle_targeting()
		State.CASTING:
			_handle_casting(delta)

func _handle_inputs() -> void:
	for action in slots.keys():
		if Input.is_action_just_pressed(action):
			var ability: AbilityData = slots[action]
			if ability != null:
				if cooldown_timers.has(ability.ability_name):
					print(ability.ability_name, " est en cooldown !")
					continue

				var base_cast_time = ability.cast_time if "cast_time" in ability else 0.0
				
				if base_cast_time <= 0.0:
					# Sort instantané, on passe par la voie classique
					_try_cast_ability(ability)
				else:
					# Sort avec temps d'incantation : On lance le CASTING
					current_state = State.CASTING
					casting_ability = ability
					casting_action = action
					current_cast_time = 0.0
					
					# --- CALCUL DE LA VITESSE SELON LA CATÉGORIE ---
					var final_speed_multiplier = 1.0
					
					if ability.category == AbilityData.AbilityCategory.WEAPON_ATTACK:
						# Attaque physique : On utilise la vitesse d'attaque
						if player_stats != null:
							final_speed_multiplier = player_stats.get_stat_value("attack_speed")
						
						# On applique le multiplicateur propre à la compétence
						var w_speed_mult = ability.weapon_speed_multiplier if "weapon_speed_multiplier" in ability else 1.0
						final_speed_multiplier *= w_speed_mult
						
					else:
						# Sort magique : On utilise la vitesse d'incantation
						if player_stats != null:
							final_speed_multiplier = player_stats.get_stat_value("casting_speed")
					
					# SÉCURITÉ : On empêche le multiplicateur de tomber à 0
					final_speed_multiplier = max(final_speed_multiplier, 0.1) 
					
					required_cast_time = base_cast_time / final_speed_multiplier
					# ---------------------------------------------------
					
					# On affiche TOUT DE SUITE l'indicateur si c'est un sort au sol !
					if ability.target_mode in [AbilityData.TargetMode.GROUND_TARGET, AbilityData.TargetMode.SUMMON]:
						if raycast != null:
							raycast.target_position = Vector3(0, 0, -ability.max_range)
							raycast.force_raycast_update() 
						
						if ability.indicator_scene != null:
							indicator_instance = ability.indicator_scene.instantiate()
							get_tree().root.add_child(indicator_instance)
					
					cast_started.emit(ability.ability_name, required_cast_time)
					print("Début du chargement de : ", ability.ability_name, " (Temps requis : ", required_cast_time, "s)")
					
				return

# --- LA FONCTION QUI GÈRE LE MAINTIEN DE LA TOUCHE ET LE RELÂCHEMENT ---
func _handle_casting(delta: float) -> void:
	# 1. On déplace l'indicateur sous la souris en temps réel
	if indicator_instance != null and raycast != null:
		if raycast.is_colliding():
			indicator_instance.visible = true
			indicator_instance.global_position = raycast.get_collision_point()
		else:
			indicator_instance.visible = false

	# 2. Annulation d'urgence (Clic Droit)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		print("Cast annulé (clic droit) !")
		cast_canceled.emit()
		_reset_casting()
		return

	# 3. On fait tourner le chronomètre TANT QUE la touche est maintenue
	if Input.is_action_pressed(casting_action):
		current_cast_time += delta
		current_cast_time = min(current_cast_time, required_cast_time)
		cast_updated.emit(current_cast_time, required_cast_time)

	# 4. Validation du tir (ON RELÂCHE LA TOUCHE)
	if Input.is_action_just_released(casting_action):
		if current_cast_time >= required_cast_time:
			
			# --- SÉCURITÉ ANTI-TIR DANS LE VIDE ---
			var requires_ground = casting_ability.target_mode in [AbilityData.TargetMode.GROUND_TARGET, AbilityData.TargetMode.SUMMON]
			var is_aiming_valid = raycast != null and raycast.is_colliding()
			
			if requires_ground and not is_aiming_valid:
				# ÉCHEC : Le sort demande le sol, mais on vise le ciel ou trop loin
				print("Cast annulé (Visée invalide ou hors de portée) !")
				cast_canceled.emit()
			else:
				# SUCCÈS : Tout est bon !
				print("Cast terminé avec succès !")
				cast_finished.emit() # On prévient l'UI que le tir est parti !
				
				var target_data = {}
				if is_aiming_valid:
					target_data["impact_point"] = raycast.get_collision_point()
					target_data["collider"] = raycast.get_collider()
				
				# On tire !
				_execute_ability(casting_ability, target_data)
		else:
			# ÉCHEC : Le joueur a relâché trop tôt
			print("Cast annulé (relâché trop tôt) !")
			cast_canceled.emit()
		
		# Quoi qu'il arrive, on nettoie tout pour le prochain sort
		_reset_casting()

# Fonction pour tout nettoyer quand on a fini (ou raté) de charger
func _reset_casting() -> void:
	current_state = State.IDLE
	casting_ability = null
	casting_action = ""
	current_cast_time = 0.0
	required_cast_time = 0.0
	
	if indicator_instance != null:
		indicator_instance.queue_free()
		indicator_instance = null

# ==========================================
# CIBLAGE CLASSIQUE (SORTS INSTANTANÉS) ET EXÉCUTION
# ==========================================
func _try_cast_ability(ability: AbilityData) -> void:
	match ability.target_mode:
		AbilityData.TargetMode.INSTANT, AbilityData.TargetMode.PROJECTILE:
			_execute_ability(ability, {})
			
		AbilityData.TargetMode.GROUND_TARGET, AbilityData.TargetMode.SUMMON:
			current_state = State.TARGETING
			active_ability = ability
			
			if raycast != null:
				raycast.target_position = Vector3(0, 0, -ability.max_range)
				raycast.force_raycast_update() 
			
			if ability.indicator_scene != null:
				indicator_instance = ability.indicator_scene.instantiate()
				get_tree().root.add_child(indicator_instance)
				
		AbilityData.TargetMode.HITSCAN:
			if raycast != null:
				raycast.target_position = Vector3(0, 0, -ability.max_range)
				raycast.force_raycast_update()
			
			var target_data = {}
			if raycast != null and raycast.is_colliding():
				target_data["impact_point"] = raycast.get_collision_point()
				target_data["collider"] = raycast.get_collider()
				
			_execute_ability(ability, target_data)

func _handle_targeting() -> void:
	if indicator_instance != null and raycast != null:
		if raycast.is_colliding():
			indicator_instance.visible = true
			indicator_instance.global_position = raycast.get_collision_point()
		else:
			indicator_instance.visible = false

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if raycast != null and raycast.is_colliding():
			var target_data = {
				"impact_point": raycast.get_collision_point()
			}
			_execute_ability(active_ability, target_data)
		else:
			print("Cible hors de portée !")
			
		_cleanup_targeting()

	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		print("Visée annulée.")
		_cleanup_targeting()

func _cleanup_targeting() -> void:
	current_state = State.IDLE
	active_ability = null
	if indicator_instance != null:
		indicator_instance.queue_free()
		indicator_instance = null

func _execute_ability(ability: AbilityData, target_data: Dictionary) -> void:
	print("Lancement réussi de : ", ability.ability_name)
	_start_cooldown(ability)

	if ability.ability_scene != null:
		var spell_instance = ability.ability_scene.instantiate()
		get_tree().root.add_child(spell_instance)
		if ability.target_mode in [AbilityData.TargetMode.GROUND_TARGET, AbilityData.TargetMode.SUMMON]:
			if target_data.has("impact_point"):
				spell_instance.global_position = target_data["impact_point"]
		if spell_instance.has_method("execute"):
			spell_instance.execute(get_parent(), target_data)

func _start_cooldown(ability: AbilityData) -> void:
	if ability.cooldown <= 0.0:
		return
		
	var final_cooldown = ability.cooldown
	
	if player_stats != null:
		var cooldown_recovery = player_stats.get_stat_value("cd_red")
		cooldown_recovery = max(cooldown_recovery, 0.1) 
		final_cooldown = ability.cooldown / cooldown_recovery
		
	var timer = Timer.new()
	timer.wait_time = final_cooldown
	timer.one_shot = true
	add_child(timer)
	timer.start()
	
	cooldown_timers[ability.ability_name] = timer
	
	timer.timeout.connect(func():
		cooldown_timers.erase(ability.ability_name)
		if is_instance_valid(timer):
			timer.queue_free()
	)
