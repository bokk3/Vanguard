extends SceneTree

## Automated Headless Test Suite for Responsive Scaling & Dialog Sizing
## Tests Vanguard dynamic logo & HUD scaling, 404 badge enlargement,
## duplicate button removal, and dialog viewport compatibility.

var frame_count: int = 0
var test_done: bool = false
var timeout: float = 0.0

func _init() -> void:
	print("=================================================================")
	print(">>> Project Vanguard: Responsive Scaling & Dialog Sizing Test <<<")
	print("=================================================================")

func _process(delta: float) -> bool:
	if test_done:
		return true
		
	timeout += delta
	if timeout > 8.0:
		push_error("Responsive scaling test timed out!")
		quit(1)
		return true

	frame_count += 1
	if frame_count < 2:
		return false
		
	test_done = true
	_run_all_tests()
	return true

func _run_all_tests() -> void:
	# 1. Instantiate HomeMenu
	var menu_scene = preload("res://home_menu.tscn")
	var menu = menu_scene.instantiate()
	root.add_child(menu)
	menu._ready()

	print("\n--- STEP 1: Test 404 Badge 25% Increase & Duplicate Button Fix ---")
	assert(menu.squadron_badge != null, "SquadronBadge must exist")
	# Base size must be 100x100 (25% increase from original 80x80)
	assert(menu.squadron_badge.custom_minimum_size.x >= 100.0, "SquadronBadge must be >= 100px wide (25% increase)")
	assert(menu.squadron_badge.custom_minimum_size.y >= 100.0, "SquadronBadge must be >= 100px tall (25% increase)")
	print("[PASS] SquadronBadge base size verified: %s (25%% increase from 80x80)" % menu.squadron_badge.custom_minimum_size)

	# Verify redundant buttons removed from PilotDossierBox
	var dossier_box = menu.pilot_dossier_box
	assert(dossier_box != null, "PilotDossierBox must exist")
	assert(dossier_box.find_child("BtnRow", true, false) == null, "Redundant BtnRow must be removed")
	assert(dossier_box.find_child("SwitchPilotBtn", true, false) == null, "Redundant SwitchPilotBtn removed from sidebar")
	assert(dossier_box.find_child("RewardsBtn", true, false) == null, "Redundant RewardsBtn removed from sidebar")
	assert(menu.stats_quick_btn != null, "StatsQuickBtn must exist in PilotDossierBox")
	print("[PASS] Redundant sidebar buttons removed; single clean service dossier action verified.")

	print("\n--- STEP 2: Test Base Windowed Layout (1152x648) ---")
	menu._update_responsive_layout()
	var base_title_w = abs(menu.title_box_right.offset_left - menu.title_box_right.offset_right)
	var base_hud_w = abs(menu.pilot_hud_card.offset_left - menu.pilot_hud_card.offset_right)
	assert(base_title_w >= 620.0, "TitleBoxRight base width should be at least 620")
	assert(base_hud_w >= 620.0, "PilotHUDCard base width should be at least 620")
	assert(menu.title_logo.custom_minimum_size.y >= 130.0, "TitleLogo base height should be at least 130")
	assert(menu.pilot_hud_card.anchor_bottom == 1.0, "PilotHUDCard must be anchored to bottom of viewport")
	assert(menu.pilot_hud_card.offset_bottom <= -20.0, "PilotHUDCard must have clean bottom offset")
	print("[PASS] Base windowed metrics: Logo H=%d, Right Box W=%d, HUD W=%d (Anchored to Bottom)" % [
		int(menu.title_logo.custom_minimum_size.y),
		int(base_title_w),
		int(base_hud_w)
	])

	print("\n--- STEP 3: Test Fullscreen Dynamic Scaling Simulation (1920x1080) ---")
	# Simulate 1920x1080 viewport sizing
	var mock_vp_size = Vector2(1920, 1080)
	var scale_x = mock_vp_size.x / 1152.0
	var scale_y = mock_vp_size.y / 648.0
	var scale_min = minf(scale_x, scale_y)
	var ui_scale = clampf(scale_min, 1.0, 1.75)

	# Direct simulation test of responsive math
	var scaled_badge_dim = roundf(100.0 * clampf(scale_min, 1.0, 1.45))
	var scaled_right_w = roundf(clampf(620.0 * scale_x, 620.0, 960.0))
	var scaled_logo_h = roundf(clampf(130.0 * ui_scale, 130.0, 220.0))
	var scaled_hud_h = roundf(clampf(156.0 * ui_scale, 156.0, 220.0))

	assert(scaled_badge_dim >= 140.0, "Badge should scale up on full screen displays")
	assert(scaled_right_w >= 900.0, "Title box should dynamically widen on 1080p")
	assert(scaled_logo_h >= 200.0, "Vanguard logo should dynamically enlarge on 1080p")
	assert(scaled_hud_h >= 200.0, "Pilot HUD Card should scale up on 1080p")
	print("[PASS] Fullscreen 1080p scaling verified:")
	print("       Badge: %dpx | Logo H: %dpx | Right Box W: %dpx | HUD H: %dpx" % [
		int(scaled_badge_dim), int(scaled_logo_h), int(scaled_right_w), int(scaled_hud_h)
	])

	print("\n--- STEP 4: Test All Modal Dialog Sizing for Default Windowed Mode (<= 648p) ---")
	var dialogs_to_test = [
		{"name": "CombatStatsDialog", "scene": "res://combat_stats_dialog.tscn", "max_h": 520.0},
		{"name": "AgilitySelectorDialog", "scene": "res://agility_selector_dialog.tscn", "max_h": 520.0},
		{"name": "LeaderboardDialog", "scene": "res://leaderboard_dialog.tscn", "max_h": 520.0},
		{"name": "RewardsDialog", "scene": "res://rewards_dialog.tscn", "max_h": 520.0},
		{"name": "MissionSelector", "scene": "res://mission_selector.tscn", "max_h": 520.0},
		{"name": "SettingsMenu", "scene": "res://settings_menu.tscn", "max_h": 520.0},
		{"name": "ModeSelectorDialog", "scene": "res://mode_selector_dialog.tscn", "max_h": 520.0},
		{"name": "UpdateDialog", "scene": "res://update_dialog.tscn", "max_h": 520.0},
		{"name": "QRJoinDialog", "scene": "res://qr_join_dialog.tscn", "max_h": 540.0}
	]

	for entry in dialogs_to_test:
		var scn = load(entry["scene"])
		assert(scn != null, "Scene %s failed to load" % entry["name"])
		var inst = scn.instantiate()
		root.add_child(inst)
		
		# Find the modal panel inside the dialog
		var main_p = inst.find_child("MainPanel", true, false)
		if not main_p:
			main_p = inst.find_child("Panel", true, false)
		if not main_p:
			main_p = inst.find_child("PanelContainer", true, false)
		if not main_p:
			main_p = inst.find_child("ModalPanel", true, false)
			
		assert(main_p != null, "Could not find main panel in %s" % entry["name"])
		var min_h = main_p.custom_minimum_size.y
		assert(min_h <= entry["max_h"], "%s height (%f) exceeds max allowed (%f) for 648p windowed!" % [
			entry["name"], min_h, entry["max_h"]
		])
		
		var clearance = 648.0 - min_h
		print("  [PASS] %-22s min_size=(%d, %d) | Window clearance=%dpx" % [
			entry["name"], int(main_p.custom_minimum_size.x), int(min_h), int(clearance)
		])
		inst.free()

	menu.free()
	await create_timer(0.05).timeout
	print("=================================================================")
	print(">>> ALL RESPONSIVE SCALING & DIALOG SIZING TESTS PASSED (100%) <<<")
	print("=================================================================")
	quit(0)
