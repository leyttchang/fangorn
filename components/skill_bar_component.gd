class_name SkillBarComponent
extends Node

enum State { IDLE, TARGETING }
var current_state: State = State.IDLE

# Le signal qui va alerter l'interface graphique
signal spells_updated

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

# On récupère dynamiquement le StatsComponent du parent (le Joueur)
@onready var player_stats = get_parent().find_child("StatsComponent", true, false)

func _ready() -> void:
	# Au lancement du jeu, on attend une fraction de seconde que tout soit chargé, 
	# puis on prévient l'UI d'afficher les sorts configurés par défaut dans l'inspecteur.
	call_deferred("_emit_initial_update")

func _emit_initial_update() -> void:
	spells_updated.emit()

# ==========================================
# GESTION DE L'INVENTAIRE DES SORTS
# ==========================================

# Fonction à appeler pour ajouter un sort dans la barre
func equip_spell(slot_name: String, ability: AbilityData) -> void:
	if slots.has(slot_name):
		slots[slot_name] = ability
		# On prévient l'interface que l'inventaire a changé !
		spells_updated.emit() 
		print("Sort équipé : ", ability.ability_name, " dans ", slot_name)
	else:
		push_error("SkillBarComponent : Impossible d'équiper, le slot '" + slot_name + "' n'existe pas.")

# Fonction à appeler pour vider une case de la barre
func unequip_spell(slot_name: String) -> void:
	if slots.has(slot_name):
		slots[slot_name] = null
		# On prévient l'interface que la case est vide
		spells_updated.emit() 
	else:
		push_error("SkillBarComponent : Impossible de déséquiper, le slot '" + slot_name + "' n'existe pas.")

# ==========================================
# LOGIQUE DES COMPÉTENCES ET INPUTS
# ==========================================

func _process(delta: float) -> void:
	if current_state == State.IDLE:
		_handle_inputs()
	elif current_state == State.TARGETING:
		_handle_targeting()

func _handle_inputs() -> void:
	for action in slots.keys():
		if Input.is_action_just_pressed(action):
			var ability: AbilityData = slots[action]
			if ability != null:
				_try_cast_ability(ability)

func _try_cast_ability(ability: AbilityData) -> void:
	if cooldown_timers.has(ability.ability_name):
		print(ability.ability_name, " est en cooldown !")
		return

	match ability.target_mode:
		AbilityData.TargetMode.INSTANT, AbilityData.TargetMode.PROJECTILE, AbilityData.TargetMode.MELEE_OVERRIDE:
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
		# Si c'est un sort de zone au sol, on le déplace à l'endroit du clic
		if ability.target_mode == AbilityData.TargetMode.GROUND_TARGET:
			if target_data.has("impact_point"):
				spell_instance.global_position = target_data["impact_point"]
		if spell_instance.has_method("execute"):
			spell_instance.execute(get_parent(), target_data)

# --- LA MAGIE OPÈRE ICI ---
func _start_cooldown(ability: AbilityData) -> void:
	if ability.cooldown <= 0.0:
		return
		
	var final_cooldown = ability.cooldown
	
	# On applique le calcul de Cooldown Recovery si on a bien trouvé le StatsComponent
	if player_stats != null:
		var cooldown_recovery = player_stats.get_stat_value("cd_red")
		cooldown_recovery = max(cooldown_recovery, 0.1) # Sécurité anti-crash
		final_cooldown = ability.cooldown / cooldown_recovery
		
	var timer = Timer.new()
	# On assigne le cooldown calculé
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
