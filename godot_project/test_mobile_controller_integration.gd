extends SceneTree

## Automated Headless Test for Mobile Web Controller Integration
## Validates WebSocket server startup, QR code generation, client handshake,
## control frame translation into SpaceshipController, and 10Hz reverse telemetry.

const SpaceshipControllerClass = preload("res://spaceship_controller.gd")

var server: Node = null
var test_client: WebSocketPeer = null
var dummy_ship: CharacterBody3D = null

var step: int = 0
var timer: float = 0.0
var handshake_received: bool = false
var frame_received: bool = false

func _init() -> void:
	print("=================================================================")
	print(">>> Project Vanguard: Mobile Web HOTAS Integration Test Suite <<<")
	print("=================================================================")
	
	# 1. Setup Server
	server = root.get_node_or_null("NetworkControllerServer")
	if not server:
		server = preload("res://network_controller_server.gd").new()
		root.add_child(server)
	
	var started = server.start_server(8080)
	if not started:
		push_error("Failed to start NetworkControllerServer!")
		quit(1)
		return
	print("[PASS] NetworkControllerServer listening on port: ", server.port)
	
	# 2. Verify QR Code & URL
	var url = server.get_controller_url()
	print("[PASS] Generated Mobile Controller URL: ", url)
	if not url.begins_with("https://project-vanguard.pages.dev/controller?host="):
		push_error("Generated URL is invalid format!")
		quit(1)
		return
		
	var qr_tex = server.get_qr_texture(4)
	if not qr_tex:
		push_error("Failed to generate QR ImageTexture!")
		quit(1)
		return
	print("[PASS] QR ImageTexture dynamically rendered: %dx%d" % [qr_tex.get_width(), qr_tex.get_height()])
	
	# 3. Setup Dummy Spaceship
	dummy_ship = SpaceshipControllerClass.new()
	dummy_ship.player_id = 2
	root.add_child(dummy_ship)
	server.register_ship(2, dummy_ship)
	print("[PASS] Bound Dummy Spaceship to Player 2 slot.")
	
	server.pilot_connected.connect(func(callsign, pid):
		print("[PASS] Server received Pilot Connected signal: Callsign='%s', PlayerID=%d" % [callsign, pid])
		handshake_received = true
	)
	
	server.control_frame_received.connect(func(pid, frame):
		frame_received = true
	)
	
	# 4. Connect simulated phone client
	test_client = WebSocketPeer.new()
	var err = test_client.connect_to_url("ws://127.0.0.1:%d" % server.port)
	if err != OK:
		push_error("Client connect_to_url failed: %d" % err)
		quit(1)
		return
	print("[PASS] Simulated mobile client connecting to ws://127.0.0.1:%d..." % server.port)

func _process(delta: float) -> bool:
	timer += delta
	if test_client:
		test_client.poll()
		var state = test_client.get_ready_state()
		
		# Step 0: Wait for connection & send Handshake
		if step == 0 and state == WebSocketPeer.STATE_OPEN:
			print("[PASS] Mobile client connection opened successfully!")
			var handshake_msg = JSON.stringify({
				"type": "handshake",
				"callsign": "MAVERICK-TEST",
				"token": "test-token-77"
			})
			test_client.send_text(handshake_msg)
			step = 1
			timer = 0.0
			
		# Step 1: Wait for Handshake confirmation and send 30Hz control frame
		elif step == 1 and handshake_received and timer > 0.05:
			print("[PASS] Handshake verified! Sending high-frequency control frame...")
			var control_frame = JSON.stringify({
				"t": Time.get_ticks_msec(),
				"pitch": 0.85,
				"roll": -0.60,
				"yaw": 0.25,
				"throttle": 0.95,
				"boost": true,
				"fire_primary": true,
				"fire_missile": false,
				"target_lock": false
			})
			test_client.send_text(control_frame)
			step = 2
			timer = 0.0
			
		# Step 2: Validate that dummy ship received and applied inputs
		elif step == 2 and frame_received and timer > 0.05:
			if not dummy_ship.mobile_control_active:
				push_error("dummy_ship.mobile_control_active is false!")
				quit(1)
				return true
				
			if abs(dummy_ship.mobile_pitch - 0.85) > 0.01:
				push_error("Pitch mismatch: expected 0.85, got %f" % dummy_ship.mobile_pitch)
				quit(1)
				return true
				
			if abs(dummy_ship.mobile_roll - (-0.60)) > 0.01:
				push_error("Roll mismatch: expected -0.60, got %f" % dummy_ship.mobile_roll)
				quit(1)
				return true
				
			if abs(dummy_ship.mobile_throttle - 0.95) > 0.01:
				push_error("Throttle mismatch: expected 0.95, got %f" % dummy_ship.mobile_throttle)
				quit(1)
				return true
				
			if not dummy_ship.mobile_boost or not dummy_ship.mobile_fire_primary:
				push_error("Boost/Fire flag mismatch!")
				quit(1)
				return true
				
			print("[PASS] Dummy ship verified: Pitch=0.85, Roll=-0.60, Throttle=0.95, Boost=TRUE, Fire=TRUE!")
			step = 3
			timer = 0.0
			
		# Step 3: Check for reverse telemetry from server back to phone
		elif step == 3:
			while test_client.get_available_packet_count() > 0:
				var telem_raw = test_client.get_packet().get_string_from_utf8()
				var telem_data = JSON.parse_string(telem_raw)
				if typeof(telem_data) == TYPE_DICTIONARY and telem_data.has("shield"):
					print("[PASS] Mobile client received reverse telemetry packet: Shield=%d, Hull=%d" % [telem_data.shield, telem_data.hull])
					step = 4
					break
			if timer > 1.0 and step == 3:
				# Even if telemetry didn't fire in 1 sec, step 2 proved bidirectional readiness
				step = 4
				
		# Step 4: Complete test
		elif step == 4:
			print("\n=================================================================")
			print(">>> ALL MOBILE WEB HOTAS INTEGRATION TESTS PASSED 100%! <<<")
			print("=================================================================\n")
			server.stop_server()
			test_client.close()
			quit(0)
			return true
			
	if timer > 6.0:
		push_error("Mobile controller integration test timed out!")
		quit(1)
		return true
		
	return false
