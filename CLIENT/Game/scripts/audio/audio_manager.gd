class_name AudioManager
extends Node
## Central Audio Manager for Project Knight: Handles combat SFX and audio feedback.
## Supports non-positional global SFX pooling for 2.5D combat clarity, direct WAV parsing,
## voice concurrency throttling, pitch variation, telemetry event tracking, and clean state resets.

static var _instance: AudioManager = null

const POOL_SIZE := 16
const MAX_CONCURRENT_PER_SOUND := 3
const MIN_RETRIGGER_INTERVAL_SEC := 0.035

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _bgm_player: AudioStreamPlayer = null
var _current_bgm: String = ""

# Concurrency & Throttling
var _last_played_time: Dictionary = {}
var _active_sound_counts: Dictionary = {}

# QA Telemetry & Tracing
var event_history: Array[Dictionary] = []
var event_counts: Dictionary = {}

const SOUND_PATHS := {
	"guard_clang": "res://assets/audio/guard_clang.wav",
	"guard_block": "res://assets/audio/guard_block.wav",
	"parry_clash": "res://assets/audio/parry_clash.wav",
	"player_slash_1": "res://assets/audio/player_slash_1.wav",
	"player_slash_2": "res://assets/audio/player_slash_2.wav",
	"player_slash_3": "res://assets/audio/player_slash_3.wav",
	"enemy_hit_impact": "res://assets/audio/enemy_hit_impact.wav",
	"enemy_hit_counter": "res://assets/audio/enemy_hit_counter.wav",
	"player_dash": "res://assets/audio/player_dash.wav",
	"player_hurt": "res://assets/audio/player_hurt.wav",
	"dive_slam_impact": "res://assets/audio/dive_slam_impact.wav",
	"boss_tell_beast": "res://assets/audio/boss_tell_beast.wav",
	"boss_tell_crossbow": "res://assets/audio/boss_tell_crossbow.wav",
	"boss_crossbow_fire": "res://assets/audio/boss_crossbow_fire.wav",
	"boss_tell_golem": "res://assets/audio/boss_tell_golem.wav",
	"boss_golem_fissure": "res://assets/audio/boss_golem_fissure.wav",
	"boss_tell_abyssal": "res://assets/audio/boss_tell_abyssal.wav",
	"boss_abyssal_strike": "res://assets/audio/boss_abyssal_strike.wav",
	"stage_clear_stinger": "res://assets/audio/stage_clear_stinger.wav",
	"campaign_victory_fanfare": "res://assets/audio/campaign_victory_fanfare.wav"
}

const SOUND_ALIASES := {
	"slash_1": "player_slash_1",
	"slash_2": "player_slash_2",
	"smash_3": "player_slash_3",
	"counter_hit": "enemy_hit_counter",
	"hit_slash": "enemy_hit_impact",
	"hit_heavy": "enemy_hit_counter",
	"counter_impact": "parry_clash",
	"pogo_hit": "enemy_hit_impact",
	"pogo_bounce": "player_dash"
}


func _init() -> void:
	if _instance == null:
		_instance = self
	_init_pool()
	_init_bgm_player()
	_load_sound_assets()


func _enter_tree() -> void:
	if _instance == null:
		_instance = self
	if _players.is_empty():
		_init_pool()
	if _bgm_player == null:
		_init_bgm_player()
	if _streams.is_empty():
		_load_sound_assets()


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _init_bgm_player() -> void:
	if _bgm_player == null:
		_bgm_player = AudioStreamPlayer.new()
		_bgm_player.name = "BGMPlayer"
		_bgm_player.bus = "Master"
		add_child(_bgm_player)


func _init_pool() -> void:
	if not _players.is_empty():
		return
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = "Master"
		add_child(p)
		p.finished.connect(_on_sfx_finished.bind(p))
		_players.append(p)


func _on_sfx_finished(player_node: AudioStreamPlayer) -> void:
	var snd_key: String = player_node.get_meta("sound_key", "")
	if not snd_key.is_empty() and _active_sound_counts.has(snd_key):
		_active_sound_counts[snd_key] = maxi(0, int(_active_sound_counts[snd_key]) - 1)


## Robust standalone WAV loader that parses 16-bit/8-bit PCM RIFF WAV directly from disk
static func load_wav_file(path: String) -> AudioStreamWAV:
	if not FileAccess.file_exists(path):
		return null
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return null
	var bytes := fa.get_buffer(fa.get_length())
	if bytes.size() < 44:
		return null
	if bytes.slice(0, 4).get_string_from_ascii() != "RIFF" or bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null
	var channels := bytes.decode_u16(22)
	var sample_rate := bytes.decode_u32(24)
	var bits_per_sample := bytes.decode_u16(34)
	var data_offset := 36
	var data_size := 0
	while data_offset < bytes.size() - 8:
		var chunk_id := bytes.slice(data_offset, data_offset + 4).get_string_from_ascii()
		var chunk_len := bytes.decode_u32(data_offset + 4)
		if chunk_id == "data":
			data_offset += 8
			data_size = chunk_len
			break
		data_offset += 8 + chunk_len
	
	if data_size <= 0 or data_offset + data_size > bytes.size():
		data_size = bytes.size() - data_offset
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS if bits_per_sample == 16 else AudioStreamWAV.FORMAT_8_BITS
	wav.stereo = (channels == 2)
	wav.mix_rate = int(sample_rate)
	wav.data = bytes.slice(data_offset, data_offset + data_size)
	return wav


func _load_sound_assets() -> void:
	for key in SOUND_PATHS:
		var path: String = SOUND_PATHS[key]
		# First attempt: load via Godot ResourceLoader if imported
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is AudioStream:
				_streams[key] = res
				continue
		# Second attempt: load directly from disk via custom WAV parser
		var direct_wav := load_wav_file(path)
		if direct_wav != null:
			_streams[key] = direct_wav
			continue
	
	# Procedural fallback synthesis in case any asset is missing from import cache
	_ensure_stream_fallback("player_slash_1", func(): return _generate_synthetic_tone(440.0, 0.08, 0.45))
	_ensure_stream_fallback("player_slash_2", func(): return _generate_synthetic_tone(554.37, 0.10, 0.50))
	_ensure_stream_fallback("player_slash_3", func(): return _generate_synthetic_tone(659.25, 0.16, 0.60))
	_ensure_stream_fallback("enemy_hit_impact", func(): return _generate_impact_sound(480.0, 75.0, 0.12, 0.40, 0.85))
	_ensure_stream_fallback("enemy_hit_counter", func(): return _generate_impact_sound(620.0, 110.0, 0.22, 0.70, 0.95))
	_ensure_stream_fallback("guard_block", func(): return _generate_impact_sound(350.0, 120.0, 0.18, 0.30, 0.80))
	_ensure_stream_fallback("parry_clash", func(): return _generate_synthetic_tone(1760.0, 0.35, 0.80))
	_ensure_stream_fallback("player_dash", func(): return _generate_synthetic_tone(523.25, 0.12, 0.45))
	_ensure_stream_fallback("player_hurt", func(): return _generate_synthetic_tone(220.0, 0.15, 0.55))
	_ensure_stream_fallback("dive_slam_impact", func(): return _generate_impact_sound(280.0, 45.0, 0.25, 0.55, 0.90))
	_ensure_stream_fallback("boss_tell_beast", func(): return _generate_synthetic_tone(140.0, 0.35, 0.60))
	_ensure_stream_fallback("boss_tell_crossbow", func(): return _generate_synthetic_tone(1200.0, 0.20, 0.50))
	_ensure_stream_fallback("boss_crossbow_fire", func(): return _generate_synthetic_tone(750.0, 0.14, 0.60))
	_ensure_stream_fallback("boss_tell_golem", func(): return _generate_synthetic_tone(65.0, 0.38, 0.65))
	_ensure_stream_fallback("boss_golem_fissure", func(): return _generate_impact_sound(220.0, 40.0, 0.30, 0.60, 0.90))
	_ensure_stream_fallback("boss_tell_abyssal", func(): return _generate_synthetic_tone(440.0, 0.35, 0.60))
	_ensure_stream_fallback("boss_abyssal_strike", func(): return _generate_impact_sound(550.0, 90.0, 0.24, 0.50, 0.85))
	_ensure_stream_fallback("stage_clear_stinger", func(): return _generate_synthetic_tone(1046.5, 0.80, 0.70))
	_ensure_stream_fallback("campaign_victory_fanfare", func(): return _generate_synthetic_loop(261.63, 1.8, 0.50))

	# Legacy keys mapped
	for legacy_key in SOUND_ALIASES:
		var target_key: String = SOUND_ALIASES[legacy_key]
		if _streams.has(target_key):
			_streams[legacy_key] = _streams[target_key]

	# Procedural dynamic background music tracks
	if not _streams.has("bgm_exploration"):
		_streams["bgm_exploration"] = _generate_synthetic_loop(110.0, 1.2, 0.25)
	if not _streams.has("bgm_boss"):
		_streams["bgm_boss"] = _generate_synthetic_loop(146.83, 0.6, 0.35)


func _ensure_stream_fallback(key: String, factory: Callable) -> void:
	if not _streams.has(key) or _streams[key] == null:
		_streams[key] = factory.call()


static func get_instance() -> Node:
	return _instance


static func ensure_manager(context: Object) -> AudioManager:
	if _instance != null and is_instance_valid(_instance):
		if not _instance.is_inside_tree():
			if context is SceneTree:
				context.root.add_child.call_deferred(_instance)
			elif context is Node and context.get_tree() != null:
				context.get_tree().root.add_child.call_deferred(_instance)
		return _instance
	var script := load("res://scripts/audio/audio_manager.gd") as GDScript
	var new_mgr: AudioManager = script.new()
	new_mgr.name = "AudioManager"
	if context is SceneTree:
		context.root.add_child.call_deferred(new_mgr)
	elif context is Node and context.get_tree() != null:
		context.get_tree().root.add_child.call_deferred(new_mgr)
	_instance = new_mgr
	return _instance


static func get_current_bgm() -> String:
	if _instance != null and is_instance_valid(_instance):
		return _instance._current_bgm
	return ""


static func is_bgm_playing() -> bool:
	if _instance != null and is_instance_valid(_instance) and _instance._bgm_player != null:
		return _instance._bgm_player.playing
	return false


func play_sfx(sound_name: String, _at_position: Vector2 = Vector2.ZERO, volume_scale: float = 1.0) -> void:
	var resolved_name := sound_name
	if SOUND_ALIASES.has(sound_name):
		resolved_name = SOUND_ALIASES[sound_name]

	if not _streams.has(resolved_name):
		return
	var stream: AudioStream = _streams[resolved_name]
	if stream == null:
		return

	var now := float(Time.get_ticks_msec()) / 1000.0

	# 1. Voice Throttling: Minimum interval per sound type
	if _last_played_time.has(resolved_name):
		var elapsed: float = now - float(_last_played_time[resolved_name])
		if elapsed < MIN_RETRIGGER_INTERVAL_SEC:
			return # Throttled to avoid sample stacking / clipping

	# 2. Concurrency Capping: Limit simultaneous instances of the same sound
	var current_count: int = int(_active_sound_counts.get(resolved_name, 0))
	if current_count >= MAX_CONCURRENT_PER_SOUND:
		return # Concurrency limit reached

	_last_played_time[resolved_name] = now
	_active_sound_counts[resolved_name] = current_count + 1

	# 3. Micro Pitch Variation for combat dynamism (+/- 3.5%)
	var pitch := 1.0
	if resolved_name.begins_with("player_slash") or resolved_name.begins_with("enemy_hit"):
		pitch = randf_range(0.965, 1.035)

	# 4. Telemetry tracking
	event_counts[resolved_name] = int(event_counts.get(resolved_name, 0)) + 1
	var event_record := {
		"name": resolved_name,
		"time": now,
		"pitch": pitch,
		"vol": volume_scale
	}
	event_history.append(event_record)
	if event_history.size() > 100:
		event_history.pop_front()

	# 5. Play using idle player in pool or steal longest playing
	var selected_player: AudioStreamPlayer = null
	for p in _players:
		if not p.playing:
			selected_player = p
			break

	if selected_player == null and not _players.is_empty():
		selected_player = _players[0]
		# Decrement stolen player's previous sound count
		var old_key: String = selected_player.get_meta("sound_key", "")
		if not old_key.is_empty() and _active_sound_counts.has(old_key):
			_active_sound_counts[old_key] = maxi(0, int(_active_sound_counts[old_key]) - 1)

	if selected_player != null and selected_player.is_inside_tree():
		selected_player.set_meta("sound_key", resolved_name)
		selected_player.stream = stream
		selected_player.pitch_scale = pitch
		# Sensible headroom: -1.5 dB default, modulated by volume_scale
		var base_db := -1.5
		selected_player.volume_db = base_db + linear_to_db(clampf(volume_scale, 0.05, 2.0))
		selected_player.play()


func play_music(bgm_name: String) -> void:
	if _current_bgm == bgm_name:
		return
	var stream_key := "bgm_" + bgm_name if not bgm_name.begins_with("bgm_") else bgm_name
	if not _streams.has(stream_key):
		return
	_current_bgm = bgm_name
	if _bgm_player != null and _bgm_player.is_inside_tree():
		_bgm_player.stream = _streams[stream_key]
		_bgm_player.play()


func stop_music() -> void:
	_current_bgm = ""
	if _bgm_player != null and _bgm_player.is_inside_tree():
		_bgm_player.stop()


func stop_all_sfx() -> void:
	for p in _players:
		if p.playing:
			p.stop()
	_active_sound_counts.clear()


func reset_audio_state() -> void:
	stop_all_sfx()
	stop_music()
	event_history.clear()
	event_counts.clear()
	_last_played_time.clear()
	_active_sound_counts.clear()


## Static convenience wrappers
static func play(sound_name: String, at_position: Vector2 = Vector2.ZERO, volume_scale: float = 1.0) -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.play_sfx(sound_name, at_position, volume_scale)
	elif Engine.get_main_loop() is SceneTree:
		var mgr := ensure_manager(Engine.get_main_loop() as SceneTree)
		mgr.play_sfx(sound_name, at_position, volume_scale)


static func bgm(track_name: String) -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.play_music(track_name)
	elif Engine.get_main_loop() is SceneTree:
		var mgr := ensure_manager(Engine.get_main_loop() as SceneTree)
		mgr.play_music(track_name)


static func stop_bgm() -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.stop_music()


static func stop_sfx() -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.stop_all_sfx()


static func reset_all() -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.reset_audio_state()


static func get_event_count(event_name: String) -> int:
	if _instance != null and is_instance_valid(_instance):
		var resolved: String = SOUND_ALIASES.get(event_name, event_name)
		return int(_instance.event_counts.get(resolved, 0))
	return 0


static func set_master_volume(linear_val: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		var db := linear_to_db(clampf(linear_val, 0.0001, 1.0)) if linear_val > 0.01 else -80.0
		AudioServer.set_bus_volume_db(bus_idx, db)


static func set_bgm_volume(linear_val: float) -> void:
	if _instance != null and is_instance_valid(_instance) and _instance._bgm_player != null:
		var db := linear_to_db(clampf(linear_val, 0.0001, 1.0)) if linear_val > 0.01 else -80.0
		_instance._bgm_player.volume_db = db


## Procedural synthesis helpers
func _generate_synthetic_tone(freq: float, duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	var sample_count := int(duration * wav.mix_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(wav.mix_rate)
		var envelope := 1.0 - (float(i) / float(sample_count))
		var wave := sin(2.0 * PI * freq * t)
		var value := int(clampf(wave * envelope * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)
	wav.data = data
	return wav


func _generate_synthetic_loop(freq: float, duration: float, volume: float = 0.22) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = int(duration * wav.mix_rate)
	var sample_count := int(duration * wav.mix_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(wav.mix_rate)
		var sub := sin(2.0 * PI * (freq * 0.5) * t) * 0.45
		var root := sin(2.0 * PI * freq * t) * 0.35
		var fifth := sin(2.0 * PI * (freq * 1.4983) * t) * 0.20
		var octave := sin(2.0 * PI * (freq * 2.0) * t) * 0.12
		var swell := 0.75 + 0.25 * sin(2.0 * PI * (1.0 / duration) * t)
		var combined := (sub + root + fifth + octave) * swell * volume
		var value := int(clampf(combined, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)
	wav.data = data
	return wav


func _generate_impact_sound(start_freq: float, end_freq: float, duration: float, noise_mix: float = 0.35, volume: float = 0.85) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	var sample_count := int(duration * wav.mix_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase: float = 0.0
	for i in range(sample_count):
		var t := float(i) / float(sample_count)
		var current_freq := lerpf(start_freq, end_freq, pow(t, 0.4))
		phase += 2.0 * PI * current_freq / float(wav.mix_rate)
		var tonal := sin(phase)
		var thump := sin(2.0 * PI * 65.0 * (float(i) / float(wav.mix_rate))) * maxf(0.0, 1.0 - t * 4.0) * 0.40
		var noise := randf_range(-1.0, 1.0) * pow(1.0 - t, 2.2) * noise_mix
		var envelope := pow(1.0 - t, 1.6)
		var sample := ((tonal + thump) * (1.0 - noise_mix * 0.4) + noise) * envelope * volume
		var value := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)
	wav.data = data
	return wav
