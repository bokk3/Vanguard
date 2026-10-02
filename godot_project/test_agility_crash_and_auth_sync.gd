extends SceneTree

## Comprehensive Verification Suite for:
## 1. Agility trial plane crash / chronometer freeze
## 2. Agility course tactical pause menu (ESC)
## 3. Guest vs. Cloud login state representation and visible LOGIN button
## 4. Cloud sync unauthenticated error banner and login prompt

var frame_count: int = 0
var test_done: bool = false
var timeout: float = 0.0

func _init() -> void:
	print("\n=======================================================")
	print(">>> Vanguard: Agility Crash, Pause & Auth Sync Test <<<")
	print("=======================================================\n")

func _process(delta: float) -> bool:
	if test_done:
		return true

	timeout += delta
	if timeout > 12.0:
		push_error("Test timed out!")
		quit(1)
		return true

	frame_count += 1
	if frame_count < 3:
		return false

	test_done = true
	_run_all_tests()
	return true

func _run_all_tests() -> void:
	var am = root.get_node_or_null("AgilityManager")
	if not am:
		am = preload("res://agility_manager.gd").new()
		am.name = "AgilityManager"
		root.add_child(am)

	var auth = root.get_node_or_null("AuthManager")
	if not auth:
		auth = preload("res://auth_manager.gd").new()
		auth.name = "AuthManager"
		root.add_child(auth)

	var rm = root.get_node_or_null("RewardManager")
	if not rm:
		rm = preload("res://reward_manager.gd").new()
		rm.name = "RewardManager"
		root.add_child(rm)

	# -------------------------------------------------------------
	# TEST 1: Agility Crash & Chronometer Freeze
	# -------------------------------------------------------------
	print("\n--- TEST 1: Agility Crash & Chronometer Freeze ---")
	var course_scene = preload("res://agility_course_level.tscn")
	var course = course_scene.instantiate()
	root.add_child(course)
	course._ready()

	am.start_trial("T01")
	assert(am.is_trial_active == true, "Trial must be active")
	
	# Simulate elapsed time
	am.start_ticks_usec = Time.get_ticks_usec() - 4500000 # 4.5 seconds
	am._process(0.016)
	var crash_time = am.elapsed_time
	assert(crash_time > 4.0, "Time elapsed must be ~4.5s")

	var hud = course.get_node("HUD/AgilityHUD") as AgilityHUD
	assert(hud != null, "AgilityHUD must exist")
	hud._process(0.016)
	var chrono_before = hud.chrono_label.text
	assert(not chrono_before.is_empty(), "Chrono label must have text")

	# Crash ship
	var ship = course.get_node("Spaceship")
	assert(ship != null, "Spaceship must exist")
	ship._trigger_catastrophic_crash(ship.global_position, Vector3.UP, "TERRAIN_COLLISION", "CRASH: IMPACT WITH TERRAIN")

	assert(am.is_trial_active == false, "AgilityManager.is_trial_active must be false after crash")
	var frozen_time = am.elapsed_time

	# Simulate more frames - chronometer must NOT increase
	hud._process(0.5)
	hud._process(0.5)
	assert(am.is_trial_active == false, "Trial remains inactive")
	assert(am.elapsed_time == frozen_time, "AgilityManager.elapsed_time must remain frozen")
	assert(hud.debrief_panel.visible == true, "Debrief panel must be visible on crash")
	assert("TRIAL ABORTED" in hud.debrief_title.text, "Debrief title must indicate aborted trial")
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Mouse cursor must be visible for debrief options")
	print("[PASS] Agility crash freezes chronometer at %s and displays failure debrief modal." % hud.chrono_label.text)

	# -------------------------------------------------------------
	# TEST 2: Agility Tactical Pause Menu (ESC)
	# -------------------------------------------------------------
	print("\n--- TEST 2: Agility Tactical Pause Menu & Objectives ---")
	var pause_menu = course.get_node("HUD/PauseMenu")
	assert(pause_menu != null, "PauseMenu must exist in AgilityCourseLevel HUD")
	
	# Reset trial to active state to test pause menu during flight
	am.is_trial_active = true
	hud.debrief_panel.hide()

	pause_menu.pause_flight()
	assert(paused == true, "Game must be paused")
	assert(pause_menu.visible == true, "Pause menu must be visible")
	assert("AGILITY TRIAL" in pause_menu.mission_name_label.text, "Pause menu must show AGILITY TRIAL header")
	assert(pause_menu.save_btn.visible == false, "Save button must be hidden during agility trial")
	assert(pause_menu.load_btn.visible == false, "Load button must be hidden during agility trial")

	pause_menu.resume_flight()
	assert(paused == false, "Game must resume flight")
	assert(pause_menu.visible == false, "Pause menu must be hidden")

	print("[PASS] Agility PauseMenu displays trial curriculum and disables save/load.")

	course.queue_free()

	# -------------------------------------------------------------
	# TEST 3: Guest vs. Cloud Auth & Visible Login Button
	# -------------------------------------------------------------
	print("\n--- TEST 3: Guest vs Cloud Auth State & Login Button ---")
	# Force local guest mode (token empty)
	auth.token = ""
	auth.is_authenticated = true
	auth.callsign = "VIPER-ONE"
	assert(auth.is_cloud_authenticated() == false, "Must not be cloud authenticated without token")

	var home_scene = preload("res://home_menu.tscn")
	var home = home_scene.instantiate()
	root.add_child(home)
	home._ready()
	home._update_pilot_dossier_ui()

	assert(home.hud_online_status_label != null, "HUDOnlineStatusLabel exists")
	assert("GUEST" in home.hud_online_status_label.text, "HUD status chip must show GUEST when offline")
	assert(home.hud_profile_btn != null, "HUDProfileBtn exists")
	assert("LOGIN" in home.hud_profile_btn.text, "HUD profile button must say LOGIN when offline")
	print("[PASS] Offline state correctly displays: Status='%s', Button='%s'" % [
		home.hud_online_status_label.text, home.hud_profile_btn.text
	])

	# Test clicking login button opens LoginDialog
	home.hud_profile_btn.pressed.emit()
	assert(home.login_dialog.visible == true, "LoginDialog opened when pressing LOGIN")
	home.login_dialog.hide()

	# Simulate cloud login
	auth.token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.cloud-valid-token"
	assert(auth.is_cloud_authenticated() == true, "Must be cloud authenticated with valid token")
	home._update_pilot_dossier_ui()

	assert("CLOUD ONLINE" in home.hud_online_status_label.text, "HUD status chip must show CLOUD ONLINE when token present")
	assert("LOGOUT" in home.hud_profile_btn.text, "HUD profile button must say LOGOUT when authenticated")
	print("[PASS] Cloud authenticated state displays: Status='%s', Button='%s'" % [
		home.hud_online_status_label.text, home.hud_profile_btn.text
	])

	# -------------------------------------------------------------
	# TEST 4: Cloud Sync Unauthenticated Error & Prompt
	# -------------------------------------------------------------
	print("\n--- TEST 4: Cloud Sync Unauthenticated Error Handling ---")
	auth.token = "" # Log out from cloud
	assert(auth.is_cloud_authenticated() == false, "Offline for sync test")

	# Test CombatStatsDialog sync
	var combat_stats = home.combat_stats as CombatStatsDialog
	assert(combat_stats != null, "CombatStatsDialog exists")
	combat_stats._on_sync_pressed()
	assert("SYNC ERROR" in combat_stats.status_msg_label.text, "Combat stats must display SYNC ERROR when not logged in")
	assert(combat_stats.status_msg_label.modulate.r > 0.8, "Sync error must be displayed in red")
	print("[PASS] CombatStatsDialog sync error: '%s'" % combat_stats.status_msg_label.text)

	# Test RewardsDialog sync
	var rewards_dialog = home.rewards_dialog as RewardsDialog
	assert(rewards_dialog != null, "RewardsDialog exists")
	rewards_dialog._on_sync_pressed()
	assert("SYNC ERROR" in rewards_dialog.status_banner_label.text, "Rewards dialog must display SYNC ERROR when not logged in")
	assert(rewards_dialog.status_banner_label.modulate.r > 0.8, "Sync error banner must be displayed in red")
	print("[PASS] RewardsDialog sync error: '%s'" % rewards_dialog.status_banner_label.text)

	home.queue_free()

	print("\n=======================================================")
	print(">>> ALL AGILITY CRASH & AUTH SYNC TESTS PASSED! <<<")
	print("=======================================================\n")
	quit(0)
