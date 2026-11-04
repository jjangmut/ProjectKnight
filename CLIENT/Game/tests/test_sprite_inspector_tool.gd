extends SceneTree
## 캐릭터·몬스터·보스 스프라이트 정밀 검증 툴(SpriteInspectorTool) 자동화 QA 테스트 스위트
## - 12초 내장 워치독 타이머 탑재 (User Rule 3 준수)
## - 28종 전체 스프라이트 카탈로그 로드, 프레임 스텝, 픽셀 바운딩 계산, 셀 침범 0건 검증
## - TitleScreen 내 [스프라이트 검증 툴] 버튼 연동 검증

const SpriteInspectorScene = preload("res://scenes/ui/SpriteInspectorTool.tscn")
const TitleScreenScene = preload("res://scenes/ui/TitleScreen.tscn")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	create_timer(12.0).timeout.connect(func():
		printerr("[WATCHDOG TIMEOUT] test_sprite_inspector_tool.gd exceeded 12.0s!")
		quit(1)
	)
	_run_tests.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("[PASS] %s" % message)
	else:
		failures += 1
		printerr("[FAIL] %s" % message)


func _run_tests() -> void:
	print("==================================================================")
	print(">>> SPRITE INSPECTOR STUDIO VERIFICATION SUITE START <<<")
	print("==================================================================")

	var tool_node := SpriteInspectorScene.instantiate()
	check(tool_node != null, "SpriteInspectorTool.tscn instantiated cleanly")
	root.add_child(tool_node)
	await process_frame

	var catalog_size: int = tool_node.get_catalog_size()
	check(catalog_size == 28, "Catalog contains all 28 active sprite entries (got %d)" % catalog_size)

	# Verify all 28 entries load valid textures, images, frame metrics, and 0 cell bleeds
	for entry in tool_node.SPRITE_CATALOG:
		var sid: String = entry["id"]
		var ok: bool = tool_node.select_sprite_by_id(sid)
		check(ok, "Selected sprite entry '%s' (%s)" % [sid, entry["title"]])
		check(tool_node.current_texture != null, "Texture loaded for '%s'" % sid)
		check(tool_node.current_image != null, "Image pixel data loaded for '%s'" % sid)
		var expected_frames: int = int(entry["frames"])
		check(tool_node.frame_metrics.size() == expected_frames, "Computed %d frame metrics for '%s'" % [expected_frames, sid])
		var bleeds: int = tool_node.get_current_sheet_bleed_count()
		check(bleeds == 0, "Zero cell border bleeds on '%s' (bleeds=%d)" % [sid, bleeds])

		# Step to last frame and verify bounds
		tool_node.set_frame(expected_frames - 1)
		check(tool_node.current_frame == expected_frames - 1, "Stepped to final frame F%d on '%s'" % [expected_frames - 1, sid])

	# Verify Category Filtering
	tool_node._select_category("PLAYER_ACTION")
	check(tool_node._asset_buttons.size() == 8, "PLAYER_ACTION filter shows 8 sheets")
	tool_node._select_category("PLAYER_EVO")
	check(tool_node._asset_buttons.size() == 6, "PLAYER_EVO filter shows 6 evolution textures")
	tool_node._select_category("ENEMY_MINION")
	check(tool_node._asset_buttons.size() == 4, "ENEMY_MINION filter shows 4 minion sheets")
	tool_node._select_category("BOSS")
	check(tool_node._asset_buttons.size() == 10, "BOSS filter shows 10 boss sheets")
	tool_node._select_category("ALL")
	check(tool_node._asset_buttons.size() == 28, "ALL filter shows all 28 entries")

	# Verify Zoom & Overlay Toggles
	tool_node._change_zoom(0.5)
	check(is_equal_approx(tool_node.preview_zoom, 1.5), "Zoom increased to 150%")
	tool_node.show_onion_skin = true
	tool_node.flip_h = true
	tool_node._preview_canvas.queue_redraw()
	await process_frame

	tool_node.queue_free()
	await process_frame

	# Verify TitleScreen Integration
	var title := TitleScreenScene.instantiate()
	root.add_child(title)
	await process_frame
	check(title.btn_sprite_studio != null, "TitleScreen has btn_sprite_studio button")
	title._on_sprite_studio_pressed()
	await process_frame
	var spawned_studio := title.get_node_or_null("SpriteInspectorTool")
	check(spawned_studio != null, "Clicking btn_sprite_studio opens SpriteInspectorTool overlay on TitleScreen")

	print("==================================================================")
	print("SPRITE INSPECTOR TEST SUMMARY: %d CHECKS | %d FAILURES" % [checks, failures])
	print("==================================================================")
	quit(0 if failures == 0 else 1)
