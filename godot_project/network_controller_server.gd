extends Node

## NetworkControllerServer: In-Engine WebSocket Server for Mobile Web HOTAS
## Listens on local LAN port (default 8080) for incoming phone connections from project-vanguard.pages.dev/controller.
## Translates 30Hz mobile frames into spaceship controls and broadcasts 10Hz flight telemetry to phones.

signal pilot_connected(callsign: String, player_id: int)
signal pilot_disconnected(callsign: String, player_id: int)
signal control_frame_received(player_id: int, frame: Dictionary)

const DEFAULT_PORT = 8080
const QRCodeScript = preload("res://qr_code.gd")

var port: int = DEFAULT_PORT
var tcp_server: TCPServer = null
var session_room_code: String = "VNG-77"
var connected_clients: Array[Dictionary] = [] # Array of { peer: WebSocketPeer, tcp: StreamPeerTCP, callsign: String, player_id: int, last_seen: float }

var target_ships: Dictionary = {} # player_id -> SpaceshipController
var queued_combat_events: Dictionary = {} # player_id -> Array[String]
var telemetry_timer: float = 0.0
var is_active: bool = false

## Enqueues a high-priority combat event for transmission to the player's mobile cockpit (e.g. HIT_CONFIRMED, KILL_CONFIRMED)
func notify_combat_event(player_id: int, event_name: String) -> void:
	if not queued_combat_events.has(player_id):
		queued_combat_events[player_id] = []
	queued_combat_events[player_id].append(event_name)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_generate_room_code()

func _generate_room_code() -> void:
	var chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	session_room_code = "VNG-"
	for i in range(2):
		session_room_code += chars[randi() % chars.length()]
	session_room_code += str(randi_range(10, 99))

## Starts listening on the specified port (tries next port if busy)
func start_server(desired_port: int = DEFAULT_PORT) -> bool:
	if tcp_server and tcp_server.is_listening():
		return true
		
	tcp_server = TCPServer.new()
	var current_port = desired_port
	var max_attempts = 5
	var started = false
	
	for i in range(max_attempts):
		var err = tcp_server.listen(current_port)
		if err == OK:
			port = current_port
			started = true
			break
		else:
			print("[NetworkControllerServer] Port %d busy, trying next..." % current_port)
			current_port += 1
			
	if not started:
		push_error("[NetworkControllerServer] Failed to bind TCP server on ports %d-%d." % [desired_port, current_port - 1])
		is_active = false
		return false
		
	is_active = true
	print(">>> [NetworkControllerServer] Listening on ws://%s:%d (Room: %s)" % [get_local_ip(), port, session_room_code])
	return true

## Stops the server and disconnects any connected mobile controllers
func stop_server() -> void:
	for client in connected_clients:
		var peer: WebSocketPeer = client.get("peer")
		if peer:
			peer.close(1000, "Server stopping")
	connected_clients.clear()
	
	if tcp_server:
		tcp_server.stop()
		tcp_server = null
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
func get_controller_url() -> String:
	return "https://project-vanguard.pages.dev/controller?host=%s:%d&room=%s" % [get_local_ip(), port, session_room_code]

## Generates a ready-to-display ImageTexture QR Code
func get_qr_texture(scale: int = 6) -> ImageTexture:
	return QRCodeScript.get_texture(get_controller_url(), scale, 3)

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
	if not is_active or not tcp_server:
		return
		
	# 1. Accept new incoming TCP connections and upgrade to WebSockets
	if tcp_server.is_connection_available():
		var conn = tcp_server.take_connection()
		if conn:
			var ws = WebSocketPeer.new()
			var err = ws.accept_stream(conn)
			if err == OK:
				var new_client = {
					"peer": ws,
					"tcp": conn,
					"callsign": "GUEST-PILOT",
					"player_id": 2, # Defaults to Player 2 (Wingman)
					"last_seen": Time.get_ticks_msec() / 1000.0,
				}
				connected_clients.append(new_client)
				print("[NetworkControllerServer] New mobile connection accepted from %s." % conn.get_connected_host())
			else:
				print("[NetworkControllerServer] WebSocket handshake failed: ", err)

	# 2. Process connected clients
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
				var raw = peer.get_packet().get_string_from_utf8()
				client["last_seen"] = Time.get_ticks_msec() / 1000.0
				_handle_packet(client, raw)
		elif state == WebSocketPeer.STATE_CLOSED or state == WebSocketPeer.STATE_CLOSING:
			to_remove.append(client)
			
	for client in to_remove:
		var cs = client.get("callsign", "PILOT")
		var pid = client.get("player_id", 2)
		connected_clients.erase(client)
		print("[NetworkControllerServer] Mobile pilot %s disconnected." % cs)
		pilot_disconnected.emit(cs, pid)
		
	# 3. 10Hz Reverse Telemetry Broadcast (Phone Instrument HUD)
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
		var cs = data.get("callsign", "WINGMAN-2").strip_edges().to_upper()
		if cs.is_empty(): cs = "WINGMAN-2"
		client["callsign"] = cs
		var pid = client.get("player_id", 2)
		print(">>> [NetworkControllerServer] Mobile Pilot '%s' commissioned as Player %d!" % [cs, pid])
		pilot_connected.emit(cs, pid)
		return
		
	# Flight telemetry frame
	var pid = client.get("player_id", 2)
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
