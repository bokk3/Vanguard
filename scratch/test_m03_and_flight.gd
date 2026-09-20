extends SceneTree

func _init() -> void:
	print("==================================================")
	print(" Testing Flight Mechanics & Mission 3 Wave System ")
	print("==================================================")
	
	test_flight_mechanics()
	test_m03_wave_progression()
	
	print("\n>>> ALL FLIGHT & M03 TESTS PASSED! <<<")
	quit(0)

func test_flight_mechanics() -> void:
	print("\n[TEST 1] Verifying Aerodynamic Lift & Sink Rate Recovery...")
	var ship_scene = load("res://main.tscn")
	assert(ship_scene != null, "Failed to load main.tscn")
	var root_inst = ship_scene.instantiate()
	root.add_child(root_inst)
	
	var ship = root_inst.find_child("Spaceship", true, false)
	assert(ship != null, "Failed to find Spaceship in main.tscn")
	ship._ready()
	
	# Verify starting speed
	assert(ship.current_speed == ship.cruise_speed, "Initial speed should be cruise speed (60 m/s)")
	assert(ship.downward_velocity == 0.0, "Initial downward velocity should be 0.0")
	
	# Simulate a stall: set speed to 5 m/s (< stall_speed = 25 m/s) and simulate physics steps
	ship.current_speed = 5.0
	for i in range(30):
		ship._physics_process(1.0 / 60.0)
	
	assert(ship.downward_velocity > 2.0, "Downward velocity should accumulate when stalling below stall speed")
	print("  -> Stalled downward velocity accumulated to: ", ship.downward_velocity, " m/s")
	
	# Simulate recovery: accelerate to cruise speed and pitch nose up into the sky
	ship.current_speed = ship.cruise_speed # 60 m/s
	ship.rotation.x = deg_to_rad(15.0) # Pitch up in local space (points towards -Z and +Y)
	
	# Run 60 frames (1 second of flight)
	for i in range(60):
		ship._physics_process(1.0 / 60.0)
	
	print("  -> Recovered downward velocity after 1.0s at cruise speed: ", ship.downward_velocity, " m/s")
	assert(ship.downward_velocity == 0.0, "Downward velocity should have completely bled off to 0.0 at cruise speed!")
	
	# Verify vertical velocity is positive (climbing strongly)
	assert(ship.velocity.y > 5.0, "Ship should be actively climbing when pitched up with adequate airspeed!")
	print("  ✓ Flight mechanics verified: Lift arrests sink rate, climb rate is positive (", ship.velocity.y, " m/s).")
	
	root_inst.queue_free()

func test_m03_wave_progression() -> void:
	print("\n[TEST 2] Verifying Mission 3 Wave Progression & Olympus Liftoff...")
	var mm_script = load("res://mission_manager.gd")
	var mm = Node.new()
	mm.set_script(mm_script)
	root.add_child(mm)
	mm._ready()
	
	var dummy_root = Node3D.new()
	root.add_child(dummy_root)
	
	mm.current_mission_id = "M03"
	mm.initialize_level(dummy_root)
	
	# Verify Olympus-4 exists
	var transport = dummy_root.find_child("TransportOlympus4", true, false)
	assert(transport != null, "TransportOlympus4 not found in M03")
	assert(mm.m03_current_wave == 1, "Expected current wave 1")
	assert(mm.m03_wave_drones_alive == 4, "Expected 4 wave drones in Wave 1")
	
	# Verify objectives configured
	var obj_waves = null
	var obj_protect = null
	for obj in mm.active_objectives:
		if obj["id"] == "obj_waves":
			obj_waves = obj
		elif obj["id"] == "obj_protect":
			obj_protect = obj
	
	assert(obj_waves != null and obj_waves["target_val"] == 12, "obj_waves target_val should be 12")
	assert(obj_protect != null and obj_protect["target_val"] == 1, "obj_protect target_val should be 1")
	
	print("  -> Wave 1 verified: 4 drones spawned, obj_waves target: 12.")
	
	# Simulate destroying wave 1
	var w1_drones = []
	for c in dummy_root.get_children():
		if c.name.begins_with("StrikeDrone_W1"):
			w1_drones.append(c)
	assert(w1_drones.size() == 4, "Expected 4 Wave 1 strike drones")
	for d in w1_drones:
		d.destroyed.emit()
	
	assert(mm.m03_current_wave == 2, "Expected wave to advance to 2")
	assert(mm.m03_wave_drones_alive == 4, "Expected 4 wave drones in Wave 2")
	print("  -> Wave 2 triggered successfully upon Wave 1 elimination.")
	
	# Simulate destroying wave 2
	var w2_drones = []
	for c in dummy_root.get_children():
		if c.name.begins_with("StrikeDrone_W2"):
			w2_drones.append(c)
	assert(w2_drones.size() == 4, "Expected 4 Wave 2 strike drones")
	for d in w2_drones:
		d.destroyed.emit()
	
	assert(mm.m03_current_wave == 3, "Expected wave to advance to 3")
	assert(mm.m03_wave_drones_alive == 4, "Expected 4 wave drones in Wave 3")
	print("  -> Wave 3 triggered successfully upon Wave 2 elimination.")
	
	# Simulate destroying wave 3
	var w3_drones = []
	for c in dummy_root.get_children():
		if c.name.begins_with("StrikeDrone_W3"):
			w3_drones.append(c)
	assert(w3_drones.size() == 4, "Expected 4 Wave 3 strike drones")
	for d in w3_drones:
		d.destroyed.emit()
	
	assert(mm.m03_is_cleared == true, "M03 should be marked cleared")
	assert(obj_waves["status"] == "COMPLETED", "obj_waves should be COMPLETED")
	assert(transport.is_boosting == true, "Olympus-4 booster liftoff should be engaged!")
	print("  -> Wave 3 eliminated: obj_waves COMPLETED (12/12), Olympus booster liftoff engaged.")
	
	# Verify Olympus movement behavior
	# If not boosting, Olympus should not go past Z = -1050m
	var test_transport = transport.duplicate()
	dummy_root.add_child(test_transport)
	test_transport.is_boosting = false
	test_transport.position = Vector3(0, 30, -1045.0)
	for i in range(100):
		test_transport._process(0.1)
	assert(test_transport.position.z == -1050.0, "Transport should hold at Z = -1050m threshold during normal cruise")
	print("  ✓ Olympus-4 holds at catapult threshold (Z = -1050m) and does not sail off map.")
	
	test_transport.queue_free()
	dummy_root.queue_free()
	mm.queue_free()
