extends SceneTree
## V3-012 Capture After State Fixture
## Captures verified after state in 1280x720:
## 1. after_01_hit_reaction_flash_and_recoil.png: Visible hit reaction with distinct damage flash and micro-recoil
## 2. after_02_death_clarity_dissolve_and_burst.png: Distinct defeat dissolve, upward lift, and defeat burst torus ring
## 3. after_03_stage3_fan_volley_3_lasers.png: Stage 3 Crossbow Commander 3-way laser fan volley on Z=0
## 4. after_04_stage4_ground_slam_aligned_ring.png: Stage 4 Golem Guardian ground slam telegraph centered at slam origin with 4.5m radius

const Stage1ScenePath := "res://scenes/side_quarter_view/SideQVStage1.tscn"
const Stage3ScenePath := "res://scenes/side_quarter_view/SideQVStage3.tscn"
const Stage4ScenePath := "res://scenes/side_quarter_view/SideQVStage4.tscn"

var stage: Node3D = null
var step: int = 0
var timer: float = 0.0

var results := {
	"task_id": "V3-012",
	"captures_captured": 0,
	"all_captured": false
}

func _initialize() -> void:
	print(">>> [V3-012 CAPTURE AFTER] Initializing after capture fixture... <<<")
	root.size = Vector2i(1280, 720)
	var packed := load(Stage1ScenePath) as PackedScene
	stage = packed.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage

	process_frame.connect(_on_process_frame)

func _on_process_frame() -> void:
	timer += 1.0 / 60.0

	match step:
		0:
			# Step 0: Hit reaction after (counter hit with cyan-gold flash & recoil)
			if timer >= 0.30:
				var minion = stage.get_node_or_null("Minion1")
				if minion != null and minion.has_method("receive_hit"):
					minion.receive_hit(1, Vector3.LEFT, true)
				_save_frame("after/after_01_hit_reaction_flash_and_recoil.png")
				step = 1
				timer = 0.0

		1:
			# Step 1: Defeat clarity after (dissolve + spark burst ring)
			if timer >= 0.20:
				var minion = stage.get_node_or_null("Minion1")
				if minion != null and minion.has_method("receive_hit"):
					minion.receive_hit(10, Vector3.LEFT, false)
				step = 2
				timer = 0.0

		2:
			# Allow 0.08s for defeat burst ring and dissolve to expand
			if timer >= 0.08:
				_save_frame("after/after_02_death_clarity_dissolve_and_burst.png")
				step = 3
				timer = 0.0

		3:
			# Step 3: Transition to Stage 3 for Fan Volley
			if timer >= 0.10:
				stage.queue_free()
				var packed3 := load(Stage3ScenePath) as PackedScene
				stage = packed3.instantiate() as Node3D
				root.add_child(stage)
				current_scene = stage
				step = 4
				timer = 0.0

		4:
			if timer >= 0.35:
				var boss = stage.get_node_or_null("CrossbowCommander")
				if boss != null and boss.has_method("_execute_fan_volley"):
					boss._execute_fan_volley()
				step = 5
				timer = 0.0

		5:
			if timer >= 0.15:
				_save_frame("after/after_03_stage3_fan_volley_3_lasers.png")
				step = 6
				timer = 0.0

		6:
			# Step 6: Transition to Stage 4 for Golem Ground Slam
			if timer >= 0.10:
				stage.queue_free()
				var packed4 := load(Stage4ScenePath) as PackedScene
				stage = packed4.instantiate() as Node3D
				root.add_child(stage)
				current_scene = stage
				step = 7
				timer = 0.0

		7:
			if timer >= 0.35:
				var boss = stage.get_node_or_null("GolemGuardian")
				if boss != null and boss.has_method("_execute_ground_slam"):
					boss._execute_ground_slam()
				step = 8
				timer = 0.0

		8:
			if timer >= 0.15:
				_save_frame("after/after_04_stage4_ground_slam_aligned_ring.png")
				_finish()
				step = 9

func _save_frame(rel_path: String) -> void:
	var base_dir := "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-012/captures"
	var full_path := base_dir + "/" + rel_path
	var parent_dir := full_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(parent_dir)

	var img := root.get_viewport().get_texture().get_image()
	if img != null:
		var err := img.save_png(full_path)
		if err == OK:
			print("[CAPTURE OK] Saved frame -> ", full_path)
			results["captures_captured"] += 1
		else:
			printerr("[CAPTURE FAIL] Error saving frame: ", err)
	else:
		printerr("[CAPTURE FAIL] Image from viewport was null!")

func _finish() -> void:
	results["all_captured"] = (results["captures_captured"] >= 4)
	var evidence_dir := "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-012"
	var f := FileAccess.open(evidence_dir + "/AFTER_CAPTURE_VERIFICATION_RESULT.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(results, "  "))
		f.close()
	print(">>> [V3-012 CAPTURE AFTER COMPLETE] Captured %d frames. <<<" % results["captures_captured"])
	quit(0 if results["all_captured"] else 1)
