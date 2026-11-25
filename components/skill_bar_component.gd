class_name SkillBarComponent
extends Node

enum State { IDLE, TARGETING, SELECTED, CASTING, CHANNELING, AUTO_CASTING, RECOVERY }
var current_state: State = State.IDLE
var can_cast_spells: bool = true

enum CastingResource { MANA, HEALTH }
var current_casting_resource: CastingResource = CastingResource.MANA

# --- SIGNAUX ---
signal spells_updated
signal health_spent_for_spell(amount: float)
signal cast_started(ability_name: String, max_time: float)
signal cast_updated(current_time: float, max_time: float)
signal channel_started(ability_name: String, max_duration: float)
signal channel_updated(elapsed: float, max_duration: float, resource_ratio: float)
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
@export var anim_tree: AnimationTree
@export var cast_vfx_spawn_point: Node3D

var cooldown_timers: Dictionary = {}
var current_charges: Dictionary = {}
var charge_recharge_timers: Dictionary = {}
var active_ability: AbilityData = null
var indicator_instance: Node3D = null
var current_vfx_instance: Node3D = null
var current_complex_spell_instance: Node3D = null
var current_channel_instance: Node3D = null

var casting_ability: AbilityData = null
var casting_action: String = ""
var current_cast_time: float = 0.0
var required_cast_time: float = 0.0
var current_channel_elapsed: float = 0.0
var _channel_net_sync_accum: float = 0.0

static var _scene_cache: Dictionary = {}

@onready var player_stats: Node = get_parent().find_child("StatsComponent", true, false)
@onready var equipment_component: Node = get_parent().find_child("EquipmentComponent", true, false)
var _mana_comp: Node = null
var _health_comp: Node = null
var _spellbook_ui: Node = null


static func _get_cached_resource(res_path: String) -> Resource:
	if res_path.is_empty():
		return null
	var cached: Resource = _scene_cache.get(res_path) as Resource
	if cached != null:
		return cached
	if ResourceLoader.exists(res_path):
		cached = load(res_path)
		if cached != null:
			_scene_cache[res_path] = cached
	return cached


func _get_equipment_component() -> Node:
	if equipment_component == null and get_parent() != null:
		equipment_component = get_parent().find_child("EquipmentComponent", true, false)
	return equipment_component


func _get_mana_comp() -> Node:
	if _mana_comp == null and get_parent() != null:
		_mana_comp = get_parent().get_node_or_null("ManaComponent")
		if _mana_comp == null:
			_mana_comp = get_parent().get_node_or_null("mana_component")
	return _mana_comp


func _get_health_comp() -> Node:
	if _health_comp == null and get_parent() != null:
		_health_comp = get_parent().get_node_or_null("HealthComponent")
		if _health_comp == null:
			_health_comp = get_parent().get_node_or_null("health_component")
	return _health_comp


func _get_spellbook_ui() -> Node:
	if _spellbook_ui == null and get_parent() != null:
		_spellbook_ui = get_parent().get_node_or_null("SpellBook_UI")
		if _spellbook_ui == null:
			_spellbook_ui = get_parent().find_child("SpellBook_UI", true, false)
	return _spellbook_ui


func get_spell_level_for(ability: AbilityData) -> int:
	if ability == null:
		return 1
	var sb: Node = _get_spellbook_ui()
	if sb != null and sb.has_method("get_spell_level"):
		return maxi(1, int(sb.call("get_spell_level", ability)))
	return 1


func get_charges_for(ability: AbilityData) -> int:
	if ability == null:
		return 0
	if ability.max_charges <= 1:
		return 0 if cooldown_timers.has(ability.ability_name) else 1
	if not current_charges.has(ability.ability_name):
		current_charges[ability.ability_name] = ability.max_charges
	return clampi(int(current_charges[ability.ability_name]), 0, ability.max_charges)


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
			pass
		State.TARGETING:
			_handle_targeting()
		State.SELECTED:
			_handle_selected()
		State.CASTING:
			_handle_casting(delta)
		State.CHANNELING:
			_handle_channeling(delta)
		State.AUTO_CASTING:
			_handle_auto_casting(delta)


func get_effective_attack_speed_factor(include_weapon_aps: bool = true, weapon_aps_weight: float = 0.45) -> float:
	var factor: float = 1.0
	if player_stats != null and player_stats.has_method("get_stat_value"):
		var p_speed: float = float(player_stats.call("get_stat_value", "attack_speed"))
		if p_speed > 0.0:
			factor *= p_speed
	if include_weapon_aps:
		var equipment: Node = _get_equipment_component()
		if equipment != null and "equipped_items" in equipment:
			var eq_dict: Dictionary = equipment.get("equipped_items") as Dictionary
			if eq_dict.has("main_hand"):
				var weapon: Variant = eq_dict["main_hand"]
				if weapon is Object and "base_attack_speed" in weapon:
					var base_aps: float = float(weapon.get("base_attack_speed"))
					if base_aps > 0.0:
						factor *= lerpf(1.0, base_aps / 1.2, clampf(weapon_aps_weight, 0.0, 1.0))
	return maxf(factor, 0.15)


func _has_resource_for_cost(cost: float) -> bool:
	if cost <= 0.0:
		return true
	if current_casting_resource == CastingResource.MANA:
		var mana_comp: Node = _get_mana_comp()
		if mana_comp != null and mana_comp.has_method("has_enough_mana"):
			return bool(mana_comp.call("has_enough_mana", cost))
		return false
	elif current_casting_resource == CastingResource.HEALTH:
		var health_comp: HealthComponent = _get_health_comp() as HealthComponent
		if health_comp != null:
			return health_comp.current_health > cost
		return false
	return false


func _consume_resource_cost(cost: float) -> void:
	if cost <= 0.0:
		return
	if current_casting_resource == CastingResource.MANA:
		var mana_comp: Node = _get_mana_comp()
		if mana_comp != null and mana_comp.has_method("use_mana"):
			mana_comp.call("use_mana", cost)
	elif current_casting_resource == CastingResource.HEALTH:
		var health_comp: HealthComponent = _get_health_comp() as HealthComponent
		if health_comp != null:
			health_comp.pay_health_cost(cost)
			health_spent_for_spell.emit(cost)


func _get_current_resource_ratio() -> float:
	if current_casting_resource == CastingResource.MANA:
		var mana_comp: Node = _get_mana_comp()
		if mana_comp != null and "current_mana" in mana_comp and player_stats != null and player_stats.has_method("get_stat_value"):
			var max_m: float = maxf(1.0, float(player_stats.call("get_stat_value", "max_mana")))
			return clampf(float(mana_comp.get("current_mana")) / max_m, 0.0, 1.0)
	elif current_casting_resource == CastingResource.HEALTH:
		var health_comp: HealthComponent = _get_health_comp() as HealthComponent
		if health_comp != null:
			var max_h: float = maxf(1.0, health_comp.get_max_health())
			return clampf(health_comp.current_health / max_h, 0.0, 1.0)
	return 1.0


func _unhandled_input(event: InputEvent) -> void:
	if not get_parent().is_multiplayer_authority():
		return
	if get_parent().get("external_motion_override") == true or get_parent().get("is_in_transformation") == true:
		return
	if current_state != State.IDLE and current_state != State.SELECTED:
		return

	for action: String in slots.keys():
		if event.is_action_pressed(action):
			# Ré-appuyer sur le même slot déjà sélectionné désélectionne proprement
			if current_state == State.SELECTED and casting_action == action:
				_reset_casting(true)
				return

			var ability: AbilityData = slots[action]
			if ability != null:
				if not can_cast_spells and ability.category == AbilityData.AbilityCategory.MAGIC:
					continue

				if ability.max_charges > 1:
					if get_charges_for(ability) <= 0:
						continue
				elif cooldown_timers.has(ability.ability_name):
					continue

				# Vérification de la ressource (pour un sort CHANNEL, on vérifie le coût initial + un minimum de maintien)
				var min_needed: float = ability.mana_cost
				if ability.target_mode == AbilityData.TargetMode.CHANNEL:
					min_needed += ability.channel_mana_per_sec * 0.15

				if not _has_resource_for_cost(min_needed):
					continue

				# Si on change de sort alors qu'un autre était sélectionné, on nettoie l'ancien indicateur
				if current_state == State.SELECTED:
					_reset_casting(true)

				# --- CAS 1 : SORT CANALISÉ (TargetMode.CHANNEL) -> Sélection puis Maintien Clic Gauche ---
				if ability.target_mode == AbilityData.TargetMode.CHANNEL:
					current_state = State.SELECTED
					casting_ability = ability
					casting_action = action
					current_cast_time = 0.0
					required_cast_time = 0.0
					if raycast != null:
						raycast.target_position = Vector3(0.0, 0.0, -ability.max_range)
						raycast.force_raycast_update()
					if ability.indicator_scene != null:
						indicator_instance = ability.indicator_scene.instantiate() as Node3D
						if indicator_instance != null:
							get_tree().root.add_child(indicator_instance)
					return

				var base_cast_time: float = ability.cast_time
				var final_speed_multiplier: float = 1.0

				# CALCUL DYNAMIQUE DE LA VITESSE
				if ability.category == AbilityData.AbilityCategory.WEAPON_ATTACK:
					var fixed_cast: bool = (ability.use_fixed_cast_time and base_cast_time > 0.0)
					if fixed_cast:
						final_speed_multiplier = get_effective_attack_speed_factor(true, 0.45)
					else:
						var equipment: Node = _get_equipment_component()
						if equipment != null and "equipped_items" in equipment:
							var eq_dict: Dictionary = equipment.get("equipped_items") as Dictionary
							if eq_dict.has("main_hand"):
								var weapon: Variant = eq_dict["main_hand"]
								if weapon is Object and "base_attack_speed" in weapon and float(weapon.get("base_attack_speed")) > 0.0:
									base_cast_time = 1.0 / float(weapon.get("base_attack_speed"))
								else:
									base_cast_time = 1.0

						if player_stats != null and player_stats.has_method("get_stat_value"):
							var p_speed: float = float(player_stats.call("get_stat_value", "attack_speed"))
							if p_speed != 0.0:
								final_speed_multiplier = p_speed

					final_speed_multiplier *= ability.weapon_speed_multiplier
				else:
					if player_stats != null and player_stats.has_method("get_stat_value"):
						var p_cast_speed: float = float(player_stats.call("get_stat_value", "casting_speed"))
						if p_cast_speed != 0.0:
							final_speed_multiplier = p_cast_speed

				final_speed_multiplier = maxf(final_speed_multiplier, 0.1)
				var final_required_time: float = base_cast_time / final_speed_multiplier

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

					if ability.target_mode == AbilityData.TargetMode.COMPLEX_ATTACK:
						if ability.ability_scene != null:
							var spell_instance: Node3D = ability.ability_scene.instantiate() as Node3D
							if spell_instance != null:
								var auth: int = get_parent().get_multiplayer_authority()
								for child: Node in spell_instance.find_children("AttackComponent*", "Area3D", true, false):
									child.set_meta("caster_authority", auth)

								get_tree().root.add_child(spell_instance)
								current_complex_spell_instance = spell_instance
								spell_instance.global_position = (get_parent() as Node3D).global_position

								if spell_instance.has_method("start_complex_cast"):
									spell_instance.call("start_complex_cast", get_parent())

					if current_state == State.AUTO_CASTING:
						if anim_player != null and ability.anim_name != "":
							if anim_player.has_animation(ability.anim_name):
								var anim_length: float = anim_player.get_animation(ability.anim_name).length
								var play_speed: float = anim_length / required_cast_time

								if _play_ability_anim_safe(ability, play_speed):
									var recovery_anim: String = ability.anim_name + "_recovery"
									if anim_player.has_animation(recovery_anim):
										anim_player.queue(recovery_anim)
						cast_started.emit(ability.ability_name, required_cast_time)

					if ability.target_mode in [AbilityData.TargetMode.GROUND_TARGET, AbilityData.TargetMode.SUMMON]:
						if raycast != null:
							raycast.target_position = Vector3(0.0, 0.0, -ability.max_range)
							raycast.force_raycast_update()

						if indicator_instance != null:
							indicator_instance.queue_free()
							indicator_instance = null

						if ability.indicator_scene != null:
							indicator_instance = ability.indicator_scene.instantiate() as Node3D
							if indicator_instance != null:
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
		_reset_casting(true)
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if casting_ability == null:
			_reset_casting(true)
			return

		if casting_ability.target_mode == AbilityData.TargetMode.CHANNEL:
			_start_channeling()
			return

		current_state = State.CASTING
		current_cast_time = 0.0

		var play_speed: float = 1.0
		if anim_player != null and casting_ability.anim_name != "":
			if anim_player.has_animation(casting_ability.anim_name):
				var anim_length: float = anim_player.get_animation(casting_ability.anim_name).length
				play_speed = anim_length / maxf(required_cast_time, 0.01)

				if _play_ability_anim_safe(casting_ability, play_speed):
					var recovery_anim: String = casting_ability.anim_name + "_recovery"
					if anim_player.has_animation(recovery_anim):
						anim_player.queue(recovery_anim)

		if casting_ability.cast_vfx_scene != null:
			current_vfx_instance = casting_ability.cast_vfx_scene.instantiate() as Node3D
			if current_vfx_instance != null:
				if cast_vfx_spawn_point != null:
					cast_vfx_spawn_point.add_child(current_vfx_instance)
				else:
					get_parent().add_child(current_vfx_instance)

				var vfx_anim: AnimationPlayer = current_vfx_instance.get_node_or_null("VFX_anim") as AnimationPlayer
				if vfx_anim != null:
					var vfx_anim_name: String = vfx_anim.autoplay
					if vfx_anim_name == "" and vfx_anim.has_animation("default"):
						vfx_anim_name = "default"
						vfx_anim.play("default")
					elif vfx_anim_name == "":
						for anim: StringName in vfx_anim.get_animation_list():
							if anim != &"RESET":
								vfx_anim_name = String(anim)
								vfx_anim.play(anim)
								break

					if vfx_anim_name != "":
						var vfx_length: float = vfx_anim.get_animation(vfx_anim_name).length
						vfx_anim.speed_scale = vfx_length / maxf(required_cast_time, 0.01)
					else:
						vfx_anim.speed_scale = play_speed

		cast_started.emit(casting_ability.ability_name, required_cast_time)
		var vfx_path: String = ""
		if casting_ability.cast_vfx_scene != null:
			vfx_path = casting_ability.cast_vfx_scene.resource_path
		if multiplayer.has_multiplayer_peer():
			rpc("_rpc_play_casting_vfx", casting_ability.anim_name, vfx_path, play_speed)


func _build_channel_aim_data(ability: AbilityData) -> Dictionary:
	var caster_3d: Node3D = get_parent() as Node3D
	var cam: Camera3D = caster_3d.get_node_or_null("Camera3D") as Camera3D if caster_3d != null else null
	var origin: Vector3 = cam.global_position if cam != null else (caster_3d.global_position + Vector3(0.0, 1.4, 0.0) if caster_3d != null else Vector3.ZERO)
	var forward: Vector3 = -cam.global_transform.basis.z.normalized() if cam != null else (-caster_3d.global_transform.basis.z.normalized() if caster_3d != null else Vector3.FORWARD)
	var hand_pos: Vector3 = cast_vfx_spawn_point.global_position if cast_vfx_spawn_point != null else origin

	var has_hit: bool = false
	var hit_point: Vector3 = origin + forward * ability.max_range
	var hit_collider: Object = null

	if raycast != null:
		raycast.target_position = Vector3(0.0, 0.0, -ability.max_range)
		raycast.force_raycast_update()
		if raycast.is_colliding():
			has_hit = true
			hit_point = raycast.get_collision_point()
			hit_collider = raycast.get_collider()

	var cast_spd: float = 1.0
	if player_stats != null and player_stats.has_method("get_stat_value"):
		var cs_val: float = float(player_stats.call("get_stat_value", "casting_speed"))
		if cs_val > 0.0:
			cast_spd = cs_val

	return {
		"ability_data": ability,
		"spell_level": get_spell_level_for(ability),
		"casting_speed": maxf(0.15, cast_spd),
		"aim_origin": origin,
		"aim_dir": forward,
		"aim_point": hit_point,
		"hand_pos": hand_pos,
		"has_hit": has_hit,
		"collider": hit_collider
	}


func _start_channeling() -> void:
	if casting_ability == null:
		_reset_casting(true)
		return

	var min_needed: float = casting_ability.mana_cost + casting_ability.channel_mana_per_sec * 0.1
	if not _has_resource_for_cost(min_needed):
		_reset_casting(true)
		return

	_consume_resource_cost(casting_ability.mana_cost)

	current_state = State.CHANNELING
	current_channel_elapsed = 0.0
	_channel_net_sync_accum = 0.0

	if casting_ability.cast_vfx_scene != null:
		current_vfx_instance = casting_ability.cast_vfx_scene.instantiate() as Node3D
		if current_vfx_instance != null:
			if cast_vfx_spawn_point != null:
				cast_vfx_spawn_point.add_child(current_vfx_instance)
			else:
				get_parent().add_child(current_vfx_instance)
			var vfx_anim: AnimationPlayer = current_vfx_instance.get_node_or_null("VFX_anim") as AnimationPlayer
			if vfx_anim != null and vfx_anim.has_animation("default"):
				vfx_anim.play("default")

	var vfx_path: String = casting_ability.cast_vfx_scene.resource_path if casting_ability.cast_vfx_scene != null else ""
	if multiplayer.has_multiplayer_peer():
		rpc("_rpc_play_casting_vfx", casting_ability.anim_name, vfx_path, 1.0)

	var aim_data: Dictionary = _build_channel_aim_data(casting_ability)

	if casting_ability.ability_scene != null:
		var inst: Node3D = casting_ability.ability_scene.instantiate() as Node3D
		if inst != null:
			var caster_auth: int = get_parent().get_multiplayer_authority()
			var direct_ac: Node = inst.get_node_or_null("AttackComponent")
			if direct_ac != null:
				direct_ac.set_meta("caster_authority", caster_auth)
			for child: Node in inst.find_children("AttackComponent*", "Area3D", true, false):
				child.set_meta("caster_authority", caster_auth)

			get_tree().root.add_child(inst)
			current_channel_instance = inst

			if inst.has_method("start_channel"):
				inst.call("start_channel", get_parent(), aim_data)
			elif inst.has_method("execute"):
				inst.call("execute", get_parent(), aim_data)

			if multiplayer.has_multiplayer_peer():
				var aim_pt: Vector3 = aim_data.get("aim_point", Vector3.ZERO) as Vector3
				var aim_d: Vector3 = aim_data.get("aim_dir", Vector3.FORWARD) as Vector3
				rpc(
					"_rpc_start_channel_visual",
					casting_ability.ability_scene.resource_path,
					caster_auth,
					aim_pt,
					aim_d,
					casting_ability.resource_path,
					int(aim_data.get("spell_level", 1))
				)

	channel_started.emit(casting_ability.ability_name, casting_ability.channel_max_duration)


func _handle_channeling(delta: float) -> void:
	if casting_ability == null:
		_stop_channeling()
		return

	if get_parent().get("is_dead") == true or get_parent().get("external_motion_override") == true:
		_stop_channeling()
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_stop_channeling()
		return

	current_channel_elapsed += delta
	if casting_ability.channel_max_duration > 0.0 and current_channel_elapsed >= casting_ability.channel_max_duration:
		_stop_channeling()
		return

	var drain: float = casting_ability.channel_mana_per_sec * delta
	if drain > 0.0:
		if not _has_resource_for_cost(drain):
			_stop_channeling()
			return
		_consume_resource_cost(drain)

	var aim_data: Dictionary = _build_channel_aim_data(casting_ability)
	if indicator_instance != null:
		var has_hit: bool = bool(aim_data.get("has_hit", false))
		indicator_instance.visible = has_hit
		if has_hit:
			indicator_instance.global_position = aim_data.get("aim_point", Vector3.ZERO) as Vector3

	if current_channel_instance != null and is_instance_valid(current_channel_instance):
		if current_channel_instance.has_method("update_channel"):
			current_channel_instance.call("update_channel", get_parent(), delta, aim_data)

	if multiplayer.has_multiplayer_peer():
		_channel_net_sync_accum += delta
		if _channel_net_sync_accum >= 0.045:
			_channel_net_sync_accum = 0.0
			var aim_pt: Vector3 = aim_data.get("aim_point", Vector3.ZERO) as Vector3
			var aim_d: Vector3 = aim_data.get("aim_dir", Vector3.FORWARD) as Vector3
			rpc("_rpc_update_channel_visual", aim_pt, aim_d)

	channel_updated.emit(current_channel_elapsed, casting_ability.channel_max_duration, _get_current_resource_ratio())


func _stop_channeling() -> void:
	var finished_ability: AbilityData = casting_ability

	if current_channel_instance != null and is_instance_valid(current_channel_instance):
		if current_channel_instance.has_method("stop_channel"):
			current_channel_instance.call("stop_channel")
		else:
			current_channel_instance.queue_free()
	current_channel_instance = null

	if multiplayer.has_multiplayer_peer():
		rpc("_rpc_stop_channel_visual")
		rpc("_rpc_stop_casting_vfx", "")

	if indicator_instance != null:
		indicator_instance.queue_free()
		indicator_instance = null

	if current_vfx_instance != null:
		_kill_vfx(current_vfx_instance)
		current_vfx_instance = null

	casting_ability = null
	casting_action = ""
	current_cast_time = 0.0
	required_cast_time = 0.0
	current_channel_elapsed = 0.0
	current_state = State.IDLE

	if finished_ability != null:
		_start_cooldown(finished_ability)

	cast_finished.emit()


func _handle_casting(delta: float) -> void:
	if indicator_instance != null and raycast != null:
		if raycast.is_colliding():
			indicator_instance.visible = true
			indicator_instance.global_position = raycast.get_collision_point()
		else:
			indicator_instance.visible = false

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		cast_canceled.emit()
		_reset_casting(true)
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		current_cast_time += delta
		current_cast_time = minf(current_cast_time, required_cast_time)
		cast_updated.emit(current_cast_time, required_cast_time)
	else:
		if current_cast_time >= required_cast_time:
			_validate_and_fire()
		else:
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
			if anim_tree != null:
				anim_tree.active = true


func _handle_auto_casting(delta: float) -> void:
	if indicator_instance != null and raycast != null:
		if raycast.is_colliding():
			indicator_instance.visible = true
			indicator_instance.global_position = raycast.get_collision_point()
		else:
			indicator_instance.visible = false

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		cast_canceled.emit()
		_reset_casting(true)
		return

	current_cast_time += delta
	current_cast_time = minf(current_cast_time, required_cast_time)
	cast_updated.emit(current_cast_time, required_cast_time)

	if current_cast_time >= required_cast_time:
		_validate_and_fire()


func _validate_and_fire() -> void:
	var requires_ground: bool = casting_ability.target_mode in [AbilityData.TargetMode.GROUND_TARGET, AbilityData.TargetMode.SUMMON]
	var is_aiming_valid: bool = raycast != null and raycast.is_colliding()

	if requires_ground and not is_aiming_valid:
		cast_canceled.emit()
	else:
		cast_finished.emit()

		var target_data: Dictionary = {}
		if is_aiming_valid:
			target_data["impact_point"] = raycast.get_collision_point()
			target_data["collider"] = raycast.get_collider()

		_execute_ability(casting_ability, target_data)

	_reset_casting(false)


func _reset_casting(is_canceled: bool = false) -> void:
	var rec_anim: String = ""
	var has_recovery: bool = false
	var recovery_time: float = 0.0

	if not is_canceled and casting_ability != null and casting_ability.anim_name != "":
		rec_anim = casting_ability.anim_name + "_recovery"
		if anim_player != null and anim_player.has_animation(rec_anim):
			has_recovery = true
			recovery_time = anim_player.get_animation(rec_anim).length / maxf(anim_player.speed_scale, 0.01)

	if multiplayer.has_multiplayer_peer():
		rpc("_rpc_stop_casting_vfx", rec_anim)

	if has_recovery:
		current_state = State.RECOVERY
	else:
		current_state = State.IDLE

	casting_ability = null
	current_complex_spell_instance = null
	casting_action = ""
	current_cast_time = 0.0
	required_cast_time = 0.0

	if indicator_instance != null:
		indicator_instance.queue_free()
		indicator_instance = null

	if current_vfx_instance != null:
		_kill_vfx(current_vfx_instance)
		current_vfx_instance = null

	if is_canceled:
		if anim_player != null:
			if anim_player.has_animation("RESET"):
				anim_player.play("RESET")
			else:
				anim_player.stop()
		if anim_tree != null:
			anim_tree.active = true

	if has_recovery:
		await get_tree().create_timer(recovery_time).timeout
		if current_state == State.RECOVERY:
			current_state = State.IDLE
			if anim_tree != null:
				anim_tree.active = true


func _play_ability_anim_safe(ability: AbilityData, speed: float = 1.0) -> bool:
	if anim_player == null or ability.anim_name == "" or not anim_player.has_animation(ability.anim_name):
		return false

	if anim_player.is_playing() and anim_player.current_animation.begins_with("attack"):
		if not ability.anim_name.begins_with("attack"):
			return false

	if anim_tree != null:
		anim_tree.active = false

	anim_player.play(ability.anim_name)
	anim_player.speed_scale = speed
	return true


func trigger_mid_cast_event(event_name: String) -> void:
	if multiplayer.has_multiplayer_peer() and not get_parent().is_multiplayer_authority():
		return
	if current_complex_spell_instance != null and current_complex_spell_instance.has_method("on_mid_cast_event"):
		current_complex_spell_instance.call("on_mid_cast_event", event_name)

		if is_multiplayer_authority() and casting_ability != null and casting_ability.ability_scene != null and multiplayer.has_multiplayer_peer():
			rpc("_rpc_trigger_mid_cast_event", event_name, casting_ability.ability_scene.resource_path)


func _try_cast_ability(ability: AbilityData) -> void:
	match ability.target_mode:
		AbilityData.TargetMode.INSTANT, AbilityData.TargetMode.PROJECTILE, AbilityData.TargetMode.COMPLEX_ATTACK:
			_execute_ability(ability, {})

		AbilityData.TargetMode.GROUND_TARGET, AbilityData.TargetMode.SUMMON:
			current_state = State.TARGETING
			active_ability = ability

			if raycast != null:
				raycast.target_position = Vector3(0.0, 0.0, -ability.max_range)
				raycast.force_raycast_update()

			if ability.indicator_scene != null:
				indicator_instance = ability.indicator_scene.instantiate() as Node3D
				if indicator_instance != null:
					get_tree().root.add_child(indicator_instance)

		AbilityData.TargetMode.HITSCAN:
			if raycast != null:
				raycast.target_position = Vector3(0.0, 0.0, -ability.max_range)
				raycast.force_raycast_update()

			var target_data: Dictionary = {}
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
			var target_data: Dictionary = {
				"impact_point": raycast.get_collision_point()
			}
			if active_ability != null:
				_play_ability_anim_safe(active_ability, 1.0)
				_execute_ability(active_ability, target_data)

		_cleanup_targeting()

	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_cleanup_targeting()


func _cleanup_targeting() -> void:
	current_state = State.IDLE
	active_ability = null
	if indicator_instance != null:
		indicator_instance.queue_free()
		indicator_instance = null


func _execute_ability(ability: AbilityData, target_data: Dictionary) -> void:
	_start_cooldown(ability)
	_consume_resource_cost(ability.mana_cost)

	var spell_lvl: int = get_spell_level_for(ability)
	target_data["ability_data"] = ability
	target_data["spell_level"] = spell_lvl

	if ability.ability_scene != null:
		var spell_instance: Node3D = null

		if ability.target_mode == AbilityData.TargetMode.COMPLEX_ATTACK and current_complex_spell_instance != null:
			spell_instance = current_complex_spell_instance
		else:
			spell_instance = ability.ability_scene.instantiate() as Node3D
			if spell_instance == null:
				return

			var caster_auth: int = get_parent().get_multiplayer_authority()
			var direct_ac: Node = spell_instance.get_node_or_null("AttackComponent")
			if direct_ac != null:
				direct_ac.set_meta("caster_authority", caster_auth)
			for child: Node in spell_instance.find_children("AttackComponent*", "Area3D", true, false):
				child.set_meta("caster_authority", caster_auth)

			get_tree().root.add_child(spell_instance)

		if ability.target_mode in [AbilityData.TargetMode.GROUND_TARGET, AbilityData.TargetMode.SUMMON]:
			if target_data.has("impact_point"):
				spell_instance.global_position = target_data["impact_point"] as Vector3

		if spell_instance.has_method("execute"):
			spell_instance.call("execute", get_parent(), target_data)

		var impact: Vector3 = Vector3.ZERO
		var has_impact: bool = false
		if target_data.has("impact_point"):
			impact = target_data["impact_point"] as Vector3
			has_impact = true

		var target_path: NodePath = ^""
		if target_data.has("collider") and target_data["collider"] != null:
			var col_node: Node = target_data["collider"] as Node
			if col_node != null:
				target_path = col_node.get_path()

		if multiplayer.has_multiplayer_peer():
			rpc(
				"_rpc_spawn_spell_visual",
				ability.ability_scene.resource_path,
				get_parent().get_multiplayer_authority(),
				impact,
				has_impact,
				target_path,
				ability.resource_path,
				spell_lvl
			)


func _start_cooldown(ability: AbilityData) -> void:
	if ability.cooldown <= 0.0:
		return

	var spell_lvl: int = get_spell_level_for(ability)
	var final_cooldown: float = ability.cooldown * ability.get_level_cooldown_multiplier(spell_lvl)

	if player_stats != null and player_stats.has_method("get_stat_value"):
		var cooldown_recovery: float = maxf(float(player_stats.call("get_stat_value", "cd_red")), 0.1)
		final_cooldown /= cooldown_recovery

	if ability.cooldown_attack_speed_scaling > 0.0:
		var atk_spd_factor: float = get_effective_attack_speed_factor(true, 0.45)
		final_cooldown /= pow(maxf(atk_spd_factor, 0.25), ability.cooldown_attack_speed_scaling)
		final_cooldown = maxf(final_cooldown, 0.15)

	if ability.max_charges > 1:
		var cur_c: int = maxi(0, get_charges_for(ability) - 1)
		current_charges[ability.ability_name] = cur_c
		_ensure_charge_recharge_timer(ability, maxf(0.05, final_cooldown))
		return

	var timer: Timer = Timer.new()
	timer.wait_time = maxf(0.05, final_cooldown)
	timer.one_shot = true
	add_child(timer)
	timer.start()

	cooldown_timers[ability.ability_name] = timer

	timer.timeout.connect(func() -> void:
		cooldown_timers.erase(ability.ability_name)
		if is_instance_valid(timer):
			timer.queue_free()
	)


func _ensure_charge_recharge_timer(ability: AbilityData, recharge_wait: float) -> void:
	var ab_name: String = ability.ability_name
	var max_c: int = ability.max_charges
	var rech_timer: Timer = charge_recharge_timers.get(ab_name) as Timer

	if rech_timer == null or not is_instance_valid(rech_timer):
		rech_timer = Timer.new()
		rech_timer.wait_time = recharge_wait
		rech_timer.one_shot = true
		add_child(rech_timer)
		charge_recharge_timers[ab_name] = rech_timer
		rech_timer.timeout.connect(func() -> void:
			var next_c: int = mini(max_c, int(current_charges.get(ab_name, 0)) + 1)
			current_charges[ab_name] = next_c
			cooldown_timers.erase(ab_name)
			if next_c < max_c and is_instance_valid(rech_timer):
				rech_timer.wait_time = recharge_wait
				rech_timer.start()
			else:
				charge_recharge_timers.erase(ab_name)
				if is_instance_valid(rech_timer):
					rech_timer.queue_free()
		)
		rech_timer.start()

	if int(current_charges.get(ab_name, 0)) <= 0:
		cooldown_timers[ab_name] = rech_timer


func _kill_vfx(vfx: Node3D) -> void:
	if vfx == null:
		return

	var vfx_anim: AnimationPlayer = vfx.get_node_or_null("VFX_anim") as AnimationPlayer
	if vfx_anim != null and vfx_anim.has_animation("casted"):
		vfx_anim.speed_scale = 1.0
		vfx_anim.play("casted")
		if not vfx_anim.is_connected("animation_finished", Callable(vfx, "queue_free")):
			vfx_anim.animation_finished.connect(func(_anim_name: StringName) -> void: vfx.queue_free())
	else:
		vfx.queue_free()


# ==========================================
# GESTION RESEAU DES ANIMATIONS DE CAST & CHANNEL
# ==========================================
@rpc("any_peer", "call_remote", "unreliable")
func _rpc_play_casting_vfx(anim_name: String, vfx_scene_path: String, play_speed: float) -> void:
	if anim_player != null and anim_name != "":
		if anim_player.has_animation(anim_name):
			anim_player.play(anim_name, -1.0, play_speed)

	if vfx_scene_path != "":
		var vfx_scene: PackedScene = _get_cached_resource(vfx_scene_path) as PackedScene
		if vfx_scene != null:
			current_vfx_instance = vfx_scene.instantiate() as Node3D
			if current_vfx_instance == null:
				return

			var attack_comp: AttackComponent = current_vfx_instance.get_node_or_null("AttackComponent") as AttackComponent
			if attack_comp != null:
				attack_comp.is_active_for_network = false

			if cast_vfx_spawn_point != null:
				cast_vfx_spawn_point.add_child(current_vfx_instance)
			else:
				get_parent().add_child(current_vfx_instance)

			var vfx_anim: AnimationPlayer = current_vfx_instance.get_node_or_null("VFX_anim") as AnimationPlayer
			if vfx_anim != null:
				var vfx_anim_name: String = vfx_anim.autoplay
				if vfx_anim_name == "" and vfx_anim.has_animation("default"):
					vfx_anim_name = "default"
					vfx_anim.play("default")
				if vfx_anim_name != "":
					var vfx_length: float = vfx_anim.get_animation(vfx_anim_name).length
					vfx_anim.speed_scale = vfx_length / maxf(1.0 / maxf(play_speed, 0.01), 0.01)


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_stop_casting_vfx(_recovery_anim: String) -> void:
	if current_vfx_instance != null:
		_kill_vfx(current_vfx_instance)
		current_vfx_instance = null


@rpc("any_peer", "call_remote", "reliable")
func _rpc_spawn_spell_visual(
	scene_path: String,
	caster_id: int,
	impact_point: Vector3,
	has_impact: bool,
	target_path: NodePath = ^"",
	ability_res_path: String = "",
	spell_level: int = 1
) -> void:
	if scene_path == "":
		return

	var spell_instance: Node3D = null

	if current_complex_spell_instance != null and current_complex_spell_instance.scene_file_path == scene_path:
		spell_instance = current_complex_spell_instance
		current_complex_spell_instance = null
	else:
		var scene: PackedScene = _get_cached_resource(scene_path) as PackedScene
		if scene == null:
			return
		spell_instance = scene.instantiate() as Node3D
		if spell_instance == null:
			return
		var direct_ac_pre: Node = spell_instance.get_node_or_null("AttackComponent")
		if direct_ac_pre != null:
			direct_ac_pre.set_meta("caster_authority", caster_id)
		for child_ac: Node in spell_instance.find_children("AttackComponent*", "Area3D", true, false):
			child_ac.set_meta("caster_authority", caster_id)
		get_tree().root.add_child(spell_instance)

		if has_impact:
			spell_instance.global_position = impact_point

	var target_data: Dictionary = {
		"spell_level": spell_level,
		"is_remote_visual": true
	}
	if ability_res_path != "":
		var loaded_ab: AbilityData = _get_cached_resource(ability_res_path) as AbilityData
		if loaded_ab != null:
			target_data["ability_data"] = loaded_ab
	if has_impact:
		target_data["impact_point"] = impact_point
	if target_path != ^"" and get_node_or_null(target_path) != null:
		target_data["collider"] = get_node(target_path)

	if spell_instance.has_method("execute"):
		spell_instance.call("execute", get_parent(), target_data)

	var direct_ac: AttackComponent = spell_instance.get_node_or_null("AttackComponent") as AttackComponent
	if direct_ac != null:
		direct_ac.is_active_for_network = false
	for child_ac_post: Node in spell_instance.find_children("AttackComponent*", "Area3D", true, false):
		var ac_typed: AttackComponent = child_ac_post as AttackComponent
		if ac_typed != null:
			ac_typed.is_active_for_network = false


@rpc("any_peer", "call_remote", "reliable")
func _rpc_start_channel_visual(
	scene_path: String,
	caster_id: int,
	aim_point: Vector3,
	aim_dir: Vector3,
	ability_res_path: String = "",
	spell_level: int = 1
) -> void:
	if current_channel_instance != null and is_instance_valid(current_channel_instance):
		if current_channel_instance.has_method("stop_channel"):
			current_channel_instance.call("stop_channel")
		else:
			current_channel_instance.queue_free()
		current_channel_instance = null

	var scene: PackedScene = _get_cached_resource(scene_path) as PackedScene
	if scene == null:
		return

	var inst: Node3D = scene.instantiate() as Node3D
	if inst == null:
		return

	var direct_ac_pre: Node = inst.get_node_or_null("AttackComponent")
	if direct_ac_pre != null:
		direct_ac_pre.set_meta("caster_authority", caster_id)
	for child_ac: Node in inst.find_children("AttackComponent*", "Area3D", true, false):
		child_ac.set_meta("caster_authority", caster_id)

	get_tree().root.add_child(inst)
	current_channel_instance = inst

	var direct_ac: AttackComponent = inst.get_node_or_null("AttackComponent") as AttackComponent
	if direct_ac != null:
		direct_ac.is_active_for_network = false
	for child_ac_post: Node in inst.find_children("AttackComponent*", "Area3D", true, false):
		var ac_typed: AttackComponent = child_ac_post as AttackComponent
		if ac_typed != null:
			ac_typed.is_active_for_network = false

	var caster_3d: Node3D = get_parent() as Node3D
	var hand_pos: Vector3 = cast_vfx_spawn_point.global_position if cast_vfx_spawn_point != null else (caster_3d.global_position + Vector3(0.0, 1.3, 0.0) if caster_3d != null else Vector3.ZERO)
	var loaded_ab: AbilityData = _get_cached_resource(ability_res_path) as AbilityData if ability_res_path != "" else null
	var aim_data: Dictionary = {
		"ability_data": loaded_ab,
		"spell_level": spell_level,
		"casting_speed": 1.0,
		"aim_origin": hand_pos,
		"aim_dir": aim_dir,
		"aim_point": aim_point,
		"hand_pos": hand_pos,
		"has_hit": true,
		"is_remote_visual": true
	}

	if inst.has_method("start_channel"):
		inst.call("start_channel", get_parent(), aim_data)


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_update_channel_visual(aim_point: Vector3, aim_dir: Vector3) -> void:
	if current_channel_instance == null or not is_instance_valid(current_channel_instance):
		return
	if current_channel_instance.has_method("update_remote_aim"):
		current_channel_instance.call("update_remote_aim", aim_point, aim_dir)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_stop_channel_visual() -> void:
	if current_channel_instance != null and is_instance_valid(current_channel_instance):
		if current_channel_instance.has_method("stop_channel"):
			current_channel_instance.call("stop_channel")
		else:
			current_channel_instance.queue_free()
	current_channel_instance = null


@rpc("any_peer", "call_remote", "reliable")
func _rpc_trigger_mid_cast_event(event_name: String, scene_path: String) -> void:
	if current_complex_spell_instance == null and scene_path != "":
		var scene: PackedScene = _get_cached_resource(scene_path) as PackedScene
		if scene != null:
			current_complex_spell_instance = scene.instantiate() as Node3D
			if current_complex_spell_instance != null:
				get_tree().root.add_child(current_complex_spell_instance)
				current_complex_spell_instance.global_position = (get_parent() as Node3D).global_position

				var auth: int = get_parent().get_multiplayer_authority()
				for child: Node in current_complex_spell_instance.find_children("AttackComponent*", "Area3D", true, false):
					child.set_meta("caster_authority", auth)
					var ac: AttackComponent = child as AttackComponent
					if ac != null:
						ac.is_active_for_network = false

				if current_complex_spell_instance.has_method("start_complex_cast"):
					current_complex_spell_instance.call("start_complex_cast", get_parent())
		else:
			push_warning("SkillBarComponent: Impossible de charger la scene " + scene_path)

	if current_complex_spell_instance != null and current_complex_spell_instance.has_method("on_mid_cast_event"):
		current_complex_spell_instance.call("on_mid_cast_event", event_name)
