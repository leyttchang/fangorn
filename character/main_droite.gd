extends Marker3D

@onready var player_stats: StatsComponent = owner.get_node("StatsComponent")
@onready var equipment: EquipmentComponent = owner.get_node("EquipmentComponent")
@onready var skill_bar: SkillBarComponent = owner.get_node("SkillBarComponent")

@onready var anim_tree: AnimationTree = $"../AnimationTree" 
@onready var anim_playback: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/StateMachine/playback")
@onready var anim_player: AnimationPlayer = %attack_animation 

## Liste des sons de frappe d'arme (un son sera tiré au hasard par play_sound())
@export var attack_sounds: Array[AudioStream] = []
@export_range(-80.0, 24.0, 0.5) var attack_sound_volume_db: float = 0.0

var current_weapon: Node3D = null
var is_attacking: bool = false
var combo_step: int = 1

# Fenêtre de tolérance pour le buffer de combo (en millisecondes)
var last_click_time: int = 0
const COMBO_BUFFER_MS: int = 350

## Méthode appelée depuis les pistes d'animation de l'AnimationPlayer
func play_sound() -> void:
	if attack_sounds.is_empty():
		return
	var sound_to_play = attack_sounds.pick_random()
	if sound_to_play != null:
		SoundManager.play_hit_sound(self, global_position, sound_to_play, attack_sound_volume_db)

func play_attack_sound() -> void:
	play_sound()

func _ready():
	if equipment != null:
		equipment.equipment_changed.connect(_on_equipment_changed)
	call_deferred("update_idle_stance")

func _on_equipment_changed(slot_name: String, _item: ItemData) -> void:
	if slot_name == "main_hand":
		if not is_attacking:
			update_idle_stance()

func _input(event):
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE: return
	if skill_bar != null and skill_bar.current_state != SkillBarComponent.State.IDLE: return
	# Les autres inputs spécifiques (si présents) peuvent rester ici

func _process(delta: float) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE: return
	if skill_bar != null and skill_bar.current_state != SkillBarComponent.State.IDLE: return
	
	# 1. Mémoriser les clics rapides (spam) pendant une attaque
	if Input.is_action_just_pressed("r_click"):
		if is_attacking:
			last_click_time = Time.get_ticks_msec()
			
	# 2. Maintenir le bouton ou démarrer une nouvelle attaque
	if Input.is_action_pressed("r_click"):
		_validate_attack_state()
		if not is_attacking:
			start_attack()

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
	last_click_time = 0
	combo_step = 1 
	disable_current_hitbox()
	if anim_tree != null:
		anim_tree.set("parameters/TimeScale/scale", 1.0)
		if not anim_tree.active:
			anim_tree.active = true

func update_idle_stance():
	var equipped_item = equipment.equipped_items.get("main_hand") as WeaponItem
	if equipped_item == null: 
		# Optionnel: on pourrait revenir à un idle sans arme si on n'a plus d'arme
		return
	var style_string = WeaponItem.WeaponStyle.keys()[equipped_item.weapon_style].to_lower()
	var idle_anim = "idle_" + style_string
	anim_playback.travel(idle_anim)

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
	last_click_time = 0
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
	last_click_time = 0
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
	# On vérifie si le dernier clic a eu lieu dans la fenêtre de tolérance (ex: moins de 350ms)
	# OU si le joueur est tout simplement en train de maintenir le bouton enfoncé !
	var time_since_click = Time.get_ticks_msec() - last_click_time
	var clicked_recently = (time_since_click <= COMBO_BUFFER_MS) and (last_click_time > 0)
	
	if clicked_recently or Input.is_action_pressed("r_click"):
		var equipped_item = equipment.equipped_items["main_hand"] as WeaponItem
		if equipped_item == null: return
		var style_string = WeaponItem.WeaponStyle.keys()[equipped_item.weapon_style].to_lower()
		var next_anim = "attack_" + style_string + "_" + str(combo_step + 1)
		
		if anim_player.has_animation(next_anim):
			last_click_time = 0
			combo_step += 1
			if is_instance_valid(current_weapon):
				current_weapon.attack_component.reset_hit_entities()
				current_weapon.update_damage_from_stats(player_stats, combo_step)
			anim_tree.set("parameters/TimeScale/scale", get_current_attack_speed()) # On maintient la vitesse pour le coup 2
			anim_playback.travel(next_anim)
		else:
			last_click_time = 0
			anim_tree.set("parameters/TimeScale/scale", 1.0) # Fin du combo, on remet le retour d'arme à vitesse normale
	else:
		last_click_time = 0
		anim_tree.set("parameters/TimeScale/scale", 1.0) # Pas de combo, le retour d'arme se fait à vitesse normale

func end_combat_state():
	reset_attack_state()
	
	var equipped_item = equipment.equipped_items["main_hand"] as WeaponItem
	if equipped_item != null:
		var style_string = WeaponItem.WeaponStyle.keys()[equipped_item.weapon_style].to_lower()
		var idle_anim = "idle_" + style_string
		anim_playback.start(idle_anim)
