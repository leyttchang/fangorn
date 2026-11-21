extends Node3D

## Centre et adapte automatiquement les particules d'arcane sur le torse du monstre
## (quel que soit son pivot : pieds pour Dumb/TreeMan, centre pour Scout, bas pour Spider/Creep)

func _ready() -> void:
	call_deferred("_align_to_host_body")

func _align_to_host_body() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var status_comp: Node = get_parent()
	if status_comp == null:
		return
	var host: Node3D = status_comp.get_parent() as Node3D
	if host == null:
		return

	var cs: CollisionShape3D = host.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var target_local_pos: Vector3 = Vector3(0.0, 0.95, 0.0)
	var scale_factor: float = 1.0

	if cs != null:
		if cs.position.y < 0.05:
			# Entité dont l'origine est déjà au centre du corps (ex: Scout / Player)
			target_local_pos = cs.position
		else:
			target_local_pos = Vector3(cs.position.x, clampf(cs.position.y, 0.32, 1.55), cs.position.z)

		if cs.shape is CapsuleShape3D:
			scale_factor = clampf((cs.shape as CapsuleShape3D).radius / 0.42, 0.75, 1.75)
		elif cs.shape is CylinderShape3D:
			scale_factor = clampf((cs.shape as CylinderShape3D).radius / 0.45, 0.75, 1.65)
		elif cs.shape is SphereShape3D:
			scale_factor = clampf((cs.shape as SphereShape3D).radius / 0.45, 0.75, 1.65)
		elif cs.shape is BoxShape3D:
			var bsize: Vector3 = (cs.shape as BoxShape3D).size
			scale_factor = clampf(maxf(bsize.x, bsize.z) * 0.5 / 0.45, 0.75, 1.65)

	position = target_local_pos
	scale = Vector3.ONE * scale_factor
