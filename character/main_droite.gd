extends Marker3D

@onready var player_stats: StatsComponent = owner.get_node("StatsComponent")
@onready var equipment: EquipmentComponent = owner.get_node("EquipmentComponent")
@onready var skill_bar: SkillBarComponent = owner.get_node("SkillBarComponent")

@onready var anim_tree: AnimationTree = $"../AnimationTree" 
@onready var anim_playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/StateMachine/playback")
@onready var anim_player: AnimationPlayer = %attack_animation 

var current_weapon: Node3D = null
var is_attacking: bool = false
var wants_to_combo: bool = false
var combo_step: int = 1

func _ready():
	call_deferred("update_idle_stance")

func _input(event):
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE: return
	if skill_bar != null and skill_bar.current_state != SkillBarComponent.State.IDLE: return
		
	if event.is_action_pressed("r_click"):
		_validate_attack_state()
		if not is_attacking:
			start_attack()
		else:
			wants_to_combo = true

func _validate_attack_state():
	if not is_attacking: return
	
	# 1. Si l'AnimationTree a été désactivé par un dash ou un sort
	if not anim_tree.active:
		reset_attack_state()
		return
		
	# 2. Si la StateMachine n'est plus sur une animation d'attaque (ex: retour automatique en idle)
	var current_node = String(anim_playback.get_current_node())
	if not current_node.begins_with("attack_") and not current_node.begins_with("heavy_slam_"):
		reset_attack_state()

func reset_attack_state():
	is_attacking = false
	wants_to_combo = false
	combo_step = 1 
	disable_current_hitbox()
	if anim_tree != null:
		anim_tree.set("parameters/TimeScale/scale", 1.0)
		if not anim_tree.active:
			anim_tree.active = true

func update_idle_stance():
	var equipped_item = equipment.equipped_items["main_hand"] as WeaponItem
	if equipped_item == null: return
	var style_string = WeaponItem.WeaponStyle.keys()[equipped_item.weapon_style].to_lower()
	var idle_anim = "idle_" + style_string
	anim_playback.start(idle_anim)

# --- NOUVEAU : Calcul des stats de vitesse pour les attaques de base ---
func get_current_attack_speed() -> float:
	var final_speed = 1.0
	var equipped_item = equipment.equipped_items["main_hand"] as WeaponItem
	if equipped_item != null and equipped_item.base_attack_speed > 0:
		final_speed = equipped_item.base_attack_speed
		
	if player_stats != null:
		var p_speed = player_stats.get_stat_value("attack_speed")
		if p_speed != 0.0:
			final_speed *= p_speed
			
	return max(final_speed, 0.1)

func start_attack():
	if get_child_count() == 0: return
	current_weapon = get_child(0)
	var attack_shape = current_weapon.get_node_or_null("AttackComponent/CollisionShape3D")
	if attack_shape == null: return
		
	is_attacking = true
	wants_to_combo = false
	combo_step = 1
	
	current_weapon.attack_component.reset_hit_entities() 
	current_weapon.update_damage_from_stats(player_stats, combo_step)
	
	var equipped_item = equipment.equipped_items["main_hand"] as WeaponItem
	if equipped_item == null: return
	var style_string = WeaponItem.WeaponStyle.keys()[equipped_item.weapon_style].to_lower()
	var anim_name = "attack_" + style_string + "_1"
	
	# On applique le multiplicateur de vitesse via l'AnimationTree !
	anim_tree.set("parameters/TimeScale/scale", get_current_attack_speed())
	anim_playback.travel(anim_name)

# Fonction appelée par le SkillBarComponent
func start_heavy_attack():
	if get_child_count() == 0: return
	current_weapon = get_child(0)
	var attack_shape = current_weapon.get_node_or_null("AttackComponent/CollisionShape3D")
	if attack_shape == null: return
		
	is_attacking = true
	wants_to_combo = false 
	combo_step = 1
	current_weapon.attack_component.reset_hit_entities() 
	current_weapon.update_damage_from_stats(player_stats, combo_step)
	
	var equipped_item = equipment.equipped_items["main_hand"] as WeaponItem
	if equipped_item == null: return
	var style_string = WeaponItem.WeaponStyle.keys()[equipped_item.weapon_style].to_lower()
	var anim_name = "heavy_slam_" + style_string
	
	anim_tree.set("parameters/TimeScale/scale", get_current_attack_speed())
	anim_playback.travel(anim_name)

func enable_current_hitbox():
	if is_instance_valid(current_weapon):
		var shape = current_weapon.get_node_or_null("AttackComponent/CollisionShape3D")
		if is_instance_valid(shape): shape.set_deferred("disabled", false)

func disable_current_hitbox():
	if is_instance_valid(current_weapon):
		var shape = current_weapon.get_node_or_null("AttackComponent/CollisionShape3D")
		current_weapon.attack_component.reset_hit_entities() 
		if is_instance_valid(shape): shape.set_deferred("disabled", true)

func check_combo():
	if wants_to_combo:
		var equipped_item = equipment.equipped_items["main_hand"] as WeaponItem
		if equipped_item == null: return
		var style_string = WeaponItem.WeaponStyle.keys()[equipped_item.weapon_style].to_lower()
		var next_anim = "attack_" + style_string + "_" + str(combo_step + 1)
		
		if anim_player.has_animation(next_anim):
			wants_to_combo = false
			combo_step += 1
			if is_instance_valid(current_weapon):
				current_weapon.attack_component.reset_hit_entities()
				current_weapon.update_damage_from_stats(player_stats, combo_step)
			anim_tree.set("parameters/TimeScale/scale", get_current_attack_speed()) # On maintient la vitesse pour le coup 2
			anim_playback.travel(next_anim)
		else:
			wants_to_combo = false
			anim_tree.set("parameters/TimeScale/scale", 1.0) # Fin du combo, on remet le retour d'arme à vitesse normale
	else:
		wants_to_combo = false
		anim_tree.set("parameters/TimeScale/scale", 1.0) # Pas de combo, le retour d'arme se fait à vitesse normale

func end_combat_state():
	reset_attack_state()
	
	var equipped_item = equipment.equipped_items["main_hand"] as WeaponItem
	if equipped_item != null:
		var style_string = WeaponItem.WeaponStyle.keys()[equipped_item.weapon_style].to_lower()
		var idle_anim = "idle_" + style_string
		anim_playback.start(idle_anim)
