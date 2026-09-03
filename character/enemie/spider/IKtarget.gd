extends Marker3D

@export var step_target: Node3D
@export var step_distance: float = 3.0
@export var step_height: float = 1.0 # J'ai rajout a pour que tu puisses contrler la hauteur du lever de patte !

@export var adjacent_target: Node3D

var is_stepping := false

func _process(delta):
	if !is_stepping && !adjacent_target.is_stepping && abs(global_position.distance_to(step_target.global_position)) > step_distance:
		step()

func step():
	var target_pos = step_target.global_position
	var half_way = (global_position + step_target.global_position) / 2
	is_stepping = true
	
	var t = get_tree().create_tween()
	# J'ai ajout "* step_height" ici parce que sinon, a levait la patte de 1 mtre complet (peu importe la taille de l'araigne)
	t.tween_property(self, "global_position", half_way + owner.basis.y * step_height, 0.1)
	t.tween_property(self, "global_position", target_pos, 0.1)
	t.tween_callback(func(): is_stepping = false)
