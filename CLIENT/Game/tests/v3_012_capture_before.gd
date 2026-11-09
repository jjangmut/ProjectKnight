extends SceneTree
## V3-012 Capture Before State Fixture
## Captures reproducible baseline shortcomings in 1280x720:
## 1. before_01_hit_reaction_unresponsive.png: Standard minion hit reaction lacks distinct counter flash and micro-recoil
## 2. before_02_death_clarity_simple_fade.png: Minion death is a plain alpha fade with lingering active collisions and no defeat spark
## 3. before_03_stage3_single_line_telegraph.png: Stage 3 Crossbow Commander fan volley only renders a single line on the ground
## 4. before_04_stage4_ground_slam_misaligned_ring.png: Stage 4 Golem Guardian ground slam telegraph ring is centered at feet (radius 2.75) instead of slam impact center (radius 4.5)

const Stage1ScenePath := "res://scenes/side_quarter_view/SideQVStage1.tscn"
const Stage3ScenePath := "res://scenes/side_quarter_view/SideQVStage3.tscn"
const Stage4ScenePath := "res://scenes/side_quarter_view/SideQVStage4.tscn"

var stage: Node3D = null
var step: int = 0
var timer: float = 0.0

func _initialize() -> void:
	print(">>> [V3-012 CAPTURE BEFORE] Initializing baseline capture fixture... <<<")
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
			# Step 0: Hit reaction before
			if timer >= 0.30:
				var player = stage.get_node_or_null("Player")
				var minion = stage.get_node_or_null("Minion1")
				if minion != null and minion.has_method("receive_hit"):
					minion.receive_hit(1, Vector3.LEFT)
				_save_frame("before/before_01_hit_reaction_unresponsive.png")
				step = 1
				timer = 0.0

		1:
			# Step 1: Death clarity before (simple alpha fade)
			if timer >= 0.20:
				var minion = stage.get_node_or_null("Minion1")
				if minion != null and minion.has_method("receive_hit"):
					minion.receive_hit(10, Vector3.LEFT)
				_save_frame("before/before_02_death_clarity_simple_fade.png")
				step = 2
				timer = 0.0

		2:
			# Step 2: Stage 3 Crossbow Commander Fan Volley single line telegraph
			if timer >= 0.20:
				stage.queue_free()
				var packed3 := load(Stage3ScenePath) as PackedScene
				stage = packed3.instantiate() as Node3D
				root.add_child(stage)
				current_scene = stage
				step = 3
				timer = 0.0

		3:
			if timer >= 0.35:
				var boss = stage.get_node_or_null("CrossbowCommander")
				if boss != null and boss.has_method("_execute_fan_volley"):
					boss._execute_fan_volley()
				step = 4
				timer = 0.0

		4:
			if timer >= 0.15:
				_save_frame("before/before_03_stage3_single_line_telegraph.png")
				step = 5
				timer = 0.0

		5:
			# Step 5: Stage 4 Golem Guardian Ground Slam ring at feet
			if timer >= 0.10:
				stage.queue_free()
				var packed4 := load(Stage4ScenePath) as PackedScene
				stage = packed4.instantiate() as Node3D
				root.add_child(stage)
				current_scene = stage
				step = 6
				timer = 0.0

		6:
			if timer >= 0.35:
				var boss = stage.get_node_or_null("GolemGuardian")
				if boss != null and boss.has_method("_execute_ground_slam"):
					boss._execute_ground_slam()
				step = 7
				timer = 0.0

		7:
			if timer >= 0.15:
				_save_frame("before/before_04_stage4_ground_slam_misaligned_ring.png")
				_finish()
				step = 8

func _save_frame(rel_path: String) -> void:
	var vp := root.get_viewport()
	if vp == null:
		return
	var img := vp.get_texture().get_image()
	if img == null:
		return
	var base_dir := "D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-012/captures/"
	var full_path := base_dir + rel_path
	var dir := full_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(full_path)
	print("[V3-012 CAPTURE] Saved: ", full_path, " (", img.get_width(), "x", img.get_height(), ")")

func _finish() -> void:
	print(">>> [V3-012 CAPTURE BEFORE] All 4 baseline frames successfully captured! <<<")
	stage.queue_free()
	quit(0)
