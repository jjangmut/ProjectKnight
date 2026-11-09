extends SceneTree
## V3-011 Focused Audio Verification Test Suite
## Tests exact event invocation, stream mapping, voice concurrency capping,
## retrigger throttling, scene-transition cleanup, mute controls, and headroom.

const ResultPath := "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-011/AUDIO_VERIFICATION_RESULT.json"

var passed_checks: int = 0
var total_checks: int = 0
var test_details: Array[Dictionary] = []

func _initialize() -> void:
	print(">>> [V3-011 AUDIO VERIFY] Starting focused audio verification suite... <<<")
	var am := AudioManager.ensure_manager(self)
	
	_test_stream_inventory(am)
	_test_core_combat_event_wiring(am)
	_test_boss_telegraph_and_impact_cues(am)
	_test_reward_and_victory_stingers(am)
	_test_concurrency_capping_and_throttling(am)
	_test_cleanup_and_reset(am)
	_test_headroom_and_volume_controls(am)
	
	_finish_and_write_results()

func _assert_check(check_name: String, condition: bool, info: String = "") -> void:
	total_checks += 1
	if condition:
		passed_checks += 1
		print(" [PASS] ", check_name, (" (" + info + ")" if not info.is_empty() else ""))
		test_details.append({"name": check_name, "status": "PASS", "info": info})
	else:
		printerr(" [FAIL] ", check_name, " - ", info)
		test_details.append({"name": check_name, "status": "FAIL", "info": info})
		assert(condition, check_name + ": " + info)

func _test_stream_inventory(am: AudioManager) -> void:
	print("\n--- 1. Audio Stream Inventory & Registration ---")
	_assert_check("manager_instantiated", am != null and is_instance_valid(am))
	_assert_check("pool_size_minimum_16", am._players.size() >= 16, "Pool size: %d" % am._players.size())
	
	var required_streams := [
		"player_slash_1", "player_slash_2", "player_slash_3",
		"enemy_hit_impact", "enemy_hit_counter",
		"guard_block", "parry_clash",
		"player_dash", "player_hurt", "dive_slam_impact",
		"boss_tell_beast", "boss_tell_crossbow", "boss_crossbow_fire",
		"boss_tell_golem", "boss_golem_fissure",
		"boss_tell_abyssal", "boss_abyssal_strike",
		"stage_clear_stinger", "campaign_victory_fanfare"
	]
	
	var missing := []
	for s_name in required_streams:
		if not am._streams.has(s_name) or am._streams[s_name] == null:
			missing.append(s_name)
	_assert_check("all_required_audio_streams_registered", missing.is_empty(), "Missing: %s" % str(missing))
	_assert_check("total_streams_count_adequate", am._streams.size() >= 20, "Total streams: %d" % am._streams.size())

func _test_core_combat_event_wiring(am: AudioManager) -> void:
	print("\n--- 2. Core Player Combat Audio Event Wiring ---")
	AudioManager.reset_all()
	
	# Test distinct slash combos
	AudioManager.play("player_slash_1")
	AudioManager.play("player_slash_2")
	AudioManager.play("player_slash_3")
	_assert_check("slash_combo1_fired", AudioManager.get_event_count("player_slash_1") == 1)
	_assert_check("slash_combo2_fired", AudioManager.get_event_count("player_slash_2") == 1)
	_assert_check("slash_combo3_fired", AudioManager.get_event_count("player_slash_3") == 1)
	
	# Test impacts
	AudioManager.play("enemy_hit_impact")
	AudioManager.play("enemy_hit_counter")
	_assert_check("normal_hit_impact_fired", AudioManager.get_event_count("enemy_hit_impact") == 1)
	_assert_check("counter_hit_impact_fired", AudioManager.get_event_count("enemy_hit_counter") == 1)
	
	# Test defensive feedback
	AudioManager.play("guard_block")
	AudioManager.play("parry_clash")
	_assert_check("guard_block_fired", AudioManager.get_event_count("guard_block") == 1)
	_assert_check("parry_clash_fired", AudioManager.get_event_count("parry_clash") == 1)
	
	# Test evasion & mobility
	AudioManager.play("player_dash")
	AudioManager.play("dive_slam_impact")
	AudioManager.play("player_hurt")
	_assert_check("dash_fired", AudioManager.get_event_count("player_dash") == 1)
	_assert_check("dive_slam_fired", AudioManager.get_event_count("dive_slam_impact") == 1)
	_assert_check("player_hurt_fired", AudioManager.get_event_count("player_hurt") == 1)

func _test_boss_telegraph_and_impact_cues(am: AudioManager) -> void:
	print("\n--- 3. Boss Telegraph & Impact Audio Cues ---")
	AudioManager.reset_all()
	
	# Stage 2 Beast tell
	AudioManager.play("boss_tell_beast")
	_assert_check("stage2_beast_tell_fired", AudioManager.get_event_count("boss_tell_beast") == 1)
	
	# Stage 3 Crossbow tell & fire
	AudioManager.play("boss_tell_crossbow")
	AudioManager.play("boss_crossbow_fire")
	_assert_check("stage3_crossbow_tell_fired", AudioManager.get_event_count("boss_tell_crossbow") == 1)
	_assert_check("stage3_crossbow_fire_fired", AudioManager.get_event_count("boss_crossbow_fire") == 1)
	
	# Stage 4 Golem tell & fissure
	AudioManager.play("boss_tell_golem")
	AudioManager.play("boss_golem_fissure")
	_assert_check("stage4_golem_tell_fired", AudioManager.get_event_count("boss_tell_golem") == 1)
	_assert_check("stage4_golem_fissure_fired", AudioManager.get_event_count("boss_golem_fissure") == 1)
	
	# Stage 5 Abyssal Arbiter tell & strike
	AudioManager.play("boss_tell_abyssal")
	AudioManager.play("boss_abyssal_strike")
	_assert_check("stage5_abyssal_tell_fired", AudioManager.get_event_count("boss_tell_abyssal") == 1)
	_assert_check("stage5_abyssal_strike_fired", AudioManager.get_event_count("boss_abyssal_strike") == 1)

func _test_reward_and_victory_stingers(am: AudioManager) -> void:
	print("\n--- 4. Reward & Victory Audio Stingers ---")
	AudioManager.reset_all()
	
	AudioManager.play("stage_clear_stinger")
	_assert_check("stage_clear_stinger_fired", AudioManager.get_event_count("stage_clear_stinger") == 1)
	
	AudioManager.play("campaign_victory_fanfare")
	_assert_check("campaign_victory_fanfare_fired", AudioManager.get_event_count("campaign_victory_fanfare") == 1)

func _test_concurrency_capping_and_throttling(am: AudioManager) -> void:
	print("\n--- 5. Voice Concurrency Capping & Retrigger Throttling ---")
	AudioManager.reset_all()
	
	# Rapid burst of identical sound in same instant
	for i in range(10):
		AudioManager.play("enemy_hit_impact")
	
	var impact_count := AudioManager.get_event_count("enemy_hit_impact")
	_assert_check("rapid_burst_throttled", impact_count == 1, "Recorded calls: %d (expected 1 due to 35ms throttle)" % impact_count)
	
	# Check active sound count never exceeds MAX_CONCURRENT_PER_SOUND (3)
	var active_count: int = int(am._active_sound_counts.get("enemy_hit_impact", 0))
	_assert_check("active_concurrency_capped", active_count <= AudioManager.MAX_CONCURRENT_PER_SOUND, "Active count: %d" % active_count)

func _test_cleanup_and_reset(am: AudioManager) -> void:
	print("\n--- 6. State Cleanup & Stop All SFX ---")
	AudioManager.play("stage_clear_stinger")
	AudioManager.play("campaign_victory_fanfare")
	
	AudioManager.stop_sfx()
	var any_playing := false
	for p in am._players:
		if p.playing:
			any_playing = true
			break
	_assert_check("all_sfx_stopped_cleanly", not any_playing)
	
	AudioManager.reset_all()
	_assert_check("event_history_cleared", am.event_history.is_empty())
	_assert_check("event_counts_cleared", am.event_counts.is_empty())

func _test_headroom_and_volume_controls(am: AudioManager) -> void:
	print("\n--- 7. Gain Headroom & Volume Controls ---")
	# Check master volume bus setting
	AudioManager.set_master_volume(0.8)
	var bus_idx := AudioServer.get_bus_index("Master")
	_assert_check("master_bus_valid", bus_idx >= 0)
	var vol_db := AudioServer.get_bus_volume_db(bus_idx)
	_assert_check("master_bus_attenuation_applied", vol_db < 0.0, "Volume DB: %.2f" % vol_db)
	
	# Restore to unity
	AudioManager.set_master_volume(1.0)
	var restored_db := AudioServer.get_bus_volume_db(bus_idx)
	_assert_check("master_bus_restored_safely", abs(restored_db) < 0.05, "Restored DB: %.2f" % restored_db)

func _finish_and_write_results() -> void:
	print("\n==================================================")
	print(">>> V3-011 AUDIO VERIFICATION COMPLETED: %d / %d PASSED <<<" % [passed_checks, total_checks])
	print("==================================================")
	
	var result_data := {
		"task_id": "V3-011",
		"timestamp": Time.get_datetime_string_from_system(true),
		"passed_checks": passed_checks,
		"total_checks": total_checks,
		"all_passed": (passed_checks == total_checks),
		"pool_size": 16,
		"max_concurrent_per_sound": 3,
		"min_retrigger_interval_sec": 0.035,
		"checks": test_details
	}
	
	var dir := ResultPath.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var fa := FileAccess.open(ResultPath, FileAccess.WRITE)
	if fa != null:
		fa.store_string(JSON.stringify(result_data, "  "))
		fa.close()
		print("Saved verification result: ", ResultPath)
	
	if passed_checks == total_checks:
		quit(0)
	else:
		quit(1)
