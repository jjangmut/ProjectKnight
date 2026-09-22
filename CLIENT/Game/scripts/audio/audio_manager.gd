class_name AudioManager
extends Node
## Central Audio Manager for Project Knight: Handles combat SFX and audio feedback.

static var _instance: AudioManager
var _players: Array[AudioStreamPlayer2D] = []
var _streams: Dictionary = {}
var _bgm_player: AudioStreamPlayer = null
var _current_bgm: String = ""
const POOL_SIZE := 8

const SOUND_PATHS := {
	"guard_clang": "res://assets/audio/guard_clang.wav"
}


func _enter_tree() -> void:
	if _instance == null:
		_instance = self
	_init_pool()
	_init_bgm_player()
	_load_sound_assets()


func _init_bgm_player() -> void:
	if _bgm_player == null:
		_bgm_player = AudioStreamPlayer.new()
		_bgm_player.name = "BGMPlayer"
		_bgm_player.bus = "Master"
		add_child(_bgm_player)



static func get_instance() -> Node:
	return _instance


static func ensure_manager(context: Object) -> Node:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	var script := load("res://scripts/audio/audio_manager.gd") as GDScript
	var new_mgr: Node = script.new()
	new_mgr.name = "AudioManager"
	if context is SceneTree:
		context.root.add_child(new_mgr)
	elif context is Node and context.get_tree() != null:
		context.get_tree().root.add_child(new_mgr)
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


func _init_pool() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer2D.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = "Master"
		add_child(p)
		_players.append(p)


func _load_sound_assets() -> void:
	for key in SOUND_PATHS:
		var path: String = SOUND_PATHS[key]
		if ResourceLoader.exists(path):
			var res := load(path)
			if res is AudioStream:
				_streams[key] = res
	# Register synthetic procedural fallback sounds for tactile responsiveness
	_streams["slash_1"] = _generate_synthetic_tone(440.0, 0.08, 0.4)
	_streams["slash_2"] = _generate_synthetic_tone(554.37, 0.10, 0.45)
	_streams["smash_3"] = _generate_synthetic_tone(659.25, 0.16, 0.6)
	_streams["counter_hit"] = _generate_synthetic_tone(880.0, 0.14, 0.7)
	_streams["pogo_bounce"] = _generate_synthetic_tone(523.25, 0.12, 0.5)
	_streams["player_hurt"] = _generate_synthetic_tone(220.0, 0.15, 0.5)

	# Heavy tactile impact sound effects for combat feedback
	_streams["hit_slash"] = _generate_impact_sound(380.0, 80.0, 0.12, 0.45, 0.85)
	_streams["hit_heavy"] = _generate_impact_sound(480.0, 50.0, 0.18, 0.65, 0.95)
	_streams["counter_impact"] = _generate_impact_sound(620.0, 110.0, 0.22, 0.75, 1.0)
	_streams["pogo_hit"] = _generate_impact_sound(420.0, 140.0, 0.14, 0.50, 0.85)

	# Procedural dynamic background music tracks
	_streams["bgm_exploration"] = _generate_synthetic_loop(110.0, 1.2, 0.25)
	_streams["bgm_boss"] = _generate_synthetic_loop(146.83, 0.6, 0.35)


func play_sfx(sound_name: String, at_position: Vector2 = Vector2.ZERO) -> void:
	if not _streams.has(sound_name):
		return
	var stream: AudioStream = _streams[sound_name]
	if stream == null:
		return

	# Pick an idle player from pool
	for p in _players:
		if not p.playing:
			p.position = at_position
			p.stream = stream
			p.play()
			return

	# Steal first player if all busy
	if not _players.is_empty():
		_players[0].position = at_position
		_players[0].stream = stream
		_players[0].play()


func play_music(bgm_name: String) -> void:
	if _current_bgm == bgm_name:
		return
	var stream_key := "bgm_" + bgm_name if not bgm_name.begins_with("bgm_") else bgm_name
	if not _streams.has(stream_key):
		return
	_current_bgm = bgm_name
	if _bgm_player != null:
		_bgm_player.stream = _streams[stream_key]
		_bgm_player.play()


func stop_music() -> void:
	_current_bgm = ""
	if _bgm_player != null:
		_bgm_player.stop()


## Static convenience wrappers
static func play(sound_name: String, at_position: Vector2 = Vector2.ZERO) -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.play_sfx(sound_name, at_position)


static func bgm(track_name: String) -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.play_music(track_name)


static func stop_bgm() -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.stop_music()


static func set_master_volume(linear_val: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		var db := linear_to_db(clampf(linear_val, 0.0001, 1.0)) if linear_val > 0.01 else -80.0
		AudioServer.set_bus_volume_db(bus_idx, db)


static func set_bgm_volume(linear_val: float) -> void:
	if _instance != null and is_instance_valid(_instance) and _instance._bgm_player != null:
		var db := linear_to_db(clampf(linear_val, 0.0001, 1.0)) if linear_val > 0.01 else -80.0
		_instance._bgm_player.volume_db = db


## Generates a short procedural square/sine beep WAV for prototype feedback
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


## Generates a looping atmospheric dark-fantasy drone/pulse with layered harmonics for BGM
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
		# Deep sub-bass root + fifth harmony + soft overtone shimmer
		var sub := sin(2.0 * PI * (freq * 0.5) * t) * 0.45
		var root := sin(2.0 * PI * freq * t) * 0.35
		var fifth := sin(2.0 * PI * (freq * 1.4983) * t) * 0.20
		var octave := sin(2.0 * PI * (freq * 2.0) * t) * 0.12
		# Slow rhythmic swell / breathing modulation
		var swell := 0.75 + 0.25 * sin(2.0 * PI * (1.0 / duration) * t)
		var combined := (sub + root + fifth + octave) * swell * volume
		var value := int(clampf(combined, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)
	wav.data = data
	return wav


## Generates a punchy procedural impact / hit sound with pitch drop, sub-bass thump, and transient noise
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
		# Exponential pitch drop
		var current_freq := lerpf(start_freq, end_freq, pow(t, 0.4))
		phase += 2.0 * PI * current_freq / float(wav.mix_rate)
		var tonal := sin(phase)
		# Heavy low-end thump in first 25% of duration
		var thump := sin(2.0 * PI * 65.0 * (float(i) / float(wav.mix_rate))) * maxf(0.0, 1.0 - t * 4.0) * 0.40
		# Fast decaying transient noise burst for metal crunch
		var noise := randf_range(-1.0, 1.0) * pow(1.0 - t, 2.2) * noise_mix
		var envelope := pow(1.0 - t, 1.6)
		var sample := ((tonal + thump) * (1.0 - noise_mix * 0.4) + noise) * envelope * volume
		var value := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)
	wav.data = data
	return wav


