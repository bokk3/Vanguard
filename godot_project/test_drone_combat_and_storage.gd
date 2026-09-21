extends SceneTree

func _init() -> void:
	print("==================================================================")
	print("RUNNING AUTOMATED DRONE COMBAT & STORAGE MANAGEMENT TEST SUITE")
	print("==================================================================")
	
	# -------------------------------------------------------------------------
	# TEST 1: Drone Weapons Fire & Difficulty Scaling
	# -------------------------------------------------------------------------
	print("\n[TEST 1] Testing Drone Damage & Difficulty Cadence Scaling...")
	var drone_script = load("res://target_drone.gd")
	assert(drone_script != null, "Failed to load target_drone.gd")
	var drone = Node3D.new()
	drone.set_script(drone_script)
	root.add_child(drone)
	
	# Validate Mission Base Damage escalation (M01 -> M08)
	var dmg_m01 = drone._get_mission_base_damage("M01")
	var dmg_m02 = drone._get_mission_base_damage("M02")
	var dmg_m04 = drone._get_mission_base_damage("M04")
	var dmg_m08 = drone._get_mission_base_damage("M08")
	
	assert(dmg_m01 == 3.0, "M01 damage should be 3.0 HP (easy start)")
	assert(dmg_m02 == 4.0, "M02 damage should be 4.0 HP")
	assert(dmg_m04 > dmg_m02, "M04 damage should be greater than M02")
	assert(dmg_m08 >= 12.0, "M08 climax damage should be >= 12.0 HP")
	print("  [OK] Mission damage scaling validated: M01=%.1f, M02=%.1f, M04=%.1f, M08=%.1f" % [
		dmg_m01, dmg_m02, dmg_m04, dmg_m08
	])
	
	# Validate ConfigManager difficulty multiplier
	var cfg = root.get_node_or_null("ConfigManager")
	if not cfg:
		var cfg_script = load("res://config_manager.gd")
		cfg = Node.new()
		cfg.name = "ConfigManager"
		cfg.set_script(cfg_script)
		root.add_child(cfg)
	
	cfg.difficulty = "EASY"
	assert(cfg.get_difficulty_damage_multiplier() == 0.5, "EASY diff damage multiplier must be 0.5")
	assert(cfg.get_difficulty_drone_cooldown() >= 5.0, "EASY diff drone cooldown should be >= 5.0s (sporadic)")
	assert(cfg.get_difficulty_drone_spread() >= 0.12, "EASY diff drone spread should be wide (inaccurate)")
	
	cfg.difficulty = "NORMAL"
	assert(cfg.get_difficulty_damage_multiplier() == 1.0, "NORMAL diff damage multiplier must be 1.0")
	
	cfg.difficulty = "ACE"
	assert(cfg.get_difficulty_damage_multiplier() == 1.5, "ACE diff damage multiplier must be 1.5")
	assert(cfg.get_difficulty_drone_spread() < 0.05, "ACE diff drone spread should be tighter")
	print("  [OK] ConfigManager difficulty scaling validated (EASY: 0.5x dmg, ACE: 1.5x dmg).")
	drone.queue_free()
	
	# -------------------------------------------------------------------------
	# TEST 2: Hostile Bullet Styling & Player Airframe Damage Reception
	# -------------------------------------------------------------------------
	print("\n[TEST 2] Testing Hostile Bullet & Spaceship take_damage()...")
	var bullet_scene = load("res://bullet.tscn")
	assert(bullet_scene != null, "Failed to load bullet.tscn")
	var bullet = bullet_scene.instantiate()
	root.add_child(bullet)
	bullet.setup(null, Vector3.FORWARD, 0.0, true)
	assert(bullet.is_hostile == true, "Bullet must be flagged as is_hostile")
	var tracer_mesh = bullet.get_node_or_null("TracerMesh") as MeshInstance3D
	assert(tracer_mesh != null and tracer_mesh.material_override != null, "Hostile bullet must have red material override")
	print("  [OK] Hostile bullet configured with crimson tracer visual.")
	bullet.queue_free()
	
	# Test Spaceship damage reception
	var main_scene = load("res://main.tscn")
	assert(main_scene != null, "Failed to load main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	
	var ship = main.get_node_or_null("Spaceship")
	assert(ship != null, "Spaceship not found in main.tscn")
	assert(ship.has_method("take_damage"), "Spaceship must implement take_damage()")
	
	var telem = ship.get_node_or_null("CombatTelemetry")
	assert(telem != null, "CombatTelemetry missing on Spaceship")
	if not ship.telemetry:
		ship.telemetry = telem
	var initial_shield = telem.current_shield
	
	# Fire a hostile round for 15.0 damage
	ship.take_damage(15.0)
	assert(telem.current_shield < initial_shield, "Shield must decrease after taking damage")
	assert(ship.camera_shake_trauma > 0.0, "Camera shake trauma must be added on hit")
	print("  [OK] Spaceship successfully received hostile gunfire: Shield %.1f -> %.1f, Trauma: %.2f" % [
		initial_shield, telem.current_shield, ship.camera_shake_trauma
	])
	
	# Deplete shields and verify hull damage
	ship.take_damage(150.0)
	assert(telem.current_shield == 0.0, "Shield must be 0 after massive hit")
	assert(telem.current_hull < 100.0, "Hull must absorb overflow damage")
	print("  [OK] Damage overflow absorbed by Hull: Hull at %.1f HP" % telem.current_hull)
	main.queue_free()
	
	# -------------------------------------------------------------------------
	# TEST 3: ConfigManager Factory Reset
	# -------------------------------------------------------------------------
	print("\n[TEST 3] Testing ConfigManager reset_to_factory_defaults()...")
	cfg.mouse_sensitivity = 2.8
	cfg.difficulty = "ACE"
	cfg.invert_pitch = true
	cfg.master_volume = 0.3
	
	cfg.reset_to_factory_defaults()
	assert(cfg.mouse_sensitivity == 1.0, "Sensitivity should reset to 1.0")
	assert(cfg.difficulty == "NORMAL", "Difficulty should reset to NORMAL")
	assert(cfg.invert_pitch == false, "Invert pitch should reset to false")
	assert(cfg.master_volume == 1.0, "Master volume should reset to 1.0")
	print("  [OK] ConfigManager successfully restored all settings to factory defaults.")
	
	# -------------------------------------------------------------------------
	# TEST 4: SaveManager & MissionManager Purge
	# -------------------------------------------------------------------------
	print("\n[TEST 4] Testing SaveManager delete_all_saves() & Campaign Reset...")
	var sm = root.get_node_or_null("SaveManager")
	if not sm:
		var sm_script = load("res://save_manager.gd")
		sm = Node.new()
		sm.name = "SaveManager"
		sm.set_script(sm_script)
		root.add_child(sm)
	
	var mm = root.get_node_or_null("MissionManager")
	if not mm:
		var mm_script = load("res://mission_manager.gd")
		mm = Node.new()
		mm.name = "MissionManager"
		mm.set_script(mm_script)
		root.add_child(mm)
	
	# Simulate unlocked progress
	var test_unlocked: Array[String] = ["M01", "M02", "M03", "M04"]
	mm.unlocked_missions = test_unlocked
	mm.completed_missions["M01"] = { "stars": 3 }
	mm.current_mission_id = "M04"
	
	# Write a temporary dummy save file
	sm.ensure_save_dir()
	var test_save_path = sm.get_save_path("test_dummy_slot")
	var f = FileAccess.open(test_save_path, FileAccess.WRITE)
	if f:
		f.store_string('{"test": true}')
		f.close()
	assert(FileAccess.file_exists(test_save_path), "Test save file was not created")
	
	# Purge all saves
	var delete_success = sm.delete_all_saves()
	assert(delete_success == true, "delete_all_saves() should return true")
	assert(not FileAccess.file_exists(test_save_path), "Dummy save file must be deleted")
	assert(mm.unlocked_missions == ["M01"], "Campaign unlocked missions must reset to [M01]")
	assert(mm.completed_missions.is_empty(), "Completed missions must be cleared")
	assert(mm.current_mission_id == "M01", "Current mission must reset to M01")
	print("  [OK] SaveManager and MissionManager purge verified: all saves cleared, campaign reset to M01.")
	
	# -------------------------------------------------------------------------
	# TEST 5: SettingsMenu UI Data & Storage Tab
	# -------------------------------------------------------------------------
	print("\n[TEST 5] Testing SettingsMenu Data & Storage Tab...")
	var settings_scene = load("res://settings_menu.tscn")
	assert(settings_scene != null, "Failed to load settings_menu.tscn")
	var settings = settings_scene.instantiate()
	root.add_child(settings)
	settings._ready()
	
	assert(settings.reset_config_btn != null, "ResetConfigBtn missing in SettingsMenu")
	assert(settings.config_status_label != null, "ConfigStatusLabel missing in SettingsMenu")
	assert(settings.clear_saves_btn != null, "ClearSavesBtn missing in SettingsMenu")
	assert(settings.save_status_label != null, "SaveStatusLabel missing in SettingsMenu")
	
	# Trigger reset config via UI
	settings._on_reset_config_pressed()
	assert(settings.config_status_label.text != "", "ConfigStatusLabel should display confirmation")
	
	# Trigger clear saves via UI
	settings._on_clear_saves_pressed()
	assert(settings.save_status_label.text != "", "SaveStatusLabel should display confirmation")
	print("  [OK] SettingsMenu Data & Storage controls and feedback actions verified.")
	settings.queue_free()
	
	print("\n==================================================================")
	print("ALL DRONE COMBAT & STORAGE MANAGEMENT TESTS PASSED (100%)!")
	print("==================================================================")
	quit(0)
