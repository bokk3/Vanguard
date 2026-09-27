extends Control

## PvPMenu: Main Portal for Project Vanguard PvP dogfights.
## Features Squadron Parties (Alpha vs Bravo), Main Pilot designation,
## input selection (AZERTY / QWERTY / Phone HOTAS), Split-Screen, LAN matchmaking,
## and Global Internet P2P Lobby Directory with real-time latency probing and UPnP.

const LoginDialogScene = preload("res://login_dialog.tscn")

@onready var split_screen_btn: Button = %SplitScreenBtn
@onready var back_btn: Button = %BackBtn
@onready var status_label: Label = %StatusLabel
@onready var fleet_telemetry_label: Label = %FleetTelemetryLabel

# Tab Buttons
@onready var split_tab_btn: Button = %SplitTabBtn
@onready var lan_tab_btn: Button = %LanTabBtn
@onready var global_tab_btn: Button = %GlobalTabBtn
@onready var split_section: Control = %SplitSection
@onready var lan_section: Control = %LanSection
@onready var global_section: Control = %GlobalSection

# LAN Controls
@onready var host_btn: Button = %HostBtn
@onready var server_name_input: LineEdit = %ServerNameInput
@onready var callsign_input: LineEdit = %CallsignInput
@onready var refresh_lan_btn: Button = %RefreshLanBtn
@onready var server_list_container: VBoxContainer = %ServerListContainer
@onready var no_servers_label: Label = %NoServersLabel
@onready var direct_ip_input: LineEdit = %DirectIpInput
@onready var direct_connect_btn: Button = %DirectConnectBtn

# Global P2P Controls
@onready var global_auth_prompt: Control = %GlobalAuthPrompt
@onready var global_login_btn: Button = %GlobalLoginBtn
@onready var global_lobby_view: Control = %GlobalLobbyView
@onready var global_pilot_label: Label = %GlobalPilotLabel
@onready var upnp_status_label: Label = %UpnpStatusLabel
@onready var global_server_name_input: LineEdit = %GlobalServerNameInput
@onready var publish_global_check: CheckBox = %PublishGlobalCheck
@onready var global_host_btn: Button = %GlobalHostBtn
@onready var refresh_global_btn: Button = %RefreshGlobalBtn
@onready var global_lobby_list_container: VBoxContainer = %GlobalLobbyListContainer
@onready var no_global_lobbies_label: Label = %NoGlobalLobbiesLabel
@onready var global_direct_ip_input: LineEdit = %GlobalDirectIpInput
@onready var global_direct_connect_btn: Button = %GlobalDirectConnectBtn

# Host Waiting Modal
@onready var host_waiting_modal: Control = %HostWaitingModal
@onready var lobby_title: Label = %LobbyTitle
@onready var waiting_label: Label = %WaitingLabel
@onready var upnp_host_modal_label: Label = %UpnpHostModalLabel
@onready var cancel_host_btn: Button = %CancelHostBtn

# Parties & Roles
@onready var alpha_pilot_label: Label = %AlphaPilotLabel
@onready var alpha_input_btn: Button = %AlphaInputBtn
@onready var alpha_claim_pilot_btn: Button = %AlphaClaimPilotBtn
@onready var alpha_crew_label: Label = %AlphaCrewLabel
@onready var alpha_join_crew_btn: Button = %AlphaJoinCrewBtn

@onready var bravo_pilot_label: Label = %BravoPilotLabel
@onready var bravo_input_btn: Button = %BravoInputBtn
@onready var bravo_claim_pilot_btn: Button = %BravoClaimPilotBtn
@onready var bravo_crew_label: Label = %BravoCrewLabel
@onready var bravo_join_crew_btn: Button = %BravoJoinCrewBtn

@onready var pair_phone_lobby_btn: Button = %PairPhoneLobbyBtn
@onready var launch_arena_btn: Button = %LaunchArenaBtn

var network_manager: Node = null
var qr_dialog: Control = null
var login_dialog_instance: Control = null
var current_tab: String = "LAN" # "LAN" or "GLOBAL"

# Stored references to lobby latency UI labels: session_id -> Label
var latency_labels: Dictionary = {}

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	network_manager = get_node_or_null("/root/NetworkManager")
	if network_manager:
		if not network_manager.network_stats_updated.is_connected(_on_network_stats_updated):
			network_manager.network_stats_updated.connect(_on_network_stats_updated)
		if not network_manager.global_lobbies_updated.is_connected(_on_global_lobbies_updated):
			network_manager.global_lobbies_updated.connect(_on_global_lobbies_updated)
		if not network_manager.lobby_ping_updated.is_connected(_on_lobby_ping_updated):
			network_manager.lobby_ping_updated.connect(_on_lobby_ping_updated)
		if not network_manager.upnp_status_changed.is_connected(_on_upnp_status_changed):
			network_manager.upnp_status_changed.connect(_on_upnp_status_changed)
			
		_update_fleet_telemetry(network_manager.registered_pilots, network_manager.online_pilots, network_manager.active_lobbies)
	
	# Connect General Navigation
	if split_screen_btn:
		split_screen_btn.pressed.connect(_on_split_screen_pressed)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if cancel_host_btn:
		cancel_host_btn.pressed.connect(_on_cancel_host_pressed)
	if launch_arena_btn:
		launch_arena_btn.pressed.connect(_on_launch_arena_pressed)
	if pair_phone_lobby_btn:
		pair_phone_lobby_btn.pressed.connect(_on_pair_phone_lobby_pressed)
		
	# Connect Mode Tabs
	if split_tab_btn:
		split_tab_btn.pressed.connect(func(): _switch_tab("SPLIT"))
	if lan_tab_btn:
		lan_tab_btn.pressed.connect(func(): _switch_tab("LAN"))
	if global_tab_btn:
		global_tab_btn.pressed.connect(func(): _switch_tab("GLOBAL"))
		
	# Connect LAN Controls
	if host_btn:
		host_btn.pressed.connect(_on_host_pressed)
	if direct_connect_btn:
		direct_connect_btn.pressed.connect(_on_direct_connect_pressed)
	if refresh_lan_btn:
		refresh_lan_btn.pressed.connect(_on_refresh_lan_pressed)
		
	# Connect Global Controls
	if global_login_btn:
		global_login_btn.pressed.connect(_on_global_login_pressed)
	if global_host_btn:
		global_host_btn.pressed.connect(_on_global_host_pressed)
	if refresh_global_btn:
		refresh_global_btn.pressed.connect(_on_refresh_global_pressed)
	if global_direct_connect_btn:
		global_direct_connect_btn.pressed.connect(_on_global_direct_connect_pressed)
		
	# Party buttons
	if alpha_input_btn:
		alpha_input_btn.pressed.connect(func(): _cycle_input_mode("Alpha"))
	if bravo_input_btn:
		bravo_input_btn.pressed.connect(func(): _cycle_input_mode("Bravo"))
	if alpha_claim_pilot_btn:
		alpha_claim_pilot_btn.pressed.connect(func(): _claim_pilot_seat("Alpha"))
	if bravo_claim_pilot_btn:
		bravo_claim_pilot_btn.pressed.connect(func(): _claim_pilot_seat("Bravo"))
	if alpha_join_crew_btn:
		alpha_join_crew_btn.pressed.connect(func(): _join_crew("Alpha"))
	if bravo_join_crew_btn:
		bravo_join_crew_btn.pressed.connect(func(): _join_crew("Bravo"))
	
	if host_waiting_modal:
		host_waiting_modal.hide()
	
	# Pre-fill callsign from AuthManager
	var auth_mgr = get_node_or_null("/root/AuthManager")
	if auth_mgr:
		if not auth_mgr.auth_success.is_connected(_on_auth_success):
			auth_mgr.auth_success.connect(_on_auth_success)
		if not auth_mgr.logged_out.is_connected(_on_logged_out):
			auth_mgr.logged_out.connect(_on_logged_out)
			
		if not auth_mgr.callsign.is_empty():
			if callsign_input:
				callsign_input.text = auth_mgr.callsign
			if network_manager:
				network_manager.player_callsign = auth_mgr.callsign

	if network_manager:
		network_manager.lan_server_found.connect(_on_lan_server_found)
		network_manager.lan_server_lost.connect(_on_lan_server_lost)
		network_manager.peer_connected.connect(_on_peer_connected)
		network_manager.peer_disconnected.connect(_on_peer_disconnected)
		network_manager.connected_to_server.connect(_on_connected_to_server)
		network_manager.connection_failed.connect(_on_connection_failed)
		if not network_manager.party_updated.is_connected(_on_party_updated):
			network_manager.party_updated.connect(_on_party_updated)
		network_manager.start_lan_discovery()
	
	_switch_tab("LAN")
	_update_server_list()
	_update_party_deck()
	_set_status("READY // SELECT COMBAT SORTIE MODE")

func _exit_tree() -> void:
	if network_manager and not network_manager.is_host:
		network_manager.stop_lan_discovery()

# -----------------------------------------------------------------------------
# Mode Tabs (Split-Screen vs LAN vs Global Internet P2P)
# -----------------------------------------------------------------------------
func _switch_tab(tab_name: String) -> void:
	current_tab = tab_name
	if split_section: split_section.visible = (tab_name == "SPLIT")
	if lan_section: lan_section.visible = (tab_name == "LAN")
	if global_section: global_section.visible = (tab_name == "GLOBAL")
	
	_style_tab_btn(split_tab_btn, tab_name == "SPLIT")
	_style_tab_btn(lan_tab_btn, tab_name == "LAN")
	_style_tab_btn(global_tab_btn, tab_name == "GLOBAL")
	
	match tab_name:
		"SPLIT":
			_set_status("LOCAL SPLIT-SCREEN MODE // SAME DEVICE • 2 PLAYERS • NO NETWORK REQUIRED")
		"LAN":
			_set_status("LOCAL LAN MODE // DISCOVERING SUBNET BEACONS ON PORT 7778 (NO INTERNET NEEDED)")
		"GLOBAL":
			_update_global_tab_view()

func _style_tab_btn(btn: Button, active: bool) -> void:
	if not btn:
		return
	if active:
		btn.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		btn.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
		btn.modulate = Color(0.75, 0.75, 0.75, 0.8)

func _update_global_tab_view() -> void:
	var auth_mgr = get_node_or_null("/root/AuthManager")
	var is_auth = (auth_mgr != null and auth_mgr.is_authenticated)
	
	if global_auth_prompt:
		global_auth_prompt.visible = not is_auth
	if global_lobby_view:
		global_lobby_view.visible = is_auth
		
	if is_auth:
		if global_pilot_label:
			global_pilot_label.text = "🎖️ PILOT: %s [%s] // %s" % [
				auth_mgr.callsign,
				auth_mgr.rank,
				auth_mgr.squadron
			]
		if upnp_status_label and network_manager:
			upnp_status_label.text = "UPNP: %s" % network_manager.upnp_status
		_set_status("GLOBAL FLEET RADAR ACTIVE // POLLING P2P LOBBIES...")
		if network_manager:
			network_manager.fetch_global_lobbies()
	else:
		_set_status("GLOBAL SORTIES REQUIRE COMMISSIONED PILOT CALLSIGN", Color(1.0, 0.8, 0.2))

func _on_auth_success(_profile: Dictionary) -> void:
	if current_tab == "GLOBAL":
		_update_global_tab_view()

func _on_logged_out() -> void:
	if current_tab == "GLOBAL":
		_update_global_tab_view()

func _on_global_login_pressed() -> void:
	if login_dialog_instance and is_instance_valid(login_dialog_instance):
		login_dialog_instance.show()
		return
	
	if LoginDialogScene:
		login_dialog_instance = LoginDialogScene.instantiate()
		add_child(login_dialog_instance)
		var auth_mgr = get_node_or_null("/root/AuthManager")
		if auth_mgr and not auth_mgr.auth_success.is_connected(_on_login_dialog_authenticated):
			auth_mgr.auth_success.connect(_on_login_dialog_authenticated)

func _on_login_dialog_authenticated(_profile: Dictionary) -> void:
	_update_global_tab_view()

# -----------------------------------------------------------------------------
# Split-Screen Launch
# -----------------------------------------------------------------------------
func _on_split_screen_pressed() -> void:
	_set_status("LAUNCHING LOCAL SPLIT-SCREEN ARENA...")
	if network_manager:
		network_manager.stop_network()
	get_tree().change_scene_to_file("res://split_screen_arena.tscn")

# -----------------------------------------------------------------------------
# LAN Hosting & Connection
# -----------------------------------------------------------------------------
func _on_host_pressed() -> void:
	if not network_manager:
		_set_status("ERROR: NETWORK SUBSYSTEM UNAVAILABLE", Color(1.0, 0.25, 0.2))
		return
	
	var s_name = server_name_input.text.strip_edges()
	if s_name.is_empty():
		s_name = "VANGUARD COMBAT LOBBY"
	
	var c_sign = callsign_input.text.strip_edges()
	if not c_sign.is_empty():
		network_manager.player_callsign = c_sign
		
	var err = network_manager.host_game(s_name, 7777, 4, false)
	if err == OK:
		_set_status("LISTEN SERVER ACTIVE // BROADCASTING ON SUBNET", Color(0.1, 0.95, 0.4))
		if lobby_title:
			lobby_title.text = "📡 LOCAL LAN LOBBY: '%s'" % s_name
		if waiting_label:
			waiting_label.text = "LISTEN SERVER ACTIVE // SUBNET BROADCAST ACTIVE // WAITING FOR SQUADRON..."
		if upnp_host_modal_label:
			upnp_host_modal_label.text = "MODE: LOCAL SUBNET BROADCAST (PORT 7777 UDP) // NO UPNP NEEDED"
			upnp_host_modal_label.modulate = Color(0.2, 0.95, 0.5)
		_update_launch_button_state()
		if host_waiting_modal:
			host_waiting_modal.show()
			
		var cfg = get_node_or_null("/root/ConfigManager")
		var is_az = cfg.is_azerty if cfg else false
		network_manager.set_my_party_role("Alpha", "pilot", "AZERTY" if is_az else "QWERTY")
		_update_party_deck()
	else:
		_set_status("ERROR CREATING SERVER (CODE %d)" % err, Color(1.0, 0.25, 0.2))

func _on_direct_connect_pressed() -> void:
	_connect_to_endpoint(direct_ip_input.text.strip_edges(), callsign_input.text.strip_edges())

func _on_refresh_lan_pressed() -> void:
	if network_manager:
		network_manager.stop_lan_discovery()
		network_manager.start_lan_discovery()
		_update_server_list()
		_set_status("SCANNING SUBNET BROADCASTS ON PORT 7778...")

# -----------------------------------------------------------------------------
# Global Internet P2P Hosting & Connection
# -----------------------------------------------------------------------------
func _on_global_host_pressed() -> void:
	if not network_manager:
		_set_status("ERROR: NETWORK SUBSYSTEM UNAVAILABLE", Color(1.0, 0.25, 0.2))
		return
		
	var auth_mgr = get_node_or_null("/root/AuthManager")
	if not auth_mgr or not auth_mgr.is_authenticated:
		_set_status("PILOT CREDENTIALS REQUIRED TO PUBLISH GLOBAL LOBBY", Color(1.0, 0.8, 0.2))
		_on_global_login_pressed()
		return
		
	var s_name = global_server_name_input.text.strip_edges()
	if s_name.is_empty():
		s_name = "%s's COMBAT LOBBY" % auth_mgr.callsign
		
	var is_public = publish_global_check.button_pressed if publish_global_check else true
	network_manager.player_callsign = auth_mgr.callsign
	
	var err = network_manager.host_game(s_name, 7777, 4, is_public)
	if err == OK:
		_set_status("GLOBAL P2P LISTEN SERVER ACTIVE // BROADCASTING ON FLEET RADAR", Color(0.1, 0.95, 0.4))
		if lobby_title:
			lobby_title.text = "🌐 PUBLIC INTERNET LOBBY: '%s'" % s_name
		if waiting_label:
			waiting_label.text = "WAITING FOR CHALLENGERS ACROSS THE GLOBE TO INITIATE P2P CONNECTION..."
		if upnp_host_modal_label:
			upnp_host_modal_label.text = "ROUTER STATUS: %s" % network_manager.upnp_status
			upnp_host_modal_label.modulate = Color(0.2, 0.95, 0.5) if (network_manager and "ACTIVE" in network_manager.upnp_status) else Color(0.85, 0.8, 0.2)
		_update_launch_button_state()
		if host_waiting_modal:
			host_waiting_modal.show()
			
		var cfg = get_node_or_null("/root/ConfigManager")
		var is_az = cfg.is_azerty if cfg else false
		network_manager.set_my_party_role("Alpha", "pilot", "AZERTY" if is_az else "QWERTY")
		_update_party_deck()
	else:
		_set_status("ERROR CREATING SERVER (CODE %d)" % err, Color(1.0, 0.25, 0.2))

func _on_refresh_global_pressed() -> void:
	if network_manager:
		_set_status("QUERYING CLOUDFLARE FLEET RADAR FOR ACTIVE INTERNET LOBBIES...")
		network_manager.fetch_global_lobbies()

func _on_global_direct_connect_pressed() -> void:
	var auth_mgr = get_node_or_null("/root/AuthManager")
	var cs = auth_mgr.callsign if (auth_mgr and auth_mgr.is_authenticated) else "Vanguard-2"
	_connect_to_endpoint(global_direct_ip_input.text.strip_edges(), cs)

func _connect_to_endpoint(target_ip: String, c_sign: String) -> void:
	if not network_manager:
		return
	if target_ip.is_empty():
		target_ip = "127.0.0.1"
		
	var port = 7777
	if target_ip.begins_with("[") and "]:" in target_ip:
		var parts = target_ip.split("]:")
		target_ip = parts[0].trim_prefix("[")
		port = int(parts[1])
	elif ":" in target_ip and target_ip.count(":") == 1:
		var parts = target_ip.split(":")
		target_ip = parts[0]
		port = int(parts[1])
		
	if not c_sign.is_empty():
		network_manager.player_callsign = c_sign
		
	_set_status("INITIATING P2P DIRECT CONNECTION TO %s:%d..." % [target_ip, port], Color(1.0, 0.85, 0.1))
	var err = network_manager.join_game(target_ip, port)
	if err != OK:
		_set_status("CONNECT FAILED (CODE %d)" % err, Color(1.0, 0.25, 0.2))

func _on_cancel_host_pressed() -> void:
	if network_manager:
		network_manager.stop_network()
		network_manager.start_lan_discovery()
	if host_waiting_modal:
		host_waiting_modal.hide()
	_set_status("HOSTING CANCELLED // READY")

# -----------------------------------------------------------------------------
# UPnP Subsystem Callbacks
# -----------------------------------------------------------------------------
func _on_upnp_status_changed(status_text: String, is_active: bool) -> void:
	if upnp_status_label:
		upnp_status_label.text = "UPNP: %s" % status_text
		upnp_status_label.modulate = Color(0.2, 0.95, 0.5) if is_active else Color(0.85, 0.8, 0.2)
	if upnp_host_modal_label and host_waiting_modal and host_waiting_modal.visible:
		upnp_host_modal_label.text = "ROUTER: %s" % status_text
		upnp_host_modal_label.modulate = Color(0.2, 0.95, 0.5) if is_active else Color(0.85, 0.8, 0.2)

# -----------------------------------------------------------------------------
# Global Lobbies Rendering & Live Latency Display
# -----------------------------------------------------------------------------
func _on_global_lobbies_updated(lobbies: Array) -> void:
	if not global_lobby_list_container:
		return
	
	latency_labels.clear()
	for child in global_lobby_list_container.get_children():
		if child == no_global_lobbies_label:
			continue
		child.queue_free()
		
	if lobbies.is_empty():
		if no_global_lobbies_label:
			no_global_lobbies_label.show()
		return
		
	if no_global_lobbies_label:
		no_global_lobbies_label.hide()
		
	for lobby in lobbies:
		var s_id = lobby.get("session_id", "")
		var item = PanelContainer.new()
		var item_style = StyleBoxFlat.new()
		item_style.bg_color = Color(0.04, 0.08, 0.14, 0.88)
		item_style.border_width_bottom = 1
		item_style.border_color = Color(0.0, 0.8, 1.0, 0.35)
		item.add_theme_stylebox_override("panel", item_style)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		item.add_child(hbox)
		
		# Main Info Label
		var lbl = Label.new()
		var host_cs = lobby.get("host_callsign", "HOST")
		var l_name = lobby.get("lobby_name", "VANGUARD SORTIE")
		var cur_p = int(lobby.get("players", 1))
		var max_p = int(lobby.get("max_players", 4))
		var map_name = lobby.get("map", "Dusk Canyon")
		var country = lobby.get("country", "GLOBAL")
		var colo = lobby.get("colo", "")
		var loc = "[ 🌍 %s%s ]" % [country, ("/" + colo) if not colo.is_empty() else ""]
		
		lbl.text = "◈ %s  |  HOST: %s  |  %s  |  %s  |  %d/%d" % [
			l_name, host_cs, loc, map_name, cur_p, max_p
		]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
		lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(lbl)
		
		# Real-Time Latency Badge
		var lat_label = Label.new()
		lat_label.custom_minimum_size = Vector2(70, 0)
		lat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lat_label.add_theme_font_size_override("font_size", 11)
		
		var cached_ping = network_manager.lobby_latencies.get(s_id, null) if network_manager else null
		if cached_ping != null:
			_style_latency_label(lat_label, int(cached_ping))
		else:
			lat_label.text = "[ PINGING ]"
			lat_label.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0, 0.7))
		
		latency_labels[s_id] = lat_label
		hbox.add_child(lat_label)
		
		# Join P2P Button
		var join_btn = Button.new()
		join_btn.text = "[ ENGAGE (P2P) ]"
		join_btn.custom_minimum_size = Vector2(110, 28)
		var h_ip = lobby.get("host_ip", "")
		var g_port = int(lobby.get("game_port", 7777))
		join_btn.pressed.connect(func():
			_set_status("JOINING P2P LOBBY '%s' (%s:%d)..." % [l_name, h_ip, g_port], Color(1.0, 0.85, 0.1))
			var auth_mgr = get_node_or_null("/root/AuthManager")
			var cs = auth_mgr.callsign if (auth_mgr and auth_mgr.is_authenticated) else "Vanguard-2"
			network_manager.player_callsign = cs
			network_manager.join_game(h_ip, g_port)
		)
		hbox.add_child(join_btn)
		
		global_lobby_list_container.add_child(item)

func _on_lobby_ping_updated(session_id: String, ping_ms: int) -> void:
	if latency_labels.has(session_id):
		var lbl = latency_labels[session_id]
		if is_instance_valid(lbl):
			_style_latency_label(lbl, ping_ms)

func _style_latency_label(lbl: Label, ping_ms: int) -> void:
	if ping_ms >= 0:
		lbl.text = "[ %d ms ]" % ping_ms
		if ping_ms < 60:
			lbl.add_theme_color_override("font_color", Color(0.2, 0.95, 0.5)) # Emerald Green
		elif ping_ms < 120:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2)) # Yellow
		else:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2)) # Orange
	else:
		lbl.text = "[ TIMEOUT ]"
		lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 0.7))

# -----------------------------------------------------------------------------
# LAN List Rendering
# -----------------------------------------------------------------------------
func _on_lan_server_found(_info: Dictionary) -> void:
	_update_server_list()

func _on_lan_server_lost(_sid: String) -> void:
	_update_server_list()

func _update_server_list() -> void:
	if not server_list_container:
		return
		
	for child in server_list_container.get_children():
		child.queue_free()
		
	var servers = network_manager.discovered_servers if network_manager else {}
	if servers.is_empty():
		if no_servers_label:
			no_servers_label.show()
		return
		
	if no_servers_label:
		no_servers_label.hide()
		
	for sid in servers:
		var info = servers[sid]
		var item = PanelContainer.new()
		var item_style = StyleBoxFlat.new()
		item_style.bg_color = Color(0.06, 0.10, 0.16, 0.85)
		item_style.border_width_bottom = 1
		item_style.border_color = Color(0.0, 0.8, 1.0, 0.4)
		item.add_theme_stylebox_override("panel", item_style)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		item.add_child(hbox)
		
		var lbl = Label.new()
		lbl.text = "◈ %s  |  HOST: %s  |  %s:%d  |  %d/%d" % [
			info["server_name"],
			info["host_callsign"],
			info["ip"],
			info["port"],
			info["players"],
			info["max_players"]
		]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
		lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(lbl)
		
		var join_btn = Button.new()
		join_btn.text = "[ ENGAGE ]"
		join_btn.custom_minimum_size = Vector2(100, 28)
		join_btn.pressed.connect(func():
			_set_status("CONNECTING TO %s..." % info["server_name"], Color(1.0, 0.85, 0.1))
			var c_sign = callsign_input.text.strip_edges()
			if not c_sign.is_empty():
				network_manager.player_callsign = c_sign
			network_manager.join_game(info["ip"], info["port"])
		)
		hbox.add_child(join_btn)
		
		server_list_container.add_child(item)

# -----------------------------------------------------------------------------
# Multiplayer Callbacks & Party Deck
# -----------------------------------------------------------------------------
func _update_launch_button_state() -> void:
	if not launch_arena_btn:
		return
	if not network_manager or not network_manager.is_host:
		launch_arena_btn.disabled = true
		launch_arena_btn.text = "🔒 [ AWAITING HOST LAUNCH COMMAND ]"
		launch_arena_btn.modulate = Color(0.7, 0.7, 0.7, 0.6)
		return
		
	var peer_count = 0
	if network_manager and not network_manager.connected_peers.is_empty():
		peer_count = network_manager.connected_peers.size()
	elif multiplayer and multiplayer.has_multiplayer_peer():
		peer_count = multiplayer.get_peers().size()
		
	if peer_count > 0:
		launch_arena_btn.disabled = false
		launch_arena_btn.text = "🚀 [ENTER] LAUNCH SORTIE (%d CHALLENGER LINKED)" % peer_count
		launch_arena_btn.modulate = Color(0.1, 0.95, 0.4, 1.0)
	else:
		launch_arena_btn.disabled = true
		launch_arena_btn.text = "⏳ [ AWAITING CHALLENGER TO CONNECT... ]"
		launch_arena_btn.modulate = Color(0.7, 0.7, 0.7, 0.6)

func _on_peer_connected(id: int) -> void:
	if network_manager and network_manager.is_host:
		if not network_manager.connected_peers.has(id):
			network_manager.connected_peers.append(id)
		_set_status("OPPONENT JOINED (PEER ID %d)! READY TO LAUNCH" % id, Color(0.1, 0.95, 0.4))
		if waiting_label:
			waiting_label.text = "SQUADRONS LINKED // READY TO LAUNCH ENGAGEMENT"
		# Auto-assign opponent to Squadron Bravo Pilot if empty
		if network_manager.parties["Bravo"]["pilot_callsign"] in ["EMPTY", "[OPEN SEAT]"]:
			network_manager.parties["Bravo"]["pilot_callsign"] = "BANDIT-" + str(id)
			network_manager.parties["Bravo"]["pilot_peer"] = id
			network_manager.party_updated.emit(network_manager.parties)
		_update_party_deck()
		_update_launch_button_state()

func _on_peer_disconnected(id: int) -> void:
	if network_manager and network_manager.is_host:
		network_manager.connected_peers.erase(id)
		_set_status("CHALLENGER DISCONNECTED (PEER ID %d) // AWAITING OPPONENT" % id, Color(1.0, 0.5, 0.2))
		if waiting_label:
			waiting_label.text = "CHALLENGER DISCONNECTED // AWAITING NEW OPPONENT..."
		_update_party_deck()
		_update_launch_button_state()

func _on_connected_to_server() -> void:
	_set_status("CONNECTED TO HOST SQUADRON! WAITING FOR LAUNCH...", Color(0.1, 0.95, 0.4))
	if host_waiting_modal:
		var is_pub = network_manager.is_public_lobby if network_manager else false
		if lobby_title:
			lobby_title.text = "%s COMBAT LOBBY // LINKED TO HOST" % ["🌐 PUBLIC" if is_pub else "📡 LAN"]
		if waiting_label:
			waiting_label.text = "CONNECTED // AWAITING MISSION HOST COMMAND..."
		host_waiting_modal.show()
		
	var cfg = get_node_or_null("/root/ConfigManager")
	var is_az = cfg.is_azerty if cfg else false
	network_manager.set_my_party_role("Bravo", "pilot", "AZERTY" if is_az else "QWERTY")
	_update_party_deck()
	_update_launch_button_state()

func _on_connection_failed() -> void:
	_set_status("FAILED TO CONNECT TO SERVER // TIMEOUT OR WRONG IP", Color(1.0, 0.25, 0.2))

func _claim_pilot_seat(party_name: String) -> void:
	if not network_manager:
		return
	var cfg = get_node_or_null("/root/ConfigManager")
	var is_az = cfg.is_azerty if cfg else false
	network_manager.set_my_party_role(party_name, "pilot", "AZERTY" if is_az else "QWERTY")
	_update_party_deck()

func _join_crew(party_name: String) -> void:
	if not network_manager:
		return
	network_manager.set_my_party_role(party_name, "crew")
	_update_party_deck()

func _cycle_input_mode(party_name: String) -> void:
	if not network_manager:
		return
	var cur_mode = network_manager.parties[party_name].get("pilot_input", "AZERTY")
	var next_mode = "AZERTY"
	match cur_mode:
		"AZERTY": next_mode = "QWERTY"
		"QWERTY": next_mode = "PHONE HOTAS"
		"PHONE HOTAS": next_mode = "GAMEPAD"
		"GAMEPAD": next_mode = "AZERTY"
		_: next_mode = "AZERTY"
		
	var cfg = get_node_or_null("/root/ConfigManager")
	if cfg:
		if next_mode == "AZERTY":
			cfg.reset_keybindings_preset(true)
		elif next_mode == "QWERTY":
			cfg.reset_keybindings_preset(false)
			
	if next_mode == "PHONE HOTAS":
		_on_pair_phone_lobby_pressed()
		
	network_manager.parties[party_name]["pilot_input"] = next_mode
	_update_party_deck()

func _on_party_updated(_parties: Dictionary) -> void:
	_update_party_deck()

func _update_party_deck() -> void:
	if not network_manager:
		return
		
	var p_alpha = network_manager.parties.get("Alpha", {})
	var p_bravo = network_manager.parties.get("Bravo", {})
	
	if alpha_pilot_label:
		alpha_pilot_label.text = "⭐ MAIN PILOT: %s" % p_alpha.get("pilot_callsign", "LEAD")
	if alpha_input_btn:
		alpha_input_btn.text = "FLIGHT CONTROL: [ %s ]" % p_alpha.get("pilot_input", "AZERTY")
		
	if bravo_pilot_label:
		bravo_pilot_label.text = "⭐ MAIN PILOT: %s" % p_bravo.get("pilot_callsign", "[OPEN SEAT]")
	if bravo_input_btn:
		bravo_input_btn.text = "FLIGHT CONTROL: [ %s ]" % p_bravo.get("pilot_input", "AZERTY")
		
	var alpha_crew = p_alpha.get("crew", [])
	if alpha_crew_label:
		alpha_crew_label.text = "TACTICAL CREW: " + (", ".join(alpha_crew) if not alpha_crew.is_empty() else "(NONE)")
		
	var bravo_crew = p_bravo.get("crew", [])
	if bravo_crew_label:
		bravo_crew_label.text = "TACTICAL CREW: " + (", ".join(bravo_crew) if not bravo_crew.is_empty() else "(NONE)")

func _process(_delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_pair_phone_lobby_pressed() -> void:
	if not qr_dialog:
		var scene = load("res://qr_join_dialog.tscn")
		if scene:
			qr_dialog = scene.instantiate()
			add_child(qr_dialog)
			if not qr_dialog.closed.is_connected(_on_qr_dialog_closed):
				qr_dialog.closed.connect(_on_qr_dialog_closed)
	if qr_dialog and qr_dialog.has_method("show_dialog"):
		qr_dialog.show_dialog(1)

func _on_qr_dialog_closed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_launch_arena_pressed() -> void:
	if launch_arena_btn and launch_arena_btn.disabled:
		_set_status("AWAITING CHALLENGER BEFORE LAUNCHING SORTIE", Color(1.0, 0.8, 0.2))
		return
	if network_manager and network_manager.is_host:
		_set_status("COMMAND SQUADRON DEPLOYING TO ARENA...", Color(0.1, 0.95, 0.4))
		if multiplayer and multiplayer.has_multiplayer_peer():
			rpc("rpc_start_arena")
		else:
			get_tree().change_scene_to_file("res://lan_arena.tscn")

@rpc("authority", "call_local", "reliable")
func rpc_start_arena() -> void:
	get_tree().change_scene_to_file("res://lan_arena.tscn")

func _set_status(msg: String, col: Color = Color(0.0, 0.85, 1.0)) -> void:
	if status_label:
		status_label.text = "// " + msg + " //"
		status_label.modulate = col

func _on_network_stats_updated(reg: int, online: int, lobbies: int) -> void:
	_update_fleet_telemetry(reg, online, lobbies)

func _update_fleet_telemetry(_reg: int, online: int, lobbies: int) -> void:
	if fleet_telemetry_label:
		var dot = "🟢" if online > 0 else "⚪"
		fleet_telemetry_label.text = "%s GLOBAL FLEET RADAR: %d PILOTS ONLINE // %d COMBAT LOBBIES ACTIVE" % [dot, online, lobbies]

func _on_back_pressed() -> void:
	if network_manager:
		network_manager.stop_network()
	get_tree().change_scene_to_file("res://home_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F3:
			_on_pair_phone_lobby_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER and host_waiting_modal and host_waiting_modal.visible:
			if launch_arena_btn and not launch_arena_btn.disabled:
				_on_launch_arena_pressed()
			get_viewport().set_input_as_handled()
