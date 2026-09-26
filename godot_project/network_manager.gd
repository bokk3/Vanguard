extends Node

## NetworkManager: Autoload singleton managing ENet listen-server/client sessions
## and UDP LAN auto-discovery beacons for Project Vanguard PvP dogfights.

signal lan_server_found(server_info: Dictionary)
signal lan_server_lost(server_ip: String)
signal server_created()
signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal connected_to_server()
signal connection_failed()
signal disconnected_from_server()

signal party_updated(parties: Dictionary)
signal network_stats_updated(registered_count: int, online_count: int, lobby_count: int)

const DEFAULT_GAME_PORT: int = 7777
const DEFAULT_BEACON_PORT: int = 7778
const BEACON_INTERVAL: float = 1.0
const BEACON_MAGIC: String = "VANGUARD_PVP_BEACON"
const CLOUD_NETWORK_API: String = "https://project-vanguard.pages.dev/api/network"

var peer: ENetMultiplayerPeer = null
var udp_broadcaster: PacketPeerUDP = null
var udp_listener: PacketPeerUDP = null

var is_host: bool = false
var is_searching_lan: bool = false
var beacon_timer: float = 0.0

var server_name: String = "VANGUARD ARENA"
var player_callsign: String = "Vanguard-1"
var current_map_name: String = "Dusk Canyon"

# Fleet Operations Presence & Telemetry
var registered_pilots: int = 1420
var online_pilots: int = 1
var active_lobbies: int = 0
var remote_lobbies: Array[Dictionary] = []

var client_session_id: String = ""
var session_type: String = "PILOT" # "PILOT" or "LOBBY"
var stats_http: HTTPRequest = null
var heartbeat_http: HTTPRequest = null
var leave_http: HTTPRequest = null
var heartbeat_timer: float = 0.0
var stats_poll_timer: float = 0.0
const HEARTBEAT_INTERVAL: float = 25.0
const STATS_POLL_INTERVAL: float = 20.0

var parties: Dictionary = {
	"Alpha": { "name": "Squadron Alpha", "pilot_callsign": "LEAD", "pilot_input": "AZERTY", "crew": [] },
	"Bravo": { "name": "Squadron Bravo", "pilot_callsign": "EMPTY", "pilot_input": "AZERTY", "crew": [] }
}
var my_party: String = "Alpha"
var my_role: String = "pilot"
var my_input: String = "AZERTY"

var discovered_servers: Dictionary = {} # IP -> { "name": ..., "port": ..., "last_seen": ..., ... }

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_init_network_presence()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		send_leave()

func _init_network_presence() -> void:
	client_session_id = "vng-client-" + str(randi() % 900000 + 100000)
	
	stats_http = HTTPRequest.new()
	stats_http.timeout = 5.0
	stats_http.name = "StatsHTTP"
	add_child(stats_http)
	stats_http.request_completed.connect(_on_stats_request_completed)
	
	heartbeat_http = HTTPRequest.new()
	heartbeat_http.timeout = 5.0
	heartbeat_http.name = "HeartbeatHTTP"
	add_child(heartbeat_http)
	
	leave_http = HTTPRequest.new()
	leave_http.timeout = 3.0
	leave_http.name = "LeaveHTTP"
	add_child(leave_http)
	
	fetch_network_stats()
	send_heartbeat()

func fetch_network_stats() -> void:
	if not stats_http or not is_inside_tree():
		return
	if stats_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	stats_http.request(CLOUD_NETWORK_API + "/stats")

func _on_stats_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code >= 200 and response_code < 300:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK and typeof(json.data) == TYPE_DICTIONARY:
			var data: Dictionary = json.data
			if data.get("success", false):
				registered_pilots = int(data.get("registered_pilots", registered_pilots))
				online_pilots = int(data.get("online_pilots", online_pilots))
				active_lobbies = int(data.get("active_lobbies", active_lobbies))
				if data.has("lobbies") and typeof(data["lobbies"]) == TYPE_ARRAY:
					remote_lobbies.clear()
					for l in data["lobbies"]:
						if typeof(l) == TYPE_DICTIONARY:
							remote_lobbies.append(l)
				network_stats_updated.emit(registered_pilots, online_pilots, active_lobbies)

func send_heartbeat() -> void:
	if not heartbeat_http or not is_inside_tree():
		return
	if heartbeat_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var auth_mgr = get_node_or_null("/root/AuthManager")
	var cs = auth_mgr.callsign if (auth_mgr and auth_mgr.is_authenticated and not auth_mgr.callsign.is_empty()) else player_callsign
	var pid = auth_mgr.pilot_id if auth_mgr else ""
	var peer_count = 1
	if multiplayer and multiplayer.has_multiplayer_peer() and is_host:
		peer_count = multiplayer.get_peers().size() + 1
	var meta = {
		"lobby_name": server_name,
		"players": peer_count,
		"max_players": 2,
		"map": current_map_name
	}
	var payload = {
		"session_id": client_session_id,
		"callsign": cs,
		"pilot_id": pid,
		"session_type": session_type,
		"metadata": meta
	}
	var headers = ["Content-Type: application/json"]
	heartbeat_http.request(CLOUD_NETWORK_API + "/heartbeat", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))

func send_leave() -> void:
	if not leave_http or not is_inside_tree() or client_session_id.is_empty():
		return
	var payload = { "session_id": client_session_id }
	var headers = ["Content-Type: application/json"]
	leave_http.request(CLOUD_NETWORK_API + "/leave", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))

func _process(delta: float) -> void:
	# Fleet Operations Periodic Telemetry
	stats_poll_timer += delta
	if stats_poll_timer >= STATS_POLL_INTERVAL:
		stats_poll_timer = 0.0
		fetch_network_stats()

	heartbeat_timer += delta
	if heartbeat_timer >= HEARTBEAT_INTERVAL:
		heartbeat_timer = 0.0
		send_heartbeat()

	# 1. Host Beacon Broadcasting
	if is_host and udp_broadcaster != null:
		beacon_timer -= delta
		if beacon_timer <= 0.0:
			beacon_timer = BEACON_INTERVAL
			_send_lan_beacon()

	# 2. Client LAN Discovery Listening
	if is_searching_lan and udp_listener != null:
		_poll_lan_beacons(delta)

# -----------------------------------------------------------------------------
# Host / Server Initialization
# -----------------------------------------------------------------------------
func host_game(host_server_name: String = "VANGUARD ARENA", port: int = DEFAULT_GAME_PORT, max_clients: int = 1) -> Error:
	stop_network()
	
	server_name = host_server_name
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, max_clients)
	if err != OK:
		push_error("[NetworkManager] Failed to create ENet server on port %d: Error %d" % [port, err])
		peer = null
		return err
	
	multiplayer.multiplayer_peer = peer
	is_host = true
	session_type = "LOBBY"
	send_heartbeat()
	
	# Start UDP Broadcaster
	udp_broadcaster = PacketPeerUDP.new()
	udp_broadcaster.set_broadcast_enabled(true)
	beacon_timer = 0.0 # Fire immediate beacon
	
	print("[NetworkManager] ENet listen server active on port %d. Broadcasting LAN beacons on port %d..." % [port, DEFAULT_BEACON_PORT])
	server_created.emit()
	return OK

# -----------------------------------------------------------------------------
# Client Connection
# -----------------------------------------------------------------------------
func join_game(ip: String, port: int = DEFAULT_GAME_PORT) -> Error:
	stop_network()
	
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		push_error("[NetworkManager] Failed to create ENet client for %s:%d: Error %d" % [ip, port, err])
		peer = null
		return err
	
	multiplayer.multiplayer_peer = peer
	is_host = false
	print("[NetworkManager] Connecting to host at %s:%d..." % [ip, port])
	return OK

# -----------------------------------------------------------------------------
# LAN Auto-Discovery
# -----------------------------------------------------------------------------
func start_lan_discovery() -> void:
	if is_searching_lan:
		return
	discovered_servers.clear()
	is_searching_lan = true
	
	udp_listener = PacketPeerUDP.new()
	var err = udp_listener.bind(DEFAULT_BEACON_PORT, "*")
	if err != OK:
		print("[NetworkManager] Warning: Failed to bind UDP listener to port %d (Error %d)" % [DEFAULT_BEACON_PORT, err])
	else:
		print("[NetworkManager] LAN discovery active on port %d." % DEFAULT_BEACON_PORT)

func stop_lan_discovery() -> void:
	is_searching_lan = false
	if udp_listener:
		udp_listener.close()
		udp_listener = null

func _send_lan_beacon() -> void:
	if not udp_broadcaster:
		return
	
	var data = {
		"magic": BEACON_MAGIC,
		"server_name": server_name,
		"port": DEFAULT_GAME_PORT,
		"host_callsign": player_callsign,
		"map": current_map_name,
		"players": multiplayer.get_peers().size() + 1,
		"max_players": 2,
		"timestamp": Time.get_ticks_msec()
	}
	var json_str = JSON.stringify(data)
	var pkt = json_str.to_utf8_buffer()
	
	udp_broadcaster.set_dest_address("255.255.255.255", DEFAULT_BEACON_PORT)
	udp_broadcaster.put_packet(pkt)

func _poll_lan_beacons(delta: float) -> void:
	if not udp_listener:
		return
	
	while udp_listener.get_available_packet_count() > 0:
		var pkt = udp_listener.get_packet()
		var sender_ip = udp_listener.get_packet_ip()
		var sender_port = udp_listener.get_packet_port()
		
		var json_str = pkt.get_string_from_utf8()
		var parsed = JSON.parse_string(json_str)
		if parsed is Dictionary and parsed.get("magic") == BEACON_MAGIC:
			var s_name = parsed.get("server_name", "UNKNOWN LOBBY")
			var game_port = int(parsed.get("port", DEFAULT_GAME_PORT))
			var server_id = "%s:%d" % [sender_ip, game_port]
			
			var server_info = {
				"id": server_id,
				"ip": sender_ip,
				"port": game_port,
				"server_name": s_name,
				"host_callsign": parsed.get("host_callsign", "Host"),
				"map": parsed.get("map", "Dusk Canyon"),
				"players": int(parsed.get("players", 1)),
				"max_players": int(parsed.get("max_players", 2)),
				"last_seen": Time.get_ticks_msec()
			}
			
			discovered_servers[server_id] = server_info
			lan_server_found.emit(server_info)
	
	# Prune stale lobbies (older than 4 seconds)
	var cur_time = Time.get_ticks_msec()
	var to_remove = []
	for sid in discovered_servers:
		if cur_time - discovered_servers[sid]["last_seen"] > 4000:
			to_remove.append(sid)
	for sid in to_remove:
		discovered_servers.erase(sid)
		lan_server_lost.emit(sid)

# -----------------------------------------------------------------------------
# Clean Disconnect
# -----------------------------------------------------------------------------
func stop_network() -> void:
	stop_lan_discovery()
	if udp_broadcaster:
		udp_broadcaster.close()
		udp_broadcaster = null
	if peer:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	is_host = false
	if session_type == "LOBBY":
		session_type = "PILOT"
		send_heartbeat()
	print("[NetworkManager] Network session stopped.")

# -----------------------------------------------------------------------------
# Multiplayer Callbacks
# -----------------------------------------------------------------------------
func _on_peer_connected(id: int) -> void:
	print("[NetworkManager] Peer connected: ID ", id)
	peer_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("[NetworkManager] Peer disconnected: ID ", id)
	peer_disconnected.emit(id)

func _on_connected_to_server() -> void:
	print("[NetworkManager] Successfully connected to host server!")
	connected_to_server.emit()

func _on_connection_failed() -> void:
	print("[NetworkManager] Connection to host server failed.")
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("[NetworkManager] Disconnected from host server.")
	disconnected_from_server.emit()

# -----------------------------------------------------------------------------
# Squadron Party & Main Pilot Management
# -----------------------------------------------------------------------------
func set_my_party_role(party_name: String, role: String, input_mode: String = "") -> void:
	my_party = party_name
	my_role = role
	if not input_mode.is_empty():
		my_input = input_mode
		
	var pid = multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1
	if multiplayer and multiplayer.has_multiplayer_peer():
		rpc("rpc_update_party_member", pid, my_party, my_role, player_callsign, my_input)
	else:
		_local_update_party(pid, my_party, my_role, player_callsign, my_input)

func _local_update_party(peer_id: int, p_name: String, role: String, cs: String, input_mode: String) -> void:
	if not parties.has(p_name):
		return
	if role == "pilot":
		parties[p_name]["pilot_callsign"] = cs
		parties[p_name]["pilot_input"] = input_mode
		parties[p_name]["pilot_peer"] = peer_id
	else:
		var crew: Array = parties[p_name].get("crew", [])
		if not crew.has(cs):
			crew.append(cs)
		parties[p_name]["crew"] = crew
	party_updated.emit(parties)

@rpc("any_peer", "call_local", "reliable")
func rpc_update_party_member(peer_id: int, p_name: String, role: String, cs: String, input_mode: String) -> void:
	_local_update_party(peer_id, p_name, role, cs, input_mode)

