class_name SkillBarComponent
extends Node

enum State { IDLE, TARGETING, SELECTED, CASTING, AUTO_CASTING }
var current_state: State = State.IDLE
var can_cast_spells: bool = true

enum CastingResource { MANA, HEALTH }
var current_casting_resource: CastingResource = CastingResource.MANA

# --- SIGNAUX ---
signal spells_updated
signal health_spent_for_spell(amount: float)
signal cast_started(ability_name: String, max_time: float)
signal cast_updated(current_time: float, max_time: float)
signal cast_canceled()
signal cast_finished() 

@export var slots: Dictionary[String, AbilityData] = {
	"slot_1": null,
	"slot_2": null,
	"slot_3": null,
	"slot_4": null,
	"slot_5": null,
	"slot_6": null
}

@export var raycast: RayCast3D 
@export var anim_player: AnimationPlayer
@export var anim_tree: AnimationTree # <-- L'ajout est ici
@export var cast_vfx_spawn_point: Node3D

var cooldown_timers: Dictionary = {}
var active_ability: AbilityData = null 
var indicator_instance: Node3D = null 
var current_vfx_instance: Node3D = null

var casting_ability: AbilityData = null
var casting_action: String = ""
var current_cast_time: float = 0.0
var required_cast_time: float = 0.0

@onready var player_stats = get_parent().find_child("StatsComponent", true, false)

func _ready() -> void:
	call_deferred("_emit_initial_update")

func _emit_initial_update() -> void:
	spells_updated.emit()

func equip_spell(slot_name: String, ability: AbilityData) -> void:
	if slots.has(slot_name):
		slots[slot_name] = ability
		spells_updated.emit() 
	else:
		push_error("SkillBarComponent : Impossible d'équiper, le slot '" + slot_name + "' n'existe pas.")

func unequip_spell(slot_name: String) -> void:
	if slots.has(slot_name):
		slots[slot_name] = null
		spells_updated.emit() 
	else:
		push_error("SkillBarComponent : Impossible de déséquiper, le slot '" + slot_name + "' n'existe pas.")

func _process(delta: float) -> void:
	if not get_parent().is_multiplayer_authority():
		return

	match current_state:
		State.IDLE:
			_handle_inputs()
		State.TARGETING:
			_handle_targeting()
		State.SELECTED:
			_handle_selected()
			_handle_inputs()
		State.CASTING:
			_handle_casting(delta)
		State.AUTO_CASTING:
			_handle_auto_casting(delta)

func _handle_inputs() -> void:
	for action in slots.keys():
		if Input.is_action_just_pressed(action):
			var ability: AbilityData = slots[action]
			if ability != null:
				if not can_cast_spells and ability.category == AbilityData.AbilityCategory.MAGIC:
					# print(ability.ability_name, " est bloqué (Magie interdite) !")
					continue
					
				if cooldown_timers.has(ability.ability_name):
					print(ability.ability_name, " est en cooldown !")
					continue

				# Vérification de la ressource (Mana ou Vie)
				var can_afford = false
				if current_casting_resource == CastingResource.MANA:
					var mana_comp = get_parent().get_node_or_null("ManaComponent")
					if mana_comp == null: mana_comp = get_parent().get_node_or_null("mana_component")
					if mana_comp != null:
						can_afford = mana_comp.has_enough_mana(ability.mana_cost)
				elif current_casting_resource == CastingResource.HEALTH:
					var health_comp = get_parent().get_node_or_null("HealthComponent")
					if health_comp == null: health_comp = get_parent().get_node_or_null("health_component")
					if health_comp != null:
						# Sécurité : la vie doit être strictement supérieure au coût pour ne pas se tuer
						can_afford = health_comp.current_health > ability.mana_cost
						
				if not can_afford:
					print(ability.ability_name, " : Pas assez de ressource (Mana/Vie) !")
					continue

				var base_cast_time = ability.cast_time if "cast_time" in ability else 0.0
				var final_speed_multiplier = 1.0
				
				# CALCUL DYNAMIQUE DE LA VITESSE
				if ability.category == AbilityData.AbilityCategory.WEAPON_ATTACK:
					var equipment = get_parent().find_child("EquipmentComponent", true, false)
					if equipment != null and equipment.equipped_items.has("main_hand"):
						var weapon = equipment.equipped_items["main_hand"]
						if weapon.base_attack_speed > 0:
							base_cast_time = 1.0 / weapon.base_attack_speed
						else:
							base_cast_time = 1.0
					
					if player_stats != null:
						var p_speed = player_stats.get_stat_value("attack_speed")
						if p_speed != 0.0:
							final_speed_multiplier = p_speed
					
					var w_speed_mult = ability.weapon_speed_multiplier if "weapon_speed_multiplier" in ability else 1.0
					final_speed_multiplier *= w_speed_mult
					
				else:
					if player_stats != null:
						var p_speed = player_stats.get_stat_value("casting_speed")
						if p_speed != 0.0:
							final_speed_multiplier = p_speed
				
				final_speed_multiplier = max(final_speed_multiplier, 0.1) 
				var final_required_time = base_cast_time / final_speed_multiplier
				
				if final_required_time <= 0.0:
					_play_ability_anim_safe(ability, 1.0)
					_try_cast_ability(ability)
				else:
					if ability.category == AbilityData.AbilityCategory.WEAPON_ATTACK:
						current_state = State.AUTO_CASTING
					else:
						current_state = State.SELECTED
					
					casting_ability = ability
					casting_action = action
					current_cast_time = 0.0
					required_cast_time = final_required_time
					
					if current_state == State.AUTO_CASTING:
						if anim_player != null and ability.anim_name != "":
							if anim_player.has_animation(ability.anim_name):
								var anim_length = anim_player.get_animation(ability.anim_name).length
								var play_speed = anim_length / required_cast_time
								
								if _play_ability_anim_safe(ability, play_speed):
									var recovery_anim = ability.anim_name + "_recovery"
									if anim_player.has_animation(recovery_anim):
										anim_player.queue(recovery_anim)
						cast_started.emit(ability.ability_name, required_cast_time)
					
					if ability.target_mode in [AbilityData.TargetMode.GROUND_TARGET, AbilityData.TargetMode.SUMMON]:
						if raycast != null:
							raycast.target_position = Vector3(0, 0, -ability.max_range)
							raycast.force_raycast_update() 
						
						if indicator_instance != null:
							indicator_instance.queue_free()
							indicator_instance = null
							
						if ability.indicator_scene != null:
							indicator_instance = ability.indicator_scene.instantiate()
							get_tree().root.add_child(indicator_instance)
				
			return

func _handle_selected() -> void:
	if indicator_instance != null and raycast != null:
		if raycast.is_colliding():
			indicator_instance.visible = true
			indicator_instance.global_position = raycast.get_collision_point()
		else:
			indicator_instance.visible = false

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		print("Sélection de sort annulée !")
		_reset_casting(true) 
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		current_state = State.CASTING
		current_cast_time = 0.0
		
		var play_speed: float = 1.0
		if anim_player != null and casting_ability.anim_name != "":
			if anim_player.has_animation(casting_ability.anim_name):
				var anim_length = anim_player.get_animation(casting_ability.anim_name).length
				play_speed = anim_length / required_cast_time
				
				if _play_ability_anim_safe(casting_ability, play_speed):
					var recovery_anim = casting_ability.anim_name + "_recovery"
					if anim_player.has_animation(recovery_anim):
						anim_player.queue(recovery_anim)
						
		# --- Gestion du VFX de Lancement ---
		if "cast_vfx_scene" in casting_ability and casting_ability.cast_vfx_scene != null:
			current_vfx_instance = casting_ability.cast_vfx_scene.instantiate()
			if cast_vfx_spawn_point != null:
				cast_vfx_spawn_point.add_child(current_vfx_instance)
			else:
				get_parent().add_child(current_vfx_instance)
			
			var vfx_anim = current_vfx_instance.get_node_or_null("VFX_anim")
			if vfx_anim != null:
				var vfx_anim_name = vfx_anim.autoplay
				if vfx_anim_name == "" and vfx_anim.has_animation("default"):
					vfx_anim_name = "default"
					vfx_anim.play("default")
				elif vfx_anim_name == "":
					for anim in vfx_anim.get_animation_list():
						if anim != "RESET":
							vfx_anim_name = anim
							vfx_anim.play(anim)
							break
				
				if vfx_anim_name != "":
					var vfx_length = vfx_anim.get_animation(vfx_anim_name).length
					vfx_anim.speed_scale = vfx_length / required_cast_time
				else:
					vfx_anim.speed_scale = play_speed
						
		cast_started.emit(casting_ability.ability_name, required_cast_time)
		var vfx_path = ""
		if "cast_vfx_scene" in casting_ability and casting_ability.cast_vfx_scene != null:
			vfx_path = casting_ability.cast_vfx_scene.resource_path
		rpc("_rpc_play_casting_vfx", casting_ability.anim_name, vfx_path, play_speed)

func _handle_casting(delta: float) -> void:
	if indicator_instance != null and raycast != null:
		if raycast.is_colliding():
			indicator_instance.visible = true
			indicator_instance.global_position = raycast.get_collision_point()
		else:
			indicator_instance.visible = false

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		cast_canceled.emit()
		_reset_casting(true) # TRUE = On coupe l'animation d'urgence
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		current_cast_time += delta
		current_cast_time = min(current_cast_time, required_cast_time)
		cast_updated.emit(current_cast_time, required_cast_time)
	else:
		if current_cast_time >= required_cast_time:
			_validate_and_fire()
		else:
			print("Cast annulé (relâché trop tôt) !")
			cast_canceled.emit()
			
			current_state = State.SELECTED
			current_cast_time = 0.0
			
			if current_vfx_instance != null:
				_kill_vfx(current_vfx_instance)
				current_vfx_instance = null
			
			if anim_player != null:
				if anim_player.has_animation("RESET"):
					anim_player.play("RESET")
				else:
					anim_player.stop()
			if anim_tree != null: anim_tree.active = true

func _handle_auto_casting(delta: float) -> void:
	if indicator_instance != null and raycast != null:
		if raycast.is_colliding():
			indicator_instance.visible = true
			indicator_instance.global_position = raycast.get_collision_point()
		else:
			indicator_instance.visible = false

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		print("Attaque annulée (clic droit) !")
		cast_canceled.emit()
		_reset_casting(true) # Coupe net l'animation
		return

	current_cast_time += delta
	current_cast_time = min(current_cast_time, required_cast_time)
	cast_updated.emit(current_cast_time, required_cast_time)

	# Dès qu'on atteint la fin du temps (donc la fin de la 1ère animation), ça tire !
	if current_cast_time >= required_cast_time:
		_validate_and_fire()

func _validate_and_fire() -> void:
	var requires_ground = casting_ability.target_mode in [AbilityData.TargetMode.GROUND_TARGET, AbilityData.TargetMode.SUMMON]
	var is_aiming_valid = raycast != null and raycast.is_colliding()
	
	if requires_ground and not is_aiming_valid:
		print("Lancement annulé (Visée invalide) !")
		cast_canceled.emit()
	else:
		print("Cast terminé avec succès !")
		cast_finished.emit() 
		
		var target_data = {}
		if is_aiming_valid:
			target_data["impact_point"] = raycast.get_collision_point()
			target_data["collider"] = raycast.get_collider()
		
		_execute_ability(casting_ability, target_data)
		
	# FALSE = On ne coupe pas l'AnimationPlayer, pour laisser jouer l'animation de Recovery en paix !
	_reset_casting(false) 

func _reset_casting(is_canceled: bool = false) -> void:
	var rec_anim = ""
	if not is_canceled and casting_ability != null and casting_ability.anim_name != "":
		rec_anim = casting_ability.anim_name + "_recovery"
	rpc("_rpc_stop_casting_vfx", rec_anim)

	current_state = State.IDLE
	casting_ability = null
	casting_action = ""
	current_cast_time = 0.0
	required_cast_time = 0.0
	
	if indicator_instance != null:
		indicator_instance.queue_free()
		indicator_instance = null
		
	if current_vfx_instance != null:
		_kill_vfx(current_vfx_instance)
		current_vfx_instance = null
		
	# Si le joueur a annulé (clic droit ou autre), on répare l'état des animations
	if is_canceled:
		if anim_player != null:
			# Au lieu de "stop()" (qui fige la hitbox active), on joue RESET pour tout ranger proprement !
			if anim_player.has_animation("RESET"):
				anim_player.play("RESET")
			else:
				anim_player.stop()
		if anim_tree != null: anim_tree.active = true

# ==========================================
# FONCTION DE SÉCURITÉ POUR LES ANIMATIONS
# ==========================================
func _play_ability_anim_safe(ability: AbilityData, speed: float = 1.0) -> bool:
	if anim_player == null or ability.anim_name == "" or not anim_player.has_animation(ability.anim_name):
		return false
		
	# Si une attaque est déjà en cours, on ne la coupe PAS pour jouer l'animation d'un sort !
	# L'attaque va continuer de se jouer normalement.
	if anim_player.is_playing() and anim_player.current_animation.begins_with("attack"):
		if not ability.anim_name.begins_with("attack"):
			print("Attaque en cours ! On ne joue pas l'animation du sort pour laisser l'attaque se terminer.")
			return false
			
	if anim_tree != null: 
		anim_tree.active = false
	
	anim_player.play(ability.anim_name)
	anim_player.speed_scale = speed
	return true

# ==========================================
# (Les fonctions qui ont sauté au copier-coller !)
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
			if active_ability != null:
				_play_ability_anim_safe(active_ability, 1.0)
				
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

	# Consommation de la ressource
	if current_casting_resource == CastingResource.MANA:
		var mana_comp = get_parent().get_node_or_null("ManaComponent")
		if mana_comp == null: mana_comp = get_parent().get_node_or_null("mana_component")
		if mana_comp != null:
			mana_comp.use_mana(ability.mana_cost)
	elif current_casting_resource == CastingResource.HEALTH:
		var health_comp = get_parent().get_node_or_null("HealthComponent")
		if health_comp == null: health_comp = get_parent().get_node_or_null("health_component")
		if health_comp != null:
			health_comp.pay_health_cost(ability.mana_cost)
			health_spent_for_spell.emit(ability.mana_cost)

	if ability.ability_scene != null:
		var spell_instance = ability.ability_scene.instantiate()
		get_tree().root.add_child(spell_instance)
		
		target_data["ability_data"] = ability 
		
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

func _kill_vfx(vfx: Node3D) -> void:
	if vfx == null:
		return
	
	var vfx_anim = vfx.get_node_or_null("VFX_anim")
	if vfx_anim != null and vfx_anim.has_animation("casted"):
		vfx_anim.speed_scale = 1.0
		vfx_anim.play("casted")
		if not vfx_anim.is_connected("animation_finished", Callable(vfx, "queue_free")):
			vfx_anim.animation_finished.connect(func(_anim_name): vfx.queue_free())
	else:
		vfx.queue_free()

# ==========================================
# GESTION RESEAU DES ANIMATIONS DE CAST
# ==========================================
@rpc("any_peer", "call_remote", "unreliable")
func _rpc_play_casting_vfx(anim_name: String, vfx_scene_path: String, play_speed: float) -> void:
	if anim_player != null and anim_name != "":
		if anim_player.has_animation(anim_name):
			anim_player.play(anim_name, -1, play_speed)
	
	if vfx_scene_path != "":
		var vfx_scene = load(vfx_scene_path)
		if vfx_scene != null:
			current_vfx_instance = vfx_scene.instantiate()
			
			# L'cho visuel ne doit surtout pas infliger de dgts
			var attack_comp = current_vfx_instance.get_node_or_null("AttackComponent")
			if attack_comp != null:
				attack_comp.is_active_for_network = false
				
			if cast_vfx_spawn_point != null:
				cast_vfx_spawn_point.add_child(current_vfx_instance)
			else:
				get_parent().add_child(current_vfx_instance)
				
			var vfx_anim = current_vfx_instance.get_node_or_null("VFX_anim")
			if vfx_anim != null:
				var vfx_anim_name = vfx_anim.autoplay
				if vfx_anim_name == "" and vfx_anim.has_animation("default"):
					vfx_anim_name = "default"
					vfx_anim.play("default")
				if vfx_anim_name != "":
					var vfx_length = vfx_anim.get_animation(vfx_anim_name).length
					vfx_anim.speed_scale = vfx_length / (1.0 / play_speed) # Approximation

@rpc("any_peer", "call_remote", "unreliable")
func _rpc_stop_casting_vfx(recovery_anim: String) -> void:
	if current_vfx_instance != null:
		_kill_vfx(current_vfx_instance)
		current_vfx_instance = null
		
	if anim_player != null:
		if recovery_anim != "" and anim_player.has_animation(recovery_anim):
			anim_player.play(recovery_anim)
		else:
			if anim_player.has_animation("RESET"):
				anim_player.play("RESET")
			else:
				anim_player.stop()
