extends SceneTree

func _init() -> void:
	print("==================================================================")
	print("RUNNING AUTOMATED PLAYER GROUND & OBJECT COLLISION TEST SUITE")
	print("==================================================================")
	
	# -------------------------------------------------------------------------
	# 1. Test Main Scene Collision Structure
	# -------------------------------------------------------------------------
	print("\n[TEST 1] Verifying Ground and Player Collision Bodies...")
	var main_scene = load("res://main.tscn")
	assert(main_scene != null, "Failed to load main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	
	var ground = main.get_node_or_null("Ground")
	assert(ground != null, "Ground node not found in main.tscn")
	var ground_body = ground.get_node_or_null("StaticBody3D")
	assert(ground_body != null, "Ground missing StaticBody3D collision body")
	assert(ground_body.collision_layer == 1, "Ground StaticBody3D collision_layer must be 1")
	print("  [OK] Ground plane equipped with StaticBody3D on Layer 1.")
	
	var ship = main.get_node_or_null("Spaceship")
	assert(ship != null, "Spaceship node not found in main.tscn")
	assert(ship.collision_layer == 2, "Spaceship collision_layer must be 2 (Player)")
	assert((ship.collision_mask & 1) != 0, "Spaceship collision_mask must monitor Layer 1 (Environment)")
	assert((ship.collision_mask & 4) != 0, "Spaceship collision_mask must monitor Layer 3 (Enemies)")
	assert((ship.collision_mask & 16) != 0, "Spaceship collision_mask must monitor Layer 5 (Allies)")
	print("  [OK] Spaceship configured with Layer 2 and Mask 29 (Environment, Enemies, Allies).")
	
	# -------------------------------------------------------------------------
	# 2. Test Glancing Scrape Collision Response
	# -------------------------------------------------------------------------
	print("\n[TEST 2] Testing Glancing Scrape & Deflection Bounce...")
	if not ship.telemetry:
		ship.telemetry = ship.get_node_or_null("CombatTelemetry")
	var initial_speed = ship.current_speed
	var initial_shield = ship.telemetry.current_shield
	
	# Trigger a glancing scrape against a vertical wall facing +X
	var wall_normal = Vector3(1, 0, 0)
	var ship_pos = ship.global_position if ship.is_inside_tree() else ship.position
	ship._trigger_glancing_scrape(wall_normal, ship_pos, 15.0)
	
	assert(ship.current_speed < initial_speed, "Speed was not bled during glancing scrape")
	assert(ship.telemetry.current_shield < initial_shield, "Shield damage was not applied during scrape")
	assert(ship.collision_cooldown > 0.0, "Collision cooldown was not set")
	assert(ship.camera_shake_trauma > 0.0, "Camera trauma shake was not triggered")
	print("  [OK] Glancing scrape successfully bled speed (to %d m/s), applied damage (-%d shield), and set trauma shake." % [round(ship.current_speed), round(initial_shield - ship.telemetry.current_shield)])
	
	# -------------------------------------------------------------------------
	# 3. Test Fail-Safe Ground Altitude Floor Collision
	# -------------------------------------------------------------------------
	print("\n[TEST 3] Testing Ground Floor Altitude Fail-Safe...")
	# Place ship below ground floor (y = -5.0) while flying low speed
	if ship.is_inside_tree():
		ship.global_position = Vector3(0, -5.0, 0)
	else:
		ship.position = Vector3(0, -5.0, 0)
	ship.velocity = Vector3(0, -10.0, -50.0)
	ship.current_speed = 30.0
	ship._process_flight_collisions(0.016)
	
	var cur_altitude = ship.global_position.y if ship.is_inside_tree() else ship.position.y
	assert(cur_altitude >= ship.terrain_floor_y, "Ship remained below terrain floor: " + str(cur_altitude))
	print("  [OK] Ground altitude fail-safe clamped ship altitude to " + str(cur_altitude) + "m and deflected velocity.")

	# -------------------------------------------------------------------------
	# 4. Test High-Velocity Catastrophic Ground Crash
	# -------------------------------------------------------------------------
	print("\n[TEST 4] Testing Catastrophic Ground / Terrain Crash...")
	# Retrieve active MissionManager singleton
	var created_mm = false
	var mm = root.get_node_or_null("MissionManager")
	if not mm:
		var mm_script = load("res://mission_manager.gd")
		mm = Node.new()
		mm.name = "MissionManager"
		mm.set_script(mm_script)
		root.add_child(mm)
		created_mm = true
	mm.is_sortie_active = true
	ship.mission_manager_override = mm
	
	var fail_result = {"called": false, "reason": ""}
	mm.mission_failed.connect(func(_mid, reason):
		fail_result["called"] = true
		fail_result["reason"] = reason
	)
	
	# Dive directly into ground at high speed
	if ship.is_inside_tree():
		ship.global_position = Vector3(0, 0.5, 0)
	else:
		ship.position = Vector3(0, 0.5, 0)
	ship.downward_velocity = 55.0
	ship.current_speed = 80.0
	ship.velocity = Vector3(0, -55.0, 0)
	ship.rotation_degrees = Vector3(-60, 0, 0) # steep dive
	ship._process_flight_collisions(0.016)
	
	assert(ship.is_airframe_destroyed, "Airframe was not marked as destroyed after catastrophic crash")
	assert(fail_result["called"], "MissionManager.mission_failed was not emitted on airframe destruction")
	print("  [OK] Catastrophic ground impact destroyed airframe and triggered mission failure: '" + fail_result["reason"] + "'")
	
	# -------------------------------------------------------------------------
	# 5. Test Obstacle Collision Shapes (Pylons & Transport)
	# -------------------------------------------------------------------------
	print("\n[TEST 5] Testing Obstacle Collision Bodies...")
	var pylon_scene = load("res://altitude_marker_pylon.tscn")
	var pylon = pylon_scene.instantiate()
	root.add_child(pylon)
	var pylon_body = pylon.get_node_or_null("StaticBody3D")
	assert(pylon_body != null, "Pylon missing StaticBody3D")
	assert(pylon_body.collision_layer == 1, "Pylon StaticBody3D must be on Layer 1")
	print("  [OK] AltitudeMarkerPylon has valid StaticBody3D on Layer 1.")
	pylon.free()
	
	var transport_scene = load("res://transport_olympus4.tscn")
	var transport = transport_scene.instantiate()
	root.add_child(transport)
	var transport_body = transport.get_node_or_null("PhysicalHull")
	assert(transport_body != null, "Transport missing PhysicalHull AnimatableBody3D")
	assert(transport_body.collision_layer == 16, "Transport PhysicalHull must be on Layer 5 (16)")
	print("  [OK] Transport Olympus-4 has valid physical collision hull on Layer 5.")
	transport.free()

	main.free()
	if created_mm and is_instance_valid(mm):
		mm.free()
	
	print("\n==================================================================")
	print("ALL GROUND & OBJECT COLLISION TESTS PASSED (100%)!")
	print("==================================================================")
	quit(0)
