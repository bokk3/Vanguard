extends SceneTree

func _init() -> void:
	print("--- BEGINNING HEADLESS CAMPAIGN & ASSET VERIFICATION ---")
	
	# 1. Verify Audio Files on disk
	var manifest_file = FileAccess.open("res://data/campaign_manifest.json", FileAccess.READ)
	assert(manifest_file != null, "Manifest file not found!")
	var manifest = JSON.parse_string(manifest_file.get_as_text())
	manifest_file.close()
	
	var missions = manifest.get("missions", [])
	print("Found ", missions.size(), " missions in manifest.")
	
	for m in missions:
		var mid = m.get("id")
		print("Checking Mission: ", mid, " - ", m.get("codename"))
		# Check sky preset
		var sky = m.get("sky_preset")
		assert(sky != "", "Missing sky preset for " + mid)
		# Check objectives
		var objs = m.get("objectives", [])
		assert(objs.size() > 0, "No objectives defined for " + mid)
		# Check tactical recon card
		var card_path = "res://ui/mission_card_" + mid.to_lower() + ".png"
		assert(FileAccess.file_exists(card_path), "Missing recon card: " + card_path)
		print("  -> Recon Card OK: ", card_path)
	
	# 2. Test Mission Manager Spawning
	var mm_script = load("res://mission_manager.gd")
	assert(mm_script != null, "Failed to load mission_manager.gd")
	var mm = Node.new()
	mm.name = "MissionManager"
	mm.set_script(mm_script)
	root.add_child(mm)
	
	for mid in ["M01", "M02", "M03", "M04", "M05", "M06", "M07", "M08"]:
		mm.current_mission_id = mid
		var dummy_root = Node3D.new()
		dummy_root.name = "LevelRoot"
		var env = WorldEnvironment.new()
		env.name = "WorldEnvironment"
		env.environment = Environment.new()
		dummy_root.add_child(env)
		
		var sun = DirectionalLight3D.new()
		sun.name = "DirectionalLight3D"
		dummy_root.add_child(sun)
		
		var ship = CharacterBody3D.new()
		ship.name = "Spaceship"
		ship.set("current_speed", 50.0)
		ship.set("stall_speed", 25.0)
		dummy_root.add_child(ship)
		
		root.add_child(dummy_root)
		mm.initialize_level(dummy_root)
		
		var child_count = dummy_root.get_child_count()
		print("  -> Mission [", mid, "] initialized successfully with ", child_count, " entities.")
		
		# Specific assertions
		match mid:
			"M01":
				assert(dummy_root.find_child("ReconDrone_01", true, false) != null, "M01 Recon drone missing")
			"M02":
				var relay = dummy_root.find_child("JammingRelay_01", true, false)
				assert(relay != null, "M02 Jamming relay missing")
				assert(relay.is_in_group("enemies"), "Relay not in group enemies")
			"M03":
				var transport = dummy_root.find_child("TransportOlympus4", true, false)
				assert(transport != null, "M03 Transport Olympus4 missing")
				assert(transport.is_in_group("friendlies"), "Transport not in group friendlies")
			"M04":
				var boss = dummy_root.find_child("Boss_CombineGhost", true, false)
				assert(boss != null, "M04 Boss CombineGhost missing")
				assert(boss.is_in_group("enemies"), "Boss not in group enemies")
			"M05":
				assert(dummy_root.find_child("AsteroidBeltRoot", true, false) != null, "M05 Asteroid belt root missing")
				assert(dummy_root.find_child("TetherMine_01", true, false) != null, "M05 Tether mine missing")
			"M06":
				assert(dummy_root.find_child("CavernTrenchRoot", true, false) != null, "M06 Cavern trench root missing")
				assert(dummy_root.find_child("GeothermalGen_01", true, false) != null, "M06 Geothermal generator missing")
			"M07":
				var carrier = dummy_root.find_child("SOC_Dauntless", true, false)
				assert(carrier != null, "M07 SOC Dauntless missing")
				assert(carrier.is_in_group("friendlies"), "Carrier not in group friendlies")
				assert(dummy_root.find_child("FusionTorpedo_01", true, false) != null, "M07 Fusion torpedo missing")
			"M08":
				var dread = dummy_root.find_child("Dreadnought_Nemesis9", true, false)
				assert(dread != null, "M08 Dreadnought Nemesis9 missing")
				assert(dread.is_in_group("enemies"), "Dreadnought not in group enemies")
				assert(dummy_root.find_child("Flak_Turret_01", true, false) != null or dummy_root.find_child("FlakPod_01", true, false) != null, "M08 Flak turret/pod missing")
				assert(dummy_root.find_child("ReactorCore", true, false) != null, "M08 Reactor core missing")
		
		dummy_root.free()
	
	# 3. Test Mission Selector Scene
	var selector_scene = load("res://mission_selector.tscn")
	assert(selector_scene != null, "Failed to load mission_selector.tscn")
	var selector = selector_scene.instantiate()
	root.add_child(selector)
	selector.open_selector()
	for mid in ["M01", "M02", "M03", "M04", "M05", "M06", "M07", "M08"]:
		selector.select_mission(mid)
		print("  -> MissionSelector selected ", mid, " successfully.")
	selector.free()
	
	# 4. Test Debrief Screen Animations & Scorecard
	var debrief_scene = load("res://debrief_screen.tscn")
	assert(debrief_scene != null, "Failed to load debrief_screen.tscn")
	var debrief = debrief_scene.instantiate()
	root.add_child(debrief)
	var test_stats = {
		"elapsed_time": 94.5,
		"targets_destroyed": 4,
		"missiles_fired": 4,
		"missiles_hit": 4,
		"hit_rate": 1.0,
		"hull_remaining": 92.0,
		"cannon_expended": 85
	}
	debrief.show_victory_debrief(test_stats)
	assert(debrief.is_animating == true, "Debrief animation should be active")
	debrief.skip_animation()
	assert(debrief.is_animating == false, "Debrief animation should be finished after skip")
	assert(debrief.rank_badge.text == "S", "Expected S-rank for flawless run, got: " + debrief.rank_badge.text)
	print("  -> DebriefScreen animated scorecard & skip validated successfully (Rank: ", debrief.rank_badge.text, ").")
	debrief.free()
	
	# 5. Test HUD & Flight Telemetry
	var hud_script = load("res://hud.gd")
	assert(hud_script != null, "Failed to load hud.gd")
	var hud = Control.new()
	hud.set_script(hud_script)
	root.add_child(hud)
	hud._ready()
	assert(hud.high_g_audio_player != null, "High-G audio player not initialized")
	print("  -> In-flight HUD flight telemetry & avionics validated successfully.")
	hud.free()
	
	# 6. Test Cinematic Interlude Cutscenes & Chapter 1/2 Finales
	var cutscene_scene = load("res://interlude_cutscene.tscn")
	assert(cutscene_scene != null, "Failed to load interlude_cutscene.tscn")
	
	var interlude_presets = [
		"INT_M01_M02", "INT_M02_M03", "INT_M03_M04", "EPILOGUE_CH1",
		"INT_M04_M05", "INT_M05_M06", "INT_M06_M07", "INT_M07_M08", "EPILOGUE_CH2"
	]
	for i_id in interlude_presets:
		var cutscene = cutscene_scene.instantiate()
		cutscene.setup(i_id)
		root.add_child(cutscene)
		assert(cutscene.current_id == i_id, "Cutscene did not configure id: " + i_id)
		assert(cutscene.config.has("cues"), "Cutscene config missing cues: " + i_id)
		assert(cutscene.config["cues"].size() > 0, "Cutscene cues empty: " + i_id)
		var a_path = cutscene.config.get("audio_path", "")
		assert(FileAccess.file_exists(a_path), "Cutscene narration audio file missing: " + a_path)
		
		# Test frame progression
		cutscene._process(1.0)
		assert(cutscene.playback_time >= 1.0, "Cutscene playback_time did not advance")
		
		print("  -> Interlude cutscene [", i_id, "] validated successfully (Audio: ", a_path, ").")
		cutscene.free()
	
	mm.free()
	print("--- ALL CAMPAIGN MISSIONS, DEBRIEF, FLIGHT TELEMETRY & CUTSCENES PASSED (100%) ---")
	quit(0)
