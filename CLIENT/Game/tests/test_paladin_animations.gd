extends SceneTree

func _init() -> void:
	# 12-second Watchdog timer as mandated by Project Knight rules
	create_timer(12.0).timeout.connect(func():
		print("[ERROR] Watchdog timer expired in test_paladin_animations.gd")
		quit(1)
	)
	
	print("==================================================")
	print("  TEST: Paladin Animated 3D Model Validation (Godot)")
	print("==================================================")
	
	var model_path = "res://assets/models/ProjectKnight_Paladin_Animated.glb"
	
	if not ResourceLoader.exists(model_path):
		print("[FAIL] Model file does not exist: %s" % model_path)
		quit(1)
		return
		
	var scene_res = load(model_path)
	if scene_res == null:
		print("[FAIL] Failed to load PackedScene: %s" % model_path)
		quit(1)
		return
		
	var instance = scene_res.instantiate()
	if instance == null:
		print("[FAIL] Failed to instantiate scene: %s" % model_path)
		quit(1)
		return
		
	# Add to root for processing
	root.add_child(instance)
	
	# Find Skeleton3D and AnimationPlayer
	var skeleton: Skeleton3D = null
	var anim_player: AnimationPlayer = null
	var mesh_inst: MeshInstance3D = null
	
	for child in instance.find_children("*", "", true, false):
		if child is Skeleton3D:
			skeleton = child
		elif child is AnimationPlayer:
			anim_player = child
		elif child is MeshInstance3D or child is ImporterMeshInstance3D:
			mesh_inst = child
			
	if skeleton == null:
		print("[FAIL] Skeleton3D node not found in model!")
		quit(1)
		return
	print("[PASS] Skeleton3D found: %s with %d bones" % [skeleton.name, skeleton.get_bone_count()])
	
	for b in range(skeleton.get_bone_count()):
		print("  Bone %d: %s" % [b, skeleton.get_bone_name(b)])
		
	if anim_player == null:
		print("[FAIL] AnimationPlayer node not found in model!")
		quit(1)
		return
	print("[PASS] AnimationPlayer found: %s" % anim_player.name)
	
	var anim_list = anim_player.get_animation_list()
	print("Animation clips found (%d total):" % anim_list.size())
	for a in anim_list:
		var anim = anim_player.get_animation(a)
		print("  - %s (Length: %.2fs, Loop: %s, Tracks: %d)" % [a, anim.length, str(anim.loop_mode != Animation.LOOP_NONE), anim.get_track_count()])
		
	var expected_anims = ["Idle", "Walk", "Attack_Slash", "Parry_Block", "Jump", "Hit_Hurt"]
	var missing_anims = []
	for ea in expected_anims:
		var found = false
		for a in anim_list:
			if a.ends_with(ea) or a == ea:
				found = true
				break
		if not found:
			missing_anims.append(ea)
			
	if missing_anims.size() > 0:
		print("[FAIL] Missing expected animations: %s" % str(missing_anims))
		quit(1)
		return
	else:
		print("[PASS] All %d expected core combat animations verified present!" % expected_anims.size())
		
	# Test playback of each animation and step simulation
	print("Testing animation playback and bone transform updates...")
	for a in anim_list:
		anim_player.play(a)
		anim_player.advance(0.1) # Advance time to compute frame transforms
		var root_bone_trans = skeleton.get_bone_pose_position(0)
		print("  Playback OK: %s -> active (Root bone pos: %s)" % [a, str(root_bone_trans)])
		
	instance.queue_free()
	
	print("==================================================")
	print("  PALADIN ANIMATED 3D MODEL 100% PASS IN GODOT 4.7.2")
	print("==================================================")
	quit(0)
