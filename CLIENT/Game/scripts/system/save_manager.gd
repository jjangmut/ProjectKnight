class_name SaveManager
extends RefCounted
## Persistent Local Save System for Project Knight: Handles user campaign progress, traits, and stats.

const SAVE_FILE_PATH := "user://save_data.json"
const CURRENT_SCHEMA_VERSION := "1.0.0"

const DEFAULT_SAVE_DATA: Dictionary = {
	"schema_version": CURRENT_SCHEMA_VERSION,
	"stage_index": 0,
	"selected_trait": "basic",
	"cleared": [false, false, false, false, false],
	"unlocked_traits": ["basic", "reach"],
	"ad_free": false,
	"stats": {
		"total_clears": 0,
		"deaths": 0,
		"soul_shards": 0,
		"upgrades": {
			"hp_boost": 0,
			"dmg_boost": 0,
			"shadow_dash": 0
		},
		"last_updated": 0
	}
}


static func add_shards(amount: int) -> int:
	var data := load_game()
	var stats: Dictionary = data.get("stats", {})
	var current: int = int(stats.get("soul_shards", 0)) + amount
	stats["soul_shards"] = current
	save_game(int(data.get("stage_index", 0)), str(data.get("selected_trait", "basic")), data.get("cleared", []), stats)
	return current


static func get_shards() -> int:
	var data := load_game()
	var stats: Dictionary = data.get("stats", {})
	return int(stats.get("soul_shards", 0))


static func get_upgrade_level(upgrade_id: String) -> int:
	var data := load_game()
	var stats: Dictionary = data.get("stats", {})
	var upgrades: Dictionary = stats.get("upgrades", {})
	return int(upgrades.get(upgrade_id, 0))


static func purchase_upgrade(upgrade_id: String, cost: int, max_level: int = 1) -> bool:
	var data := load_game()
	var stats: Dictionary = data.get("stats", {})
	var shards: int = int(stats.get("soul_shards", 0))
	if shards < cost:
		return false
	var upgrades: Dictionary = stats.get("upgrades", {})
	var current_lvl: int = int(upgrades.get(upgrade_id, 0))
	if current_lvl >= max_level and max_level > 0:
		return false
	upgrades[upgrade_id] = current_lvl + 1
	stats["upgrades"] = upgrades
	stats["soul_shards"] = shards - cost
	save_game(int(data.get("stage_index", 0)), str(data.get("selected_trait", "basic")), data.get("cleared", []), stats)
	return true


static func is_ad_free() -> bool:
	var data := load_game()
	if data.has("ad_free"):
		return bool(data["ad_free"])
	var stats: Dictionary = data.get("stats", {})
	return bool(stats.get("ad_free", false))


static func set_ad_free(enabled: bool) -> void:
	var data := load_game()
	var stats: Dictionary = data.get("stats", {}).duplicate(true)
	stats["ad_free"] = enabled
	save_game(int(data.get("stage_index", 0)), str(data.get("selected_trait", "basic")), data.get("cleared", []), stats)


static func apply_upgrades_to_player(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return
	var hp_boost := get_upgrade_level("hp_boost")
	var dmg_boost := get_upgrade_level("dmg_boost")
	var dash_unlocked := get_upgrade_level("shadow_dash")
	if "max_hp" in player:
		player.max_hp = 3 + hp_boost
		if "current_hp" in player:
			player.current_hp = mini(int(player.current_hp) + hp_boost, int(player.max_hp))
	if "current_attack_damage" in player:
		player.current_attack_damage = 1 + dmg_boost
	if "has_shadow_dash" in player:
		player.has_shadow_dash = (dash_unlocked > 0 or player.has_shadow_dash)
	var spd_boost := get_upgrade_level("speed_boost")
	var atk_spd_boost := get_upgrade_level("attack_speed_boost")
	if player.has_method("update_stats_from_upgrades"):
		player.update_stats_from_upgrades(spd_boost, atk_spd_boost)





static func save_game(stage_idx: int, trait_id: String, cleared_arr: Array, extra_stats: Dictionary = {}) -> bool:
	var existing_data := load_game()

	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Failed to open save file for writing: %s (Error: %d)" % [SAVE_FILE_PATH, FileAccess.get_open_error()])
		return false

	var save_dict: Dictionary = DEFAULT_SAVE_DATA.duplicate(true)
	var ad_free_val: bool = bool(existing_data.get("ad_free", false))
	if extra_stats.has("ad_free"):
		ad_free_val = bool(extra_stats["ad_free"])
	save_dict["ad_free"] = ad_free_val
	save_dict["stage_index"] = clampi(stage_idx, 0, 4)
	save_dict["selected_trait"] = trait_id
	save_dict["cleared"] = cleared_arr.duplicate()

	var stats: Dictionary = save_dict["stats"]
	for k in extra_stats:
		if k != "ad_free":
			stats[k] = extra_stats[k]
	stats["last_updated"] = Time.get_unix_time_from_system()

	var json_string := JSON.stringify(save_dict, "\t")
	file.store_string(json_string)
	file.close()
	return true


static func load_game() -> Dictionary:
	if not has_save_file():
		return DEFAULT_SAVE_DATA.duplicate(true)

	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		push_warning("[SaveManager] Save file exists but could not be read. Returning defaults.")
		return DEFAULT_SAVE_DATA.duplicate(true)

	var content := file.get_as_text().strip_edges()
	file.close()

	if content.is_empty():
		return DEFAULT_SAVE_DATA.duplicate(true)

	var test_json_conv := JSON.new()
	var parse_result := test_json_conv.parse(content)
	if parse_result != OK:
		push_error("[SaveManager] Corrupt save file JSON. Returning defaults.")
		return DEFAULT_SAVE_DATA.duplicate(true)

	var parsed_data = test_json_conv.data
	if not (parsed_data is Dictionary):
		return DEFAULT_SAVE_DATA.duplicate(true)

	var result: Dictionary = DEFAULT_SAVE_DATA.duplicate(true)
	var loaded_dict: Dictionary = parsed_data as Dictionary

	if loaded_dict.has("ad_free"):
		result["ad_free"] = bool(loaded_dict["ad_free"])
	if loaded_dict.has("stage_index"):
		result["stage_index"] = clampi(int(loaded_dict["stage_index"]), 0, 4)
	if loaded_dict.has("selected_trait"):
		result["selected_trait"] = str(loaded_dict["selected_trait"])
	if loaded_dict.has("cleared") and loaded_dict["cleared"] is Array:
		var raw_cleared: Array = loaded_dict["cleared"]
		var cleared_bools: Array[bool] = [false, false, false, false, false]
		for i in range(mini(raw_cleared.size(), 5)):
			cleared_bools[i] = bool(raw_cleared[i])
		result["cleared"] = cleared_bools
	if loaded_dict.has("stats") and loaded_dict["stats"] is Dictionary:
		result["stats"] = loaded_dict["stats"]
		if not loaded_dict.has("ad_free") and result["stats"].has("ad_free"):
			result["ad_free"] = bool(result["stats"]["ad_free"])

	return result



static func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)


static func clear_save() -> bool:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var dir := DirAccess.open("user://")
		if dir != null:
			var err := dir.remove("save_data.json")
			return err == OK
	return true
