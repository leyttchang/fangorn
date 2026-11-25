class_name SpellAudioManager
extends RefCounted

## Gestionnaire audio studio dédié aux sorts élémentaires (Feu, Glace, Foudre + Tonnerre).
## - Bus dédié "SpellSFX" piloté par SettingsManager.spell_volume (EQ anti-fatigue 3.2 kHz + Réverb forêt + Compresseur doux)
## - Supporte les one-shots spatialisés ET les boucles attachées (ex: crépitement continu de la boule de feu en vol)
## - Variations non-répétitives (Round-Robin), humanisation de pitch et absorption d'air avec la distance.

const BUS_NAME: StringName = &"SpellSFX"
const POOL_SIZE: int = 18
const LOOP_NODE_NAME: String = "SpellLoopAudio3D"
const FIREBALL_LOOP_PATH: String = "res://assets/sound_effects/spells/sfx_fireball_loop.wav"

const BANK_PATHS: Dictionary = {
	"fire_cast": [
		"res://assets/sound_effects/spells/sfx_fire_cast_01.wav",
		"res://assets/sound_effects/spells/sfx_fire_cast_02.wav",
		"res://assets/sound_effects/spells/sfx_fire_cast_03.wav",
	],
	"fire_impact": [
		"res://assets/sound_effects/spells/sfx_fire_impact_01.wav",
		"res://assets/sound_effects/spells/sfx_fire_impact_02.wav",
		"res://assets/sound_effects/spells/sfx_fire_impact_03.wav",
	],
	"ice_cast": [
		"res://assets/sound_effects/spells/sfx_ice_cast_01.wav",
		"res://assets/sound_effects/spells/sfx_ice_cast_02.wav",
		"res://assets/sound_effects/spells/sfx_ice_cast_03.wav",
	],
	"ice_windup": [
		"res://assets/sound_effects/spells/sfx_ice_windup_01.wav",
	],
	"lightning_cast": [
		"res://assets/sound_effects/spells/sfx_lightning_cast_01.wav",
		"res://assets/sound_effects/spells/sfx_lightning_cast_02.wav",
		"res://assets/sound_effects/spells/sfx_lightning_cast_03.wav",
	],
	"lightning_strike": [
		"res://assets/sound_effects/spells/sfx_lightning_strike_01.wav",
		"res://assets/sound_effects/spells/sfx_lightning_strike_02.wav",
		"res://assets/sound_effects/spells/sfx_lightning_strike_03.wav",
	],
}

static var _loaded_banks: Dictionary = {}
static var _fire_loop_stream: AudioStream = null
static var _last_variant_idx: Dictionary = {}
static var _last_play_msec: Dictionary = {}
static var _pool_host: Node = null
static var _players: Array[AudioStreamPlayer3D] = []
static var _pool_cursor: int = 0
static var _rng: RandomNumberGenerator = null


static func play_fire_cast(ctx: Node, world_pos: Vector3, base_pitch: float = 1.0, vol_db_offset: float = 0.0) -> void:
	_play_bank(ctx, "fire_cast", world_pos, -4.5 + vol_db_offset, base_pitch, 0.055, 18.0, 68.0, 0.24)


static func play_fire_impact(ctx: Node, world_pos: Vector3, base_pitch: float = 1.0, vol_db_offset: float = 0.0) -> void:
	_play_bank(ctx, "fire_impact", world_pos, -1.8 + vol_db_offset, base_pitch, 0.055, 22.0, 84.0, 0.38)


static func play_ice_cast(ctx: Node, world_pos: Vector3, base_pitch: float = 1.0, vol_db_offset: float = 0.0) -> void:
	_play_bank(ctx, "ice_cast", world_pos, -2.5 + vol_db_offset, base_pitch, 0.050, 20.0, 76.0, 0.30)


static func play_ice_windup(ctx: Node, world_pos: Vector3, base_pitch: float = 1.0, vol_db_offset: float = 0.0) -> void:
	_play_bank(ctx, "ice_windup", world_pos, -4.8 + vol_db_offset, base_pitch, 0.040, 17.0, 52.0, 0.18)


static func play_lightning_cast(ctx: Node, world_pos: Vector3, base_pitch: float = 1.0, vol_db_offset: float = 0.0) -> void:
	_play_bank(ctx, "lightning_cast", world_pos, -2.4 + vol_db_offset, base_pitch, 0.055, 21.0, 82.0, 0.28)


static func play_lightning_strike_thunder(ctx: Node, world_pos: Vector3, base_pitch: float = 1.0, vol_db_offset: float = 0.0) -> void:
	_play_bank(ctx, "lightning_strike", world_pos, -0.4 + vol_db_offset, base_pitch, 0.045, 30.0, 145.0, 0.40)


static func attach_fire_loop(host_3d: Node3D, volume_db: float = -7.2, unit_size: float = 11.5, max_dist: float = 44.0) -> AudioStreamPlayer3D:
	if host_3d == null or not is_instance_valid(host_3d) or not host_3d.is_inside_tree():
		return null
	_ensure_bus(host_3d.get_tree())

	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()

	if _fire_loop_stream == null and ResourceLoader.exists(FIREBALL_LOOP_PATH):
		var loaded: AudioStream = ResourceLoader.load(FIREBALL_LOOP_PATH) as AudioStream
		if loaded != null:
			if loaded is AudioStreamWAV:
				var wav: AudioStreamWAV = loaded as AudioStreamWAV
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				wav.loop_begin = 0
				wav.loop_end = int(wav.data.size() / 4)
			_fire_loop_stream = loaded

	if _fire_loop_stream == null:
		return null

	var existing: AudioStreamPlayer3D = host_3d.get_node_or_null(LOOP_NODE_NAME) as AudioStreamPlayer3D
	if existing != null and is_instance_valid(existing):
		return existing

	var lp := AudioStreamPlayer3D.new()
	lp.name = LOOP_NODE_NAME
	lp.bus = BUS_NAME
	lp.stream = _fire_loop_stream
	lp.volume_db = volume_db
	lp.pitch_scale = _rng.randf_range(0.95, 1.06)
	lp.unit_size = unit_size
	lp.max_distance = max_dist
	lp.panning_strength = 0.34
	lp.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	lp.attenuation_filter_cutoff_hz = 9500.0
	lp.attenuation_filter_db = -18.0
	lp.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	host_3d.add_child(lp)
	lp.play(_rng.randf_range(0.0, 4.2))
	return lp


static func stop_attached_loop(host_node: Node) -> void:
	if host_node == null or not is_instance_valid(host_node):
		return
	var lp: AudioStreamPlayer3D = host_node.get_node_or_null(LOOP_NODE_NAME) as AudioStreamPlayer3D
	if lp != null and is_instance_valid(lp):
		lp.stop()
		lp.queue_free()


static func _ensure_bus(tree: SceneTree = null) -> void:
	if tree != null and tree.root != null:
		var sm: Node = tree.root.get_node_or_null("SettingsManager")
		if sm != null and sm.has_method("ensure_spell_sfx_bus"):
			sm.call("ensure_spell_sfx_bus")
			return

	var bus_idx: int = AudioServer.get_bus_index(BUS_NAME)
	if bus_idx == -1:
		AudioServer.add_bus()
		bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_idx, String(BUS_NAME))
		AudioServer.set_bus_send(bus_idx, &"Master")
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(0.55) - 4.5)

		var eq := AudioEffectEQ6.new()
		eq.set("band_db/100_hz", 1.2)
		eq.set("band_db/320_hz", 0.8)
		eq.set("band_db/3200_hz", -3.5)
		eq.set("band_db/10000_hz", -1.5)
		AudioServer.add_bus_effect(bus_idx, eq)

		var rev := AudioEffectReverb.new()
		rev.room_size = 0.58
		rev.damping = 0.68
		rev.spread = 0.85
		rev.predelay_msec = 26.0
		rev.predelay_feedback = 0.22
		rev.hipass = 0.15
		rev.dry = 0.92
		rev.wet = 0.18
		AudioServer.add_bus_effect(bus_idx, rev)

		var comp := AudioEffectCompressor.new()
		comp.threshold = -7.5
		comp.ratio = 3.0
		comp.attack_us = 6000.0
		comp.release_ms = 140.0
		AudioServer.add_bus_effect(bus_idx, comp)


static func _ensure_pool(tree: SceneTree) -> void:
	if tree == null or tree.root == null:
		return
	_ensure_bus(tree)

	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()

	if _pool_host == null or not is_instance_valid(_pool_host) or not _pool_host.is_inside_tree():
		_pool_host = tree.root.get_node_or_null("SpellAudioPool")
		if _pool_host == null:
			_pool_host = Node.new()
			_pool_host.name = "SpellAudioPool"
			tree.root.add_child(_pool_host)

	if _players.size() == POOL_SIZE and is_instance_valid(_players[0]) and _players[0].is_inside_tree():
		return

	_players.clear()
	for i: int in range(POOL_SIZE):
		var p := AudioStreamPlayer3D.new()
		p.name = "SpellAudio3D_" + str(i)
		p.bus = BUS_NAME
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		# Absorption naturelle des hautes fréquences à distance (crée une vraie profondeur avant/arrière)
		p.attenuation_filter_cutoff_hz = 11500.0
		p.attenuation_filter_db = -18.0
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		p.max_polyphony = 1
		_pool_host.add_child(p)
		_players.append(p)
	_pool_cursor = 0


static func _get_bank_streams(bank_key: String) -> Array[AudioStream]:
	if _loaded_banks.has(bank_key):
		return _loaded_banks[bank_key] as Array[AudioStream]

	var streams: Array[AudioStream] = []
	if BANK_PATHS.has(bank_key):
		var raw_paths: Array = BANK_PATHS[bank_key] as Array
		for p_var in raw_paths:
			var path_str: String = str(p_var)
			if ResourceLoader.exists(path_str):
				var s: AudioStream = ResourceLoader.load(path_str) as AudioStream
				if s != null:
					if s is AudioStreamWAV:
						(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
					streams.append(s)
	_loaded_banks[bank_key] = streams
	return streams


static func _acquire_player(tree: SceneTree) -> AudioStreamPlayer3D:
	_ensure_pool(tree)
	if _players.is_empty():
		return null

	var count: int = _players.size()
	for offset: int in range(count):
		var idx: int = (_pool_cursor + offset) % count
		var cand: AudioStreamPlayer3D = _players[idx]
		if is_instance_valid(cand) and not cand.playing:
			_pool_cursor = (idx + 1) % count
			return cand

	var fallback: AudioStreamPlayer3D = _players[_pool_cursor]
	_pool_cursor = (_pool_cursor + 1) % count
	if is_instance_valid(fallback):
		fallback.stop()
		return fallback
	return null


static func _play_bank(
	ctx: Node,
	bank_key: String,
	world_pos: Vector3,
	volume_db: float,
	base_pitch: float,
	pitch_jitter: float,
	unit_size: float,
	max_dist: float,
	panning: float
) -> void:
	if ctx == null or not is_instance_valid(ctx) or not ctx.is_inside_tree():
		return
	var tree: SceneTree = ctx.get_tree()
	if tree == null:
		return

	var now_ms: int = Time.get_ticks_msec()
	var prev_ms: int = int(_last_play_msec.get(bank_key, -1000))
	var delta_ms: int = now_ms - prev_ms
	# Anti-phasing & anti-spam : bloque les doublons stricts et adoucit les rafales rapides
	if delta_ms < 18:
		return
	var stack_trim_db: float = -3.2 if delta_ms < 75 else 0.0
	_last_play_msec[bank_key] = now_ms

	var streams: Array[AudioStream] = _get_bank_streams(bank_key)
	if streams.is_empty():
		return

	var player: AudioStreamPlayer3D = _acquire_player(tree)
	if player == null:
		return

	var pick_idx: int = 0
	var s_count: int = streams.size()
	if s_count > 1:
		var last_idx: int = int(_last_variant_idx.get(bank_key, -1))
		pick_idx = _rng.randi_range(0, s_count - 1)
		if pick_idx == last_idx:
			pick_idx = (pick_idx + 1 + _rng.randi_range(0, max(0, s_count - 2))) % s_count
		_last_variant_idx[bank_key] = pick_idx

	player.stream = streams[pick_idx]
	player.volume_db = volume_db + stack_trim_db + _rng.randf_range(-0.5, 0.5)
	player.pitch_scale = clampf(base_pitch + _rng.randf_range(-pitch_jitter, pitch_jitter), 0.65, 1.55)
	player.unit_size = unit_size
	player.max_distance = max_dist
	player.panning_strength = panning
	player.attenuation_filter_cutoff_hz = 11500.0
	player.attenuation_filter_db = -18.0
	player.global_position = world_pos
	player.play()
