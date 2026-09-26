extends Node

## NetworkControllerServer: In-Engine Dual HTTP + WebSocket Server for Mobile Web HOTAS
## Hosts local HTTP server (default port 8080) for zero-friction browser UI delivery over LAN.
## Hosts high-performance WebSocket server (default port 8081) for 30Hz controls and 10Hz telemetry.
## Translates 30Hz mobile frames into spaceship controls and broadcasts 10Hz flight telemetry to phones.

signal pilot_connected(callsign: String, player_id: int)
signal pilot_disconnected(callsign: String, player_id: int)
signal control_frame_received(player_id: int, frame: Dictionary)

const DEFAULT_HTTP_PORT = 8080
const DEFAULT_WS_PORT = 8081
const QRCodeScript = preload("res://qr_code.gd")

var http_port: int = DEFAULT_HTTP_PORT
var port: int = DEFAULT_WS_PORT # WebSocket port (exposed as `port` for backwards compatibility)
var http_server: TCPServer = null
var tcp_server: TCPServer = null # WebSocket TCPServer
var http_clients: Array[Dictionary] = [] # Array of { tcp: StreamPeerTCP, time: int }
var html_bytes: PackedByteArray = PackedByteArray()

var session_room_code: String = "VNG-77"
var connected_clients: Array[Dictionary] = [] # Array of { peer: WebSocketPeer, tcp: StreamPeerTCP, callsign: String, player_id: int, last_seen: float }

var target_ships: Dictionary = {} # player_id -> SpaceshipController
var queued_combat_events: Dictionary = {} # player_id -> Array[String]
var telemetry_timer: float = 0.0
var is_active: bool = false
var is_solo_mode: bool = true
var default_player_id: int = 1
var use_web_gateway: bool = false
const WEB_GATEWAY_BASE: String = "https://project-vanguard.pages.dev/controller.html"

## Enqueues a high-priority combat event for transmission to the player's mobile cockpit (e.g. HIT_CONFIRMED, KILL_CONFIRMED)
func notify_combat_event(player_id: int, event_name: String) -> void:
	if not queued_combat_events.has(player_id):
		queued_combat_events[player_id] = []
	queued_combat_events[player_id].append(event_name)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_generate_room_code()
	_load_standalone_html()
	start_server()

func _generate_room_code() -> void:
	var chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	session_room_code = "VNG-"
	for i in range(2):
		session_room_code += chars[randi() % chars.length()]
	session_room_code += str(randi_range(10, 99))

func _load_standalone_html() -> void:
	if not html_bytes.is_empty():
		return
	if FileAccess.file_exists("res://controller_standalone.html"):
		var f = FileAccess.open("res://controller_standalone.html", FileAccess.READ)
		if f:
			html_bytes = f.get_as_text().to_utf8_buffer()
			f.close()
			print("[NetworkControllerServer] Loaded standalone controller HTML (%d bytes)" % html_bytes.size())
			return
	push_warning("[NetworkControllerServer] res://controller_standalone.html not found! Using fallback.")
	html_bytes = "<html><body><h1>Project Vanguard Controller</h1><p>Please build controller_standalone.html.</p></body></html>".to_utf8_buffer()

## Starts listening for both HTTP (browser UI) and WebSocket (telemetry) connections
func start_server(desired_http_port: int = DEFAULT_HTTP_PORT, desired_ws_port: int = DEFAULT_WS_PORT) -> bool:
	if is_active:
		return true

	_load_standalone_html()

	# 1. Bind HTTP Web Server (default 8080)
	http_server = TCPServer.new()
	var curr_http = desired_http_port
	var started_http = false
	for i in range(5):
		var err = http_server.listen(curr_http)
		if err == OK:
			http_port = curr_http
			started_http = true
			break
		else:
			print("[NetworkControllerServer] HTTP Port %d busy, trying next..." % curr_http)
			curr_http += 1

	if not started_http:
		push_error("[NetworkControllerServer] Failed to bind HTTP server on ports %d-%d." % [desired_http_port, curr_http - 1])
		return false

	# 2. Bind WebSocket Game Streamer (default 8081)
	tcp_server = TCPServer.new()
	var curr_ws = desired_ws_port
	if curr_ws == http_port:
		curr_ws = http_port + 1
	var started_ws = false
	for i in range(5):
		var err = tcp_server.listen(curr_ws)
		if err == OK:
			port = curr_ws
			started_ws = true
			break
		else:
			print("[NetworkControllerServer] WS Port %d busy, trying next..." % curr_ws)
			curr_ws += 1

	if not started_ws:
		push_error("[NetworkControllerServer] Failed to bind WS server on ports %d-%d." % [desired_ws_port, curr_ws - 1])
		http_server.stop()
		http_server = null
		return false

	is_active = true
	print(">>> [NetworkControllerServer] DUAL SERVER ACTIVE!")
	print("    [HTTP] Serving Controller UI: http://%s:%d/" % [get_local_ip(), http_port])
	print("    [WS]   Streaming Flight HOTAS: ws://%s:%d/ (Room: %s)" % [get_local_ip(), port, session_room_code])
	return true

## Stops both servers and disconnects any connected mobile controllers
func stop_server() -> void:
	for client in connected_clients:
		var peer: WebSocketPeer = client.get("peer")
		if peer:
			peer.close(1000, "Server stopping")
	connected_clients.clear()

	for item in http_clients:
		var conn: StreamPeerTCP = item.get("tcp")
		if conn:
			conn.disconnect_from_host()
	http_clients.clear()

	if tcp_server:
		tcp_server.stop()
		tcp_server = null
	if http_server:
		http_server.stop()
		http_server = null

	is_active = false
	print(">>> [NetworkControllerServer] Stopped.")

## Automatically resolves local WiFi IPv4 address
func get_local_ip() -> String:
	var addresses = IP.get_local_addresses()
	for addr in addresses:
		# Prefer standard LAN addresses
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	# Fallback to non-loopback
	for addr in addresses:
		if addr != "127.0.0.1" and addr.find(":") == -1: # IPv4
			return addr
	return "127.0.0.1"

## Formats the exact URL to encode in the QR code
func get_controller_url(target_pid: int = 1, role_name: String = "pilot", gateway_mode: Variant = null) -> String:
	var use_gw = use_web_gateway if gateway_mode == null else bool(gateway_mode)
	var auth_mgr = get_node_or_null("/root/AuthManager") if is_inside_tree() else null
	var host_callsign = auth_mgr.callsign if (auth_mgr and not auth_mgr.callsign.is_empty()) else "LEAD"
	var cs = host_callsign + ("-HOTAS" if target_pid == 1 else "-WING")
	
	if use_gw:
		return "%s?host=%s:%d&http=%d&ws=%d&room=%s&callsign=%s&pid=%d&role=%s" % [
			WEB_GATEWAY_BASE, get_local_ip(), port, http_port, port, session_room_code, cs, target_pid, role_name
		]
	else:
		return "http://%s:%d/?ws=%d&room=%s&callsign=%s&pid=%d&role=%s" % [
			get_local_ip(), http_port, port, session_room_code, cs, target_pid, role_name
		]

## Generates a ready-to-display ImageTexture QR Code
func get_qr_texture(target_pid: int = 1, role_name: String = "pilot", gateway_mode: Variant = null, scale: int = 8) -> ImageTexture:
	return QRCodeScript.get_texture(get_controller_url(target_pid, role_name, gateway_mode), scale, 4)

## Registers a SpaceshipController instance to be driven by a specific player_id
func register_ship(player_id: int, ship: Node) -> void:
	target_ships[player_id] = ship
	if ship and ship.has_method("set"):
		ship.set("mobile_control_active", true)
	print("[NetworkControllerServer] Bound ship for Player %d -> %s" % [player_id, ship.name])

func unregister_ship(player_id: int) -> void:
	if target_ships.has(player_id):
		var ship = target_ships[player_id]
		if is_instance_valid(ship) and ship.has_method("set"):
			ship.set("mobile_control_active", false)
		target_ships.erase(player_id)

func _process(delta: float) -> void:
	if not is_active:
		return

	# 1. Process HTTP Server requests (serving standalone mobile controller to smartphones)
	if http_server and http_server.is_connection_available():
		var conn = http_server.take_connection()
		if conn:
			http_clients.append({
				"tcp": conn,
				"time": Time.get_ticks_msec()
			})

	var to_remove_http = []
	for item in http_clients:
		var conn: StreamPeerTCP = item.get("tcp")
		if not conn:
			to_remove_http.append(item)
			continue

		conn.poll()
		var status = conn.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTED:
			var avail = conn.get_available_bytes()
			if avail > 0:
				var req = conn.get_utf8_string(avail)
				if req.find(" /favicon.ico") != -1:
					var resp_favicon = "HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
					conn.put_data(resp_favicon.to_utf8_buffer())
				else:
					var headers = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n" % html_bytes.size()
					conn.put_data(headers.to_utf8_buffer())
					conn.put_data(html_bytes)
				conn.disconnect_from_host()
				to_remove_http.append(item)
		elif status != StreamPeerTCP.STATUS_CONNECTING:
			to_remove_http.append(item)
		elif Time.get_ticks_msec() - item.get("time", 0) > 4000:
			conn.disconnect_from_host()
			to_remove_http.append(item)

	for item in to_remove_http:
		http_clients.erase(item)

	# 2. Process WebSocket Server connections (30Hz flight controls stream)
	if tcp_server and tcp_server.is_connection_available():
		var conn = tcp_server.take_connection()
		if conn:
			var ws = WebSocketPeer.new()
			var err = ws.accept_stream(conn)
			if err == OK:
				var new_client = {
					"peer": ws,
					"tcp": conn,
					"callsign": "GUEST-PILOT",
					"player_id": default_player_id, # Defaults to Player 1 (Controller 1)
					"last_seen": Time.get_ticks_msec() / 1000.0,
				}
				connected_clients.append(new_client)
				print("[NetworkControllerServer] New mobile connection accepted from %s (Assigned to Controller %d)." % [conn.get_connected_host(), default_player_id])
			else:
				print("[NetworkControllerServer] WebSocket handshake failed: ", err)

	# 3. Process connected WebSocket clients
	var to_remove = []
	for client in connected_clients:
		var peer: WebSocketPeer = client.get("peer")
		if not peer:
			to_remove.append(client)
			continue

		peer.poll()
		var state = peer.get_ready_state()

		if state == WebSocketPeer.STATE_OPEN:
			while peer.get_available_packet_count() > 0:
				var packet = peer.get_packet()
				client["last_seen"] = Time.get_ticks_msec() / 1000.0
				if packet.size() == 16:
					_handle_binary_packet(client, packet)
				else:
					var raw = packet.get_string_from_utf8()
					_handle_packet(client, raw)
		elif state == WebSocketPeer.STATE_CLOSED or state == WebSocketPeer.STATE_CLOSING:
			to_remove.append(client)

	for client in to_remove:
		var cs = client.get("callsign", "PILOT")
		var pid = client.get("player_id", default_player_id)
		connected_clients.erase(client)
		print("[NetworkControllerServer] Mobile pilot %s (Player %d) disconnected." % [cs, pid])
		pilot_disconnected.emit(cs, pid)

	# 4. 10Hz Reverse Telemetry Broadcast (Phone Instrument HUD)
	telemetry_timer += delta
	if telemetry_timer >= 0.10: # 100ms
		telemetry_timer = 0.0
		_broadcast_telemetry_to_phones()

func _handle_packet(client: Dictionary, raw_json: String) -> void:
	if raw_json.is_empty():
		return

	var parsed = JSON.parse_string(raw_json)
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var data: Dictionary = parsed

	# Handshake packet
	if data.get("type") == "handshake":
		var cs = data.get("callsign", "PILOT-1").strip_edges().to_upper()
		if cs.is_empty(): cs = "PILOT-1"
		client["callsign"] = cs
		
		# Resolve player_id: explicit in packet, or solo_mode defaults to 1
		var req_pid = int(data.get("player_id", 0))
		if req_pid <= 0:
			req_pid = 1 if is_solo_mode else 2
		client["player_id"] = req_pid
		
		var role = data.get("role", "pilot" if req_pid == 1 else "wingman")
		print(">>> [NetworkControllerServer] Mobile Pilot '%s' commissioned as Controller %d (%s)!" % [cs, req_pid, role])
		pilot_connected.emit(cs, req_pid)
		return

	# Flight telemetry frame
	var pid = client.get("player_id", default_player_id)
	control_frame_received.emit(pid, data)

	# Forward to registered spaceship
	if target_ships.has(pid):
		var ship = target_ships[pid]
		if is_instance_valid(ship) and ship.has_method("apply_mobile_inputs"):
			ship.apply_mobile_inputs(data)

func _handle_binary_packet(client: Dictionary, bytes: PackedByteArray) -> void:
	if bytes.size() != 16:
		return

	var sp = StreamPeerBuffer.new()
	sp.data_array = bytes
	var pitch = sp.get_float()
	var roll = sp.get_float()
	var throttle = sp.get_float()
	var yaw_int = sp.get_16()
	var yaw = float(yaw_int) / 32767.0
	var flags = sp.get_u8()
	var seq = sp.get_u8()

	var fire_primary = bool(flags & 1)
	var boost = bool(flags & 2)
	var fire_missile = bool(flags & 4)
	var power_code = (flags >> 3) & 3
	var power_modes = ["BALANCED", "ENGINES", "SHIELDS", "WEAPONS"]
	var power_mode = power_modes[power_code]
	var target_lock = bool(flags & 32)
	var tare_pulse = bool(flags & 64)

	var data = {
		"pitch": pitch,
		"roll": roll,
		"yaw": yaw,
		"throttle": throttle,
		"boost": boost,
		"fire_primary": fire_primary,
		"fire": fire_primary,
		"fire_missile": fire_missile,
		"missile": fire_missile,
		"target_lock": target_lock,
		"power": power_mode,
		"power_divert": power_mode,
		"tare": tare_pulse,
		"seq": seq,
		"is_binary": true
	}

	var pid = client.get("player_id", default_player_id)
	control_frame_received.emit(pid, data)

	# Forward to registered spaceship
	if target_ships.has(pid):
		var ship = target_ships[pid]
		if is_instance_valid(ship) and ship.has_method("apply_mobile_inputs"):
			ship.apply_mobile_inputs(data)

func _broadcast_telemetry_to_phones() -> void:
	if connected_clients.is_empty():
		return

	for client in connected_clients:
		var peer: WebSocketPeer = client.get("peer")
		if not peer or peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
			continue

		var pid = client.get("player_id", 2)
		var ship = target_ships.get(pid)

		var telem_payload = {
			"shield": 100.0,
			"hull": 100.0,
			"speed": 60.0,
			"missiles": 4,
			"target_locked": false,
			"under_fire": false,
			"power_mode": "BALANCED",
			"events": []
		}

		# Flush any combat events queued for this player
		if queued_combat_events.has(pid):
			var ev_list = queued_combat_events[pid]
			if not ev_list.is_empty():
				telem_payload["events"] = ev_list.duplicate()
				ev_list.clear()

		if is_instance_valid(ship):
			var telem_node = ship.get_node_or_null("CombatTelemetry")
			if telem_node:
				telem_payload["shield"] = telem_node.current_shield
				telem_payload["hull"] = telem_node.current_hull
				telem_payload["missiles"] = telem_node.missiles_remaining
				if "current_target" in telem_node and telem_node.current_target != null:
					telem_payload["target_locked"] = true
			if "current_speed" in ship:
				telem_payload["speed"] = ship.current_speed
			if "power_divert_mode" in ship:
				telem_payload["power_mode"] = ship.power_divert_mode
			if "target_locked" in ship and ship.target_locked:
				telem_payload["target_locked"] = true

		var msg = JSON.stringify(telem_payload)
		peer.send_text(msg)
