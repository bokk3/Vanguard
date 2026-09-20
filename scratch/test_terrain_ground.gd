extends SceneTree

func _init() -> void:
	print("--- [TEST] Starting Terrain Ground & Altitude Reference Test Suite ---")
	
	# TEST 1: Load and verify Shader and Material
	print("\n[TEST 1] Verifying Terrain Shader & Material...")
	var mat = load("res://shaders/terrain_ground_material.tres")
	assert(mat != null, "Failed to load terrain_ground_material.tres!")
	assert(mat is ShaderMaterial, "Material is not a ShaderMaterial!")
	
	var macro_tex = mat.get_shader_parameter("macro_noise_tex")
	var normal_tex = mat.get_shader_parameter("micro_normal_tex")
	var rough_tex = mat.get_shader_parameter("micro_rough_tex")
	var corridor_tex = mat.get_shader_parameter("runway_corridor_tex")
	
	assert(macro_tex != null, "macro_noise_tex is null!")
	assert(normal_tex != null, "micro_normal_tex is null!")
	assert(rough_tex != null, "micro_rough_tex is null!")
	assert(corridor_tex != null, "runway_corridor_tex is null!")
	print("  ✓ Terrain ShaderMaterial loaded with all 4 PBR textures nominal.")
	
	# TEST 2: Instantiate AltitudeMarkerPylon
	print("\n[TEST 2] Verifying AltitudeMarkerPylon...")
	var pylon_scene = load("res://altitude_marker_pylon.tscn")
	assert(pylon_scene != null, "Failed to load altitude_marker_pylon.tscn!")
	var pylon = pylon_scene.instantiate()
	root.add_child(pylon)
	
	var top_strobe = pylon.find_child("TopStrobe", true, false)
	var beacon1 = pylon.find_child("MidBeacon1", true, false)
	var beacon2 = pylon.find_child("MidBeacon2", true, false)
	assert(top_strobe != null, "TopStrobe not found at summit!")
	assert(beacon1 != null, "MidBeacon1 not found at 40m rung!")
	assert(beacon2 != null, "MidBeacon2 not found at 80m rung!")
	print("  ✓ 120m AltitudeMarkerPylon verified (Found 40m, 80m, 120m beacons).")
	pylon.queue_free()
	
	# TEST 3: Verify main.tscn Scene Integration
	print("\n[TEST 3] Verifying main.tscn integration...")
	var main_scene = load("res://main.tscn")
	assert(main_scene != null, "Failed to load main.tscn!")
	var main_inst = main_scene.instantiate()
	root.add_child(main_inst)
	
	var ground = main_inst.find_child("Ground", true, false)
	assert(ground != null, "Ground node missing in main.tscn!")
	assert(ground.mesh != null, "Ground mesh is null!")
	assert(ground.mesh.size.x >= 4000, "Ground plane size too small!")
	
	var pylons_found = 0
	for child in main_inst.get_children():
		if child.name.begins_with("AltitudePylon"):
			pylons_found += 1
	assert(pylons_found >= 4, "Expected at least 4 AltitudePylons along corridor!")
	print("  ✓ main.tscn has Ground plane (" + str(ground.mesh.size) + ") and " + str(pylons_found) + " AltitudePylons.")
	
	# TEST 4: Verify MissionManager Dynamic Ground Presets
	print("\n[TEST 4] Verifying MissionManager Ground Presets across theaters...")
	var mm = main_inst.find_child("MissionManager", true, false)
	if not mm:
		var mm_script = load("res://mission_manager.gd")
		mm = Node.new()
		mm.set_script(mm_script)
		main_inst.add_child(mm)
	
	mm.active_root = main_inst
	var ground_mat = ground.mesh.material as ShaderMaterial
	assert(ground_mat != null, "Ground mesh material is not ShaderMaterial!")
	
	var presets = ["overcast_storm", "dusk_canyon", "dawn_clear", "stratosphere_space"]
	for p in presets:
		mm._apply_ground_preset(p)
		var col = ground_mat.get_shader_parameter("ground_color_primary")
		print("  -> Preset '" + p + "' applied primary ground color: " + str(col))
		assert(col != null, "Failed to apply color for " + p)
	
	print("\n>>> ALL TERRAIN & ALTITUDE REFERENCE TESTS PASSED (Exit code 0) <<<")
	main_inst.queue_free()
	quit(0)
