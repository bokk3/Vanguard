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

const DEFAULT_GAME_PORT: int = 7777
const DEFAULT_BEACON_PORT: int = 7778
const BEACON_INTERVAL: float = 1.0
const BEACON_MAGIC: String = "VANGUARD_PVP_BEACON"

var peer: ENetMultiplayerPeer = null
var udp_broadcaster: PacketPeerUDP = null
var udp_listener: PacketPeerUDP = null

var is_host: bool = false
var is_searching_lan: bool = false
var beacon_timer: float = 0.0

var server_name: String = "VANGUARD ARENA"
var player_callsign: String = "Vanguard-1"
var current_map_name: String = "Dusk Canyon"

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

func _process(delta: float) -> void:
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

