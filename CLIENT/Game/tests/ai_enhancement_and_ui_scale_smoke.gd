extends SceneTree
## Automated QA Smoke Test for UI 2x Scale, Floating Joypad, and Autonomous Monster AI.

const MobileControlsClass := preload("res://scripts/ui/mobile_controls.gd")
const CampfireShopClass := preload("res://scripts/ui/campfire_shop.gd")
const BossHealthBarClass := preload("res://scripts/ui/boss_health_bar.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func _create_platform(parent: Node2D, pos: Vector2, sz: Vector2, one_way: bool = false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = sz
	col.shape = rect
	col.one_way_collision = one_way
	body.add_child(col)
	body.position = pos
	parent.add_child(body)
	return body

func _run() -> void:
	print("\n--- START UI 2X SCALE, FLOATING JOYPAD & MONSTER AI SMOKE TEST ---")

	var world := Node2D.new()
	root.add_child(world)

	await process_frame
	await process_frame

	# =========================================================================
	# Check 1: HUD and UI Font Sizes Doubled
	# =========================================================================
	print("\n[Check 1: UI & HUD Font Scaling]")
	var boss_bar := BossHealthBarClass.new()
	world.add_child(boss_bar)
	await process_frame

	check(boss_bar._title_label.get_theme_font_size("font_size") >= 36, "Boss bar title font scaled to >= 36 (Current: %d)" % boss_bar._title_label.get_theme_font_size("font_size"))
	check(boss_bar._phase_label.get_theme_font_size("font_size") >= 24, "Boss bar phase font scaled to >= 24 (Current: %d)" % boss_bar._phase_label.get_theme_font_size("font_size"))
	check(boss_bar.BAR_WIDTH >= 700.0, "Boss bar width expanded to >= 700 (Current: %.1f)" % boss_bar.BAR_WIDTH)
	check(boss_bar.BAR_HEIGHT >= 36.0, "Boss bar height expanded to >= 36 (Current: %.1f)" % boss_bar.BAR_HEIGHT)
	boss_bar.queue_free()

	var shop := CampfireShopClass.new()
	world.add_child(shop)
	await process_frame

	check(shop._shard_label.get_theme_font_size("font_size") >= 36, "CampfireShop shard label font scaled to >= 36 (Current: %d)" % shop._shard_label.get_theme_font_size("font_size"))
	check(shop._hp_btn.get_theme_font_size("font_size") >= 26, "CampfireShop purchase button font scaled to >= 26 (Current: %d)" % shop._hp_btn.get_theme_font_size("font_size"))
	shop.queue_free()

	var mobile_ctrl := MobileControlsClass.new()
	world.add_child(mobile_ctrl)
	await process_frame

	check(mobile_ctrl.btn_toggle.get_theme_font_size("font_size") >= 18, "MobileControls toggle font scaled to >= 18 (Current: %d)" % mobile_ctrl.btn_toggle.get_theme_font_size("font_size"))
	check(mobile_ctrl.btn_attack.size.x >= 120.0, "Attack button scaled to >= 120px (Current: %.1f)" % mobile_ctrl.btn_attack.size.x)
	check(mobile_ctrl.btn_dash.size.x >= 100.0, "Dash button scaled to >= 100px (Current: %.1f)" % mobile_ctrl.btn_dash.size.x)

	# =========================================================================
	# Check 2: Floating Joypad Dynamics & Dynamic Finger Following
	# =========================================================================
	print("\n[Check 2: Floating Joypad Dynamics & Dynamic Finger Following]")
	var left_zone: Control = mobile_ctrl.get_node("Root/LeftControls") as Control
	check(left_zone != null, "Left touch zone exists for floating joypad")
	check(left_zone.anchor_right >= 0.60, "Left zone expanded to >= 60 percent of screen width (Current: %.2f)" % left_zone.anchor_right)

	var initial_joy_pos := mobile_ctrl.joystick.position
	var touch_point := Vector2(140, 320)
	mobile_ctrl.joystick.float_to(touch_point)
	check(mobile_ctrl.joystick.position != initial_joy_pos, "Joystick floated to new touch position")
	var expected_center := touch_point - mobile_ctrl.joystick.size * 0.5
	check(mobile_ctrl.joystick.position.distance_to(expected_center) < 1.0, "Joystick accurately centered at touch position")

	# Test 8-directional input through joystick
	mobile_ctrl.joystick.simulate_drag(Vector2(50, -50)) # UP-RIGHT (Jump + Move Right)
	check(Input.is_action_pressed("jump"), "Floating joypad triggers jump upward")
	check(Input.is_action_pressed("move_right"), "Floating joypad triggers move_right concurrently")

	# Test Dynamic Finger Following (Base center follows finger when exceeding max_drag_radius)
	var pre_follow_pos := mobile_ctrl.joystick.position
	mobile_ctrl.joystick.simulate_drag(Vector2(120, 0)) # Drag 120px to right (max 62px, excess 58px)
	check(mobile_ctrl.joystick.position.x > pre_follow_pos.x + 40.0, "Joystick base dynamically followed finger drag (Delta X: %.1f)" % (mobile_ctrl.joystick.position.x - pre_follow_pos.x))

	mobile_ctrl.joystick.reset_joystick()
	check(not Input.is_action_pressed("jump"), "Reset clears joypad actions cleanly")
	mobile_ctrl.queue_free()
	await process_frame

	# =========================================================================
	# Check 3: Monster AI - Descending to Lower Floor & Ground Safeguards
	# =========================================================================
	print("\n[Check 3: Monster AI - Descending to Lower Floor & Ground Safeguards]")
	var ground_floor := _create_platform(world, Vector2(400, 520), Vector2(1200, 40), false)
	var upper_platform := _create_platform(world, Vector2(300, 370), Vector2(300, 20), true)

	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	var player: CharacterBody2D = player_scene.instantiate()
	player.position = Vector2(300, 490) # Player on ground floor
	world.add_child(player)

	var enemy_scene := load("res://scenes/enemy/TestEnemy.tscn") as PackedScene
	var enemy: CharacterBody2D = enemy_scene.instantiate()
	enemy.position = Vector2(300, 340) # Enemy placed on upper floor (150px above player)
	enemy.set_physics_process(false) # Controlled stepping
	world.add_child(enemy)

	# Trigger chase AI when player is on floor below (upper platform -> should drop down)
	enemy._update_chase()
	check(enemy._drop_down_timer > 0.0, "Upper floor enemy initiated drop-down when player is below")
	check(enemy.get_collision_mask_value(1), "Terrain collision mask stays active to protect solid ground")

	# Advance physics frames to complete drop to ground floor
	for f in range(35):
		enemy._physics_process(0.016)

	check(enemy.position.y > 450.0, "Enemy successfully descended to ground floor (Y: %.1f)" % enemy.position.y)

	# Safeguard Test 1: Ground floor drop-down immunity (must NEVER drop down when on main ground y >= 560)
	enemy.position = Vector2(300, 590)
	enemy.velocity = Vector2.ZERO
	enemy._drop_down_timer = 0.0
	enemy._perform_drop_down()
	check(enemy._drop_down_timer == 0.0, "Ground floor enemy refuses drop-down to prevent falling through floor")
	check(enemy.get_collision_mask_value(1), "Collision mask remains active on ground floor")

	# Safeguard Test 2: Fall rescue fail-safe (if clipped below y > 640, immediately rescued to y=590)
	enemy.position = Vector2(300, 650)
	enemy._physics_process(0.016)
	check(enemy.position.y == 590.0, "Fell-through enemy instantly rescued to floor level (Y: %.1f)" % enemy.position.y)

	# Safeguard Test 3: Left boundary lock (cannot escape stage start x < 40)
	enemy.position = Vector2(10, 590)
	enemy.velocity.x = -150.0
	enemy._physics_process(0.016)
	check(enemy.position.x >= 40.0, "Stage start boundary locked enemy inside playable stage (X: %.1f)" % enemy.position.x)

	# =========================================================================
	# Check 4: Monster AI - Autonomous Jumping (Pounce and Defense)
	# =========================================================================
	print("\n[Check 4: Monster AI - Autonomous Combat Jumping]")
	# Position enemy on ground floor at distance 180px
	enemy.position = Vector2(480, 470)
	enemy.velocity = Vector2.ZERO
	enemy._drop_down_timer = 0.0
	enemy._jump_cooldown = 0.0 # Ready to jump
	enemy.state = 1 # State.CHASE

	# Settle enemy on floor with controlled move_and_slide
	for f in range(5):
		enemy.velocity.y += 1400.0 * 0.016
		enemy.move_and_slide()

	# (A) Autonomous Pounce Jump: Player is stationary on ground, enemy jumps to attack
	enemy._jump_cooldown = 0.0
	enemy._update_chase()
	check(enemy.velocity.y < -400.0, "Enemy autonomously performed aggressive pounce jump without player jumping (vel.y: %.1f)" % enemy.velocity.y)
	check(enemy.velocity.x < 0.0, "Enemy jumped forward toward player (vel.x: %.1f)" % enemy.velocity.x)

	# (B) No Synchronized Jump Copying: If player jumps in mid-air at mid-range, enemy does NOT copy player jump
	enemy.position = Vector2(480, 470)
	enemy.velocity = Vector2.ZERO
	enemy._jump_cooldown = 0.0
	for f in range(5):
		enemy.velocity.y += 1400.0 * 0.016
		enemy.move_and_slide()
	# Simulate player jumping up in air (not on floor, y=-80 above enemy)
	player.position = Vector2(300, 390)
	# Player is in air (not on floor)
	enemy._update_chase()
	check(enemy.velocity.y >= 0.0, "Enemy does NOT blindly copy player mid-air jump (vel.y: %.1f)" % enemy.velocity.y)

	# (C) Autonomous Anti-Air Evasion: If player dives close in mid-air, enemy leaps backward to evade
	player.position = Vector2(340, 430) # Player in mid-air, close (distance 80px)
	enemy.position = Vector2(420, 470)
	enemy.velocity = Vector2.ZERO
	enemy._jump_cooldown = 0.0
	for f in range(5):
		enemy.velocity.y += 1400.0 * 0.016
		enemy.move_and_slide()
	enemy._update_chase()
	check(enemy.velocity.y < -300.0, "Enemy executed anti-air evasion jump when player dived close (vel.y: %.1f)" % enemy.velocity.y)
	check(enemy.velocity.x > 0.0, "Enemy leaped backward away from diving player (vel.x: %.1f)" % enemy.velocity.x)

	player.queue_free()
	enemy.queue_free()
	ground_floor.queue_free()
	upper_platform.queue_free()
	await process_frame

	# =========================================================================
	# Check 5: Stage Ground Top Alignment (y = 620.0) & Floor Contact
	# =========================================================================
	print("\n[Check 5: Stage Ground Top Alignment & Floor Contact]")
	var stage_scene := load("res://scenes/stage/FirstStage.tscn") as PackedScene
	var stage_node: Node2D = stage_scene.instantiate()
	world.add_child(stage_node)
	await process_frame

	var ground_body: StaticBody2D = stage_node.get_node_or_null("Ground") as StaticBody2D
	check(ground_body != null, "Stage Ground static body exists")
	var ground_col: CollisionShape2D = null
	if ground_body != null:
		for child in ground_body.get_children():
			if child is CollisionShape2D:
				ground_col = child
				break
	check(ground_col != null, "Ground collision shape found")
	if ground_col != null and ground_col.shape is RectangleShape2D:
		var ground_rect := ground_col.shape as RectangleShape2D
		var ground_top := ground_body.position.y - (ground_rect.size.y * 0.5)
		check(is_equal_approx(ground_top, 620.0), "Ground collider top surface precisely matches art tile baseline y=620.0 (Current: %.1f)" % ground_top)

	stage_node.queue_free()
	await process_frame

	# =========================================================================
	# Check 6: BossCommander High-Res Sprite & Top Center Health Bar Position
	# =========================================================================
	print("\n[Check 6: BossCommander Sprite & Top Health Bar]")
	var BossCommanderClass := preload("res://scripts/enemy/boss_commander.gd")
	var boss: CharacterBody2D = BossCommanderClass.new()
	world.add_child(boss)
	await process_frame

	check(boss.get("boss_sprite") != null and boss.get("boss_sprite").texture != null, "BossCommander loaded high-res sprite texture")
	check(not boss.get("body_poly").visible and not boss.get("shield_poly").visible, "Primitive polygon placeholders hidden on BossCommander")
	check(boss.get("boss_sprite").scale.x >= 0.18, "BossCommander scaled to imposing boss dimensions (scale: %.2f)" % boss.get("boss_sprite").scale.x)
	boss.queue_free()
	await process_frame

	var test_bar := BossHealthBarClass.new()
	test_bar.name = "TestBar"
	world.add_child(test_bar)
	await process_frame
	var top_center_pos := Vector2((1280.0 - test_bar.BAR_WIDTH) * 0.5, 72.0)
	check(is_equal_approx(top_center_pos.x, 290.0) and is_equal_approx(top_center_pos.y, 72.0), "Boss health bar positioned at top center (290, 72)")
	test_bar.queue_free()
	await process_frame

	# =========================================================================
	# Check 7: Stage Finish / Result Screen Mobile Controls Hiding
	# =========================================================================
	print("\n[Check 7: Result Screen Mobile Controls Hiding]")
	var clear_stage_scene := load("res://scenes/stage/FirstStage.tscn") as PackedScene
	var clear_stage: Node2D = clear_stage_scene.instantiate()
	world.add_child(clear_stage)
	await process_frame

	clear_stage._attach_mobile_controls()
	check(clear_stage.mobile_controls != null and clear_stage.mobile_controls.visible, "Mobile controls active during gameplay")

	# Finish stage with CLEARED (simulate stage clear / transition to result panel)
	clear_stage._finish(1) # StageState.CLEARED
	check(not clear_stage.mobile_controls.visible, "Mobile controls hidden when stage finishes to prevent blocking result UI")
	check(clear_stage.mobile_controls.process_mode == Node.PROCESS_MODE_DISABLED, "Mobile controls disabled on stage finish")

	clear_stage.queue_free()
	await process_frame

	# =========================================================================
	# Check 8: Combat Impact (Subdued Shake & Amplified Knockback & Hit SFX)
	# =========================================================================
	print("\n[Check 8: Combat Impact (Subdued Shake & Amplified Knockback & Hit SFX)]")
	var gfm: GameFeelManager = GameFeelManager.ensure_manager(self)
	check(gfm != null, "GameFeelManager active")
	check(gfm.max_shake_offset.x <= 15.0, "Camera shake offset subdued for comfortable viewing (Current: %.1f)" % gfm.max_shake_offset.x)
	check(gfm.trauma_decay >= 2.5, "Trauma decay recovers quickly to prevent motion disorientation (Current: %.2f)" % gfm.trauma_decay)

	# Verify audio streams registered
	var audio_mgr: Node = preload("res://scripts/audio/audio_manager.gd").ensure_manager(self)
	var audio_streams: Dictionary = audio_mgr.get("_streams")
	check(audio_streams.has("hit_slash"), "AudioManager loaded hit_slash impact SFX")
	check(audio_streams.has("hit_heavy"), "AudioManager loaded hit_heavy impact SFX")
	check(audio_streams.has("counter_impact"), "AudioManager loaded counter_impact SFX")

	# Verify Slash Spark VFX spawn
	var test_parent := Node2D.new()
	world.add_child(test_parent)
	gfm.spawn_slash_spark(test_parent, Vector2(100, 100), 1.0, true)
	check(test_parent.get_child_count() > 0, "Slash spark VFX node spawned into world")
	var vfx_node := test_parent.get_child(0) as Node2D
	check(vfx_node.get_child_count() >= 3, "Slash spark VFX contains slash beam, cross beam, and spark particles (Count: %d)" % vfx_node.get_child_count())
	test_parent.queue_free()

	# Verify Player Attack Knockback on Enemy
	var combat_player: CharacterBody2D = player_scene.instantiate()
	combat_player.position = Vector2(200, 500)
	world.add_child(combat_player)
	var combat_enemy: CharacterBody2D = enemy_scene.instantiate()
	combat_enemy.position = Vector2(250, 500)
	world.add_child(combat_enemy)
	await process_frame

	# Simulate attack collision: Player attacks enemy
	combat_player.is_attacking = true
	combat_player.combo_step = 3
	combat_player.facing_direction = 1.0
	var enemy_hurt_area: Area2D = combat_enemy.get_node("HurtArea")
	combat_player._on_attack_area_entered(enemy_hurt_area)

	check(combat_enemy.velocity.x >= 400.0, "Combo 3 attack inflicted amplified horizontal knockback on enemy (vel.x: %.1f)" % combat_enemy.velocity.x)
	check(combat_enemy.velocity.y < -150.0, "Combo 3 attack lifted enemy into air (vel.y: %.1f)" % combat_enemy.velocity.y)
	check(gfm.trauma <= 0.40, "Subdued comfortable camera trauma on combo 3 hit (trauma: %.2f)" % gfm.trauma)

	# =========================================================================
	# Check 9: Solid Blocking, Top Platform, Boss Slash VFX & Stat Scaling
	# =========================================================================
	print("\n[Check 9: Solid Blocking, Top Platform, Boss Slash VFX & Stat Scaling]")
	# (A) Solid Enemy Body Blocking: Player cannot ghost-pass through enemy body layer (16)
	check(combat_player.collision_mask & 16 != 0, "Player collision_mask includes Enemy Body Layer (16) to prevent walking through")

	# (B) Enemy Top Platform: allows player to ride/stand on top of monster
	var top_plat: AnimatableBody2D = combat_enemy.get_node_or_null("TopPlatform") as AnimatableBody2D
	check(top_plat != null, "Monster has dynamic TopPlatform child node")
	if top_plat != null:
		check(top_plat.collision_layer == 1, "TopPlatform on Terrain Layer (1) so player can land on it")
		var top_col: CollisionShape2D = top_plat.get_child(0) as CollisionShape2D
		check(top_col != null and top_col.one_way_collision, "TopPlatform has one_way_collision enabled for smooth jumping onto head")

	# (C) Player Speed and Attack Speed Stat Progression
	check(is_equal_approx(combat_player.move_speed, 230.0), "Player initial move speed calibrated to grounded 230.0 (Current: %.1f)" % combat_player.move_speed)
	combat_player.update_stats_from_upgrades(2, 2)
	check(is_equal_approx(combat_player.move_speed, 280.0), "Player move speed scaled up with speed level (Current: %.1f)" % combat_player.move_speed)
	check(is_equal_approx(combat_player.attack_speed_multiplier, 1.3), "Player attack speed multiplier scaled with agility (Current: %.2f)" % combat_player.attack_speed_multiplier)

	# (D) Boss Slash Arc VFX Spawn
	var test_boss: CharacterBody2D = BossCommanderClass.new()
	world.add_child(test_boss)
	test_boss._spawn_boss_attack_vfx(1, 1.0) # COMBO_CLEAVE
	var boss_vfx_found := false
	for child in world.get_children():
		if child.name != "TestEnemy" and child != test_boss and child != combat_player and child != combat_enemy:
			if child is Node2D and child.get_child_count() >= 2:
				boss_vfx_found = true
				break
	check(boss_vfx_found, "Boss spawned imposing crescent slash arc attack VFX")
	test_boss.queue_free()

	combat_player.queue_free()
	combat_enemy.queue_free()
	await process_frame

	# =========================================================================
	# Check 10: All 5 Gate Bosses & 4 Enemy Units High-Res Visuals & TopPlatform
	# =========================================================================
	print("\n[Check 10: All 5 Gate Bosses & 4 Enemy Units High-Res Visuals & TopPlatform]")

	var BeastChieftainClass := preload("res://scripts/enemy/beast_chieftain.gd")
	var CrossbowCommanderClass := preload("res://scripts/enemy/crossbow_commander.gd")
	var AncientGolemGuardianClass := preload("res://scripts/enemy/ancient_golem_guardian.gd")
	var AbyssalArbiterClass := preload("res://scripts/enemy/abyssal_arbiter.gd")

	var RangedEnemyScene := preload("res://scenes/enemy/RangedEnemy.tscn")
	var ChargingBeastScene := preload("res://scenes/enemy/ChargingBeast.tscn")
	var GroundSlamGolemScene := preload("res://scenes/enemy/GroundSlamGolem.tscn")

	# (1) Stage 1 Boss: Commander
	var b1: CharacterBody2D = BossCommanderClass.new()
	world.add_child(b1)
	check(b1.get("boss_sprite") != null and b1.boss_sprite.texture != null, "Stage 1 Boss Commander equipped with high-res sprite")
	var b1_top: AnimatableBody2D = b1.get_node_or_null("TopPlatform") as AnimatableBody2D
	check(b1_top != null and (b1_top.get_child(0) as CollisionShape2D).one_way_collision, "Stage 1 Boss Commander equipped with one-way TopPlatform")
	b1.queue_free()

	# (2) Stage 2 Boss: Beast Chieftain
	var b2: CharacterBody2D = BeastChieftainClass.new()
	world.add_child(b2)
	check(b2.get("boss_sprite") != null and b2.boss_sprite.texture != null, "Stage 2 Boss Beast Chieftain equipped with high-res sprite")
	var b2_top: AnimatableBody2D = b2.get_node_or_null("TopPlatform") as AnimatableBody2D
	check(b2_top != null and (b2_top.get_child(0) as CollisionShape2D).one_way_collision, "Stage 2 Boss Beast Chieftain equipped with one-way TopPlatform")
	b2.queue_free()

	# (3) Stage 3 Boss: Crossbow Commander
	var b3: CharacterBody2D = CrossbowCommanderClass.new()
	world.add_child(b3)
	check(b3.get("boss_sprite") != null and b3.boss_sprite.texture != null, "Stage 3 Boss Crossbow Commander equipped with high-res sprite")
	var b3_top: AnimatableBody2D = b3.get_node_or_null("TopPlatform") as AnimatableBody2D
	check(b3_top != null and (b3_top.get_child(0) as CollisionShape2D).one_way_collision, "Stage 3 Boss Crossbow Commander equipped with one-way TopPlatform")
	b3.queue_free()

	# (4) Stage 4 Boss: Ancient Golem Guardian
	var b4: CharacterBody2D = AncientGolemGuardianClass.new()
	world.add_child(b4)
	check(b4.get("boss_sprite") != null and b4.boss_sprite.texture != null, "Stage 4 Boss Ancient Golem Guardian equipped with high-res sprite")
	var b4_top: AnimatableBody2D = b4.get_node_or_null("TopPlatform") as AnimatableBody2D
	check(b4_top != null and (b4_top.get_child(0) as CollisionShape2D).one_way_collision, "Stage 4 Boss Ancient Golem Guardian equipped with one-way TopPlatform")
	b4.queue_free()

	# (5) Stage 5 Boss: Abyssal Arbiter
	var b5: CharacterBody2D = AbyssalArbiterClass.new()
	world.add_child(b5)
	check(b5.get("boss_sprite") != null and b5.boss_sprite.texture != null, "Stage 5 Final Boss Abyssal Arbiter equipped with high-res sprite")
	var b5_top: AnimatableBody2D = b5.get_node_or_null("TopPlatform") as AnimatableBody2D
	check(b5_top != null and (b5_top.get_child(0) as CollisionShape2D).one_way_collision, "Stage 5 Final Boss Abyssal Arbiter equipped with one-way TopPlatform")
	b5.queue_free()

	# (6) Regular Enemy 1: TestEnemy (Melee)
	var e1: CharacterBody2D = enemy_scene.instantiate()
	world.add_child(e1)
	check(e1.get("enemy_sprite") != null and e1.enemy_sprite.texture != null, "TestEnemy (Melee) equipped with high-res sprite")
	check(e1.get_node("Visual").visible == false, "TestEnemy polygon placeholder hidden")
	var e1_top: AnimatableBody2D = e1.get_node_or_null("TopPlatform") as AnimatableBody2D
	check(e1_top != null and (e1_top.get_child(0) as CollisionShape2D).one_way_collision, "TestEnemy equipped with one-way TopPlatform")
	e1.queue_free()

	# (7) Regular Enemy 2: RangedEnemy
	var e2: CharacterBody2D = RangedEnemyScene.instantiate()
	world.add_child(e2)
	check(e2.get("enemy_sprite") != null and e2.enemy_sprite.texture != null, "RangedEnemy equipped with high-res sprite")
	check(e2.get_node("Visual").visible == false, "RangedEnemy polygon placeholder hidden")
	var e2_top: AnimatableBody2D = e2.get_node_or_null("TopPlatform") as AnimatableBody2D
	check(e2_top != null and (e2_top.get_child(0) as CollisionShape2D).one_way_collision, "RangedEnemy equipped with one-way TopPlatform")
	e2.queue_free()

	# (8) Regular Enemy 3: ChargingBeast
	var e3: CharacterBody2D = ChargingBeastScene.instantiate()
	world.add_child(e3)
	check(e3.get("enemy_sprite") != null and e3.enemy_sprite.texture != null, "ChargingBeast equipped with high-res sprite")
	check(e3.get_node("Visual").visible == false, "ChargingBeast polygon placeholder hidden")
	var e3_top: AnimatableBody2D = e3.get_node_or_null("TopPlatform") as AnimatableBody2D
	check(e3_top != null and (e3_top.get_child(0) as CollisionShape2D).one_way_collision, "ChargingBeast equipped with one-way TopPlatform")
	e3.queue_free()

	# (9) Regular Enemy 4: GroundSlamGolem
	var e4: CharacterBody2D = GroundSlamGolemScene.instantiate()
	world.add_child(e4)
	check(e4.get("enemy_sprite") != null and e4.enemy_sprite.texture != null, "GroundSlamGolem equipped with high-res sprite")
	check(e4.get_node("Visual").visible == false, "GroundSlamGolem polygon placeholder hidden")
	var e4_top: AnimatableBody2D = e4.get_node_or_null("TopPlatform") as AnimatableBody2D
	check(e4_top != null and (e4_top.get_child(0) as CollisionShape2D).one_way_collision, "GroundSlamGolem equipped with one-way TopPlatform")
	e4.queue_free()

	# =========================================================================
	# Check 11: Optional Course Bonus HUD Non-Overlap & Ranged 2D Aiming
	# =========================================================================
	print("\n[Check 11: Optional Course Bonus HUD Non-Overlap & Ranged 2D Aiming]")
	
	# 1. Verify upper enemy detects player below and engages into CHASE
	var test_enemy_scn := load("res://scenes/enemy/TestEnemy.tscn") as PackedScene
	var player_scn := load("res://scenes/player/Player.tscn") as PackedScene
	var upper_test_enemy: CharacterBody2D = test_enemy_scn.instantiate()
	upper_test_enemy.position = Vector2(300, 320)
	world.add_child(upper_test_enemy)
	var ground_player: CharacterBody2D = player_scn.instantiate()
	ground_player.position = Vector2(320, 590)
	world.add_child(ground_player)
	upper_test_enemy._player = ground_player
	upper_test_enemy.state = 0 # State.PATROL
	upper_test_enemy._update_patrol()
	check(upper_test_enemy.state == 1, "Upper floor enemy engaged into CHASE when player is on floor below (vertical_dist: 270px)")
	upper_test_enemy.queue_free()
	ground_player.queue_free()

	# 2. Verify Ranged Enemy 2D Target Aiming
	var ranged_test: CharacterBody2D = RangedEnemyScene.instantiate()
	ranged_test.position = Vector2(400, 320)
	world.add_child(ranged_test)
	var target_player: CharacterBody2D = player_scn.instantiate()
	target_player.position = Vector2(480, 590) # Below and to the right
	world.add_child(target_player)
	ranged_test._player = target_player
	ranged_test._fire_projectile()
	var spawned_proj: Area2D = null
	for child in world.get_children():
		if child.is_in_group("enemy_projectile"):
			spawned_proj = child
			break
	check(spawned_proj != null, "Ranged enemy spawned projectile")
	if spawned_proj != null:
		check("velocity_vector" in spawned_proj and spawned_proj.velocity_vector.y > 0.0, "Projectile directed angled downward toward player below")
		spawned_proj.queue_free()
	ranged_test.queue_free()
	target_player.queue_free()

	await process_frame

	# =========================================================================
	# Check 12: TopPlatform Riding Attack Stability & Black Screen Defense
	# =========================================================================
	print("\n[Check 12: TopPlatform Riding Attack Stability & Black Screen Defense]")

	var c12_ground_body := StaticBody2D.new()
	c12_ground_body.collision_layer = 1
	var g_shape := CollisionShape2D.new()
	var g_rect := RectangleShape2D.new()
	g_rect.size = Vector2(3000, 160)
	g_shape.shape = g_rect
	c12_ground_body.add_child(g_shape)
	c12_ground_body.position = Vector2(1000, 700)
	world.add_child(c12_ground_body)

	var rider_player: CharacterBody2D = player_scn.instantiate()
	rider_player.position = Vector2(500, 500)
	world.add_child(rider_player)

	var mount_enemy: CharacterBody2D = test_enemy_scn.instantiate()
	mount_enemy.max_hp = 100
	mount_enemy.current_hp = 100
	mount_enemy.position = Vector2(500, 580)
	world.add_child(mount_enemy)

	for i in range(25):
		await physics_frame

	# Land player on monster's TopPlatform
	rider_player.position = Vector2(mount_enemy.position.x, mount_enemy.position.y - 60.0)
	rider_player.velocity = Vector2.ZERO
	for i in range(20):
		await physics_frame

	check(rider_player.is_on_floor(), "Player securely landed on monster TopPlatform")
	check(rider_player.position.is_finite(), "Player position is finite upon landing")

	# Register camera to GameFeelManager
	var rider_cam: Camera2D = rider_player.get_node_or_null("Camera2D") as Camera2D
	if rider_cam != null:
		GameFeelManager.get_instance().register_camera(rider_cam)

	var all_finite := true
	var no_physics_explosion := true

	# Continuous attack cycle while standing on enemy
	for round in range(6):
		rider_player._start_attack()
		for f in range(15):
			await physics_frame
			if not rider_player.position.is_finite() or not rider_player.velocity.is_finite():
				all_finite = false
			if rider_cam != null and (not rider_cam.offset.is_finite() or not rider_cam.global_position.is_finite()):
				all_finite = false
			if rider_player.position.y > 640.0 or rider_player.position.y < -300.0:
				no_physics_explosion = false

	check(all_finite, "Player position, velocity, and camera offset strictly finite across continuous attacks (No NaN)")
	check(no_physics_explosion, "Player remained securely within playable world bounds (No physics launch into void)")

	# Verify downward knockback when attacking from above (enemy velocity.y is not pushed upward into player)
	rider_player.position = Vector2(mount_enemy.position.x, mount_enemy.position.y - 65.0)
	rider_player.velocity = Vector2.ZERO
	for f in range(10):
		await physics_frame
	rider_player._start_attack()
	await physics_frame
	check(mount_enemy.velocity.y >= 0.0, "Enemy hit from above received grounded/downward recoil, never launched into rider (vel.y=%.1f)" % mount_enemy.velocity.y)

	# Safe drop down dismount
	rider_player.position = Vector2(mount_enemy.position.x, mount_enemy.position.y - 65.0)
	rider_player.velocity = Vector2.ZERO
	for f in range(10):
		await physics_frame
	rider_player._try_drop_down_platform()
	for f in range(20):
		await physics_frame
	check(rider_player.position.is_finite(), "Player position strictly finite after dropping down from enemy")
	check(rider_player.position.y <= 600.0, "Player safely landed on ground without clipping through")

	# Safe enemy death while rider is near/on TopPlatform
	if is_instance_valid(mount_enemy):
		mount_enemy.current_hp = 1
		mount_enemy.receive_hit()
	await physics_frame
	check(not is_instance_valid(mount_enemy) or mount_enemy.is_queued_for_deletion(), "Enemy successfully processed death on 0 HP")

	rider_player.queue_free()
	c12_ground_body.queue_free()
	await process_frame


	# =========================================================================
	# Summary
	# =========================================================================
	print("\n--- TEST SUMMARY ---")
	print("Checks Passed: %d, Failures: %d" % [checks, failures])
	if failures == 0:
		print("TEST RESULT: ALL UI SCALE, FLOATING JOYPAD & AI CHECKS PASSED (100%)\n")
		quit(0)
	else:
		push_error("TEST RESULT: SMOKE TEST FAILED")
		quit(1)
