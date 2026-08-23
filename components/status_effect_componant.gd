class_name StatusEffectComponent
extends Node3D

@export var stats_component: Node # StatsComponent
@export var health_component: Node # HealthComponent

class ActiveEffect:
	var data: StatusEffectData
	var time_remaining: float = 0.0
	var next_tick_time: float = 0.0
	var visual_instance: Node = null

var _active_effects: Dictionary = {}

# --- MULTIJOUEUR : APPLY ---
func apply_effect(data: StatusEffectData, duration: float) -> void:
	if data == null: return
	if data.resource_path.is_empty():
		push_error("StatusEffectData n'a pas de resource_path! (Sauvegarde-le en .tres)")
		return
		
	if is_multiplayer_authority():
		_apply_effect_broadcast.rpc(data.resource_path, duration)
	else:
		_request_apply_effect.rpc_id(1, data.resource_path, duration)

@rpc("any_peer", "call_remote", "reliable")
func _request_apply_effect(effect_path: String, duration: float) -> void:
	if not is_multiplayer_authority(): return
	_apply_effect_broadcast.rpc(effect_path, duration)

@rpc("authority", "call_local", "reliable")
func _apply_effect_broadcast(effect_path: String, duration: float) -> void:
	var data = load(effect_path) as StatusEffectData
	if data != null:
		_internal_apply_effect(data, duration)

func _internal_apply_effect(data: StatusEffectData, duration: float) -> void:
	print("Tentative application status : " + str(data.effect_id))
	if data == null: return
	
	# Si l'effet existe deja, on refresh la duree
	if _active_effects.has(data.effect_id):
		var eff = _active_effects[data.effect_id]
		eff.time_remaining = max(eff.time_remaining, duration)
		# Appel de la fonction custom meme en cas de refresh
		data.on_apply(get_parent(), self, true)
		return
		
	var new_effect = ActiveEffect.new()
	new_effect.data = data
	new_effect.time_remaining = duration
	new_effect.next_tick_time = data.tick_interval
	
	_active_effects[data.effect_id] = new_effect
	
	# --- APPLICATION DES STATS ---
	if stats_component != null and stats_component.has_method("add_modifier"):
		for mod in data.stat_modifiers:
			stats_component.add_modifier(mod.stat_name, mod.mod_type, mod.value, "STATUS_" + data.effect_id)
			
	# --- SPAWN VISUEL ---
	var is_local_player = false
	var p = get_parent()
	if p.is_in_group("Player") and p.is_multiplayer_authority():
		is_local_player = true
		
	var visual_scene = data.player_effect if is_local_player else data.enemie_effect
	
	if visual_scene != null:
		var vfx = visual_scene.instantiate()
		new_effect.visual_instance = vfx
		add_child(vfx)
		
	# --- APPLICATION DU SHADER (Overlay Material) ---
	if data.overlay_material != null and not is_local_player:
		print("Application du shader " + str(data.overlay_material) + " sur " + str(get_parent().name))
		_apply_overlay_material(get_parent(), data.overlay_material)
		
	# Appel de la fonction custom
	data.on_apply(get_parent(), self, false)

# --- MULTIJOUEUR : REMOVE ---
func remove_effect(effect_id: String) -> void:
	if is_multiplayer_authority():
		_remove_effect_broadcast.rpc(effect_id)
	else:
		_request_remove_effect.rpc_id(1, effect_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_remove_effect(effect_id: String) -> void:
	if not is_multiplayer_authority(): return
	_remove_effect_broadcast.rpc(effect_id)

@rpc("authority", "call_local", "reliable")
func _remove_effect_broadcast(effect_id: String) -> void:
	_internal_remove_effect(effect_id)

func _internal_remove_effect(effect_id: String) -> void:
	if not _active_effects.has(effect_id): return
	
	var eff = _active_effects[effect_id]
	eff.data.on_remove(get_parent(), self)
	
	# Retrait des stats
	if stats_component != null and stats_component.has_method("remove_modifier_by_source"):
		stats_component.remove_modifier_by_source("STATUS_" + effect_id)
		
	# Destruction visuel
	if is_instance_valid(eff.visual_instance):
		eff.visual_instance.queue_free()
		
	# Retrait du shader
	if eff.data.overlay_material != null:
		var is_local = false
		var p = get_parent()
		if p.is_in_group("Player") and p.is_multiplayer_authority():
			is_local = true
		if not is_local:
			_remove_overlay_material(get_parent(), eff.data.overlay_material)
		
	_active_effects.erase(effect_id)

func has_effect(effect_id: String) -> bool:
	return _active_effects.has(effect_id)

func _process(delta: float) -> void:
	var keys = _active_effects.keys()
	for key in keys:
		if not _active_effects.has(key): continue
		var eff = _active_effects[key]
		
		# Ticks de degats (DoT)
		if eff.data.tick_damage > 0.0 and eff.data.tick_interval > 0.0:
			eff.next_tick_time -= delta
			if eff.next_tick_time <= 0.0:
				eff.next_tick_time = eff.data.tick_interval
				if is_multiplayer_authority(): # ONLY HOST INFLIGE DEGATS
					if health_component != null and health_component.has_method("take_damage"):
						health_component.take_damage(eff.data.tick_damage)
		
		# Duree
		eff.time_remaining -= delta
		if eff.time_remaining <= 0.0:
			if is_multiplayer_authority(): # ONLY HOST DECIDE DE LA FIN
				remove_effect(key)

# --- FONCTIONS POUR SHADERS ---
func _apply_overlay_material(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_overlay = mat
	for child in node.get_children():
		_apply_overlay_material(child, mat)

func _remove_overlay_material(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		if node.material_overlay == mat:
			node.material_overlay = null
	for child in node.get_children():
		_remove_overlay_material(child, mat)
