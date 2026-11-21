extends Node3D

## Effet corporel de givre visible sur les joueurs distants (ou entités tierces) ralentis par la nova :
## - S'adapte au centre du corps et intensifie ses flocons selon le nombre de stacks de slow

@onready var chill_mist: GPUParticles3D = get_node_or_null("ChillMist") as GPUParticles3D
@onready var snow_flakes: GPUParticles3D = get_node_or_null("SnowFlakes") as GPUParticles3D

func _ready() -> void:
	call_deferred("_align_to_host")

func _align_to_host() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var status_comp := get_parent()
	if status_comp == null:
		return
	var host := status_comp.get_parent() as Node3D
	if host == null:
		return
	var cs := host.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs != null:
		if cs.position.y < 0.05:
			position = cs.position
		else:
			position = Vector3(cs.position.x, clampf(cs.position.y, 0.35, 1.45), cs.position.z)

func set_slow_stacks(stacks: int, max_stacks: int, _pulse_flash: bool = false) -> void:
	var ratio := clampf(float(stacks) / float(maxi(1, max_stacks)), 0.0, 1.0)
	if chill_mist != null:
		chill_mist.amount_ratio = lerpf(0.35, 1.0, ratio)
	if snow_flakes != null:
		snow_flakes.amount_ratio = lerpf(0.30, 1.0, ratio)
