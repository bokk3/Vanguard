extends SceneTree

## Automated Headless Test Suite for Career Flight Stats & Battle Logging
## Validates AuthManager battle logging, sorties/kills/win-rate calculation,
## disk persistence, and CombatStatsDialog UI population.

var frame_count: int = 0
var test_done: bool = false
var timeout: float = 0.0

func _init() -> void:
	print("=================================================================")
	print(">>> Project Vanguard: Career Flight Stats & Logging Test Suite <<<")
	print("=================================================================")

func _process(delta: float) -> bool:
	if test_done:
		return true
		
	timeout += delta
	if timeout > 8.0:
		push_error("Career stats test timed out!")
		quit(1)
		return true

	frame_count += 1
	if frame_count < 2:
		return false
		
	test_done = true
	_run_stats_tests()
	return true

func _run_stats_tests() -> void:
	var auth_mgr = root.get_node_or_null("AuthManager")
	if not auth_mgr:
		auth_mgr = preload("res://auth_manager.gd").new()
		root.add_child(auth_mgr)
	
	# 1. Login local pilot
	auth_mgr.login_local("TEST-MAVERICK", "TopGun Test Squadron", true)
	print("[PASS] Authenticated local pilot: %s" % auth_mgr.callsign)
	
	# Reset stats for clean test
	auth_mgr.stats = {
		"total_sorties": 0,
		"total_kills": 0,
		"total_flight_time_sec": 0.0,
		"highest_mission_unlocked": "M01",
		"battles_won": 0,
		"battles_lost": 0,
		"dogfight_kills": 0,
		"preferred_controls": "AZERTY",
		"battle_history": []
	}
	
	# 2. Record Sortie 1 (Victory)
	auth_mgr.record_battle_result("SORTIE [M01] CLOUDBURST", "VICTORY", 5, 120.0)
	assert(auth_mgr.stats["total_sorties"] == 1, "Sorties count should be 1")
	assert(auth_mgr.stats["total_kills"] == 5, "Kills count should be 5")
	assert(auth_mgr.stats["battles_won"] == 1, "Wins should be 1")
	assert(auth_mgr.stats["battles_lost"] == 0, "Losses should be 0")
	print("[PASS] Sortie 1 recorded (VICTORY, 5 kills, 120s)")
	
	# 3. Record Sortie 2 (Defeat)
	auth_mgr.record_battle_result("SORTIE [M02] APEX ASCENT", "DEFEAT", 2, 45.0)
	assert(auth_mgr.stats["total_sorties"] == 2, "Sorties count should be 2")
	assert(auth_mgr.stats["total_kills"] == 7, "Kills count should be 7")
	assert(auth_mgr.stats["battles_won"] == 1, "Wins should be 1")
	assert(auth_mgr.stats["battles_lost"] == 1, "Losses should be 1")
	assert(abs(auth_mgr.stats["total_flight_time_sec"] - 165.0) < 1.0, "Flight time should be 165s")
	print("[PASS] Sortie 2 recorded (DEFEAT, 2 kills, 45s)")
	
	# 4. Verify History Schema
	var history: Array = auth_mgr.stats["battle_history"]
	assert(history.size() == 2, "History must have 2 entries")
	var entry1: Dictionary = history[0]
	assert(entry1.has("timestamp"), "Entry must have timestamp")
	assert(entry1.has("controls"), "Entry must have controls")
	assert(entry1["theater"] == "SORTIE [M01] CLOUDBURST", "Theater name match")
	assert(entry1["outcome"] == "VICTORY", "Outcome match")
	print("[PASS] Battle history schema verified: %s" % JSON.stringify(entry1))
	
	# 5. Verify Disk Persistence
	var save_path = "user://pilot_profile.json"
	assert(FileAccess.file_exists(save_path), "Save file must exist")
	var file = FileAccess.open(save_path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	assert(parsed["stats"]["total_kills"] == 7, "Persisted kills match")
	print("[PASS] Verified stats persisted to disk JSON.")
	
	# 6. Test CombatStatsDialog UI
	var dialog_scene = preload("res://combat_stats_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	root.add_child(dialog)
	dialog.show_stats()
	assert(dialog.sorties_val.text == "2", "Dialog sorties label matches")
	assert(dialog.kills_val.text == "7", "Dialog kills label matches")
	assert(dialog.wins_val.text == "1", "Dialog wins label matches")
	assert(dialog.losses_val.text == "1", "Dialog losses label matches")
	assert(dialog.win_ratio_val.text == "50.0%", "Dialog win ratio is 50.0%")
	print("[PASS] CombatStatsDialog UI populated successfully with 50.0% win rate.")
	dialog.queue_free()
	
	print("=================================================================")
	print(">>> ALL CAREER FLIGHT STATS TESTS PASSED (100%)              <<<")
	print("=================================================================")
	quit(0)
