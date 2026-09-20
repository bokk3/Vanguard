extends SceneTree

func _init() -> void:
	print("==================================================================")
	print("RUNNING AUTOMATED CONTROLLER & CUTSCENE VERIFICATION TEST SUITE")
	print("==================================================================")
	
	# -------------------------------------------------------------------------
	# 1. TEST CONFIG MANAGER JOYPAD BINDINGS
	# -------------------------------------------------------------------------
	print("\n[TEST 1] Verifying ConfigManager Joypad Mappings...")
	var config_script = load("res://config_manager.gd")
	assert(config_script != null, "Failed to load config_manager.gd")
	
	var cfg = Node.new()
	cfg.name = "ConfigManager"
	cfg.set_script(config_script)
	root.add_child(cfg)
	cfg._ready()
	cfg.apply_input_mappings()
	
	var required_actions = [
		"throttle_up", "throttle_down", "pitch_up", "pitch_down",
		"roll_left", "roll_right", "yaw_left", "yaw_right",
		"boost", "fire_gun", "fire_missile", "toggle_radar"
	]
	
	for action in required_actions:
		assert(InputMap.has_action(action), "InputMap missing action: " + action)
		var events = InputMap.action_get_events(action)
		var has_joypad_event = false
		for ev in events:
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_joypad_event = true
				break
		assert(has_joypad_event, "Action missing joypad event: " + action)
		print("  [OK] Action '" + action + "' has valid joypad event mapping.")
	
	# Verify UI Joypad Mappings (A/Cross for accept, B/Circle for cancel)
	var ui_accept_events = InputMap.action_get_events("ui_accept")
	var ui_accept_joy = false
	for ev in ui_accept_events:
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_A:
			ui_accept_joy = true
	assert(ui_accept_joy, "ui_accept missing JOY_BUTTON_A (Xbox A / PS5 Cross)")
	print("  [OK] ui_accept mapped to JOY_BUTTON_A (Xbox A / PS5 Cross).")

	var ui_cancel_events = InputMap.action_get_events("ui_cancel")
	var ui_cancel_joy = false
	for ev in ui_cancel_events:
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_B:
			ui_cancel_joy = true
	assert(ui_cancel_joy, "ui_cancel mapped to JOY_BUTTON_B (Xbox B / PS5 Circle)")
	print("  [OK] ui_cancel mapped to JOY_BUTTON_B (Xbox B / PS5 Circle).")
	
	# -------------------------------------------------------------------------
	# 2. EMULATE JOYPAD INPUTS & VERIFY FLIGHT AXES
	# -------------------------------------------------------------------------
	print("\n[TEST 2] Emulating Joypad Motion & Button Events...")
	
	# Test Left Stick Y (Pitch: down = pitch up, up = pitch down)
	var motion_pitch_up = InputEventJoypadMotion.new()
	motion_pitch_up.axis = JOY_AXIS_LEFT_Y
	motion_pitch_up.axis_value = 1.0 # Pull back stick
	assert(InputMap.event_is_action(motion_pitch_up, "pitch_up"), "motion_pitch_up did not match pitch_up action in InputMap")
	Input.parse_input_event(motion_pitch_up)
	Input.flush_buffered_events()
	print("  [OK] Left stick pull-back (+Y) matches pitch_up action in InputMap.")
	
	# Test Triggers (Right Trigger = Throttle Up)
	var motion_rt = InputEventJoypadMotion.new()
	motion_rt.axis = JOY_AXIS_TRIGGER_RIGHT
	motion_rt.axis_value = 1.0
	assert(InputMap.event_is_action(motion_rt, "throttle_up"), "Right trigger motion did not match throttle_up in InputMap")
	print("  [OK] Right Trigger (R2/RT) matches throttle_up in InputMap.")
	
	# Test Rotary Gun Fire (Button A)
	var btn_a = InputEventJoypadButton.new()
	btn_a.button_index = JOY_BUTTON_A
	btn_a.pressed = true
	assert(InputMap.event_is_action(btn_a, "fire_gun"), "JOY_BUTTON_A did not match fire_gun in InputMap")
	print("  [OK] Button A/Cross matches fire_gun in InputMap.")
	
	# Test Strike Missile (Button B)
	var btn_b = InputEventJoypadButton.new()
	btn_b.button_index = JOY_BUTTON_B
	btn_b.pressed = true
	assert(InputMap.event_is_action(btn_b, "fire_missile"), "JOY_BUTTON_B did not match fire_missile in InputMap")
	print("  [OK] Button B/Circle matches fire_missile in InputMap.")

	# Test Haptic Rumble API
	cfg.enable_rumble = true
	cfg.play_rumble(0.5, 0.8, 0.2) # Should execute safely without error even if no physical pad connected
	print("  [OK] Haptic vibration API executed safely.")



	# -------------------------------------------------------------------------
	# 3. VERIFY BETWEEN-MISSION ~20S CUTSCENES & DISTINCT CHAPTER 1 TITLES
	# -------------------------------------------------------------------------
	print("\n[TEST 3] Verifying ~20s Narrative Cutscenes & Demarcation...")
	var cutscene_scene = load("res://interlude_cutscene.tscn")
	assert(cutscene_scene != null, "Failed to load interlude_cutscene.tscn")
	
	var cutscene_keys = ["INT_M01_M02", "INT_M02_M03", "INT_M03_M04", "EPILOGUE_CH1"]
	for c_id in cutscene_keys:
		var cs = cutscene_scene.instantiate()
		cs.setup(c_id)
		root.add_child(cs)
		
		# Verify duration is ~20 seconds (between 15s and 25s)
		var dur = cs.total_duration
		assert(dur >= 15.0 and dur <= 25.0, "Duration out of ~20s bounds for " + c_id + ": " + str(dur))
		
		# Verify distinct non-confusing naming
		var title = cs.config.get("title", "")
		var subtitle = cs.config.get("subtitle", "")
		assert(not title.is_empty(), "Empty title for " + c_id)
		assert(not subtitle.is_empty(), "Empty subtitle for " + c_id)
		
		# Check audio existence
		var a_path = cs.config.get("audio_path", "")
		assert(FileAccess.file_exists(a_path), "Missing voice narration file: " + a_path)
		
		# Check subtitle cues
		var cues = cs.config.get("cues", [])
		assert(cues.size() >= 3, "Insufficient cues for " + c_id)
		
		print("  [OK] " + c_id + " -> '" + title + " - " + subtitle + "' (Duration: " + str(dur) + "s, Audio: " + a_path.get_file() + ")")
		
		# Test Controller Skip via Joypad Button Event
		var pad_skip = InputEventJoypadButton.new()
		pad_skip.button_index = JOY_BUTTON_A
		pad_skip.pressed = true
		assert(not cs.is_finishing, "Cutscene should not be finishing prior to skip")
		cs._input(pad_skip)
		assert(cs.is_finishing, "Joypad button skip failed to set is_finishing to true!")
		print("  [OK] Joypad button skip successfully triggered for " + c_id + ".")
		
		cs.queue_free()

	cfg.queue_free()
	print("\n==================================================================")
	print("ALL CONTROLLER & CUTSCENE TESTS PASSED WITH 100% SUCCESS!")
	print("==================================================================")
	quit(0)
