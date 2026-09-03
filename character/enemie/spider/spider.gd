extends Node3D

@export_category("Procedural Animation")
@export var step_distance: float = 1.0  # Distance max avant que la patte dcide de bouger
@export var step_height: float = 0.8    # Hauteur de la patte pendant le pas
@export var step_speed: float = 0.2     # Dure du pas (plus c'est bas, plus elle est vive)

var legs: Array[Dictionary] = []

var last_global_pos: Vector3
var current_velocity: Vector3

func _ready() -> void:
	# 1. Dmarrer tous les moteurs d'IK
	for ik in find_children("*", "SkeletonIK3D"):
		ik.start()
		
	# L'ORDRE DANS LEQUEL ON DECLARE LES PATTES EST VITAL !
	# C'est ce qui dtermine qui bouge en premier (Alternating Tetrapod Gait).
	# Le Groupe A (R1, L2, R3, L4) s'value en premier et bloque le Groupe B (R2, L1, R4, L3).
	
	# --- GROUPE A (Prioritaires) ---
	legs.append(_create_leg_dict("R_1", ["R_2"]))
	legs.append(_create_leg_dict("L_2", ["L_1"]))
	legs.append(_create_leg_dict("R_3", ["R_4"]))
	legs.append(_create_leg_dict("L_4", ["L_3"]))
	
	# --- GROUPE B (Attendent leur tour) ---
	legs.append(_create_leg_dict("R_2", ["R_1"]))
	legs.append(_create_leg_dict("L_1", ["L_2"]))
	legs.append(_create_leg_dict("R_4", ["R_3"]))
	legs.append(_create_leg_dict("L_3", ["L_4"]))
	
	# 3. Au lancement, on colle immdiatement les 8 pattes au sol sous les raycasts
	for leg in legs:
		var raycast = leg.raycast as RayCast3D
		raycast.force_raycast_update()
		if raycast.is_colliding():
			leg.target.global_position = raycast.get_collision_point()
		else:
			leg.target.global_position = raycast.global_position + raycast.target_position

func _create_leg_dict(leg_name: String, opposites: Array[String]) -> Dictionary:
	return {
		"name": leg_name,
		"raycast": get_node("RayCast_" + leg_name),
		"target": get_node("target_container/" + leg_name + "_target"),
		"opposites": opposites,
		"is_stepping": false,
		"last_dest_pos": Vector3.ZERO
	}

# Petite fonction pour rcuprer une patte par son nom
func _get_leg(leg_name: String) -> Dictionary:
	for leg in legs:
		if leg.name == leg_name:
			return leg
	return {}

func _physics_process(delta: float) -> void:
	#  chaque frame, on vrifie chaque patte individuellement !
	for leg in legs:
		_process_single_leg(leg, delta)

func _process_single_leg(leg: Dictionary, delta: float) -> void:
	# 1. Si elle est dj en l'air, on ne fait rien
	if leg.is_stepping: 
		# On doit quand mme mettre  jour sa dernire position connue pour pas que sa vlocit explose la frame d'aprs !
		var raycast = leg.raycast as RayCast3D
		if raycast.is_colliding():
			leg.last_dest_pos = raycast.get_collision_point()
		else:
			leg.last_dest_pos = raycast.global_position + raycast.target_position
		return
	
	# 2. Si une de ses voisines est en l'air, on annule (pour ne pas tomber)
	for opp_name in leg.opposites:
		var opp_leg = _get_leg(opp_name)
		if opp_leg.has("is_stepping") and opp_leg.is_stepping:
			# Mise a jour position avant de return
			var raycast_opp = leg.raycast as RayCast3D
			if raycast_opp.is_colliding():
				leg.last_dest_pos = raycast_opp.get_collision_point()
			else:
				leg.last_dest_pos = raycast_opp.global_position + raycast_opp.target_position
			return

	# 3. Vrification de la distance
	var raycast = leg.raycast as RayCast3D
	var target = leg.target as Node3D
	
	var dest_pos = raycast.global_position
	if raycast.is_colliding():
		dest_pos = raycast.get_collision_point()
	else:
		dest_pos = raycast.global_position + raycast.target_position
		
	# --- LE SECRET DE LA ROTATION ---
	# On calcule la vitesse de CE RAYCAST prcis.
	# Comme a, mme si l'araigne tourne sur place, le raycast se dplace trs vite en arc de cercle,
	# et on peut prdire son mouvement (Overshoot) !
	var leg_velocity = Vector3.ZERO
	if delta > 0 and leg.last_dest_pos != Vector3.ZERO:
		leg_velocity = (dest_pos - leg.last_dest_pos) / delta
	leg.last_dest_pos = dest_pos
		
	# Overshoot Prediction
	var overshoot = leg_velocity * (step_speed * 1.5)
	var final_dest = dest_pos + overshoot
		
	# Si la patte est trop tendue, ELLE SEULE dclenche un pas !
	if target.global_position.distance_to(final_dest) > step_distance:
		_step_leg(leg, final_dest)

func _step_leg(leg: Dictionary, dest_pos: Vector3) -> void:
	leg.is_stepping = true
	var target = leg.target as Node3D
	
	var mid_pos = (target.global_position + dest_pos) / 2.0
	mid_pos.y += step_height
	
	var tween = get_tree().create_tween()
	
	# Phase 1 : Lever
	tween.tween_property(target, "global_position", mid_pos, step_speed / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Phase 2 : Poser
	tween.tween_property(target, "global_position", dest_pos, step_speed / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# Dverrouiller quand c'est fini
	tween.tween_callback(func():
		leg.is_stepping = false
	)
