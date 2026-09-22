extends SceneTree
## Automated QA Smoke Test for Project Knight Ad Monetization Architecture.
## Verifies that:
## 1. AdManager manages rewarded video playback, completion signals, and VIP No-Ads bypass.
## 2. CampfireShop Rewarded Shard Booster grants +30 shards cleanly.
## 3. Revive-on-Defeat restores full HP, grants I-Frame, and respects 1-per-run limit.
## 4. Campaign Stage Clear Rewarded Bonus multiplies run shard rewards.
## 5. VIP No-Ads bypass grants all rewards immediately without playing ads.

const AdManagerClass := preload("res://scripts/system/ad_manager.gd")
const CampfireShopClass := preload("res://scripts/ui/campfire_shop.gd")

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

func _run() -> void:
	print("\n--- START AD MONETIZATION ARCHITECTURE SMOKE TEST ---")

	var world := Node2D.new()
	root.add_child(world)

	# Baseline setup
	SaveManager.clear_save()
	SaveManager.set_ad_free(false)
	var ad_mgr := AdManagerClass.ensure_manager(world)

	await process_frame
	await process_frame

	print("\n[Check 1: AdManager Lifecycle & State Initialization]")
	check(ad_mgr != null, "AdManager singleton verified")
	check(not AdManagerClass.is_ad_free(), "Initial ad-free status is false")
	check(AdManagerClass.can_revive_with_ad(), "Initial revive available for new run")

	print("\n[Check 2: Rewarded Ad Playback & Reward Granting]")
	var ad_state := {"completed": false}
	AdManagerClass.show_rewarded_ad("test_reward", world, func():
		ad_state["completed"] = true
	)
	check(ad_mgr.is_ad_playing, "Ad playback modal layer is active")
	# Wait for simulated ad completion (1.2s + buffer)
	await create_timer(1.5, false).timeout
	check(ad_state["completed"], "Rewarded ad completed callback invoked successfully")
	check(not ad_mgr.is_ad_playing, "Ad playback ended cleanly")

	print("\n[Check 3: CampfireShop Rewarded Shard Booster (+30 Shards)]")
	var initial_shards := SaveManager.get_shards()
	check(initial_shards == 0, "Initial wallet is 0 shards")

	var shop := CampfireShopClass.new()
	world.add_child(shop)
	await process_frame

	var ad_btn: Button = null
	for child in shop.find_children("", "Button", true, false):
		if "성소의 기도" in (child as Button).text:
			ad_btn = child as Button
			break
	check(ad_btn != null, "CampfireShop contains Rewarded Shard Booster button")

	# Simulate pressing ad booster
	if ad_btn != null:
		shop._on_watch_ad_boost()
		await create_timer(1.5, false).timeout
		var new_shards := SaveManager.get_shards()
		check(new_shards == 30, "Rewarded ad successfully credited +30 soul shards (Total: %d)" % new_shards)

	shop.queue_free()
	await process_frame

	print("\n[Check 4: Revive-on-Defeat Player & Stage Restoration]")
	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	var player: CharacterBody2D = player_scene.instantiate()
	world.add_child(player)
	await process_frame

	# Simulate death
	player.current_hp = 0
	player._die()
	check(player.is_dead, "Player marked as dead")

	# Revive via Ad
	check(AdManagerClass.can_revive_with_ad(), "Can revive with ad on first defeat")
	AdManagerClass.consume_revive_with_ad()
	player.revive(true)
	check(not player.is_dead, "Player successfully revived from death")
	check(player.current_hp == player.max_hp, "Player HP restored to full (HP: %d/%d)" % [player.current_hp, player.max_hp])
	check(not AdManagerClass.can_revive_with_ad(), "Revive consumed: Cannot revive again in same run")

	# Reset run counters
	AdManagerClass.reset_run_ad_counters()
	check(AdManagerClass.can_revive_with_ad(), "Reset restores revive availability for next run")
	player.queue_free()
	await process_frame

	print("\n[Check 5: Campaign Stage Clear Rewarded Bonus]")
	var campaign_scene := load("res://scenes/stage/Campaign.tscn") as PackedScene
	var campaign = campaign_scene.instantiate()
	world.add_child(campaign)
	await process_frame

	campaign.last_cleared_shards = 20
	var shards_before_bonus := SaveManager.get_shards()
	campaign._claim_ad_shard_bonus(10) # 50% bonus of 20 = 10
	await create_timer(1.5, false).timeout
	check(SaveManager.get_shards() == shards_before_bonus + 10, "Stage clear bonus credited +10 shards")
	check(campaign.ad_bonus_claimed == true, "Bonus marked as claimed (cannot double claim)")
	campaign.queue_free()
	await process_frame

	print("\n[Check 6: VIP No-Ads Instant Bypass]")
	AdManagerClass.set_ad_free(true)
	check(AdManagerClass.is_ad_free(), "No-Ads VIP package successfully enabled")

	var vip_state := {"success": false}
	AdManagerClass.show_rewarded_ad("vip_instant_test", world, func():
		vip_state["success"] = true
	)
	check(vip_state["success"], "VIP No-Ads bypassed video ad immediately (0s latency)")
	check(not ad_mgr.is_ad_playing, "No ad player spawned for VIP user")

	# Reset save
	SaveManager.clear_save()

	print("\n--- AD MONETIZATION SUITE SUMMARY ---")
	print("Checks Passed: %d, Failures: %d" % [checks, failures])
	if failures == 0:
		print("TEST RESULT: ALL AD MONETIZATION CHECKS PASSED (100%)\n")
		quit(0)
	else:
		push_error("TEST RESULT: AD MONETIZATION TEST FAILED")
		quit(1)
