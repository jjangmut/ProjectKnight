extends SceneTree
## capture_ax_viewer_screenshots.gd
## 타이틀 화면 및 AXDataViewer의 6개 탭 화면을 실제 렌더링하여 아티팩트 디렉토리에 PNG로 캡처합니다.

const TitleScreenScene := preload("res://scenes/ui/TitleScreen.tscn")
const AXDataViewerScene := preload("res://scenes/ui/AXDataViewer.tscn")
const OUT_DIR := "C:/Users/jjang/.gemini/antigravity/brain/f5640d23-d7a9-4c71-a22a-2b289504a39b"


func _init() -> void:
	create_timer(15.0).timeout.connect(func():
		quit(1)
	)
	call_deferred("_capture_all")


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _save_shot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png(OUT_DIR + "/" + filename)
		print("[AX_CAPTURE] Saved: ", filename)


func _capture_all() -> void:
	await _wait_frames(3)

	# 1. Title Screen with AX Data Button
	var title := TitleScreenScene.instantiate()
	root.add_child(title)
	await _wait_frames(4)
	await _save_shot("ax_viewer_title_entry.png")
	title.queue_free()
	await _wait_frames(2)

	# 2. AX Data Viewer Tabs 0..5
	var viewer: Control = AXDataViewerScene.instantiate()
	root.add_child(viewer)
	await _wait_frames(4)

	var tab_files := [
		"ax_viewer_tab0_overview.png",
		"ax_viewer_tab1_player_combat.png",
		"ax_viewer_tab2_stages.png",
		"ax_viewer_tab3_enemies.png",
		"ax_viewer_tab4_bosses.png",
		"ax_viewer_tab5_sanctuary.png"
	]

	for i in range(tab_files.size()):
		viewer.select_tab(i)
		await _wait_frames(4)
		await _save_shot(tab_files[i])

	quit(0)
