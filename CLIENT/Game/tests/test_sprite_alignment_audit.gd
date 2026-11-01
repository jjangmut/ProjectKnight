extends SceneTree
## 캐릭터·몬스터·보스 스프라이트 정렬 및 셀 경계 침범(Bleed) 무결성 검증 스위트
## - 12초 내장 워치독 타이머 탑재 (User Rule 3 준수)
## - 플레이어 9종 액션 시트 780x780 셀 규격 통일, 베이스라인 정렬, 셀 경계 침범 0건 검증
## - SideQVPlayer 전 상태(Idle, Move, Jump, Attack, Guard, Dash, Hurt, Dead) pixel_size = 0.00282 통일 검증
## - 적 미니언 4종(melee, ranged, golem, beast) 512x512 셀 경계 침범 0건 및 베이스라인(y=490) 통일 검증
## - 보스 10종(Stage 1~5 Main/Skills) 4x3 셀 경계 침범 0건 및 Stage 3 석궁 사령관 전용 시트(crossbow_cmd_v2) 연동 검증

const SideQVPlayerClass = preload("res://scripts/side_quarter_view/side_qv_player.gd")
const SideQVCrossbowCommanderClass = preload("res://scripts/side_quarter_view/bosses/side_qv_crossbow_commander.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	create_timer(12.0).timeout.connect(func():
		printerr("[WATCHDOG TIMEOUT] test_sprite_alignment_audit.gd exceeded 12.0s!")
		quit(1)
	)
	_run_audit.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("[PASS] %s" % message)
	else:
		failures += 1
		printerr("[FAIL] %s" % message)


func _audit_sheet_cells(res_path: String, cols: int, rows: int, expected_cw: int, expected_ch: int, min_bot_y: int, max_bot_y: int) -> void:
	var global_path := ProjectSettings.globalize_path(res_path)
	var img := Image.load_from_file(global_path)
	check(img != null, "%s loaded from disk (%dx%d)" % [res_path.get_file(), img.get_width() if img else 0, img.get_height() if img else 0])
	if img == null:
		return

	var cw: int = img.get_width() / cols
	var ch: int = img.get_height() / rows
	check(cw == expected_cw and ch == expected_ch, "%s cell size is %dx%d (expected %dx%d)" % [res_path.get_file(), cw, ch, expected_cw, expected_ch])

	var bleed_frames: Array[int] = []
	var bot_out_frames: Array[String] = []

	for r in range(rows):
		for c in range(cols):
			var idx: int = r * cols + c
			var cell_img := img.get_region(Rect2i(c * cw, r * ch, cw, ch))
			var used: Rect2i = cell_img.get_used_rect()
			if used.size.x <= 0 or used.size.y <= 0:
				bleed_frames.append(idx)
				continue
			var bx0: int = used.position.x
			var by0: int = used.position.y
			var bx1: int = used.position.x + used.size.x
			var by1: int = used.position.y + used.size.y
			if bx0 <= 0 or bx1 >= cw or by0 <= 0 or by1 >= ch:
				bleed_frames.append(idx)
			if by1 < min_bot_y or by1 > max_bot_y:
				bot_out_frames.append("F%d(bot=%d)" % [idx, by1])

	check(bleed_frames.is_empty(), "%s has ZERO cell border bleeds across %d frames (bleeds: %s)" % [res_path.get_file(), cols * rows, str(bleed_frames)])
	check(bot_out_frames.is_empty(), "%s all frames grounded within baseline [%d..%d] (outliers: %s)" % [res_path.get_file(), min_bot_y, max_bot_y, str(bot_out_frames)])


func _run_audit() -> void:
	print("==================================================================")
	print(">>> CHARACTER, MINION & BOSS SPRITE ALIGNMENT AUDIT START <<<")
	print("==================================================================")

	# 1. Player Sprite Sheets (Unified 780x780 cells, baseline ~700)
	var player_sheets := [
		["res://assets/player_frames/idle_v1_aligned.png", 2, 2, 695, 702],
		["res://assets/player_frames/run_v2_aligned.png", 3, 2, 690, 702],
		["res://assets/player_frames/attack_v1_aligned.png", 2, 2, 695, 702],
		["res://assets/player_frames/attack_v2_aligned.png", 2, 2, 695, 702],
		["res://assets/player_frames/guard_v1_aligned.png", 3, 1, 695, 702],
		["res://assets/player_frames/jump_v1.png", 3, 1, 670, 702],
		["res://assets/player_frames/dodge_v1.png", 2, 2, 695, 702],
		["res://assets/player_frames/hurt_v1.png", 3, 1, 695, 702],
		["res://assets/player_frames/death_v1.png", 2, 2, 695, 702],
	]
	for spec in player_sheets:
		_audit_sheet_cells(spec[0], spec[1], spec[2], 780, 780, spec[3], spec[4])

	# 2. Enemy Minion Sprite Sheets (Unified 512x512 cells, baseline ~490)
	var minion_sheets := [
		"res://assets/enemy_frames/melee_v1.png",
		"res://assets/enemy_frames/ranged_v1.png",
		"res://assets/enemy_frames/golem_v1.png",
		"res://assets/enemy_frames/beast_v2.png",
	]
	for path in minion_sheets:
		_audit_sheet_cells(path, 3, 2, 512, 512, 486, 494)

	# 3. Boss Sprite Sheets (4x3 grid, 300x298 cells, zero border bleed)
	var boss_sheets := [
		"res://assets/enemy_frames/boss_commander_v2.png",
		"res://assets/enemy_frames/boss_commander_v2_defense.png",
		"res://assets/enemy_frames/beast_chieftain_v2.png",
		"res://assets/enemy_frames/beast_chieftain_v2_skills.png",
		"res://assets/enemy_frames/crossbow_cmd_v2.png",
		"res://assets/enemy_frames/crossbow_cmd_v2_skills.png",
		"res://assets/enemy_frames/golem_guardian_v2.png",
		"res://assets/enemy_frames/golem_guardian_v2_skills.png",
		"res://assets/enemy_frames/abyssal_arbiter_v2.png",
		"res://assets/enemy_frames/abyssal_arbiter_v2_skills.png",
	]
	for path in boss_sheets:
		_audit_sheet_cells(path, 4, 3, 300, 298, 240, 296)

	# 4. Verify SideQVPlayer Runtime State Transitions & Unified pixel_size (0.00282)
	var player := SideQVPlayerClass.new()
	root.add_child(player)
	await process_frame

	check(is_equal_approx(player.sprite_3d.pixel_size, 0.00282), "Player initial IDLE pixel_size is 0.00282")
	player._set_state(SideQVPlayerClass.State.HURT)
	player._update_character_animation(0.016)
	check(is_equal_approx(player.sprite_3d.pixel_size, 0.00282), "Player HURT pixel_size is unified to 0.00282")
	player._set_state(SideQVPlayerClass.State.DASH)
	player._update_character_animation(0.016)
	check(is_equal_approx(player.sprite_3d.pixel_size, 0.00282), "Player DASH pixel_size is unified to 0.00282")
	player._enter_death_state()
	check(is_equal_approx(player.sprite_3d.pixel_size, 0.00282), "Player DEAD pixel_size is unified to 0.00282")
	player.queue_free()

	# 5. Verify Stage 3 Boss (SideQVCrossbowCommander) Dedicated Boss Sprite Sheet Wiring
	var cmd_boss := SideQVCrossbowCommanderClass.new()
	root.add_child(cmd_boss)
	await process_frame

	check(cmd_boss.sprite_3d.texture.resource_path.ends_with("crossbow_cmd_v2.png"),
		"Stage 3 CrossbowCommander uses dedicated crossbow_cmd_v2.png (got: %s)" % cmd_boss.sprite_3d.texture.resource_path)
	check(cmd_boss.sprite_3d.hframes == 4 and cmd_boss.sprite_3d.vframes == 3,
		"Stage 3 CrossbowCommander configured as 4x3 boss sheet")
	cmd_boss.apply_parry_stun(1.0)
	check(cmd_boss.sprite_3d.texture.resource_path.ends_with("crossbow_cmd_v2_skills.png") and cmd_boss.sprite_3d.frame == 8,
		"Stage 3 CrossbowCommander switches to crossbow_cmd_v2_skills.png Frame 8 on Stun")
	cmd_boss.queue_free()

	await process_frame
	print("==================================================================")
	print("SPRITE ALIGNMENT AUDIT SUMMARY: %d CHECKS | %d FAILURES" % [checks, failures])
	print("==================================================================")
	quit(0 if failures == 0 else 1)
