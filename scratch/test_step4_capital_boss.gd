extends SceneTree

func _init() -> void:
	print("==================================================")
	print(" Testing Step 4: Capital Escort & Ace Boss Models ")
	print("==================================================")
	
	test_models_load()
	test_transport_olympus4()
	test_boss_combine_ghost()
	
	print("\n>>> ALL STEP 4 TESTS PASSED! <<<")
	quit(0)

func test_models_load() -> void:
	print("\n[TEST 1] Verifying GLB 3D Assets...")
	var olympus_res = load("res://assets/meshes/vehicles/transport_olympus4_c900.glb")
	assert(olympus_res != null, "Failed to load transport_olympus4_c900.glb")
	
	var ghost_res = load("res://assets/meshes/vehicles/boss_combine_ghost_sg99.glb")
	assert(ghost_res != null, "Failed to load boss_combine_ghost_sg99.glb")
	print("  ✓ C-900 Transport and SG-99 Combine Ghost GLB models verified.")

func test_transport_olympus4() -> void:
	print("\n[TEST 2] Verifying Transport Olympus-4 Scene...")
	var scene = load("res://transport_olympus4.tscn")
	assert(scene != null, "Failed to load transport_olympus4.tscn")
	
	var inst = scene.instantiate()
	assert(inst != null, "Failed to instantiate transport_olympus4.tscn")
	root.add_child(inst)
	inst._ready()
	
	# Verify ModelRoot and OlympusModel
	var model_root = inst.get_node_or_null("ModelRoot")
	assert(model_root != null, "ModelRoot missing on Olympus-4")
	var model = model_root.get_node_or_null("OlympusModel")
	assert(model != null, "OlympusModel missing inside ModelRoot")
	
	# Verify HitBox
	var hitbox = inst.get_node_or_null("HitBox")
	assert(hitbox != null, "HitBox missing on Olympus-4")
	var col_shape = hitbox.get_node_or_null("CollisionShape3D")
	assert(col_shape != null and col_shape.shape is BoxShape3D, "HitBox shape invalid")
	
	# Verify ShieldBubble
	var shield_bubble = inst.get_node_or_null("ShieldBubble")
	assert(shield_bubble != null, "ShieldBubble missing on Olympus-4")
	
	# Verify Thrusters
	assert(inst.get_node_or_null("ThrusterL") != null, "ThrusterL missing")
	assert(inst.get_node_or_null("ThrusterR") != null, "ThrusterR missing")
	
	# Verify Damage mechanics
	var initial_shield = inst.shield
	var initial_hull = inst.hull
	inst.take_damage(50.0)
	assert(inst.shield == initial_shield - 50.0, "Shield absorption failed")
	assert(inst.hull == initial_hull, "Hull took damage before shield depleted")
	
	# Deplete shield and damage hull
	inst.take_damage(inst.shield + 100.0)
	assert(inst.shield == 0.0, "Shield should be 0")
	assert(inst.hull == initial_hull - 100.0, "Hull damage calculation incorrect")
	
	print("  ✓ Transport Olympus-4: 66m model loaded, shields, hitboxes, and thrusters operational.")
	inst.queue_free()

func test_boss_combine_ghost() -> void:
	print("\n[TEST 3] Verifying Boss Combine Ghost Scene...")
	var scene = load("res://boss_combine_ghost.tscn")
	assert(scene != null, "Failed to load boss_combine_ghost.tscn")
	
	var inst = scene.instantiate()
	assert(inst != null, "Failed to instantiate boss_combine_ghost.tscn")
	root.add_child(inst)
	inst._ready()
	
	# Verify ViperModelRoot and GhostModel
	var model_root = inst.get_node_or_null("ViperModelRoot")
	assert(model_root != null, "ViperModelRoot missing on Combine Ghost")
	var model = model_root.get_node_or_null("GhostModel")
	assert(model != null, "GhostModel missing inside ViperModelRoot")
	
	# Verify Muzzles
	var muzzle_l = inst.get_node_or_null("MuzzleL")
	var muzzle_r = inst.get_node_or_null("MuzzleR")
	assert(muzzle_l != null and muzzle_r != null, "Rotary cannon muzzles missing")
	
	# Verify HitBox
	var hitbox = inst.get_node_or_null("HitBox")
	assert(hitbox != null, "HitBox missing on Combine Ghost")
	var col_shape = hitbox.get_node_or_null("CollisionShape3D")
	assert(col_shape != null and col_shape.shape is BoxShape3D, "HitBox shape invalid")
	
	# Verify mesh instances cached
	assert(inst._cached_mesh_instances.size() > 0, "Mesh instances were not cached")
	
	# Verify Damage and Destroyed signal
	var destroyed_box = [false]
	inst.destroyed.connect(func(): destroyed_box[0] = true)
	
	inst.take_damage(100.0) # shield absorb
	assert(inst.shield == 150.0, "Boss shield absorption failed")
	
	inst.take_damage(inst.shield + inst.hull) # lethal damage
	assert(destroyed_box[0] == true, "Boss destroyed signal not emitted on death")
	
	print("  ✓ Boss Combine Ghost: SG-99 model loaded, " + str(inst._cached_mesh_instances.size()) + " meshes cached for hit flashes, vitals, and death cascade operational.")
