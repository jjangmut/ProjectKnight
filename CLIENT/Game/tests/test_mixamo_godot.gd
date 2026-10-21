extends SceneTree

func _init() -> void:
	create_timer(12.0).timeout.connect(func():
		print("[ERROR] Watchdog timer expired in test_mixamo_godot.gd")
		quit(1)
	)
	
	print("==================================================")
	print("  TEST: Mixamo-Rigged Paladin in Godot 4.7.2      ")
	print("==================================================")
	
	var model_path = "res://assets/models/ProjectKnight_Paladin_Animated.glb"
	
	var scene_res = load(model_path)
	if scene_res == null:
		print("[FAIL] Failed to load: %s" % model_path)
		quit(1)
		return
		
	var inst = scene_res.instantiate()
	root.add_child(inst)
	
	var skel: Skeleton3D = null
	var anim_player: AnimationPlayer = null
	
	for child in inst.find_children("*", "", true, false):
		if child is Skeleton3D:
			skel = child
		elif child is AnimationPlayer:
			anim_player = child
			
	if skel:
		print("[PASS] Skeleton3D found: %s with %d bones" % [skel.name, skel.get_bone_count()])
		for i in range(min(skel.get_bone_count(), 10)):
			print("  Bone %d: %s" % [i, skel.get_bone_name(i)])
	else:
		print("[FAIL] Skeleton3D not found!")
		quit(1)
		return
		
	if anim_player:
		print("[PASS] AnimationPlayer found: %s" % anim_player.name)
		var anims = anim_player.get_animation_list()
		print("Animations (%d):" % anims.size())
		for a in anims:
			var anim = anim_player.get_animation(a)
			print("  - %s (len: %.2fs, tracks: %d)" % [a, anim.length, anim.get_track_count()])
			anim_player.play(a)
			anim_player.advance(0.1)
			print("    Playback OK: %s" % a)
	else:
		print("[FAIL] AnimationPlayer not found!")
		quit(1)
		return
		
	inst.queue_free()
	print("==================================================")
	print("  MIXAMO PALADIN 100% PASS IN GODOT 4.7.2         ")
	print("==================================================")
	quit(0)
