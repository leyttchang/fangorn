extends Node3D

var caster: Node3D = null

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sphere3_local_basis = $Sphere3.transform.basis
@onready var sphere3_local_pos = $Sphere3.position

@export var attached_nodes: Array[Node3D] = []
var initial_offsets: Dictionary = {}

func _ready() -> void:
	# On sauvegarde la position de depart des objets qui doivent rester attaches
	for node in attached_nodes:
		if node != null:
			initial_offsets[node] = node.transform

func start_complex_cast(player: Node3D) -> void:
	caster = player
	# On cache le sort par defaut, il ne sera visible qu'au moment du coup d'epee !
	$Sphere3.visible = false
	global_transform.basis = player.global_transform.basis

func _process(delta: float) -> void:
	# Seuls les objets dans l'array "attached_nodes" vont suivre le joueur
	if is_instance_valid(caster) and attached_nodes.size() > 0:
		var target_transform = caster.global_transform
		var cam = caster.get_node_or_null("Camera3D")
		if cam != null:
			target_transform = cam.global_transform
			
		for node in attached_nodes:
			if node != null and initial_offsets.has(node):
				# On applique le mouvement tout en gardant l'offset local de l'editeur
				node.global_transform = target_transform * initial_offsets[node]

func on_mid_cast_event(event_name: String) -> void:
	if event_name == "stab":
		if is_instance_valid(caster):
			var target_basis = caster.global_transform.basis
			var cam = caster.get_node_or_null("Camera3D")
			
			if cam != null:
				target_basis = cam.global_transform.basis
				$Sphere3.global_position = cam.global_position + (target_basis * sphere3_local_pos)
			else:
				$Sphere3.global_position = caster.global_position + (target_basis * sphere3_local_pos)
			
			$Sphere3.global_transform.basis = target_basis * sphere3_local_basis
		
		if anim_player != null:
			anim_player.stop()
			anim_player.play("stab") 
			print("Flaming Stab : Animation 'stab' declenchee !")
			$Sphere3.visible = true
			
			# On calcule les degats (la hitbox sera activee par l'AnimationPlayer)
			var scaling_comp = $SpellScalingComponent
			if scaling_comp != null:
				scaling_comp.on_execute(caster, {})



func execute(player: Node3D, target_data: Dictionary) -> void:
	print("Flaming Stab : Fin du cast !")
	# On attend la fin de l'animation (ex: 3 secondes suffisent) avant de detruire le sort
	await get_tree().create_timer(3.0).timeout
	queue_free()
