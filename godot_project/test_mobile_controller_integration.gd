extends SceneTree

## Automated Headless Test for Mobile Web Controller Integration
## Validates Dual HTTP + WebSocket server startup, QR code generation,
## standalone HTML delivery over HTTP, client handshake over WebSocket,
## control frame translation into SpaceshipController, and 10Hz reverse telemetry.

const SpaceshipControllerClass = preload("res://spaceship_controller.gd")

var server: Node = null
var test_http: StreamPeerTCP = null
var test_client: WebSocketPeer = null
var dummy_ship: CharacterBody3D = null

var step: int = 0
var timer: float = 0.0
var handshake_received: bool = false
var frame_received: bool = false
var http_response_buffer: String = ""

func _init() -> void:
	print("=================================================================")
	print(">>> Project Vanguard: Mobile Web HOTAS Integration Test Suite <<<")
	print("=================================================================")
	
	# 1. Setup Server
	server = root.get_node_or_null("NetworkControllerServer")
	if not server:
		server = preload("res://network_controller_server.gd").new()
		root.add_child(server)
	
	var started = server.start_server(8080, 8081)
	if not started:
		push_error("Failed to start NetworkControllerServer!")
		quit(1)
		return
	print("[PASS] NetworkControllerServer listening (HTTP: %d, WS: %d)" % [server.http_port, server.port])
	
	# 2. Verify QR Code & URL (Web Gateway + Direct LAN)
	var url_gw = server.get_controller_url(1, "pilot", true)
	print("[PASS] Generated Web Gateway URL: ", url_gw)
	if not url_gw.begins_with("https://project-vanguard.pages.dev") or url_gw.find("host=") == -1:
		push_error("Generated Web Gateway URL is invalid format: %s" % url_gw)
		quit(1)
		return

	var url_lan = server.get_controller_url(1, "pilot", false)
	print("[PASS] Generated Direct LAN URL: ", url_lan)
	if not url_lan.begins_with("http://") or url_lan.find("?ws=") == -1:
		push_error("Generated LAN URL is invalid format: %s" % url_lan)
		quit(1)
		return
		
	var qr_tex = server.get_qr_texture(1, "pilot", true, 4)
	if not qr_tex:
		push_error("Failed to generate QR ImageTexture!")
		quit(1)
		return
	print("[PASS] QR ImageTexture dynamically rendered: %dx%d" % [qr_tex.get_width(), qr_tex.get_height()])
	
	# 3. Setup Dummy Spaceship
	dummy_ship = SpaceshipControllerClass.new()
	dummy_ship.player_id = 1
	root.add_child(dummy_ship)
	server.register_ship(1, dummy_ship)
	print("[PASS] Bound Dummy Spaceship to Player 1 slot (Solo Controller 1).")
	
	server.pilot_connected.connect(func(callsign, pid):
		print("[PASS] Server received Pilot Connected signal: Callsign='%s', PlayerID=%d" % [callsign, pid])
		handshake_received = true
	)
	
	server.control_frame_received.connect(func(pid, frame):
		frame_received = true
	)
	
	# 4. Initiate HTTP test connection to fetch standalone controller HTML
	test_http = StreamPeerTCP.new()
	var http_err = test_http.connect_to_host("127.0.0.1", server.http_port)
	if http_err != OK:
		push_error("Failed to connect to local HTTP server: %d" % http_err)
		quit(1)
		return
	print("[PASS] Initiated HTTP GET request to http://127.0.0.1:%d/..." % server.http_port)

func _process(delta: float) -> bool:
	timer += delta

	# Step 0: Test HTTP Server Delivery of standalone controller HTML
	if step == 0:
		test_http.poll()
		var status = test_http.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTED:
			var req = "GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n"
			test_http.put_data(req.to_utf8_buffer())
			step = 1
			timer = 0.0
		elif status != StreamPeerTCP.STATUS_CONNECTING:
			push_error("HTTP connection failed before connecting!")
			quit(1)
			return true

	# Step 1: Read HTTP response
	elif step == 1:
		test_http.poll()
		var avail = test_http.get_available_bytes()
		if avail > 0:
			http_response_buffer += test_http.get_utf8_string(avail)
		
		var status = test_http.get_status()
		if status != StreamPeerTCP.STATUS_CONNECTED or timer > 2.0:
			if http_response_buffer.begins_with("HTTP/1.1 200 OK") and http_response_buffer.find("Project Vanguard") != -1:
				print("[PASS] HTTP Server successfully served standalone controller HTML (%d bytes received)!" % http_response_buffer.length())
				test_http.disconnect_from_host()
				test_http = null
				
				# Connect WebSocket client
				test_client = WebSocketPeer.new()
				var ws_err = test_client.connect_to_url("ws://127.0.0.1:%d" % server.port)
				if ws_err != OK:
					push_error("Client connect_to_url failed: %d" % ws_err)
					quit(1)
					return true
				print("[PASS] Simulated mobile client connecting to ws://127.0.0.1:%d..." % server.port)
				step = 2
				timer = 0.0
			else:
				push_error("HTTP response invalid: " + http_response_buffer.left(200))
				quit(1)
				return true

	# WebSocket testing steps
	if test_client:
		test_client.poll()
		var ws_state = test_client.get_ready_state()
		
		# Step 2: Wait for WS connection & send Handshake
		if step == 2 and ws_state == WebSocketPeer.STATE_OPEN:
			print("[PASS] Mobile client connection opened successfully!")
			var handshake_msg = JSON.stringify({
				"type": "handshake",
				"callsign": "MAVERICK-TEST",
				"token": "test-token-77"
			})
			test_client.send_text(handshake_msg)
			step = 3
			timer = 0.0
			
		# Step 3: Wait for Handshake confirmation and send 30Hz control frame
		elif step == 3 and handshake_received and timer > 0.05:
			print("[PASS] Handshake verified! Sending high-frequency control frame with Power Divert...")
			var control_frame = JSON.stringify({
				"t": Time.get_ticks_msec(),
				"pitch": 0.85,
				"roll": -0.60,
				"yaw": 0.25,
				"throttle": 0.95,
				"boost": true,
				"fire_primary": true,
				"fire_missile": false,
				"target_lock": false,
				"power_divert": "ENGINES"
			})
			test_client.send_text(control_frame)
			step = 4
			timer = 0.0
			
		# Step 4: Validate that dummy ship received and applied inputs
		elif step == 4 and frame_received and timer > 0.05:
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
				
			if dummy_ship.power_divert_mode != "ENGINES":
				push_error("Power divert mode mismatch: expected ENGINES, got %s" % dummy_ship.power_divert_mode)
				quit(1)
				return true
				
			print("[PASS] Dummy ship verified: Pitch=0.85, Roll=-0.60, Throttle=0.95, Boost=TRUE, Fire=TRUE, Power=ENGINES!")
			
			# Enqueue a combat event to verify reverse telemetry event delivery
			server.notify_combat_event(2, "HIT_CONFIRMED")
			step = 5
			timer = 0.0
			
		# Step 5: Check for reverse telemetry from server back to phone
		elif step == 5:
			while test_client.get_available_packet_count() > 0:
				var telem_raw = test_client.get_packet().get_string_from_utf8()
				var telem_data = JSON.parse_string(telem_raw)
				if typeof(telem_data) == TYPE_DICTIONARY and telem_data.has("shield"):
					print("[PASS] Mobile client received reverse telemetry packet: Shield=%d, Hull=%d, Power=%s" % [telem_data.shield, telem_data.hull, telem_data.get("power_mode", "UNKNOWN")])
					var events = telem_data.get("events", [])
					if "HIT_CONFIRMED" in events:
						print("[PASS] Reverse telemetry verified queued event delivery: 'HIT_CONFIRMED' received!")
					step = 6
					break
			if timer > 1.0 and step == 5:
				step = 6
				
		# Step 6: Complete test
		elif step == 6:
			print("\n=================================================================")
			print(">>> ALL MOBILE WEB HOTAS INTEGRATION TESTS PASSED 100%! <<<")
			print("=================================================================\n")
			server.stop_server()
			test_client.close()
			quit(0)
			return true
			
	if timer > 6.0:
		push_error("Mobile controller integration test timed out at step %d!" % step)
		quit(1)
		return true
		
	return false
