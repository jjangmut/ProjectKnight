extends SceneTree
## ax_data_viewer_smoke.gd
## AX 기획 데이터 레지스트리(AXDataRegistry), 인게임 뷰어 페이지(AXDataViewer), 타이틀 및 스테이지 연동 스모크 테스트.

const AXDataRegistryClass := preload("res://scripts/data/ax_data_registry.gd")
const AXDataViewerScene := preload("res://scenes/ui/AXDataViewer.tscn")
const TitleScreenScene := preload("res://scenes/ui/TitleScreen.tscn")
const Stage1Scene := preload("res://scenes/side_quarter_view/SideQVStage1.tscn")


func _init() -> void:
	# 15초 내장 워치독 타이머 (고아 프로세스 원천 차단)
	create_timer(15.0).timeout.connect(func():
		push_error("[AX_SMOKE] Watchdog timeout reached (15.0s)! Aborting.")
		quit(1)
	)
	call_deferred("_run_test")


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		push_error("[AX_SMOKE FAIL] " + msg)
		quit(1)


func _run_test() -> void:
	print("=== [AX_SMOKE] Starting AX Data Registry & Viewer Smoke Test ===")

	# 1. Schema Validation
	var validation := AXDataRegistryClass.validate_schema()
	_assert(bool(validation.get("valid", false)), "AXDataRegistry schema validation must pass: %s" % str(validation.get("errors", [])))

	var metrics: Dictionary = validation.get("summary", {})
	_assert(int(metrics.get("stage_count", 0)) == 5, "Expected 5 stages in AX Data.")
	_assert(int(metrics.get("enemy_type_count", 0)) == 5, "Expected 5 enemy archetypes in AX Data.")
	_assert(int(metrics.get("boss_count", 0)) == 5, "Expected 5 bosses in AX Data.")
	_assert(int(metrics.get("boss_pattern_count", 0)) == 17, "Expected 17 boss patterns in AX Data.")
	_assert(int(metrics.get("player_anim_count", 0)) == 8, "Expected 8 player animation states in AX Data.")
	_assert(int(metrics.get("shop_item_count", 0)) == 5, "Expected 5 sanctuary shop items in AX Data.")
	_assert(int(metrics.get("relic_count", 0)) == 5, "Expected 5 stage relics in AX Data.")
	print("[AX_SMOKE] Step 1 PASS: AX Data JSON schema & metrics verified -> ", metrics)

	# 2. Search Engine Verification
	var parry_hits := AXDataRegistryClass.search_entries("패링")
	_assert(parry_hits.size() >= 2, "Keyword '패링' should match player and relics.")
	var golem_hits := AXDataRegistryClass.search_entries("골렘")
	_assert(golem_hits.size() >= 2, "Keyword '골렘' should match stage 4 enemy & boss.")
	print("[AX_SMOKE] Step 2 PASS: Search queries verified (parry=%d, golem=%d)." % [parry_hits.size(), golem_hits.size()])

	# 3. AXDataViewer Scene & Tab Navigation
	var viewer: Control = AXDataViewerScene.instantiate()
	_assert(viewer != null, "AXDataViewerScene must instantiate.")
	root.add_child(viewer)
	await process_frame

	for tab_idx in range(6):
		viewer.select_tab(tab_idx)
		await process_frame
		_assert(viewer.current_tab == tab_idx, "Viewer current_tab should match %d" % tab_idx)
		_assert(viewer.get_rendered_card_count() > 0, "Tab %d must render cards (>0)." % tab_idx)

	# Search mode & Raw JSON mode
	viewer.set_search_query("심판관")
	await process_frame
	_assert(viewer.get_rendered_card_count() >= 2, "Search '심판관' in viewer must render header + result cards.")
	viewer.set_search_query("")
	viewer._on_toggle_raw_json()
	await process_frame
	_assert(viewer.show_raw_json == true and viewer.get_rendered_card_count() == 1, "Raw JSON toggle must render JSON view.")

	viewer._on_close_pressed()
	await process_frame
	print("[AX_SMOKE] Step 3 PASS: AXDataViewer all 6 tabs, search, raw JSON, and close verified.")

	# 4. TitleScreen Integration
	var title := TitleScreenScene.instantiate() as TitleScreen
	root.add_child(title)
	await process_frame
	_assert(title.btn_ax_data != null, "TitleScreen must have btn_ax_data button.")
	title._on_ax_data_pressed()
	await process_frame
	var modal_viewer := title.get_node_or_null("AXDataViewer")
	_assert(modal_viewer != null, "Clicking btn_ax_data on TitleScreen must spawn AXDataViewer.")
	title.queue_free()
	await process_frame
	print("[AX_SMOKE] Step 4 PASS: TitleScreen integration verified.")

	# 5. In-Game Stage HUD Integration
	var stage1 := Stage1Scene.instantiate()
	root.add_child(stage1)
	await process_frame
	var opened_viewer = stage1.open_ax_data_viewer()
	await process_frame
	_assert(opened_viewer != null, "Stage 1 open_ax_data_viewer() must spawn AXDataViewerModal.")
	stage1.queue_free()
	await process_frame
	print("[AX_SMOKE] Step 5 PASS: In-game stage HUD AXDataViewer integration verified.")

	print("=== [AX_SMOKE] ALL TESTS 100% PASSED ===")
	quit(0)
