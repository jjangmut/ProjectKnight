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


const STAGE_RELICS := {
	1: {
		"id": "bastion_shield",
		"name": "타락한 사령관의 수호 방패",
		"title": "사령관의 대형 방패",
		"rarity": "전설 유물",
		"icon_color": Color(1.0, 0.85, 0.25),
		"desc": "저스트 패링 시 3 데미지 치명타 반격 활성화",
		"visual": "shield",
		"visual_name": "강철 수호 방패 외형 장착",
	},
	2: {
		"id": "shadow_cloak",
		"name": "심연 맹수의 그림자 망토",
		"title": "맹수의 바람 망토",
		"rarity": "전설 유물",
		"icon_color": Color(0.95, 0.25, 0.35),
		"desc": "그림자 대시 쿨타임 -25% & 이동 속도 +20 영구 증가",
		"visual": "cloak",
		"visual_name": "진홍빛 그림자 망토 외형 장착",
	},
	3: {
		"id": "piercing_quiver",
		"name": "폐허 저격수의 예기 화살깃",
		"title": "폐허 저격수의 시위",
		"rarity": "전설 유물",
		"icon_color": Color(0.3, 0.95, 1.0),
		"desc": "3타 콤보 피니셔 검기 사거리 +40% 및 비행 속도 +20% 증가",
		"visual": "quiver",
		"visual_name": "예기 화살통 및 검기 광륜 외형 장착",
	},
	4: {
		"id": "golem_pauldrons",
		"name": "고대 수호자의 룬 견갑",
		"title": "타이탄 룬 견갑",
		"rarity": "신화 유물",
		"icon_color": Color(0.95, 0.65, 0.2),
		"desc": "최대 체력 +1 영구 증가 및 피격 시 넉백 저항",
		"visual": "pauldrons",
		"visual_name": "고대 타이탄 룬 어깨 견갑 외형 장착",
	},
	5: {
		"id": "abyssal_crown",
		"name": "심연 심판관의 공허 날개깃",
		"title": "공허의 심판관 크라운",
		"rarity": "신화 유물",
		"icon_color": Color(0.8, 0.4, 1.0),
		"desc": "기본 공격력 +1 영구 강화 및 공중 체공 시간 증가",
		"visual": "crown",
		"visual_name": "공허의 에테르 헤일로/날개깃 외형 장착",
	}
}


static func mark_stage_cleared(stage_num: int) -> void:
	var data := load_game()
	var raw_cleared: Array = data.get("cleared", [false, false, false, false, false])
	var cleared_arr: Array = raw_cleared.duplicate()
	var idx := stage_num - 1
	if idx >= 0 and idx < cleared_arr.size():
		cleared_arr[idx] = true
	var stats: Dictionary = data.get("stats", {})
	save_game(maxi(stage_num, int(data.get("stage_index", 0))), str(data.get("selected_trait", "basic")), cleared_arr, stats)


static func is_stage_cleared(stage_num: int) -> bool:
	var data := load_game()
	var cleared_arr: Array = data.get("cleared", [false, false, false, false, false])
	var idx := stage_num - 1
	if idx >= 0 and idx < cleared_arr.size():
		return bool(cleared_arr[idx])
	return false


static func get_cleared_stages() -> Array[bool]:
	var data := load_game()
	var raw: Array = data.get("cleared", [false, false, false, false, false])
	var res: Array[bool] = [false, false, false, false, false]
	for i in range(mini(raw.size(), 5)):
		res[i] = bool(raw[i])
	return res





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
