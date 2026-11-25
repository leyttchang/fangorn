extends RayCast3D

var current_target: InteractionComponent = null
var player: CharacterBody3D = null

func _ready() -> void:
	# --- SECURITE : Forcer le raycast a detecter les Area3D ---
	collide_with_areas = true
	# Si tu ne detectes toujours rien, de-commente la ligne suivante pour forcer le masque 6 (valeur 32)
	# collision_mask |= 32 
	
	# Trouver le joueur parent
	var p = get_parent()
	while p != null:
		if p is CharacterBody3D:
			player = p
			break
		p = p.get_parent()

func _process(delta: float) -> void:
	if player != null and not player.is_multiplayer_authority():
		return
		
	var collider = get_collider()
	
	# DEBUG: Pour t'aider a voir ce que le raycast touche reelement
	# if collider != null:
	# 	print("[LOOT CAST] Je touche : ", collider.name)
	
	if collider is InteractionComponent:
		if collider != current_target:
			if current_target != null:
				current_target.hide_prompt()
			current_target = collider
			current_target.show_prompt()
			
		# --- GESTION DU MAINTIEN (ReviveComponent) ---
		if current_target.get_parent() is ReviveComponent:
			var hold_act: StringName = current_target.interaction_action if not current_target.interaction_action.is_empty() else &"interact"
			if Input.is_action_pressed(hold_act):
				(current_target.get_parent() as ReviveComponent).process_revive(delta, player)
	else:
		if current_target != null:
			current_target.hide_prompt()
			current_target = null

func _unhandled_input(event: InputEvent) -> void:
	if player != null and not player.is_multiplayer_authority():
		return
		
	if current_target != null:
		var press_act: StringName = current_target.interaction_action if not current_target.interaction_action.is_empty() else &"interact"
		if event.is_action_pressed(press_act) and not event.is_echo():
			current_target.trigger_interaction(player)
			get_viewport().set_input_as_handled()
