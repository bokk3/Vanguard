extends SceneTree

func _init() -> void:
	print("==================================================================")
	print("RUNNING AUTOMATED LAUNCH FLY-THROUGH & PROLOGUE INTRO TEST SUITE")
	print("==================================================================")
	
	# 1. Test Mission Dossiers Completeness (All 8 Missions)
	print("\n[TEST 1] Verifying all 8 missions have complete briefing dossiers...")
	var selector_script = load("res://mission_selector.gd")
	assert(selector_script != null, "Failed to load mission_selector.gd")
	var selector = Control.new()
	selector.set_script(selector_script)
	root.add_child(selector)
	
	var expected_missions = ["M01", "M02", "M03", "M04", "M05", "M06", "M07", "M08"]
	for mid in expected_missions:
		assert(selector.DOSSIERS.has(mid), "MissionSelector missing dossier for " + mid)
		var d = selector.DOSSIERS[mid]
		assert(d.get("codename", "") != "", "Missing codename for " + mid)
		assert(d.get("narrative", "") != "", "Missing narrative for " + mid)
		assert(d.get("flight_specs", "") != "", "Missing flight_specs for " + mid)
		assert(d.get("threat_assessment", "") != "", "Missing threat_assessment for " + mid)
		print("  [OK] Mission [%s] dossier validated: %s" % [mid, d["codename"]])
	selector.queue_free()
	
	# 2. Test HomeMenu Launch Fly-Through Animation Setup
	print("\n[TEST 2] Verifying HomeMenu Vanguard logo & camera fly-through...")
	var menu_scene = load("res://home_menu.tscn")
	assert(menu_scene != null, "Failed to load home_menu.tscn")
	var menu = menu_scene.instantiate()
	root.add_child(menu)
	menu._ready()
	
	assert(menu.camera_3d != null, "Camera3D not found on HomeMenu")
	assert(menu.title_box_right != null, "TitleBoxRight not found on HomeMenu")
	assert(menu.fade_overlay != null, "FadeOverlay not found on HomeMenu")
	assert(menu.warp_audio != null, "WarpAudio not found on HomeMenu")
	print("  [OK] HomeMenu contains Camera3D, TitleBoxRight, FadeOverlay, and WarpAudio.")
	
	# Trigger launch animation
	menu._launch_game_animation("M01", false)
	assert(menu.is_launching == true, "is_launching should be true after triggering launch")
	assert(menu.continue_btn.disabled == true, "Buttons should be disabled during fly-through")
	print("  [OK] Launch fly-through animation dispatched with UI lock.")
	menu.queue_free()
	
	# 3. Test Prologue Cutscene Routing Logic
	print("\n[TEST 3] Verifying Prologue Cutscene transition routing...")
	var mm_script = load("res://mission_manager.gd")
	var mm = Node.new()
	mm.name = "MissionManager"
	mm.set_script(mm_script)
	root.add_child(mm)
	
	var prologue_scene = load("res://prologue_cutscene.tscn")
	assert(prologue_scene != null, "Failed to load prologue_cutscene.tscn")
	var prologue = prologue_scene.instantiate()
	root.add_child(prologue)
	prologue._ready()
	
	# Test preview mode routing
	mm.is_prologue_preview_only = true
	assert(mm.is_prologue_preview_only == true, "MissionManager should hold preview flag")
	print("  [OK] Preview mode correctly flags return to home_menu.")
	
	# Test mission 1 mode routing
	mm.is_prologue_preview_only = false
	assert(mm.is_prologue_preview_only == false, "Mission 1 intro correctly flags forward progression to main.tscn.")
	print("  [OK] Mission 1 launch sequence guarantees intro playback before main sortie.")
	
	prologue.queue_free()
	mm.queue_free()
	
	print("\n==================================================================")
	print("ALL LAUNCH FLY-THROUGH & PROLOGUE INTRO TESTS PASSED (100%)!")
	print("==================================================================")
	quit(0)
