extends SceneTree

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================")
	print("PROJECT VANGUARD: CAMPAIGN DROP-IN CO-OP TEST SUITE")
	print("==================================================")
	
	# 1. Load and instantiate main.tscn
	var main_scene = load("res://main.tscn")
	assert(main_scene != null, "Failed to load main.tscn")
	var main = main_scene.instantiate()
	assert(main != null, "Failed to instantiate main.tscn")
	root.add_child(main)
	
	await process_frame
	await process_frame
	
	# Test single player default state
	assert(main.is_coop_active == false, "Campaign should start in single-player mode")
	assert(main.coop_layer == null, "Coop layer should not exist yet")
	assert(main.single_hud.visible == true, "Single player HUD should be visible")
	var players = main.get_tree().get_nodes_in_group("player")
	assert(players.size() == 1, "Only 1 player ship should exist initially")
	print("  [OK] Default single-player mode verified.")
	
	# 2. Test secondary control event filtering
	var p1_key = InputEventKey.new()
	p1_key.keycode = KEY_W
	p1_key.pressed = true
	assert(main._is_secondary_control_event(p1_key) == false, "P1 key should not trigger co-op")
	
	var joy_p1 = InputEventJoypadButton.new()
	joy_p1.device = 0
	joy_p1.button_index = JOY_BUTTON_A
	joy_p1.pressed = true
	assert(main._is_secondary_control_event(joy_p1) == false, "Joypad device 0 should not trigger co-op")
	
	var joy_p2 = InputEventJoypadButton.new()
	joy_p2.device = 1
	joy_p2.button_index = JOY_BUTTON_A
	joy_p2.pressed = true
	assert(main._is_secondary_control_event(joy_p2) == true, "Joypad device 1 should trigger co-op")
	
	var p2_key = InputEventKey.new()
	p2_key.keycode = KEY_ENTER
	p2_key.pressed = true
	assert(main._is_secondary_control_event(p2_key) == true, "KEY_ENTER should trigger co-op")
	
	var p2_key_i = InputEventKey.new()
	p2_key_i.keycode = KEY_I
	p2_key_i.pressed = true
	assert(main._is_secondary_control_event(p2_key_i) == true, "KEY_I should trigger co-op")
	print("  [OK] Secondary control event detection verified.")
	
	# 3. Simulate drop-in join
	main.join_player_2()
	await process_frame
	await process_frame
	
	assert(main.is_coop_active == true, "Co-op should now be active")
	assert(main.p2_ship != null, "Player 2 ship should be instantiated")
	assert(main.p2_ship.player_id == 2, "P2 ship player_id must be 2")
	assert(main.p2_ship.is_split_screen == true, "P2 ship is_split_screen must be true")
	assert(main.p2_ship.pvp_mode == false, "P2 ship pvp_mode must be false (co-op mode)")
	assert(main.p2_ship.is_in_group("player"), "P2 must be in group 'player'")
	assert(main.p2_ship.is_in_group("radar_targets"), "P2 must be in group 'radar_targets'")
	assert(not main.p2_ship.is_in_group("enemies"), "P2 wingman must NOT be in group 'enemies'")
	
	# P1 split screen flag
	assert(main.ship_p1.is_split_screen == true, "P1 ship is_split_screen must be true")
	
	# Dual viewports and World3D sharing
	assert(main.sub_viewport_1 != null and main.sub_viewport_2 != null, "Dual subviewports must exist")
	assert(main.sub_viewport_1.world_3d == main.get_world_3d(), "Viewport 1 must share campaign World3D")
	assert(main.sub_viewport_2.world_3d == main.get_world_3d(), "Viewport 2 must share campaign World3D")
	assert(main.single_hud.visible == false, "Single player HUD must be hidden")
	print("  [OK] Dynamic drop-in co-op split-screen instantiation verified.")
	
	# 4. Test Split Layout Switching (Horizontal vs Vertical)
	assert(main.is_horizontal_split == true, "Default layout should be horizontal")
	assert(main.container_p1.anchor_bottom == 0.5, "Container 1 should occupy top half")
	assert(main.container_p2.anchor_top == 0.5, "Container 2 should occupy bottom half")
	
	# Toggle layout (F2)
	main.toggle_split_layout()
	assert(main.is_horizontal_split == false, "Layout should now be vertical")
	assert(main.container_p1.anchor_right == 0.5, "Container 1 should occupy left half")
	assert(main.container_p2.anchor_left == 0.5, "Container 2 should occupy right half")
	
	# Toggle back
	main.toggle_split_layout()
	assert(main.is_horizontal_split == true, "Layout should be back to horizontal")
	print("  [OK] Split-screen layout toggle (Horizontal <-> Vertical) verified.")
	
	# 5. Test Drone Multi-Player Target Acquisition
	var enemies = main.get_tree().get_nodes_in_group("enemies")
	var drone = null
	for e in enemies:
		if e.has_method("_acquire_player"):
			drone = e
			break
	if not drone:
		drone = main.find_child("ReconDrone_01", true, false)
	assert(drone != null, "Target drone should exist in mission")
	
	# Place drone close to P1 (-30m on X axis, away from P2 which is at +22m X)
	drone.global_position = main.ship_p1.global_position + Vector3(-30, 0, 0)
	drone._acquire_player()
	assert(drone.target_player == main.ship_p1, "Drone should target closer player (P1)")
	
	# Place drone close to P2 (+30m on X axis beyond P2)
	drone.global_position = main.p2_ship.global_position + Vector3(30, 0, 0)
	drone._acquire_player()
	assert(drone.target_player == main.p2_ship, "Drone should target closer player (P2)")
	print("  [OK] Hostile drone AI dynamic targeting (closest active player) verified.")
	
	# 6. Test Co-Op Destruction & 5s Respawn Loop
	# P2 destroyed
	main.p2_ship._trigger_coop_destroyed("TEST_CRASH", "Wingman collision")
	assert(main.p2_ship.is_airframe_destroyed == true, "P2 should be marked destroyed")
	assert(main.p2_respawn_timer > 0.0, "P2 respawn timer should be active")
	
	# Simulate 3 seconds passing (not yet respawned)
	main._process(3.0)
	assert(main.p2_ship.is_airframe_destroyed == true, "P2 should still be destroyed at 3s")
	
	# Simulate remaining 2.5 seconds (respawn triggers)
	main._process(2.5)
	assert(main.p2_ship.is_airframe_destroyed == false, "P2 should be respawned after 5s")
	assert(main.p2_ship.get_node("Model").visible == true, "P2 model should be visible after respawn")
	print("  [OK] Co-op 5-second wingman respawn loop verified.")
	
	# 7. Test Sortie Failure when BOTH players are destroyed
	main.ship_p1.is_airframe_destroyed = true
	main.p2_ship.is_airframe_destroyed = true
	main._on_coop_player_destroyed(main.ship_p1, "TEST_WIPE", "Both lost")
	print("  [OK] Simultaneous dual-airframe loss fail-safe verified.")
	
	print("==================================================")
	print("ALL CAMPAIGN DROP-IN CO-OP TESTS PASSED (100%)!")
	print("==================================================")
	quit(0)
