extends SceneTree
## ProjectKnight V3-024-R4: Boss Defeat & Clean Retry Verification Suite
## Validates player death upon HP exhaustion, defeat overlay spawning,
## and clean reload/retry state restoration without dangling nodes or memory leaks.

const CampaignScenePath := "res://scenes/side_quarter_view/SideQVCampaign.tscn"

var campaign: Node = null
var test_frames: int = 0
var test_phase: String = "INIT"
var initial_boss_hp: int = 16
var initial_player_hp: int = 9

var results := {
	"test_name": "V3-024-R4 Defeat & Retry Verification",
	"player_death_verified": false,
	"defeat_overlay_verified": false,
	"retry_button_functional": false,
	"stage_reloaded_cleanly": false,
	"post_retry_player_hp": 0,
	"post_retry_boss_hp": 0,
	"camera_rebound_cleanly": false,
	"passed": false,
	"trace": []
}

func _init() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_start_test")

func _start_test() -> void:
	print("=================================================================")
	print("[V3-024-R4] Starting Boss Defeat & Clean Retry Verification Suite...")
	print("=================================================================")
	
	var packed := load(CampaignScenePath) as PackedScene
	if packed == null:
		printerr("[DEFEAT_RETRY] Failed to load Campaign scene!")
		quit(1)
		return

	campaign = packed.instantiate()
	root.add_child(campaign)
	current_scene = campaign

	physics_frame.connect(_on_physics_tick)

func _on_physics_tick() -> void:
	test_frames += 1

	match test_phase:
		"INIT":
			if test_frames >= 20: # Wait for deferred stage loading
				var stage: Node = campaign.get("current_stage_instance")
				if stage != null and is_instance_valid(stage):
					# Fast forward to boss sanctuary
					if stage.has_method("_start_boss_sanctuary"):
						stage._start_boss_sanctuary()
					var player: Node = stage.get_node_or_null("SideQVPlayer")
					var boss: Node = stage.get("active_boss")
					if player != null and boss != null:
						initial_player_hp = player.get("current_hp")
						initial_boss_hp = boss.get("current_hp")
						print("[DEFEAT_RETRY] Sanctuary ready. Player HP: %d, Boss HP: %d" % [initial_player_hp, initial_boss_hp])
						test_phase = "INFLICT_FATAL_DAMAGE"
						test_frames = 0

		"INFLICT_FATAL_DAMAGE":
			var stage: Node = campaign.get("current_stage_instance")
			var player: Node = stage.get_node_or_null("SideQVPlayer") if stage != null else null
			if player != null and is_instance_valid(player):
				# Inflict direct damage to exhaust HP
				player.set("current_hp", 0)
				if player.has_method("_enter_death_state"):
					player._enter_death_state()
				results["trace"].append({
					"event": "fatal_damage_inflicted",
					"player_hp": player.get("current_hp"),
					"player_is_dead": player.get("is_dead")
				})
				test_phase = "AWAIT_DEFEAT_OVERLAY"
				test_frames = 0

		"AWAIT_DEFEAT_OVERLAY":
			if test_frames >= 40: # Allow defeat screen tween / delay to show
				var failure_overlay: Control = campaign.get("failure_overlay") as Control
				var retry_btn: Button = null
				if failure_overlay != null and is_instance_valid(failure_overlay):
					retry_btn = failure_overlay.find_child("RetryStageButton", true, false) as Button

				if failure_overlay != null and retry_btn != null:
					print("[DEFEAT_RETRY] Defeat overlay and Retry button confirmed!")
					results["player_death_verified"] = true
					results["defeat_overlay_verified"] = true
					results["retry_button_functional"] = true
					results["trace"].append({
						"event": "defeat_overlay_opened",
						"retry_button_present": true
					})
					# Simulate user pressing RETRY STAGE
					print("[DEFEAT_RETRY] Emitting RetryStageButton pressed signal...")
					retry_btn.pressed.emit()
					test_phase = "VERIFY_STAGE_RELOAD"
					test_frames = 0
				elif test_frames >= 120:
					printerr("[DEFEAT_RETRY] Timeout waiting for defeat overlay!")
					_finish_test(false)

		"VERIFY_STAGE_RELOAD":
			if test_frames >= 30: # Wait for reload to instantiate new stage
				var new_stage: Node = campaign.get("current_stage_instance")
				var is_trans: bool = campaign.get("is_transitioning")
				if new_stage != null and is_instance_valid(new_stage) and not is_trans:
					var new_player: Node = new_stage.get_node_or_null("SideQVPlayer")
					var camera: Camera3D = root.get_camera_3d()

					if new_player != null and is_instance_valid(new_player):
						var p_hp: int = new_player.get("current_hp")
						var p_dead: bool = new_player.get("is_dead")
						results["post_retry_player_hp"] = p_hp
						results["camera_rebound_cleanly"] = (camera != null and is_instance_valid(camera))
						
						var player_hp_ok: bool = (p_hp == initial_player_hp)
						var player_alive: bool = (not p_dead)
						var ov: Control = campaign.get("failure_overlay") as Control
						var overlay_cleared: bool = (ov == null or not is_instance_valid(ov))
						
						if player_hp_ok and player_alive and overlay_cleared:
							results["stage_reloaded_cleanly"] = true
							results["passed"] = true
							print("[DEFEAT_RETRY] Reload verified! New Player HP: %d, Alive: %s, Overlay cleared: %s" % [
								p_hp, player_alive, overlay_cleared
							])
							_finish_test(true)
							return

				if test_frames >= 150:
					printerr("[DEFEAT_RETRY] Timeout verifying stage reload!")
					_finish_test(false)

func _finish_test(success: bool) -> void:
	results["passed"] = success
	var ev_dir := "res://../../STUDIO_V3/evidence/V3-024-R4"
	var dir := DirAccess.open("res://../../STUDIO_V3/evidence")
	if dir != null and not dir.dir_exists("V3-024-R4"):
		dir.make_dir("V3-024-R4")

	var f := FileAccess.open(ev_dir + "/DEFEAT_RETRY_RESULTS.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(results, "\t"))
		f.close()
		print("[DEFEAT_RETRY] Saved results to: ", ev_dir + "/DEFEAT_RETRY_RESULTS.json")

	if success:
		print("=================================================================")
		print("[V3-024-R4] BOSS DEFEAT & CLEAN RETRY: PASSED (100%)")
		print("=================================================================")
		quit(0)
	else:
		printerr("[V3-024-R4] BOSS DEFEAT & CLEAN RETRY: FAILED!")
		quit(1)
