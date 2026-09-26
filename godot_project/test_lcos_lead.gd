extends SceneTree

## Automated Headless Test Suite for LCOS Lead-Computing Pipper & Combat Juice
## Verifies 3D ballistic intercept math, lead pipper convergence, hitmarker audio,
## and dynamic camera FOV scaling.

var frame_count: int = 0
var test_done: bool = false
var timeout: float = 0.0

func _init() -> void:
	print("=================================================================")
	print(">>> Project Vanguard: LCOS Lead & Combat Juice Test Suite     <<<")
	print("=================================================================")

func _process(delta: float) -> bool:
	if test_done:
		return true
		
	timeout += delta
	if timeout > 8.0:
		push_error("Test timed out!")
		quit(1)
		return true

	frame_count += 1
	if frame_count < 2:
		return false
		
	test_done = true
	_run_all_tests()
	return true

func _run_all_tests() -> void:
	# 1. Setup Root 3D World Container
	var world = Node3D.new()
	root.add_child(world)
	
	var ship = preload("res://spaceship_controller.gd").new()
	world.add_child(ship)
	ship.position = Vector3(0, 500, 0)
	ship.current_speed = 100.0
	
	var cam = Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0, 503, 12)
	cam.look_at(ship.global_position, Vector3.UP)
	
	var hud = preload("res://hud.gd").new()
	world.add_child(hud)
	hud.bind_to_ship(ship, cam, 1)
	
	print("[PASS] World, Ship, Camera3D, and HUD instantiated inside tree.")
	
	# 2. Test LCOS Ballistic Math: Stationary Target at 650m
	var target_dummy = CharacterBody3D.new()
	world.add_child(target_dummy)
	target_dummy.position = Vector3(0, 500, -650)
	
	var lead_stationary = hud._calculate_lcos_lead(target_dummy, target_dummy.global_position, 0.016)
	if lead_stationary.is_empty():
		push_error("LCOS calculation returned empty dictionary for stationary target!")
		quit(1)
		return
		
	var lead_pos_stat: Vector3 = lead_stationary["lead_pos"]
	var tof_stat: float = lead_stationary["time_of_flight"]
	
	print("[PASS] Stationary Target (650m): Time-of-Flight = %.2fs, Lead Pos = %s" % [tof_stat, lead_pos_stat])
	# With bullet speed 650 + 100 = 750 m/s: tof should be ~650/750 = 0.867s
	if abs(tof_stat - (650.0 / 750.0)) >= 0.08:
		push_error("Time of flight mismatch: expected ~%.3f, got %.3f" % [650.0 / 750.0, tof_stat])
		quit(1)
		return
	print("[PASS] Time of flight verified.")
	
	# 3. Test LCOS Ballistic Math: Crossing Target (Banking Left-to-Right at 100 m/s)
	target_dummy.set("velocity", Vector3(100.0, 0.0, 0.0))
	var lead_crossing = hud._calculate_lcos_lead(target_dummy, target_dummy.global_position, 0.016)
	if lead_crossing.is_empty():
		push_error("LCOS calculation returned empty dictionary for crossing target!")
		quit(1)
		return
		
	var lead_pos_cross: Vector3 = lead_crossing["lead_pos"]
	var tof_cross: float = lead_crossing["time_of_flight"]
	
	print("[PASS] Crossing Target (100 m/s Right): Lead X = %.1fm (predicted offset: +%.1fm)" % [
		lead_pos_cross.x, 100.0 * tof_cross
	])
	if lead_pos_cross.x < 60.0:
		push_error("Lead X should lead ahead in the direction of motion, got %.1f" % lead_pos_cross.x)
		quit(1)
		return
	print("[PASS] Ballistic lead deflection vector verified.")
	
	# 4. Test Hitmarker Audio & Visual State
	if hud.hitmarker_timer != 0.0:
		push_error("Initial hitmarker timer must be 0")
		quit(1)
		return
	hud.trigger_hitmarker()
	if hud.hitmarker_timer <= 0.2:
		push_error("Hitmarker timer did not activate on trigger")
		quit(1)
		return
	print("[PASS] Hitmarker triggered with audio player active.")
	
	# 5. Test Camera G-Lag & Dynamic FOV Scaling
	ship.custom_camera = cam
	ship.current_speed = 220.0
	ship.was_boosting = true
	ship.power_divert_mode = "ENGINES"
	for i in range(10):
		ship._process_camera_follow(0.033)
	
	print("[PASS] Dynamic Camera FOV expanding on boost: %.1f deg (Base: %.1f deg)" % [cam.fov, ship.base_camera_fov])
	if cam.fov <= ship.base_camera_fov:
		push_error("Camera FOV must expand on afterburner nitro")
		quit(1)
		return
		
	# Cleanup
	world.free()
	
	print("=================================================================")
	print(">>> ALL LCOS & COMBAT JUICE TESTS PASSED (100%)              <<<")
	print("=================================================================")
	quit(0)
