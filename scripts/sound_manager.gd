class_name SoundManager
extends Node

const POOL_SIZE: int = 24
const HIT_THROTTLE_MS: int = 30
const MAX_HIT_SOUNDS_PER_FRAME: int = 4

static var hit_stream: AudioStreamWAV = null
static var footstep_stream: AudioStreamWAV = null
static var _last_hit_sound_time: int = 0
static var _last_stream_play_time: Dictionary = {}
static var _hit_sounds_frame: int = -1
static var _hit_sounds_this_frame: int = 0

static var _pool_host: Node = null
static var _audio_pool: Array[AudioStreamPlayer3D] = []
static var _pool_cursor: int = 0

func _ready() -> void:
	_ensure_pool(get_tree(), self)

static func _init_sounds() -> void:
	if hit_stream == null:
		hit_stream = _generate_hit_sound()
	if footstep_stream == null:
		footstep_stream = _generate_footstep_sound()

static func _ensure_pool(tree: SceneTree, explicit_host: Node = null) -> void:
	if tree == null or tree.root == null:
		return
	if explicit_host != null and is_instance_valid(explicit_host):
		_pool_host = explicit_host
	elif _pool_host == null or not is_instance_valid(_pool_host) or not _pool_host.is_inside_tree():
		var autoload_sm: Node = tree.root.get_node_or_null("SoundManager")
		if autoload_sm != null:
			_pool_host = autoload_sm
		else:
			_pool_host = tree.root.get_node_or_null("SoundManagerAudioPool")
			if _pool_host == null:
				_pool_host = Node.new()
				_pool_host.name = "SoundManagerAudioPool"
				tree.root.add_child(_pool_host)

	if _audio_pool.size() == POOL_SIZE and is_instance_valid(_audio_pool[0]) and _audio_pool[0].is_inside_tree():
		return

	_audio_pool.clear()
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer3D.new()
		p.name = "PooledAudio3D_" + str(i)
		p.attenuation_filter_cutoff_hz = 18500.0
		_pool_host.add_child(p)
		_audio_pool.append(p)
	_pool_cursor = 0

static func _acquire_player(tree: SceneTree) -> AudioStreamPlayer3D:
	_ensure_pool(tree)
	if _audio_pool.is_empty():
		return null

	var count: int = _audio_pool.size()
	for offset in range(count):
		var idx: int = (_pool_cursor + offset) % count
		var candidate: AudioStreamPlayer3D = _audio_pool[idx]
		if is_instance_valid(candidate) and not candidate.playing:
			_pool_cursor = (idx + 1) % count
			return candidate

	var fallback: AudioStreamPlayer3D = _audio_pool[_pool_cursor]
	_pool_cursor = (_pool_cursor + 1) % count
	if is_instance_valid(fallback):
		fallback.stop()
		return fallback
	return null

static func play_hit_sound(node: Node, pos: Vector3, custom_stream: AudioStream = null, volume_db: float = 0.0, pitch_min: float = 0.88, pitch_max: float = 1.12, max_distance: float = 40.0) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree(): return
	
	_init_sounds()
	var final_stream: AudioStream = custom_stream if custom_stream != null else hit_stream
	if final_stream == null:
		return

	var current_time: int = Time.get_ticks_msec()
	var stream_key: int = final_stream.get_instance_id()
	var last_time: int = int(_last_stream_play_time.get(stream_key, -1000))
	if current_time - last_time < HIT_THROTTLE_MS:
		return

	var frame: int = Engine.get_process_frames()
	if frame != _hit_sounds_frame:
		_hit_sounds_frame = frame
		_hit_sounds_this_frame = 0
	if _hit_sounds_this_frame >= MAX_HIT_SOUNDS_PER_FRAME:
		return

	if _last_stream_play_time.size() > 64:
		_last_stream_play_time.clear()
	_last_stream_play_time[stream_key] = current_time
	_last_hit_sound_time = current_time
	_hit_sounds_this_frame += 1

	if final_stream is AudioStreamWAV:
		final_stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif final_stream is AudioStreamOggVorbis:
		final_stream.loop = false

	var player: AudioStreamPlayer3D = _acquire_player(node.get_tree())
	if player != null:
		player.stream = final_stream
		player.volume_db = volume_db
		player.pitch_scale = randf_range(pitch_min, pitch_max)
		player.max_distance = max_distance
		player.unit_size = 9.0
		player.panning_strength = 0.55
		player.attenuation_filter_cutoff_hz = 18500.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.global_position = pos
		player.play()

static func play_footstep_sound(node: Node, pos: Vector3, custom_stream: AudioStream = null, volume_db: float = -16.0, pitch_min: float = 0.85, pitch_max: float = 1.15, max_distance: float = 15.0) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree(): return
	_init_sounds()
	
	var final_stream: AudioStream = custom_stream if custom_stream != null else footstep_stream
	if final_stream == null:
		return
	if final_stream is AudioStreamWAV:
		final_stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif final_stream is AudioStreamOggVorbis:
		final_stream.loop = false

	var player: AudioStreamPlayer3D = _acquire_player(node.get_tree())
	if player != null:
		player.stream = final_stream
		player.volume_db = volume_db
		player.pitch_scale = randf_range(pitch_min, pitch_max)
		player.max_distance = max_distance
		player.unit_size = 4.5
		player.panning_strength = 0.50
		player.attenuation_filter_cutoff_hz = 18500.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.global_position = pos
		player.play()

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
