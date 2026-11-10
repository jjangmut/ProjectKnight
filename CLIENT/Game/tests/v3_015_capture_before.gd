extends SceneTree
## V3-015 Baseline Capture Fixture: Audit actual rendered experience across Stages 1, 3, 4, 5.
## Captures 1280x720 baseline gameplay frames and measures performance metrics.

const Stage1ScenePath := "res://scenes/side_quarter_view/SideQVStage1.tscn"
const Stage3ScenePath := "res://scenes/side_quarter_view/SideQVStage3.tscn"
const Stage4ScenePath := "res://scenes/side_quarter_view/SideQVStage4.tscn"
const Stage5ScenePath := "res://scenes/side_quarter_view/SideQVStage5.tscn"

const EvidenceDir := "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-015"
const BeforeCaptureDir := EvidenceDir + "/captures/before"

var stage: Node3D = null
var step: int = 0
var timer: float = 0.0

var fps_samples: Array[float] = []
var frame_time_samples: Array[float] = []
var draw_call_samples: Array[float] = []


func _initialize() -> void:
	print(">>> [V3-015 BASELINE] Initializing multi-stage gameplay visual audit fixture... <<<")
	root.size = Vector2i(1280, 720)
	
	var dir := DirAccess.open("res://")
	if dir != null:
		dir.make_dir_recursive(BeforeCaptureDir)

	_load_stage(Stage1ScenePath)
	process_frame.connect(_on_process_frame)


func _load_stage(path: String) -> void:
	if stage != null and is_instance_valid(stage):
		stage.queue_free()
		stage = null
	
	var packed := load(path) as PackedScene
	if packed == null:
		printerr("Failed to load scene: ", path)
		quit(1)
		return
	stage = packed.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage


func _on_process_frame() -> void:
	timer += 1.0 / 60.0
	
	# Sample performance during combat
	if step == 0 and timer >= 0.20:
		fps_samples.append(float(Engine.get_frames_per_second()))
		frame_time_samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		draw_call_samples.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))

	match step:
		0:
			# Stage 1: Player & Minion 1 combat engagement
			if timer >= 0.50:
				var player = stage.get_node_or_null("Player")
				var minion = stage.get_node_or_null("Minion1")
				if player != null:
					player.position.x = 0.5
				if minion != null:
					minion.position.x = 2.0
				_save_frame(BeforeCaptureDir + "/before_01_stage1_terrace_combat.png")
				print("[V3-015 BASELINE] Captured Stage 1 Terrace combat frame.")
				
				# Record Stage 1 baseline perf
				_save_baseline_perf()
				
				step = 1
				timer = 0.0
				_load_stage(Stage3ScenePath)

		1:
			# Stage 3: Crossbow Bastion overview
			if timer >= 0.50:
				var player = stage.get_node_or_null("Player")
				if player != null:
					player.position.x = -2.0
				_save_frame(BeforeCaptureDir + "/before_02_stage3_crossbow_bastion.png")
				print("[V3-015 BASELINE] Captured Stage 3 Crossbow Bastion frame.")
				step = 2
				timer = 0.0
				_load_stage(Stage4ScenePath)

		2:
			# Stage 4: Stone Sanctuary overview
			if timer >= 0.50:
				var player = stage.get_node_or_null("Player")
				if player != null:
					player.position.x = -1.0
				_save_frame(BeforeCaptureDir + "/before_03_stage4_stone_sanctuary.png")
				print("[V3-015 BASELINE] Captured Stage 4 Stone Sanctuary frame.")
				step = 3
				timer = 0.0
				_load_stage(Stage5ScenePath)

		3:
			# Stage 5: Silent Citadel throne overview
			if timer >= 0.50:
				var player = stage.get_node_or_null("Player")
				if player != null:
					player.position.x = 0.0
				_save_frame(BeforeCaptureDir + "/before_04_stage5_silent_citadel.png")
				print("[V3-015 BASELINE] Captured Stage 5 Silent Citadel frame.")
				print("[V3-015 BASELINE] All 4 baseline stages captured successfully.")
				quit(0)


func _save_frame(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null:
		var err := img.save_png(path)
		if err == OK:
			print("Saved: ", path)
		else:
			printerr("Failed to save image: ", path, " err: ", err)


func _save_baseline_perf() -> void:
	var avg_fps := 0.0
	var avg_ft := 0.0
	var avg_dc := 0.0
	if fps_samples.size() > 0:
		for f in fps_samples:
			avg_fps += f
		avg_fps /= float(fps_samples.size())
		for ft in frame_time_samples:
			avg_ft += ft
		avg_ft /= float(frame_time_samples.size())
		for dc in draw_call_samples:
			avg_dc += dc
		avg_dc /= float(draw_call_samples.size())
	
	var data := {
		"stage": "Stage 1 Citadel Terrace Combat",
		"sample_count": fps_samples.size(),
		"avg_fps": avg_fps,
		"avg_frame_time_ms": avg_ft,
		"avg_draw_calls": avg_dc,
		"timestamp": Time.get_datetime_string_from_system()
	}
	var f := FileAccess.open(EvidenceDir + "/BASELINE_PERFORMANCE.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
		print("Saved baseline perf data to BASELINE_PERFORMANCE.json")
