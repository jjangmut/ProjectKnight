extends SceneTree
# Before-state baseline capture script for V3-003
var campaign: Node3D = null
var stage: Node3D = null
var player: CharacterBody3D = null
var timer: float = 0.0
var output_dir: String = "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-003/captures/before"
var log_file_path: String = "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-003/logs/before_playtest_raw.log"
var csv_file_path: String = "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-003/logs/before_z_plane.csv"
var log_lines: Array[String] = []
var csv_lines: Array[String] = ["timestamp_s,player_x,player_y,player_z,player_vel_z,minion1_z,minion2_z,boss_z"]

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_run.call_deferred()

func _log(msg: String) -> void:
	var t = "[%.3f] %s" % [timer, msg]
	print(t)
	log_lines.append(t)

func _capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	if img != null:
		var p = output_dir.path_join(filename)
		var err = img.save_png(p)
		_log("Captured screenshot: " + filename + " err=" + str(err))

func _run() -> void:
	_log("=== V3-003 BEFORE-STATE BASELINE CAPTURE START ===")
	var title = load("res://scenes/ui/TitleScreen.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await create_timer(0.3).timeout
	await _capture("00_title.png")
	title.queue_free()
	await process_frame

	campaign = load("res://scenes/side_quarter_view/SideQVCampaign.tscn").instantiate()
	root.add_child(campaign)
	current_scene = campaign
	await create_timer(0.4).timeout

	stage = campaign.get("current_stage_instance")
	if stage != null:
		player = stage.get("player")
	
	_log("Loaded Stage 1 into campaign: stage=" + str(stage) + " player=" + str(player))
	await _capture("01_stage_entry.png")

	# Move player in X and Z to demonstrate depth steering
	Input.action_press("move_right")
	Input.action_press("move_down") # Steering in Z
	for i in range(30):
		await process_frame
		timer += 1.0 / 60.0
		if player != null:
			csv_lines.append("%.3f,%.3f,%.3f,%.3f,%.3f,0.0,0.0,0.0" % [
				timer, player.global_position.x, player.global_position.y,
				player.global_position.z, player.velocity.z
			])
	await _capture("02_movement_plane_depth.png")
	Input.action_release("move_right")
	Input.action_release("move_down")

	# Check mobile UI controls
	await _capture("03_touch_controls_check.png")

	# Attack minions
	Input.action_press("attack")
	await create_timer(0.2).timeout
	Input.action_release("attack")
	await create_timer(0.3).timeout
	await _capture("04_wave1_combat.png")

	# Advance to boss arena (X > 8.0)
	if player != null:
		player.global_position.x = 9.5
		player.global_position.z = 0.5
	await create_timer(0.5).timeout
	await _capture("05_boss_arena_occlusion.png")

	# Check Pillar_FrontRight occlusion
	var pillar = stage.get_node_or_null("Pillar_FrontRight")
	if pillar != null:
		_log("Found Pillar_FrontRight at: " + str(pillar.global_position))
	
	_log("=== BEFORE-STATE BASELINE CAPTURE COMPLETE ===")
	# Save logs
	var f = FileAccess.open(log_file_path, FileAccess.WRITE)
	if f != null:
		for l in log_lines:
			f.store_line(l)
		f.close()
	var f_csv = FileAccess.open(csv_file_path, FileAccess.WRITE)
	if f_csv != null:
		for l in csv_lines:
			f_csv.store_line(l)
		f_csv.close()
	quit()
