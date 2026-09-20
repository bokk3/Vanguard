extends SceneTree

## Automated Headless Test for Vanguard Mission Debriefing Screen
## Verifies victory scorecard, failure handling, rank calculations, and scene bindings.

func _init() -> void:
	print("--- [TEST] Starting Vanguard Debrief Screen Test Suite ---")
	
	test_rank_calculations()
	test_victory_scorecard_presentation()
	test_failure_presentation()
	test_main_scene_integration()
	
	print("\n>>> ALL DEBRIEF SCREEN TESTS PASSED SUCCESSFULLY (Exit code 0) <<<")
	quit(0)

func test_rank_calculations() -> void:
	print("\n[TEST 1] Testing Rank & Score Calculations...")
	var debrief = load("res://debrief_screen.gd").new()
	
	# S-Rank case: 90s, 100% accuracy, 95% hull
	var r_s = debrief._calculate_rank(90.0, 100.0, 95.0, 4)
	assert(r_s["rank"] == "S", "Should be S-Rank for fast, pristine combat")
	assert(r_s["score"] >= 18000, "S-Rank score threshold met")
	print("  ✓ S-Rank: %s (%d pts)" % [r_s["title"], r_s["score"]])
	
	# A-Rank case: 140s, 70% accuracy, 60% hull
	var r_a = debrief._calculate_rank(140.0, 70.0, 60.0, 4)
	assert(r_a["rank"] == "A", "Should be A-Rank")
	print("  ✓ A-Rank: %s (%d pts)" % [r_a["title"], r_a["score"]])
	
	# B-Rank case: 180s, 40% accuracy, 40% hull
	var r_b = debrief._calculate_rank(180.0, 40.0, 40.0, 4)
	assert(r_b["rank"] == "B", "Should be B-Rank")
	print("  ✓ B-Rank: %s (%d pts)" % [r_b["title"], r_b["score"]])
	
	debrief.queue_free()

func test_victory_scorecard_presentation() -> void:
	print("\n[TEST 2] Testing Victory Scorecard Presentation...")
	var scene = load("res://debrief_screen.tscn")
	assert(scene != null, "debrief_screen.tscn must load")
	
	var inst = scene.instantiate()
	root.add_child(inst)
	
	var mock_stats = {
		"mission_id": "M01",
		"elapsed_time": 95.0,
		"missiles_fired": 4,
		"missiles_hit": 4,
		"hit_rate": 1.0,
		"targets_destroyed": 4,
		"hull_remaining": 92.0,
		"cannon_expended": 140
	}
	
	inst.current_mission_id = "M01"
	inst.show_victory_debrief(mock_stats)
	inst.skip_animation()
	
	assert(inst.visible == true, "Debrief screen must be visible")
	assert(inst.is_victory == true, "is_victory must be true")
	assert(inst.stat_time_val.text == "01:35", "Time formatted as 01:35")
	assert(inst.stat_targets_val.text == "4 HOSTILES SPLASHED", "Targets smashed text")
	assert(inst.stat_accuracy_val.text == "100% MISSILE LOCK", "Accuracy formatted")
	assert(inst.stat_hull_val.text == "92% COMPOSITE", "Hull remaining formatted")
	assert(inst.stat_cannon_val.text == "140 ROUNDS", "Cannon rounds formatted")
	assert(inst.rank_badge.text == "S", "Should be S-Rank badge")
	
	# Since M01 is completed, Scramble M02 button should be active
	assert(inst.scramble_next_btn.visible == true, "Scramble next button should be visible")
	assert(inst.scramble_next_btn.text.contains("M02"), "Scramble button should target M02")
	print("  ✓ Victory debrief UI populated nominal.")
	
	inst.queue_free()

func test_failure_presentation() -> void:
	print("\n[TEST 3] Testing Failure Presentation...")
	var scene = load("res://debrief_screen.tscn")
	var inst = scene.instantiate()
	root.add_child(inst)
	
	inst.current_mission_id = "M01"
	inst.show_failure_debrief("Airspeed dropped below stall threshold")
	
	assert(inst.visible == true, "Debrief screen must be visible on failure")
	assert(inst.is_victory == false, "is_victory must be false")
	assert(inst.rank_badge.text == "F", "Failure rank must be F")
	assert(inst.scramble_next_btn.visible == false, "Scramble next button must be hidden on failure")
	assert(inst.replay_btn.text == "[ RETRY SORTIE ]", "Button text should be RETRY")
	print("  ✓ Failure debrief UI nominal.")
	
	inst.queue_free()

func test_main_scene_integration() -> void:
	print("\n[TEST 4] Testing main.tscn scene tree integration...")
	var main_scene = load("res://main.tscn")
	assert(main_scene != null, "main.tscn must load")
	
	var inst = main_scene.instantiate()
	root.add_child(inst)
	
	var debrief_node = inst.get_node_or_null("HUD/DebriefScreen")
	assert(debrief_node != null, "DebriefScreen must exist under HUD")
	assert(debrief_node.visible == false, "DebriefScreen should start hidden")
	
	inst.queue_free()
	print("  ✓ main.tscn integration verified.")
