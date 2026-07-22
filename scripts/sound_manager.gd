class_name SoundManager
extends Node

static var hit_stream: AudioStreamWAV = null
static var footstep_stream: AudioStreamWAV = null

static func _init_sounds() -> void:
	if hit_stream == null:
		hit_stream = _generate_hit_sound()
	if footstep_stream == null:
		footstep_stream = _generate_footstep_sound()

static func play_hit_sound(node: Node, pos: Vector3, custom_stream: AudioStream = null, volume_db: float = 0.0, pitch_min: float = 0.88, pitch_max: float = 1.12, max_distance: float = 40.0) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree(): return
	_init_sounds()
	
	var final_stream = custom_stream if custom_stream != null else hit_stream
	if final_stream is AudioStreamWAV:
		final_stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif final_stream is AudioStreamOggVorbis:
		final_stream.loop = false

	var player = AudioStreamPlayer3D.new()
	player.stream = final_stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.max_distance = max_distance
	player.unit_size = 5.0
	player.panning_strength = 1.0
	
	var scene = node.get_tree().current_scene
	if scene != null:
		scene.add_child(player)
		player.global_position = pos
		player.play()
		player.finished.connect(func(): if is_instance_valid(player): player.queue_free())

static func play_footstep_sound(node: Node, pos: Vector3, custom_stream: AudioStream = null, volume_db: float = -16.0, pitch_min: float = 0.85, pitch_max: float = 1.15, max_distance: float = 15.0) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree(): return
	_init_sounds()
	
	var final_stream = custom_stream if custom_stream != null else footstep_stream
	if final_stream is AudioStreamWAV:
		final_stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif final_stream is AudioStreamOggVorbis:
		final_stream.loop = false

	var player = AudioStreamPlayer3D.new()
	player.stream = final_stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.max_distance = max_distance
	player.unit_size = 3.0
	player.panning_strength = 1.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	
	var scene = node.get_tree().current_scene
	if scene != null:
		scene.add_child(player)
		player.global_position = pos
		player.play()
		player.finished.connect(func(): if is_instance_valid(player): player.queue_free())

static func _generate_hit_sound() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	var sample_count = int(44100 * 0.10) # 100ms
	var data = PackedByteArray()
	data.resize(sample_count * 2) # 16 bits = 2 octets par échantillon
	
	var last_noise = 0.0
	for i in range(sample_count):
		var t = float(i) / 44100.0
		
		# Enveloppe d'impact percutante
		var envelope = exp(-t * 32.0) * sin(clamp(t * 700.0, 0.0, PI * 0.5))
		
		# Pitch-drop d'impact sourd (160 Hz -> 50 Hz)
		var freq = 160.0 * exp(-t * 28.0)
		var body = sin(t * freq * TAU) * 0.7
		
		# Filtre passe-bas (supprime le grésillement / bruit blanc aigu)
		var raw_noise = randf_range(-0.25, 0.25)
		last_noise = lerp(last_noise, raw_noise, 0.15)
		
		var signal_val = (body + last_noise * 0.2) * envelope
		var int_val = int(clamp(signal_val * 14000.0, -32768, 32767))
		
		data[i * 2] = int_val & 0xFF
		data[i * 2 + 1] = (int_val >> 8) & 0xFF
		
	stream.data = data
	return stream

static func _generate_footstep_sound() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	var sample_count = int(44100 * 0.08) # 80ms
	var data = PackedByteArray()
	data.resize(sample_count * 2) # 16 bits = 2 octets par échantillon
	
	var last_noise = 0.0
	for i in range(sample_count):
		var t = float(i) / 44100.0
		
		# Enveloppe d'impact douce
		var envelope = exp(-t * 45.0) * sin(clamp(t * 600.0, 0.0, PI * 0.5))
		
		# Bruit de terre/herbe avec filtre passe-bas doux
		var raw_noise = randf_range(-0.3, 0.3)
		last_noise = lerp(last_noise, raw_noise, 0.20)
		
		# Impact sourd en basse fréquence
		var thud = sin(t * 50.0 * TAU) * exp(-t * 35.0) * 0.4
		
		var signal_val = (thud + last_noise * 0.25) * envelope
		var int_val = int(clamp(signal_val * 12000.0, -32768, 32767))
		
		data[i * 2] = int_val & 0xFF
		data[i * 2 + 1] = (int_val >> 8) & 0xFF
		
	stream.data = data
	return stream
