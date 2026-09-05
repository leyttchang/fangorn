extends Node3D

var mon_lanceur: Node3D = null

@export var weapon_material: Material
@export var buff_data: StatusEffectData
@export var buff_duration: float = 5.0

func execute(caster: Node3D, target_data: Dictionary) -> void:
	mon_lanceur = caster
	global_position = caster.global_position
	
	if buff_data != null and caster.is_multiplayer_authority():
		var status_comp = caster.get_node_or_null("status_effect_componant")
		if status_comp != null:
			status_comp.apply_effect(buff_data, buff_duration)
	
	_set_weapon_material(weapon_material)
	
	var anim_player = get_node_or_null("AnimationPlayer")
	if anim_player:
		anim_player.play("buff_duration")
	else:
		await get_tree().create_timer(buff_duration).timeout
		queue_free()

func _exit_tree() -> void:
	_set_weapon_material(null)

func _set_weapon_material(mat: Material) -> void:
	if mon_lanceur == null: return
	
	var main_droite = mon_lanceur.get_node_or_null("Camera3D/MainDroite")
	if main_droite:
		var meshes = main_droite.find_children("*", "MeshInstance3D", true, false)
		for mesh in meshes:
			mesh.material_overlay = mat
