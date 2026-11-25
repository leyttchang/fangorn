class_name WeatherAmbienceManager
extends Node3D

## Mixeur d'Ambiance Météo Dynamique Multi-Pistes (Style Studio / Wwise-like)
## - Crossfades continus A/B à puissance constante (sin/cos) sur des boucles sans couture
##   de durées premières entre elles (zéro sensation de répétition, zéro clic).
## - Rafales de vent 3D orientées selon la vraie direction de WindManager.
## - Faune très discrète au calme qui se tait à l'approche de l'orage.
## - Tonnerres croppés sans voix : roulements lointains rares à mi-pluie, puis gros éclairs espacés en pleine tempête.

const BUS_NAME := "WeatherAmbience"

const LOOP_DIR := "res://assets/sound_effects/weather/loops/"
const GUST_DIR := "res://assets/sound_effects/weather/gusts_and_birds/"
const THUNDER_DIR := "res://assets/sound_effects/weather/thunder_cropped/"

const RAIN_LIGHT_FILES: Array[String] = [
	LOOP_DIR + "rain_forest_01.wav",
	LOOP_DIR + "rain_forest_02.wav",
	LOOP_DIR + "rain_forest_03.wav",
	LOOP_DIR + "rain_forest_04.wav",
]

const RAIN_HEAVY_FILES: Array[String] = [
	LOOP_DIR + "rain_storm_heavy_01.wav",
	LOOP_DIR + "rain_storm_heavy_02.wav",
	LOOP_DIR + "rain_storm_heavy_03.wav",
	LOOP_DIR + "rain_storm_heavy_04.wav",
]

const WIND_TREES_FILES: Array[String] = [
	LOOP_DIR + "wind_trees_strong_01.wav",
	LOOP_DIR + "wind_trees_strong_02.wav",
]

const WIND_STORM_FILES: Array[String] = [
	LOOP_DIR + "wind_storm_eye.wav",
	LOOP_DIR + "wind_trees_strong_01.wav",
	LOOP_DIR + "wind_trees_strong_02.wav",
]

const GUST_FOLIAGE_FILES: Array[String] = [
	GUST_DIR + "wind_gust_foliage_01.wav",
	GUST_DIR + "wind_gust_foliage_02.wav",
]

const GUST_TREES_FILES: Array[String] = [
	GUST_DIR + "wind_gust_trees_01.wav",
	GUST_DIR + "wind_gust_trees_02.wav",
	GUST_DIR + "wind_gust_foliage_02.wav",
]

const CROW_FILES: Array[String] = [
	GUST_DIR + "crow_distant_01.wav",
	GUST_DIR + "crow_distant_02.wav",
	GUST_DIR + "crow_wings_03.wav",
]

const THUNDER_DISTANT_FILES: Array[String] = [
	THUNDER_DIR + "thunder_distant_01.wav",
	THUNDER_DIR + "thunder_distant_02.wav",
	THUNDER_DIR + "thunder_distant_03.wav",
	THUNDER_DIR + "thunder_distant_04.wav",
]

const THUNDER_HEAVY_FILES: Array[String] = [
	THUNDER_DIR + "thunder_heavy_01.wav",
	THUNDER_DIR + "thunder_heavy_02.wav",
	THUNDER_DIR + "thunder_heavy_03.wav",
	THUNDER_DIR + "thunder_heavy_04.wav",
]

@export_range(-24.0, 12.0, 0.5) var master_volume_db: float = 0.0:
	set(val):
		master_volume_db = val
		_update_bus_volume()


# =============================================================================
# PISTE DOUBLE-PLATINE A/B AVEC CROSSFADE À PUISSANCE CONSTANTE (SIN / COS)
# =============================================================================
class DualDeckBed:
	var deck_a: AudioStreamPlayer
	var deck_b: AudioStreamPlayer
	var streams: Array[AudioStream] = []
	var active_is_a: bool = true
	var current_idx: int = -1

	var cur_gain: float = 0.0
	var target_gain: float = 0.0
	var gain_smooth_speed: float = 0.65

	var xfade_progress: float = 1.0
	var xfade_duration: float = 5.5
	var segment_timer: float = 0.0
	var next_switch_time: float = 20.0
	var min_switch_s: float = 16.0
	var max_switch_s: float = 25.0
	var pitch_min: float = 0.95
	var pitch_max: float = 1.05
	var rng: RandomNumberGenerator

	func _init(parent: Node, label: String, bus_name: String, p_streams: Array[AudioStream], p_rng: RandomNumberGenerator, p_min_sw: float = 16.0, p_max_sw: float = 25.0) -> void:
		streams = p_streams
		rng = p_rng
		min_switch_s = p_min_sw
		max_switch_s = p_max_sw

		deck_a = AudioStreamPlayer.new()
		deck_a.name = label + "_DeckA"
		deck_a.bus = bus_name
		deck_a.volume_db = -80.0
		parent.add_child(deck_a)

		deck_b = AudioStreamPlayer.new()
		deck_b.name = label + "_DeckB"
		deck_b.bus = bus_name
		deck_b.volume_db = -80.0
		parent.add_child(deck_b)

	func _pick_next_index() -> int:
		if streams.is_empty():
			return -1
		if streams.size() == 1:
			return 0
		var idx := rng.randi_range(0, streams.size() - 1)
		if idx == current_idx:
			idx = (idx + 1) % streams.size()
		current_idx = idx
		return idx

	func _start_player(p: AudioStreamPlayer) -> void:
		var idx := _pick_next_index()
		if idx < 0:
			return
		var st := streams[idx]
		p.stream = st
		p.pitch_scale = rng.randf_range(pitch_min, pitch_max)
		var start_offset := 0.0
		var st_len := st.get_length()
		if st_len > 6.0:
			start_offset = rng.randf_range(0.0, st_len * 0.45)
		p.play(start_offset)

	func update(delta: float, extra_mult: float = 1.0) -> void:
		if streams.is_empty():
			return

		cur_gain = move_toward(cur_gain, target_gain, delta * gain_smooth_speed * maxf(0.18, absf(target_gain - cur_gain) + 0.08))
		var eff_gain := clampf(cur_gain * extra_mult, 0.0, 2.0)

		# Mise en sommeil automatique à gain nul (0 coût CPU audio quand la piste est muette)
		if eff_gain <= 0.0006 and target_gain <= 0.0006:
			if deck_a.playing:
				deck_a.stop()
			if deck_b.playing:
				deck_b.stop()
			return

		var active_deck := deck_a if active_is_a else deck_b
		var fading_deck := deck_b if active_is_a else deck_a

		if not active_deck.playing:
			_start_player(active_deck)
			xfade_progress = 1.0
			segment_timer = 0.0
			next_switch_time = rng.randf_range(min_switch_s, max_switch_s)

		if xfade_progress < 1.0:
			xfade_progress = minf(1.0, xfade_progress + delta / maxf(0.5, xfade_duration))
			if xfade_progress >= 1.0 and fading_deck.playing:
				fading_deck.stop()
		else:
			segment_timer += delta
			if segment_timer >= next_switch_time:
				segment_timer = 0.0
				next_switch_time = rng.randf_range(min_switch_s, max_switch_s)
				active_is_a = not active_is_a
				active_deck = deck_a if active_is_a else deck_b
				fading_deck = deck_b if active_is_a else deck_a
				_start_player(active_deck)
				xfade_progress = 0.0

		# Courbe sin/cos à puissance acoustique constante (sin² + cos² = 1)
		var angle := xfade_progress * PI * 0.5
		var gain_active := eff_gain * sin(angle)
		var gain_fading := eff_gain * cos(angle)

		active_deck.volume_db = linear_to_db(maxf(0.00001, gain_active))
		if fading_deck.playing:
			fading_deck.volume_db = linear_to_db(maxf(0.00001, gain_fading))


# =============================================================================
# ÉTAT INTERNE DU MIXEUR MÉTÉO
# =============================================================================
var _rng := RandomNumberGenerator.new()

var _bed_soft_air: DualDeckBed
var _bed_meadow_calm: DualDeckBed
var _bed_wind_trees: DualDeckBed
var _bed_wind_storm: DualDeckBed
var _bed_wind_whip: DualDeckBed
var _bed_rain_light: DualDeckBed
var _bed_rain_heavy: DualDeckBed

var _gust_streams_foliage: Array[AudioStream] = []
var _gust_streams_trees: Array[AudioStream] = []
var _crow_streams: Array[AudioStream] = []
var _thunder_distant_streams: Array[AudioStream] = []
var _thunder_heavy_streams: Array[AudioStream] = []

var _gust_players: Array[AudioStreamPlayer3D] = []
var _crow_player: AudioStreamPlayer3D = null
var _thunder_players: Array[AudioStreamPlayer3D] = []

var _gust_timer: float = 8.0
var _crow_timer: float = 18.0
var _distant_thunder_timer: float = 22.0
var _heavy_thunder_timer: float = 35.0

var _last_distant_idx: int = -1
var _last_heavy_idx: int = -1
var _last_gust_idx: int = -1
var _last_crow_idx: int = -1

var _thunder_duck_mult: float = 1.0
var _smooth_wind_mod: float = 1.0


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return

	# Permet d'entendre les variations de volume en direct quand on règle les sliders dans le menu Pause !
	process_mode = Node.PROCESS_MODE_ALWAYS

	_rng.randomize()
	_ensure_weather_bus()
	var settings := _get_settings()
	if settings != null and settings.has_signal("audio_settings_changed"):
		if not settings.is_connected("audio_settings_changed", _update_bus_volume):
			settings.connect("audio_settings_changed", _update_bus_volume)

	# Chargement des boucles (avec activation garantie de LOOP_FORWARD)
	var air_streams := _load_streams([LOOP_DIR + "wind_soft_air.wav"], true)
	var meadow_streams := _load_streams([LOOP_DIR + "forest_meadow_calm.wav"], true)
	var trees_streams := _load_streams(WIND_TREES_FILES, true)
	var storm_wind_streams := _load_streams(WIND_STORM_FILES, true)
	var whip_streams := _load_streams([LOOP_DIR + "wind_storm_whip.wav"], true)
	var rain_l_streams := _load_streams(RAIN_LIGHT_FILES, true)
	var rain_h_streams := _load_streams(RAIN_HEAVY_FILES, true)

	_bed_soft_air = DualDeckBed.new(self, "SoftAir", BUS_NAME, air_streams, _rng, 18.0, 26.0)
	_bed_meadow_calm = DualDeckBed.new(self, "MeadowCalm", BUS_NAME, meadow_streams, _rng, 22.0, 30.0)
	_bed_wind_trees = DualDeckBed.new(self, "WindTrees", BUS_NAME, trees_streams, _rng, 16.0, 24.0)
	_bed_wind_storm = DualDeckBed.new(self, "WindStorm", BUS_NAME, storm_wind_streams, _rng, 17.0, 26.0)
	_bed_wind_whip = DualDeckBed.new(self, "WindWhip", BUS_NAME, whip_streams, _rng, 14.0, 20.0)
	_bed_rain_light = DualDeckBed.new(self, "RainLight", BUS_NAME, rain_l_streams, _rng, 15.0, 23.0)
	_bed_rain_heavy = DualDeckBed.new(self, "RainHeavy", BUS_NAME, rain_h_streams, _rng, 16.0, 25.0)

	# Chargement des one-shots spatialisés (rafales, corbeaux doux, tonnerres croppés)
	_gust_streams_foliage = _load_streams(GUST_FOLIAGE_FILES, false)
	_gust_streams_trees = _load_streams(GUST_TREES_FILES, false)
	_crow_streams = _load_streams(CROW_FILES, false)
	_thunder_distant_streams = _load_streams(THUNDER_DISTANT_FILES, false)
	_thunder_heavy_streams = _load_streams(THUNDER_HEAVY_FILES, false)

	# 2 lecteurs 3D pour que deux rafales de vent puissent se chevaucher autour du joueur
	for i in range(2):
		var gp := _make_3d_player("WindGust3D_%d" % i, 18.0, 140.0, 0.55)
		_gust_players.append(gp)

	_crow_player = _make_3d_player("DistantCrow3D", 14.0, 160.0, 0.75)

	# 2 lecteurs 3D pour le tonnerre (permet qu'un coup lointain et un gros coup proche résonnent sans se couper)
	for i in range(2):
		var tp := _make_3d_player("Thunder3D_%d" % i, 85.0, 450.0, 0.45)
		tp.attenuation_filter_cutoff_hz = 20500.0
		_thunder_players.append(tp)

	_gust_timer = _rng.randf_range(6.0, 14.0)
	_crow_timer = _rng.randf_range(16.0, 34.0)
	_distant_thunder_timer = _rng.randf_range(12.0, 26.0)
	_heavy_thunder_timer = _rng.randf_range(22.0, 45.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _bed_soft_air == null:
		return
	# Quand le jeu est en pause (menu Option ouvert), maintient uniquement les fondus des boucles actives
	if get_tree() != null and get_tree().paused:
		var bed_env := _thunder_duck_mult
		_bed_soft_air.update(delta, bed_env)
		_bed_meadow_calm.update(delta, bed_env)
		_bed_wind_trees.update(delta, bed_env * _smooth_wind_mod)
		_bed_wind_storm.update(delta, bed_env * _smooth_wind_mod)
		_bed_wind_whip.update(delta, bed_env * _smooth_wind_mod)
		_bed_rain_light.update(delta, bed_env)
		_bed_rain_heavy.update(delta, bed_env)


func _get_settings() -> Node:
	if Engine.has_singleton("SettingsManager"):
		return Engine.get_singleton("SettingsManager")
	if is_inside_tree() and get_tree() != null and get_tree().root != null and get_tree().root.has_node("SettingsManager"):
		return get_tree().root.get_node("SettingsManager")
	return null


func _ensure_weather_bus() -> void:
	var settings := _get_settings()
	if settings != null and settings.has_method("ensure_weather_ambience_bus"):
		settings.call("ensure_weather_ambience_bus")
		_update_bus_volume()
		return
	var idx := AudioServer.get_bus_index(BUS_NAME)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS_NAME)
		AudioServer.set_bus_send(idx, "Master")
		# Compresseur doux de cohésion ("glue") évitant toute saturation quand pluie + vent + gros tonnerre s'additionnent
		var comp := AudioEffectCompressor.new()
		comp.threshold = -8.0
		comp.ratio = 2.5
		comp.attack_us = 15000.0
		comp.release_ms = 280.0
		AudioServer.add_bus_effect(idx, comp)
	_update_bus_volume()


func _update_bus_volume() -> void:
	var settings := _get_settings()
	if settings != null and "ambient_offset_db" in settings:
		settings.set("ambient_offset_db", master_volume_db)
		return
	var idx := AudioServer.get_bus_index(BUS_NAME)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, master_volume_db)


func _make_3d_player(p_name: String, unit_sz: float, max_dist: float, pan_strength: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = p_name
	p.bus = BUS_NAME
	p.unit_size = unit_sz
	p.max_distance = max_dist
	p.panning_strength = pan_strength
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(p)
	return p


func _load_streams(paths: Array[String], make_loop: bool) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	for path in paths:
		if not ResourceLoader.exists(path):
			continue
		var st := load(path) as AudioStream
		if st == null:
			continue
		if st is AudioStreamWAV:
			var w := st as AudioStreamWAV
			if make_loop:
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_begin = 0
				var bytes_per_frame := (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if w.stereo else 1)
				if w.data.size() > 0 and (w.format == AudioStreamWAV.FORMAT_8_BITS or w.format == AudioStreamWAV.FORMAT_16_BITS):
					w.loop_end = maxi(1, int(w.data.size() / bytes_per_frame))
				else:
					w.loop_end = maxi(1, int(floor(w.get_length() * float(w.mix_rate))))
			else:
				w.loop_mode = AudioStreamWAV.LOOP_DISABLED
		elif st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = make_loop
		out.append(st)
	return out


# =============================================================================
# PILOTAGE ÉCHELONNÉ DEPUIS TIMERSYS (0 MIN -> 15 MIN)
# =============================================================================
func update_weather_soundscape(
	delta: float,
	elapsed_time: float,
	wind_start_time: float,
	rain_start_time: float,
	rain_max_time: float
) -> void:
	if Engine.is_editor_hint() or _bed_soft_air == null:
		return

	var listener_pos := _get_listener_position()
	global_position = listener_pos

	# 1. Calcul des progressions normalisées [0..1]
	# - Phase calme initiale (0 -> wind_start_time, ex: 0..60s) : quasi rien, montée très timide
	var pre_wind_t := clampf(elapsed_time / maxf(1.0, wind_start_time), 0.0, 1.0)
	# - Montée du vent sec avant la pluie (wind_start_time -> rain_start_time, ex: 60..300s)
	var dry_wind_t := clampf((elapsed_time - wind_start_time) / maxf(1.0, rain_start_time - wind_start_time), 0.0, 1.0)
	# - Progression de la pluie & de l'orage (rain_start_time -> rain_max_time, ex: 300..900s)
	var rain_t := 0.0
	if elapsed_time >= rain_start_time:
		rain_t = clampf((elapsed_time - rain_start_time) / maxf(1.0, rain_max_time - rain_start_time), 0.0, 1.0)

	# 2. Couplage organique avec les vraies bourrasques / accalmies de WindManager
	var wind_gust_mod := 1.0
	var wind_dir_2d := Vector2(1.0, 0.4).normalized()
	var wind_singleton := get_node_or_null("/root/Wind")
	if wind_singleton != null:
		var raw_dir: Variant = wind_singleton.get("current_wind_direction")
		if raw_dir is Vector2 and (raw_dir as Vector2).length_squared() > 0.0001:
			wind_dir_2d = (raw_dir as Vector2).normalized()
		var raw_str: Variant = wind_singleton.get("current_wind_strength")
		if raw_str is float or raw_str is int:
			var w_str: float = float(raw_str)
			# Transforme la force du shader (0.08 calme -> 1.15 tempête) en respiration naturelle du volume (0.78..1.24)
			wind_gust_mod = clampf(lerpf(0.84, 1.22, clampf(w_str / 1.10, 0.0, 1.0)), 0.75, 1.28)
	_smooth_wind_mod = lerpf(_smooth_wind_mod, wind_gust_mod, clampf(delta * 2.5, 0.0, 1.0))

	# Retour progressif après un micro-ducking de gros coup de tonnerre
	_thunder_duck_mult = move_toward(_thunder_duck_mult, 1.0, delta * 0.55)
	var bed_env := _thunder_duck_mult

	# -------------------------------------------------------------------------
	# CIBLES DE VOLUME (EN AMPLITUDE LINÉAIRE) DES 7 LITS SONORES CONTINUS
	# -------------------------------------------------------------------------
	# A) Souffle d'air très léger : quasi inaudible au début (0.004 = -48 dB) pour éviter tout bruit de fond/souffle avant la pluie
	var air_gain: float = lerpf(0.004, 0.015, pre_wind_t)
	air_gain = lerpf(air_gain, 0.045, pow(dry_wind_t, 1.6))
	air_gain = lerpf(air_gain, 0.10, rain_t) # Laisse la place aux pistes riches sous l'orage
	_bed_soft_air.target_gain = air_gain

	# B) Prairie calme (insectes/oiseaux ultra discrets : max 0.011 = -39 dB !), disparaît dès que la pluie commence
	var meadow_fade_out: float = 1.0 - smoothstep(0.0, 0.12, rain_t)
	var meadow_pre: float = lerpf(0.003, 0.011, smoothstep(0.25, 1.0, pre_wind_t))
	_bed_meadow_calm.target_gain = meadow_pre * meadow_fade_out

	# C) Vent dans les arbres (Lakeside WINDVege) :
	#    0..1 min : silence complet (0 bruit de fond au départ) -> 1..5 min : montée progressive -> 5..15 min : soutient la tempête !
	var trees_gain: float = 0.0
	if dry_wind_t > 0.0:
		trees_gain = lerpf(0.0, 0.15, pow(dry_wind_t, 1.85))
	trees_gain = lerpf(trees_gain, 0.42, smoothstep(0.0, 0.85, rain_t))
	_bed_wind_trees.target_gain = trees_gain

	# D) Hurlement / souffle profond d'orage (Eye of the Storm + Whip) : monte en seconde moitié de pluie
	_bed_wind_storm.target_gain = lerpf(0.0, 0.28, smoothstep(0.25, 0.95, rain_t))
	_bed_wind_whip.target_gain = lerpf(0.0, 0.15, smoothstep(0.50, 1.0, rain_t))

	# E) Pluie forêt faible / modérée (RAINMisc sur les feuilles) :
	#    Démarre tout doux à 5 min (0.055 = -25dB), monte à ~0.34 (-9.3dB) à mi-pluie,
	#    et reste présente à 0.25 sous la grosse averse pour garder le grain des feuilles !
	var rain_light_gain := 0.0
	if elapsed_time >= rain_start_time:
		var rise := smoothstep(0.0, 0.48, rain_t)
		var settle := smoothstep(0.55, 1.0, rain_t)
		rain_light_gain = lerpf(0.055, 0.34, rise) * lerpf(1.0, 0.76, settle)
	_bed_rain_light.target_gain = rain_light_gain

	# F) Forte pluie & bourrasques d'orage (BackGardenStorm 11 & 13) :
	#    Entre progressivement à partir de ~30% de pluie (~8 min) jusqu'au déluge complet à 15 min
	var rain_heavy_gain := 0.0
	if elapsed_time >= rain_start_time:
		rain_heavy_gain = lerpf(0.0, 0.46, smoothstep(0.26, 0.95, rain_t))
	_bed_rain_heavy.target_gain = rain_heavy_gain

	# Mise à jour de toutes les platines A/B
	_bed_soft_air.update(delta, bed_env)
	_bed_meadow_calm.update(delta, bed_env)
	_bed_wind_trees.update(delta, bed_env * _smooth_wind_mod)
	_bed_wind_storm.update(delta, bed_env * _smooth_wind_mod)
	_bed_wind_whip.update(delta, bed_env * _smooth_wind_mod)
	_bed_rain_light.update(delta, bed_env)
	_bed_rain_heavy.update(delta, bed_env)

	# -------------------------------------------------------------------------
	# ÉVÉNEMENTS SPATIALISÉS RANDOMISÉS (RAFALES 3D, CORBEAUX DOUX, TONNERRES)
	# -------------------------------------------------------------------------
	_update_wind_gusts(delta, listener_pos, wind_dir_2d, pre_wind_t, dry_wind_t, rain_t)
	_update_distant_crows(delta, listener_pos, pre_wind_t, rain_t)
	_update_thunder_strikes(delta, listener_pos, elapsed_time >= rain_start_time, rain_t)


func _update_wind_gusts(delta: float, listener_pos: Vector3, wind_dir_2d: Vector2, pre_wind_t: float, dry_wind_t: float, rain_t: float) -> void:
	# Au début (< ~35s), calme plat sans rafale parasite
	if pre_wind_t < 0.58:
		return

	_gust_timer -= delta
	if _gust_timer > 0.0:
		return

	# Fréquence et volume des rafales selon la phase météo
	var pool: Array[AudioStream] = _gust_streams_foliage if (dry_wind_t < 0.65 and rain_t < 0.15) else _gust_streams_trees
	if pool.is_empty():
		_gust_timer = 12.0
		return

	var player: AudioStreamPlayer3D = _find_free_3d_player(_gust_players)
	if player == null:
		_gust_timer = 3.0
		return

	var idx: int = _pick_non_repeating(pool.size(), _last_gust_idx)
	_last_gust_idx = idx

	# Place la rafale dans la direction d'où vient le vent (upwind) pour qu'elle enveloppe naturellement le joueur !
	var side_jitter: float = _rng.randf_range(-0.65, 0.65)
	var gust_dir: Vector2 = wind_dir_2d.rotated(side_jitter)
	var dist: float = _rng.randf_range(12.0, 26.0)
	player.global_position = listener_pos + Vector3(-gust_dir.x * dist, _rng.randf_range(2.5, 6.5), -gust_dir.y * dist)
	player.stream = pool[idx]
	player.pitch_scale = _rng.randf_range(0.88, 1.08)

	var vol_db: float = lerpf(-25.5, -11.5, clampf(dry_wind_t * 0.68 + rain_t * 0.62, 0.0, 1.0))
	player.volume_db = vol_db + _rng.randf_range(-1.5, 1.5)
	player.play()

	var min_wait := lerpf(18.0, 6.5, clampf(dry_wind_t * 0.65 + rain_t * 0.55, 0.0, 1.0))
	var max_wait := lerpf(30.0, 13.5, clampf(dry_wind_t * 0.65 + rain_t * 0.55, 0.0, 1.0))
	_gust_timer = _rng.randf_range(min_wait, max_wait)


func _update_distant_crows(delta: float, listener_pos: Vector3, pre_wind_t: float, rain_t: float) -> void:
	# Uniquement par temps sec (avant la pluie), rare et très doux en arrière-plan !
	if rain_t > 0.02 or pre_wind_t < 0.45 or _crow_streams.is_empty() or _crow_player == null:
		return

	_crow_timer -= delta
	if _crow_timer > 0.0:
		return

	if not _crow_player.playing:
		var idx := _pick_non_repeating(_crow_streams.size(), _last_crow_idx)
		_last_crow_idx = idx
		var angle := _rng.randf_range(0.0, TAU)
		var dist := _rng.randf_range(45.0, 80.0)
		_crow_player.global_position = listener_pos + Vector3(cos(angle) * dist, _rng.randf_range(10.0, 22.0), sin(angle) * dist)
		_crow_player.stream = _crow_streams[idx]
		_crow_player.pitch_scale = _rng.randf_range(0.90, 1.06)
		# Très doux (-24 à -28 dB + atténuation de distance à 45-80m) : jamais envahissant !
		_crow_player.volume_db = _rng.randf_range(-28.0, -24.0)
		_crow_player.play()

	_crow_timer = _rng.randf_range(42.0, 78.0)


func _update_thunder_strikes(delta: float, listener_pos: Vector3, is_raining: bool, rain_t: float) -> void:
	# Pas de tonnerre pendant la pluie faible initiale : commence doucement au loin vers 35% de progression (~8m30)
	if not is_raining or rain_t < 0.34:
		return

	# 1. Tonnerre lointain (dès rain_t >= 0.34 : "un tout petit peu de tonnerre lointain")
	if not _thunder_distant_streams.is_empty():
		_distant_thunder_timer -= delta
		if _distant_thunder_timer <= 0.0:
			var p_dist := _find_free_3d_player(_thunder_players)
			if p_dist != null:
				var idx := _pick_non_repeating(_thunder_distant_streams.size(), _last_distant_idx)
				_last_distant_idx = idx
				var ang := _rng.randf_range(0.0, TAU)
				p_dist.global_position = listener_pos + Vector3(cos(ang) * 140.0, 65.0, sin(ang) * 140.0)
				p_dist.stream = _thunder_distant_streams[idx]
				p_dist.pitch_scale = _rng.randf_range(0.86, 1.05)
				# Discret au début (-13.5 dB), un peu plus présent sous forte pluie (-9.0 dB)
				p_dist.volume_db = lerpf(-13.5, -9.0, smoothstep(0.34, 0.90, rain_t)) + _rng.randf_range(-1.2, 1.2)
				p_dist.play()

			var min_dt := lerpf(34.0, 22.0, smoothstep(0.34, 1.0, rain_t))
			var max_dt := lerpf(58.0, 40.0, smoothstep(0.34, 1.0, rain_t))
			_distant_thunder_timer = _rng.randf_range(min_dt, max_dt)

	# 2. Gros coups de tonnerre proches ("puis de temps en temps un gros coup de tonnerre et forte pluie/vent")
	if rain_t >= 0.68 and not _thunder_heavy_streams.is_empty():
		_heavy_thunder_timer -= delta
		if _heavy_thunder_timer <= 0.0:
			var p_heavy := _find_free_3d_player(_thunder_players)
			if p_heavy != null:
				var idx_h := _pick_non_repeating(_thunder_heavy_streams.size(), _last_heavy_idx)
				_last_heavy_idx = idx_h
				var ang_h := _rng.randf_range(0.0, TAU)
				p_heavy.global_position = listener_pos + Vector3(cos(ang_h) * 45.0, 55.0, sin(ang_h) * 45.0)
				p_heavy.stream = _thunder_heavy_streams[idx_h]
				p_heavy.pitch_scale = _rng.randf_range(0.90, 1.05)
				p_heavy.volume_db = lerpf(-5.5, -2.5, smoothstep(0.68, 1.0, rain_t)) + _rng.randf_range(-0.8, 0.8)
				p_heavy.play()
				# Léger ducking cinéma (-2 dB) des lits continus au moment de l'impact de foudre !
				_thunder_duck_mult = 0.79
				# Décale un peu le prochain tonnerre lointain pour éviter qu'ils tombent pile ensemble
				_distant_thunder_timer = maxf(_distant_thunder_timer, _rng.randf_range(12.0, 20.0))

			var min_ht := lerpf(48.0, 36.0, smoothstep(0.68, 1.0, rain_t))
			var max_ht := lerpf(82.0, 64.0, smoothstep(0.68, 1.0, rain_t))
			_heavy_thunder_timer = _rng.randf_range(min_ht, max_ht)


func _find_free_3d_player(pool: Array[AudioStreamPlayer3D]) -> AudioStreamPlayer3D:
	for p in pool:
		if is_instance_valid(p) and not p.playing:
			return p
	return null


func _pick_non_repeating(count: int, last_idx: int) -> int:
	if count <= 1:
		return 0
	var idx := _rng.randi_range(0, count - 1)
	if idx == last_idx:
		idx = (idx + 1) % count
	return idx


func stop_all() -> void:
	var beds: Array[DualDeckBed] = [
		_bed_soft_air,
		_bed_meadow_calm,
		_bed_wind_trees,
		_bed_wind_storm,
		_bed_wind_whip,
		_bed_rain_light,
		_bed_rain_heavy,
	]
	for bed in beds:
		if bed != null:
			bed.target_gain = 0.0
			bed.cur_gain = 0.0
			if is_instance_valid(bed.deck_a) and bed.deck_a.playing:
				bed.deck_a.stop()
			if is_instance_valid(bed.deck_b) and bed.deck_b.playing:
				bed.deck_b.stop()
	for p in _gust_players:
		if is_instance_valid(p) and p.playing:
			p.stop()
	if is_instance_valid(_crow_player) and _crow_player.playing:
		_crow_player.stop()
	for p in _thunder_players:
		if is_instance_valid(p) and p.playing:
			p.stop()


func _get_listener_position() -> Vector3:
	var vp := get_viewport()
	if vp != null:
		var cam := vp.get_camera_3d()
		if cam != null and is_instance_valid(cam):
			return cam.global_position
	if is_inside_tree() and get_tree() != null:
		for p in get_tree().get_nodes_in_group("Player"):
			if is_instance_valid(p) and p is Node3D:
				if not p.has_method("is_multiplayer_authority") or p.is_multiplayer_authority():
					return (p as Node3D).global_position
	return global_position
