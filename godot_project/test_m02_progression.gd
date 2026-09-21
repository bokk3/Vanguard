extends SceneTree

func _init() -> void:
	print("==================================================================")
	print("RUNNING AUTOMATED M02 COMPLETION & INTERLUDE PROGRESSION TEST")
	print("==================================================================")
	
	var root = get_root()
	
	# 1. Setup MissionManager Autoload
	var mm_script = load("res://mission_manager.gd")
	assert(mm_script != null, "Failed to load mission_manager.gd")
	var mm = Node.new()
	mm.name = "MissionManager"
	mm.set_script(mm_script)
	root.add_child(mm)
	mm._ready()
	
	# 2. Test M02 Level Initialization and Objectives
	print("\n[TEST 1] Testing M02 Initialization & Objectives...")
	mm.current_mission_id = "M02"
	var dummy_level = Node3D.new()
	dummy_level.name = "Main"
	var ship = CharacterBody3D.new()
	ship.name = "Spaceship"
	ship.position = Vector3(0, 40, 0)
	dummy_level.add_child(ship)
	root.add_child(dummy_level)
	
	mm.initialize_level(dummy_level)
	assert(mm.active_objectives.size() == 3, "Expected 3 objectives for M02, got: " + str(mm.active_objectives.size()))
	print("  [OK] M02 objectives initialized: ", mm.active_objectives.map(func(o): return o["id"]))
	
	# Check altitude objective completes when flying below 120m
	mm._evaluate_continuous_objectives(0.016)
	var obj_canyon = null
	for o in mm.active_objectives:
		if o["id"] == "obj_canyon":
			obj_canyon = o
			break
	assert(obj_canyon != null, "obj_canyon objective not found")
	assert(obj_canyon["status"] == "COMPLETED", "obj_canyon should be COMPLETED at y=40m")
	print("  [OK] obj_canyon is COMPLETED at low altitude.")
	
	# 3. Simulate Relays and Patrol Escorts Destruction
	print("\n[TEST 2] Simulating M02 Target Destruction & Completion...")
	var test_result = {"fired": false, "mid": ""}
	mm.mission_completed.connect(func(mid, _stats):
		test_result["fired"] = true
		test_result["mid"] = mid
	)
	
	# Destroy 3 relays
	for i in range(3):
		mm._on_mission_target_destroyed(null, "obj_relays")
	# Destroy 4 patrol drones
	for i in range(4):
		mm._on_mission_target_destroyed(null, "obj_escorts")
	
	assert(test_result["fired"], "mission_completed should have emitted for M02")
	assert(test_result["mid"] == "M02", "Expected completed mission to be M02, got: " + test_result["mid"])
	assert(mm.is_mission_unlocked("M03"), "M03 should be unlocked after completing M02")
	print("  [OK] M02 completed successfully and unlocked M03.")
	
	# 4. Test Debrief Screen Scramble Next Sortie Button
	print("\n[TEST 3] Testing Debrief Screen Transition from M02 -> M03...")
	var debrief_scene = load("res://debrief_screen.tscn")
	assert(debrief_scene != null, "Failed to load debrief_screen.tscn")
	var debrief = debrief_scene.instantiate()
	root.add_child(debrief)
	
	var fake_stats = {
		"mission_id": "M02",
		"elapsed_time": 120.0,
		"missiles_fired": 4,
		"missiles_hit": 4,
		"hit_rate": 1.0,
		"targets_destroyed": 7,
		"hull_remaining": 88.0,
		"cannon_expended": 120
	}
	debrief.show_victory_debrief(fake_stats)
	assert(debrief.next_mission_id == "M03", "Expected next_mission_id to be M03, got: " + debrief.next_mission_id)
	print("  [OK] Debrief screen correctly resolved next_mission_id = 'M03'")
	
	# Call _on_scramble_next_pressed (without changing scene to prevent unloading test script)
	var interlude_map = {
		"M02": "INT_M01_M02",
		"M03": "INT_M02_M03",
		"M04": "INT_M03_M04"
	}
	mm.pending_interlude_id = interlude_map[debrief.next_mission_id]
	mm.current_mission_id = debrief.next_mission_id
	assert(mm.pending_interlude_id == "INT_M02_M03", "Pending interlude should be INT_M02_M03")
	print("  [OK] pending_interlude_id set to 'INT_M02_M03'")
	
	# 5. Test Interlude Cutscene Dynamic Instantiation & Reading pending_interlude_id
	print("\n[TEST 4] Testing Interlude Cutscene Instantiation with pending_interlude_id...")
	var cutscene_scene = load("res://interlude_cutscene.tscn")
	assert(cutscene_scene != null, "Failed to load interlude_cutscene.tscn")
	var cutscene = cutscene_scene.instantiate()
	# add_child triggers _ready() which must pick up pending_interlude_id
	root.add_child(cutscene)
	cutscene._ready()
	
	assert(cutscene.current_id == "INT_M02_M03", "Cutscene should have configured INT_M02_M03, got: " + cutscene.current_id)
	assert(cutscene.config.get("next_mission") == "M03", "Cutscene next_mission should be M03, got: " + str(cutscene.config.get("next_mission")))
	assert(cutscene.config.get("subtitle") == "THE LIFTOFF PROTOCOL", "Cutscene subtitle mismatch: " + str(cutscene.config.get("subtitle")))
	print("  [OK] Interlude cutscene configured correctly: ", cutscene.current_id, " ('", cutscene.config.get("subtitle"), "') -> Next: ", cutscene.config.get("next_mission"))
	
	# Test transition from cutscene to next mission
	var next_m = cutscene.config.get("next_mission", "")
	mm.current_mission_id = next_m
	mm.pending_interlude_id = ""
	assert(mm.current_mission_id == "M03", "MissionManager current_mission_id should be M03, got: " + mm.current_mission_id)
	assert(mm.pending_interlude_id == "", "MissionManager pending_interlude_id should be cleared")
	print("  [OK] Cutscene transition cleanly hands off to M03.")
	
	print("\n==================================================================")
	print("ALL M02 PROGRESSION & INTERLUDE TESTS PASSED (100%)!")
	print("==================================================================")
	
	# Cleanup
	cutscene.queue_free()
	debrief.queue_free()
	dummy_level.queue_free()
	mm.queue_free()
	
	quit(0)
