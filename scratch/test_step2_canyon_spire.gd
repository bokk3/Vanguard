extends SceneTree

func _init() -> void:
	print("--- [TEST] Starting Step 2: Canyon Terrain & Spire-45 Test Suite ---")
	
	# TEST 1: Load and verify 3D Model Assets
	print("\n[TEST 1] Verifying 3D GLB Model Assets...")
	var cliff_glb = load("res://assets/meshes/environment/canyon_cliff_straight.glb")
	var mesa_glb = load("res://assets/meshes/environment/canyon_mesa_pillar.glb")
	var spire_glb = load("res://assets/meshes/environment/spire45_jamming_array.glb")
	
	assert(cliff_glb != null, "Failed to load canyon_cliff_straight.glb!")
	assert(mesa_glb != null, "Failed to load canyon_mesa_pillar.glb!")
	assert(spire_glb != null, "Failed to load spire45_jamming_array.glb!")
	print("  ✓ All 3 Blender GLB models loaded cleanly.")
	
	# TEST 2: Verify Spire-45 Hierarchy & Nodes
	print("\n[TEST 2] Verifying Spire-45 Hierarchy...")
	var spire_inst = spire_glb.instantiate()
	root.add_child(spire_inst)
	var ecm_head = spire_inst.find_child("ECM_Emitter_Head", true, false)
	assert(ecm_head != null, "ECM_Emitter_Head node missing in Spire-45 GLB!")
	print("  ✓ Spire-45 model contains rotatable ECM_Emitter_Head node.")
	spire_inst.queue_free()
	
	# TEST 3: Verify M02 Canyon Terrain Spawning
	print("\n[TEST 3] Verifying M02 Canyon Terrain Spawning in Level...")
	var dummy_root = Node3D.new()
	dummy_root.name = "LevelRoot"
	root.add_child(dummy_root)
	
	var mm_script = load("res://mission_manager.gd")
	var mm = Node.new()
	mm.set_script(mm_script)
	root.add_child(mm)
	
	mm.current_mission_id = "M02"
	mm.initialize_level(dummy_root)
	
	var canyon_root = dummy_root.find_child("CanyonTerrainRoot", true, false)
	assert(canyon_root != null, "CanyonTerrainRoot missing in M02 level!")
	
	var cliff_count = 0
	var mesa_count = 0
	for child in canyon_root.get_children():
		if child.name.begins_with("CanyonCliff"):
			cliff_count += 1
		elif child.name.begins_with("CanyonMesa"):
			mesa_count += 1
			
	print("  -> Found " + str(cliff_count) + " canyon cliff wall segments.")
	print("  -> Found " + str(mesa_count) + " canyon mesa butte pillars.")
	assert(cliff_count >= 12, "Expected at least 12 cliff wall segments (6 left, 6 right)!")
	assert(mesa_count >= 4, "Expected 4 mesa buttes along corridor!")
	print("  ✓ M02 Canyon corridor terrain verified (180m sandstone walls + mesa buttes).")
	
	# TEST 4: Verify Jammer Destruction with Spire-45
	print("\n[TEST 4] Verifying Jammer destruction with Spire-45 model...")
	var jammer1 = dummy_root.find_child("JammingRelay_01", true, false)
	assert(jammer1 != null, "JammingRelay_01 missing in M02!")
	jammer1.take_damage(200.0)
	assert(mm.targets_destroyed == 1, "Expected 1 target destroyed!")
	for obj in mm.active_objectives:
		if obj["id"] == "obj_relays":
			assert(obj["current_val"] == 1, "Expected obj_relays to be 1/3")
	print("  ✓ Spire-45 Jammer destruction and objective tracking verified.")
	
	print("\n>>> ALL STEP 2 CANYON & SPIRE-45 TESTS PASSED (Exit code 0) <<<")
	dummy_root.queue_free()
	mm.queue_free()
	quit(0)
