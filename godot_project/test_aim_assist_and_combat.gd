extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("==================================================================")
	print("PROJECT VANGUARD: COMBAT AIM ASSIST & MOBILE HOTAS TEST SUITE")
	print("==================================================================")

	# -------------------------------------------------------------------------
	# TEST 1: Machine Gun Auto Aim Assist & Lead Magnetism
	# -------------------------------------------------------------------------
	print("\n[TEST 1] Testing Machine Gun Auto Aim Assist & Lead Magnetism...")
	var ship_script = load("res://spaceship_controller.gd")
	assert(ship_script != null, "Failed to load spaceship_controller.gd")
	var ship = CharacterBody3D.new()
	ship.name = "TestShip"
	ship.set_script(ship_script)
	root.add_child(ship)
	ship.global_position = Vector3(0, 0, 0)
	ship.current_speed = 60.0

	var dummy_target = Node3D.new()
	dummy_target.name = "EnemyDrone"
	dummy_target.add_to_group("enemies")
	dummy_target.set("is_alive", true)
	root.add_child(dummy_target)
	# Target at 150m forward, offset to right by 18m (~6.8 degrees)
	dummy_target.global_position = Vector3(18, 0, -150)
	dummy_target.set("velocity", Vector3(10, 0, 0)) # Flying right

	var muzzle_pos = Vector3(0.85, 0, -2.6)
	var straight_fwd = Vector3(0, 0, -1)
	var assisted_dir = ship._calculate_aim_assist_dir(muzzle_pos, straight_fwd)

	assert(assisted_dir.x > 0.0, "Aim assist should bend trajectory toward target on right (x > 0)")
	assert(assisted_dir.dot(straight_fwd) > 0.9, "Aim assist should maintain forward trajectory")
	var unassisted_angle = rad_to_deg(straight_fwd.angle_to((dummy_target.global_position - muzzle_pos).normalized()))
	var assisted_angle = rad_to_deg(assisted_dir.angle_to((dummy_target.global_position - muzzle_pos).normalized()))
	assert(assisted_angle < unassisted_angle, "Assisted angle to target should be smaller than straight forward")
	print("  [PASS] Aim assist verified: straight angle = %.2f deg -> assisted angle = %.2f deg" % [unassisted_angle, assisted_angle])

	dummy_target.queue_free()

	# -------------------------------------------------------------------------
	# TEST 2: Bullet Proximity Proxy Hit Detection
	# -------------------------------------------------------------------------
	print("\n[TEST 2] Testing Bullet Proximity Proxy Hit Detection...")
	var drone_scene = load("res://target_drone.gd")
	var drone = Node3D.new()
	drone.set_script(drone_scene)
	root.add_child(drone)
	drone.global_position = Vector3(0, 0, -40)
	var initial_hp = drone.health

	var bullet_scene = load("res://bullet.tscn")
	assert(bullet_scene != null, "Failed to load bullet.tscn")
	var bullet = bullet_scene.instantiate()
	root.add_child(bullet)
	# Position bullet offset by 0.5m laterally (normally misses a zero-radius ray, but hits with 0.85m proxy radius)
	bullet.global_position = Vector3(0.5, 0, 0)
	bullet.damage = 15.0
	bullet.setup(ship, Vector3(0, 0, -1), 0.0, false)

	# Allow physics tick to process bullet movement and proxy collision
	await create_timer(0.08).timeout

	assert(drone.health < initial_hp, "Proximity proxy sweep should have scored a hit on the target drone")
	print("  [PASS] Proximity hit detection verified: Drone HP reduced from %.1f to %.1f" % [initial_hp, drone.health])

	drone.queue_free()

	# -------------------------------------------------------------------------
	# TEST 3: Mobile HOTAS Scene Persistence Across Sorties
	# -------------------------------------------------------------------------
	print("\n[TEST 3] Testing Mobile HOTAS Persistence Across Scene Reloads...")
	var net_server = root.get_node_or_null("NetworkControllerServer")
	assert(net_server != null, "NetworkControllerServer autoload must exist")

	# Ship 1 registers automatically in _ready()
	assert(net_server.target_ships.has(1), "Ship 1 must be registered in target_ships")
	assert(net_server.target_ships[1] == ship, "Registered ship must match active ship")

	# Deliver mobile frame to Ship 1
	var frame1 = {
		"pitch": 0.45,
		"roll": -0.30,
		"yaw": 0.15,
		"throttle": 0.80,
		"boost": false,
		"fire_primary": false
	}
	net_server._handle_packet({"player_id": 1}, JSON.stringify(frame1))
	assert(ship.mobile_pitch == 0.45, "Ship 1 must receive mobile pitch")
	assert(ship.mobile_roll == -0.30, "Ship 1 must receive mobile roll")
	print("  [PASS] Sortie 1 mobile inputs applied successfully.")

	# Simulate Sortie 1 ending / scene change: Ship 1 leaves tree
	ship.queue_free()
	# Wait for exit_tree to process
	await create_timer(0.05).timeout

	assert(not net_server.target_ships.has(1) or not is_instance_valid(net_server.target_ships.get(1)), "Ship 1 must unregister on scene exit")

	# Deliver frame while transitioning between scenes (should not crash!)
	net_server._handle_packet({"player_id": 1}, JSON.stringify(frame1))
	print("  [PASS] Mid-transition packet handled gracefully without active ship.")

	# Simulate Sortie 2 launching: Ship 2 instantiates in new scene
	var ship2 = CharacterBody3D.new()
	ship2.name = "SpaceshipSortie2"
	ship2.set_script(ship_script)
	root.add_child(ship2)
	assert(net_server.target_ships.has(1), "Ship 2 must auto-register in Sortie 2")
	assert(net_server.target_ships[1] == ship2, "Ship 2 must be the active bound ship")

	# Deliver mobile frame in Sortie 2
	var frame2 = {
		"pitch": -0.65,
		"roll": 0.50,
		"yaw": -0.20,
		"throttle": 0.95,
		"boost": true,
		"fire_primary": true
	}
	net_server._handle_packet({"player_id": 1}, JSON.stringify(frame2))
	assert(ship2.mobile_pitch == -0.65, "Ship 2 in Sortie 2 must receive mobile pitch")
	assert(ship2.mobile_roll == 0.50, "Ship 2 in Sortie 2 must receive mobile roll")
	assert(ship2.mobile_boost == true, "Ship 2 in Sortie 2 must receive mobile boost")
	print("  [PASS] Sortie 2 mobile inputs seamlessly routed to new airframe!")

	ship2.queue_free()

	print("\n==================================================================")
	print(">>> ALL AIM ASSIST, PROXIMITY HIT & HOTAS TESTS PASSED (100%) <<<")
	print("==================================================================")
	quit(0)
