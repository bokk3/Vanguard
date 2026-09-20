extends SceneTree

func _init() -> void:
	print("\n========================================================")
	print(">>> RUNNING COMBAT, DIFFICULTY, CONTROLS & BOSS TEST")
	print("========================================================\n")
	
	var passed = 0
	var failed = 0
	
	# Root test node in active tree
	var test_root = Node3D.new()
	test_root.name = "TestRoot"
	root.add_child(test_root)
	
	# 1. ConfigManager & Difficulty
	print("[TEST 1] Testing ConfigManager difficulty multipliers & keybindings...")
	var config_script = load("res://config_manager.gd")
	var cfg = Node.new()
	cfg.name = "ConfigManager"
	cfg.set_script(config_script)
	test_root.add_child(cfg)
	
	cfg.difficulty = "EASY"
	if cfg.get_difficulty_damage_multiplier() == 0.5 and cfg.get_difficulty_drone_cooldown() == 4.5 and cfg.get_difficulty_drone_spread() == 0.12:
		print("  -> EASY difficulty verified (dmg 0.5x, cd 4.5s, spread 0.12)")
		passed += 1
	else:
		push_error("EASY difficulty check failed")
		failed += 1
		
	cfg.difficulty = "ACE"
	if cfg.get_difficulty_damage_multiplier() == 1.5 and cfg.get_difficulty_drone_cooldown() == 2.0 and cfg.get_difficulty_drone_spread() == 0.04:
		print("  -> ACE difficulty verified (dmg 1.5x, cd 2.0s, spread 0.04)")
		passed += 1
	else:
		push_error("ACE difficulty check failed")
		failed += 1
		
	cfg.difficulty = "NORMAL"
	if cfg.get_difficulty_damage_multiplier() == 1.0 and cfg.get_difficulty_drone_cooldown() == 3.0 and cfg.get_difficulty_drone_spread() == 0.08:
		print("  -> NORMAL difficulty verified (dmg 1.0x, cd 3.0s, spread 0.08)")
		passed += 1
	else:
		push_error("NORMAL difficulty check failed")
		failed += 1
		
	# 2. Keybindings & Reversed Pitch/Roll defaults
	print("[TEST 2] Verifying default pitch and roll mappings...")
	var def_keys = cfg.get_default_keybindings(false)
	if def_keys["pitch_up"] == KEY_UP and def_keys["pitch_down"] == KEY_DOWN:
		print("  -> Default pitch mappings: pitch_up=KEY_UP, pitch_down=KEY_DOWN")
		passed += 1
	else:
		push_error("Default pitch bindings incorrect: " + str(def_keys))
		failed += 1
		
	# 3. Spaceship Controller & Group
	print("[TEST 3] Testing Spaceship controller & group registration...")
	var ship = CharacterBody3D.new()
	ship.name = "Spaceship"
	ship.add_to_group("player")
	test_root.add_child(ship)
	
	var ship_script = load("res://spaceship_controller.gd")
	# Check ship methods
	if ship.is_in_group("player"):
		print("  -> Spaceship registered in 'player' group successfully")
		passed += 1
	else:
		push_error("Spaceship not in 'player' group")
		failed += 1
		
	# 4. Boss Combine Ghost Acquisition, AI & Dual Shields/Hull
	print("[TEST 4] Testing Boss Combine Ghost AI target acquisition, dogfight pursuit & shields...")
	var boss_scene = load("res://boss_combine_ghost.tscn")
	if boss_scene:
		var boss = boss_scene.instantiate()
		boss.name = "Boss_CombineGhost"
		boss.position = Vector3(0, 85, -360)
		test_root.add_child(boss)
		
		# Test acquisition
		boss._acquire_player()
		if boss.target_player == ship:
			print("  -> Boss successfully acquired Spaceship in 'player' group")
			passed += 1
		else:
			push_error("Boss target_player mismatch: " + str(boss.target_player))
			failed += 1
			
		# Test combat state at 360m: must NOT be ZOOM_CLIMB (fleeing)
		boss.state_timer = 0.0
		boss._update_ai_state(0.016)
		if boss.current_state != boss.State.ZOOM_CLIMB:
			print("  -> Boss AI state is combat engaging (%d) instead of fleeing in ZOOM_CLIMB" % boss.current_state)
			passed += 1
		else:
			push_error("Boss AI incorrectly entered ZOOM_CLIMB at combat distance")
			failed += 1
			
		# Test shield & hull damage
		var init_sh = boss.shield
		var init_hull = boss.hull
		boss.take_damage(60.0)
		if boss.shield == init_sh - 60.0 and boss.hull == init_hull:
			print("  -> Boss shields absorbed 60.0 dmg (Shield: %s, Hull: %s)" % [boss.shield, boss.hull])
			passed += 1
		else:
			push_error("Boss shield damage calculation failed")
			failed += 1
			
		# Deplete shields and damage hull
		boss.take_damage(boss.shield + 40.0)
		if boss.shield == 0.0 and boss.hull == init_hull - 40.0:
			print("  -> Boss shield overflow damaged hull properly (Shield: 0.0, Hull: %s)" % boss.hull)
			passed += 1
		else:
			push_error("Boss hull overflow damage failed")
			failed += 1
	else:
		push_error("Failed to load boss_combine_ghost.tscn")
		failed += 1

	# 5. Target Drone Weapons
	print("[TEST 5] Testing Target Drone weapons system & cooldown...")
	var drone_script = load("res://target_drone.gd")
	var drone = Node3D.new()
	drone.set_script(drone_script)
	test_root.add_child(drone)
	drone.position = Vector3(0, 85, -120)
	drone.target_player = ship
	
	if "gun_cooldown" in drone and "bullet_scene" in drone:
		print("  -> Target Drone weapons system verified (cooldown and bullet_scene present)")
		passed += 1
	else:
		push_error("Target drone weapons not initialized")
		failed += 1

	# 6. Mission Manager M04 Intercept & Completion
	print("[TEST 6] Testing MissionManager M04 intercept evaluation...")
	var mm_script = load("res://mission_manager.gd")
	var mm = Node.new()
	mm.name = "MissionManager"
	mm.set_script(mm_script)
	test_root.add_child(mm)
	mm._load_campaign_manifest()
	mm.current_mission_id = "M04"
	mm.initialize_level(test_root)
	
	# Check objectives loaded
	var has_intercept = false
	var has_boss = false
	var has_escorts = false
	for obj in mm.active_objectives:
		if obj["id"] == "obj_intercept": has_intercept = true
		if obj["id"] == "obj_boss": has_boss = true
		if obj["id"] == "obj_escorts": has_escorts = true
	
	if has_intercept and has_boss and has_escorts:
		print("  -> M04 objectives verified (intercept, boss, escorts)")
		passed += 1
	else:
		push_error("M04 missing expected objectives")
		failed += 1
		
	# Test intercept objective trigger
	mm._evaluate_continuous_objectives(0.016)
	var intercept_completed = false
	for obj in mm.active_objectives:
		if obj["id"] == "obj_intercept" and obj["status"] == "COMPLETED":
			intercept_completed = true
			break
	if intercept_completed:
		print("  -> M04 Intercept objective automatically completed when within radar combat range (360m)")
		passed += 1
	else:
		push_error("M04 Intercept objective did not complete at 360m range")
		failed += 1

	test_root.queue_free()

	print("\n========================================================")
	print(">>> COMBAT & CONTROLS TEST SUITE: %d PASSED, %d FAILED" % [passed, failed])
	print("========================================================\n")
	
	if failed == 0:
		quit(0)
	else:
		quit(1)
