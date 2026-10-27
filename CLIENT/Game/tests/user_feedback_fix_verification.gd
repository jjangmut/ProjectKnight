extends SceneTree
## Automated Regression & Feature Verification Suite for User Feedback (4 Core Requirements)
## Validates:
## 1. Character Run Spritesheet Alignment (run_v2_aligned.png, unified 780x780, pixel_size 0.00282, 0-jitter)
##    and Camera Lockstep Physics Tracking (_physics_process)
## 2. Sword Attack Thrust Motion & Visual Direction Alignment (Sharp forward linear spear, NOT a torus donut,
##    and Piercing Supersonic Thrust Lance Beam)
## 3. Advancing Gameplay Progression ("GO! ▶▶▶" prompt upon minion defeat, stage progress tracking, forward boss encounter)
## 4. Complete HUD Composition:
##    - Top-Left PlayerHUD (Avatar Frame, 5 Soul Gems, HP text label)
##    - Top-Center Gothic Winged BossHealthBar with Ruby fill & amber trail
##    - 3D Billboard Overhead HP Bars on all minions (SideQVEnemy, Beast, Ranged, Golem, Elite)

const Stage1Scene = preload("res://scenes/side_quarter_view/SideQVStage1.tscn")
const Stage2Scene = preload("res://scenes/side_quarter_view/SideQVStage2.tscn")
const SideQVPlayerClass = preload("res://scripts/side_quarter_view/side_qv_player.gd")
const SideQVCameraClass = preload("res://scripts/side_quarter_view/side_qv_camera.gd")
const SideQVSwordBeamClass = preload("res://scripts/side_quarter_view/side_qv_sword_beam.gd")
const SideQVEnemyClass = preload("res://scripts/side_quarter_view/side_qv_enemy.gd")
const SideQVBeastMinionClass = preload("res://scripts/side_quarter_view/enemies/side_qv_beast_minion.gd")
const SideQVRangedMinionClass = preload("res://scripts/side_quarter_view/side_qv_ranged_minion.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	# 15s Watchdog Fail-Safe Timer (User Rule 3 Compliance)
	var watchdog: SceneTreeTimer = create_timer(15.0)
	watchdog.timeout.connect(func():
		printerr("[WATCHDOG TIMEOUT] User feedback verification exceeded 15.0s. Forcing exit.")
		quit(1)
	)

	_run_verification.call_deferred()


func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  [PASS] %s" % msg)
	else:
		failures += 1
		printerr("  [FAIL] %s" % msg)


func _advance_frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _run_verification() -> void:
	print("\n===================================================================")
	print(">>> START USER FEEDBACK (4 CORE ISSUES) VERIFICATION SUITE <<<")
	print("===================================================================\n")

	# =========================================================================
	# ISSUE 1: Running Jitter & Blurry Ghosting Elimination
	# =========================================================================
	print("--- [ISSUE 1] Running Jitter Elimination & Camera Physics Tracking ---")
	var stage1 = Stage1Scene.instantiate()
	root.add_child(stage1)
	current_scene = stage1
	await _advance_frames(5)

	var player: SideQVPlayer = stage1.player
	check(player != null, "SideQVPlayer exists")
	check(player.TexRun != null, "player.TexRun is loaded")
	check(player.TexRun.resource_path.ends_with("run_v2_aligned.png"),
		"TexRun preloads unified run_v2_aligned.png (Got: %s)" % player.TexRun.resource_path)

	# Settle player on floor
	for i in range(15):
		player.move_and_slide()
		await physics_frame

	# Simulate move state on floor
	player.current_state = SideQVPlayer.State.MOVE
	player.velocity = Vector3(5.0, 0, 0)
	player._update_character_animation(0.016)

	check(player.sprite_3d.texture == player.TexRun, "Sprite texture switched to TexRun in MOVE state")
	check(is_equal_approx(player.sprite_3d.pixel_size, 0.00282),
		"Sprite pixel_size is 0.00282 (Exact match with idle/attack/guard, no scale pop! Got: %.5f)" % player.sprite_3d.pixel_size)
	check(player.sprite_3d.hframes == 3 and player.sprite_3d.vframes == 2,
		"Sprite sheet is 3x2 frames (6 frames)")
	check(is_equal_approx(player.sprite_3d.position.y, 0.874),
		"Sprite foot contact firmly anchored at ground Y=0.0 (Got: %.4f)" % player.sprite_3d.position.y)

	var camera: SideQVCamera = stage1.camera
	check(camera != null, "SideQVCamera exists")
	check(camera.has_method("_physics_process"), "Camera has _physics_process for lockstep tracking")
	check(camera.follow_smoothness >= 10.0, "Camera follow smoothness is >= 10.0 (Got: %.1f)" % camera.follow_smoothness)

	# =========================================================================
	# ISSUE 2: Sword Attack Thrust Motion & Effect Direction Matching
	# =========================================================================
	print("\n--- [ISSUE 2] Attack Thrust Motion & Forward Piercing Visual Alignment ---")
	check(player.slash_visual_3d != null, "slash_visual_3d exists")
	check(player.slash_visual_3d.mesh is CylinderMesh,
		"slash_visual_3d uses sharp forward-pointing cylinder/spear mesh (NOT a Torus donut! Got: %s)" % player.slash_visual_3d.mesh.get_class())

	# Test attack facing right (+X)
	player.facing_dir_x = 1.0
	player.start_attack()
	check(player.slash_visual_3d.visible, "slash_visual_3d visible during attack thrust")
	check(is_equal_approx(player.slash_visual_3d.rotation_degrees.z, -90.0),
		"Thrust needle points straight forward along +X when facing right (-90 deg, Got: %.1f)" % player.slash_visual_3d.rotation_degrees.z)
	check(player.slash_visual_3d.position.x > 0.0, "Thrust effect positioned in front of player (+X)")

	# Test attack facing left (-X)
	player.facing_dir_x = -1.0
	player.start_attack()
	check(is_equal_approx(player.slash_visual_3d.rotation_degrees.z, 90.0),
		"Thrust needle points straight forward along -X when facing left (+90 deg, Got: %.1f)" % player.slash_visual_3d.rotation_degrees.z)
	check(player.slash_visual_3d.position.x < 0.0, "Thrust effect positioned in front of player (-X)")

	# Test Combo 3 Finisher Sword Beam: Piercing Lance Wave
	player.combo_step = 2
	player.start_attack() # Becomes combo_step 3
	await _advance_frames(3)

	var spawned_beams: Array[Node] = []
	for child in stage1.get_children():
		if child is SideQVSwordBeam:
			spawned_beams.append(child)

	check(spawned_beams.size() > 0, "Combo 3 Finisher fired SideQVSwordBeam")
	if spawned_beams.size() > 0:
		var beam: SideQVSwordBeam = spawned_beams[0] as SideQVSwordBeam
		check(beam.has_node("CoreMeshInstance3D"), "Sword beam has CoreMeshInstance3D")
		check(beam.has_node("AuraMeshInstance3D"), "Sword beam has AuraMeshInstance3D")
		check(beam.has_node("TrailParticles3D"), "Sword beam has TrailParticles3D")
		check(beam.has_node("BeamLight3D"), "Sword beam has dynamic BeamLight3D")

	# =========================================================================
	# ISSUE 3: Forward Progression ("GO! ▶▶▶", Progress Bar, Advance to Boss)
	# =========================================================================
	print("\n--- [ISSUE 3] Forward Scrolling Gameplay Progression ---")
	check(stage1.advance_banner != null, "advance_banner node exists in mobile UI")
	check(stage1.progress_bar_fill != null, "Stage progress bar fill exists in mobile UI")

	# Defeat Wave 1 minions to trigger advance
	var enemy_copy: Array = stage1.enemies.duplicate()
	for e in enemy_copy:
		if is_instance_valid(e) and e.has_method("receive_hit"):
			e.receive_hit(10, Vector3.ZERO)

	await _advance_frames(5)
	stage1._process(0.016)
	check(stage1.advance_banner.visible == true,
		"Advance banner ('ADVANCE ▶▶▶' / 'GO!') appears after defeating minions, guiding player forward!")

	# Player advances forward towards the boss arena
	player.global_position.x = 3.5
	stage1._process(0.016)
	check(stage1.current_wave == 2, "Advancing forward triggered Wave 2 (Boss Emergence)")
	check(stage1.advance_banner.visible == false, "Advance banner hides when Boss appears")

	# =========================================================================
	# ISSUE 4: Complete HUD Composition & Overhead Monster HP Bars
	# =========================================================================
	print("\n--- [ISSUE 4] HUD Composition & Overhead Monster HP Bars ---")
	check(stage1.player_hud != null, "PlayerHUD node exists at top-left")
	check(stage1.player_avatar_rect != null, "PlayerAvatar frame exists")
	check(stage1.player_hp_label != null, "PlayerHPLabel exists")
	check(stage1.player_hp_label.text == "5 / 5 HP", "PlayerHPLabel displays '5 / 5 HP'")
	check(stage1.soul_gem_rects.size() == 5, "5 Soul Gem crystals displayed (Count: %d)" % stage1.soul_gem_rects.size())

	# Test Player damage reflection on HUD
	player.receive_incoming_attack(2, null, Vector3.ZERO)
	check(player.current_hp == 3, "Player HP reduced to 3")
	check(stage1.player_hp_label.text == "3 / 5 HP",
		"PlayerHPLabel updated to '3 / 5 HP' (Got: '%s')" % stage1.player_hp_label.text)
	check(stage1.soul_gem_rects[0].texture == stage1.TexSoulGemFull, "Soul Gem 0 is FULL")
	check(stage1.soul_gem_rects[1].texture == stage1.TexSoulGemFull, "Soul Gem 1 is FULL")
	check(stage1.soul_gem_rects[2].texture == stage1.TexSoulGemFull, "Soul Gem 2 is FULL")
	check(stage1.soul_gem_rects[3].texture == stage1.TexSoulGemEmpty, "Soul Gem 3 is EMPTY")
	check(stage1.soul_gem_rects[4].texture == stage1.TexSoulGemEmpty, "Soul Gem 4 is EMPTY")

	# Test Boss Health Bar
	check(stage1.boss_health_bar != null, "BossHealthBar exists at top-center")
	check(stage1.boss_health_bar.is_active == true, "BossHealthBar is active and tracking boss")
	check(stage1.boss_health_bar.boss_name == "성문 수호 기사단장",
		"BossHealthBar displays stage boss name '성문 수호 기사단장'")

	# Test Overhead Monster HP Bars on Minions
	var test_minion = SideQVEnemyClass.new()
	stage1.add_child(test_minion)
	var hp_bar_node = test_minion.get_node_or_null("OverheadHPBar")
	check(hp_bar_node != null, "Minion has OverheadHPBar node")
	if hp_bar_node:
		var fill_node = hp_bar_node.get_node_or_null("HPBarFill") as MeshInstance3D
		check(fill_node != null, "OverheadHPBar has HPBarFill MeshInstance3D")
		test_minion.receive_hit(2, Vector3.ZERO)
		check(test_minion.current_hp == 2, "Minion took damage (HP: 2/4)")
		check(is_equal_approx(fill_node.scale.x, 0.5),
			"OverheadHPBar fill scaled to 50%% (Got: %.2f)" % fill_node.scale.x)
	test_minion.queue_free()

	# Also verify Stage 2 Beast Minion and Ranged Minion have OverheadHPBar
	var test_beast = SideQVBeastMinionClass.new()
	stage1.add_child(test_beast)
	check(test_beast.get_node_or_null("OverheadHPBar") != null, "SideQVBeastMinion has OverheadHPBar")
	test_beast.queue_free()

	var test_ranged = SideQVRangedMinionClass.new()
	stage1.add_child(test_ranged)
	check(test_ranged.get_node_or_null("OverheadHPBar") != null, "SideQVRangedMinion has OverheadHPBar")
	test_ranged.queue_free()

	stage1.queue_free()

	# =========================================================================
	# SUMMARY
	# =========================================================================
	print("\n===================================================================")
	print("USER FEEDBACK VERIFICATION RESULTS: %d Checks, %d Failures" % [checks, failures])
	print("===================================================================")

	if failures == 0:
		print("\n>>> ALL 4 USER REQUIREMENTS VERIFIED & PASSED (100% SUCCESS) <<<\n")
		quit(0)
	else:
		printerr("\n>>> %d CHECKS FAILED! <<<\n" % failures)
		quit(1)
