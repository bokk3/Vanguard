extends SceneTree

func _init() -> void:
	print("--- [TEST] Starting Step 3: Helion Drone Fleet Test Suite ---")
	
	# TEST 1: Load and verify 3D GLB Models
	print("\n[TEST 1] Verifying 3D GLB Drone Models...")
	var stalker = load("res://assets/meshes/vehicles/drone_stalker4_recon.glb")
	var razor = load("res://assets/meshes/vehicles/drone_razor_skirmisher.glb")
	var bomber = load("res://assets/meshes/vehicles/drone_strikefly_bomber.glb")
	
	assert(stalker != null, "Failed to load drone_stalker4_recon.glb!")
	assert(razor != null, "Failed to load drone_razor_skirmisher.glb!")
	assert(bomber != null, "Failed to load drone_strikefly_bomber.glb!")
	print("  ✓ Stalker-4 Recon, Razor Skirmisher, and Strikefly Bomber GLB models loaded.")
	
	# TEST 2: Verify TargetDrone Instantiation for each type
	print("\n[TEST 2] Verifying TargetDrone Dynamic Model Instantiation...")
	var drone_script = load("res://target_drone.gd")
	
	var types = ["recon", "skirmisher", "bomber"]
	for t in types:
		var d = Node3D.new()
		d.set_script(drone_script)
		d.drone_type = t
		root.add_child(d)
		d._ready()
		
		var visual = d.find_child("UCAV_VisualModel", true, false)
		assert(visual != null, "TargetDrone failed to instantiate UCAV_VisualModel for " + t)
		assert(d.cached_materials.size() > 0, "No cached materials found on drone " + t)
		print("  -> Drone [" + t + "] initialized visual model with " + str(d.cached_materials.size()) + " PBR materials.")
		
		# Test hit reaction
		d.take_damage(25.0)
		assert(d.health == 75.0, "Damage deduction failed!")
		
		d.queue_free()
	print("  ✓ All 3 drone types instantiate 3D models and handle hit damage reactions.")
	
	# TEST 3: Verify Destruction and Signal Emission
	print("\n[TEST 3] Verifying Drone Destruction & Cleanup...")
	var test_drone = Node3D.new()
	test_drone.set_script(drone_script)
	test_drone.drone_type = "recon"
	test_drone.respawn_enabled = false
	root.add_child(test_drone)
	test_drone._ready()
	
	var signal_box = [false]
	test_drone.destroyed.connect(func(): signal_box[0] = true)
	test_drone.take_damage(150.0)
	
	assert(signal_box[0], "destroyed signal was not fired on lethal damage!")
	assert(not test_drone.is_alive, "Drone should be dead!")
	print("  ✓ Drone lethal damage emits signal and deactivates correctly.")
	test_drone.queue_free()
	
	print("\n>>> ALL STEP 3 HELION DRONE TESTS PASSED (Exit code 0) <<<")
	quit(0)
