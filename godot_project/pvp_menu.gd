extends Control

## PvPMenu: Main Portal for Project Vanguard PvP dogfights.
## Features Squadron Parties (Alpha vs Bravo), Main Pilot designation,
## input selection (AZERTY / QWERTY / Phone HOTAS), Split-Screen, and LAN matchmaking.

@onready var split_screen_btn: Button = %SplitScreenBtn
@onready var host_btn: Button = %HostBtn
@onready var server_name_input: LineEdit = %ServerNameInput
@onready var callsign_input: LineEdit = %CallsignInput
@onready var direct_ip_input: LineEdit = %DirectIpInput
@onready var direct_connect_btn: Button = %DirectConnectBtn
@onready var refresh_lan_btn: Button = %RefreshLanBtn
@onready var server_list_container: VBoxContainer = %ServerListContainer
@onready var no_servers_label: Label = %NoServersLabel
@onready var back_btn: Button = %BackBtn
@onready var status_label: Label = %StatusLabel

@onready var host_waiting_modal: Control = %HostWaitingModal
@onready var lobby_title: Label = %LobbyTitle
@onready var waiting_label: Label = %WaitingLabel
@onready var cancel_host_btn: Button = %CancelHostBtn

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

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	network_manager = get_node_or_null("/root/NetworkManager")
	
	if split_screen_btn:
		split_screen_btn.pressed.connect(_on_split_screen_pressed)
	if host_btn:
		host_btn.pressed.connect(_on_host_pressed)
	if direct_connect_btn:
		direct_connect_btn.pressed.connect(_on_direct_connect_pressed)
	if refresh_lan_btn:
		refresh_lan_btn.pressed.connect(_on_refresh_lan_pressed)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if cancel_host_btn:
		cancel_host_btn.pressed.connect(_on_cancel_host_pressed)
	if launch_arena_btn:
		launch_arena_btn.pressed.connect(_on_launch_arena_pressed)
	if pair_phone_lobby_btn:
		pair_phone_lobby_btn.pressed.connect(_on_pair_phone_lobby_pressed)
		
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
	
	# Pre-fill host callsign from AuthManager
	var auth_mgr = get_node_or_null("/root/AuthManager")
	if auth_mgr and not auth_mgr.callsign.is_empty():
		if callsign_input:
			callsign_input.text = auth_mgr.callsign
		if network_manager:
			network_manager.player_callsign = auth_mgr.callsign

	if network_manager:
		network_manager.lan_server_found.connect(_on_lan_server_found)
		network_manager.lan_server_lost.connect(_on_lan_server_lost)
		network_manager.peer_connected.connect(_on_peer_connected)
		network_manager.connected_to_server.connect(_on_connected_to_server)
		network_manager.connection_failed.connect(_on_connection_failed)
		if not network_manager.party_updated.is_connected(_on_party_updated):
			network_manager.party_updated.connect(_on_party_updated)
		network_manager.start_lan_discovery()
	
	_update_server_list()
	_update_party_deck()
	_set_status("READY // SELECT COMBAT SORTIE MODE")

func _exit_tree() -> void:
	if network_manager and not network_manager.is_host:
		network_manager.stop_lan_discovery()

func _on_split_screen_pressed() -> void:
	_set_status("LAUNCHING LOCAL SPLIT-SCREEN ARENA...")
	if network_manager:
		network_manager.stop_network()
	get_tree().change_scene_to_file("res://split_screen_arena.tscn")

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
		
	var err = network_manager.host_game(s_name, 7777, 4)
	if err == OK:
		_set_status("LISTEN SERVER ACTIVE // BROADCASTING ON SUBNET", Color(0.1, 0.95, 0.4))
		if lobby_title:
			lobby_title.text = "LOBBY: '%s'" % s_name
		if waiting_label:
			waiting_label.text = "LISTEN SERVER ACTIVE // SUBNET BROADCAST ACTIVE // WAITING FOR SQUADRON..."
		if host_waiting_modal:
			host_waiting_modal.show()
			
		var cfg = get_node_or_null("/root/ConfigManager")
		var is_az = cfg.is_azerty if cfg else false
		network_manager.set_my_party_role("Alpha", "pilot", "AZERTY" if is_az else "QWERTY")
		_update_party_deck()
	else:
		_set_status("ERROR CREATING SERVER (CODE %d)" % err, Color(1.0, 0.25, 0.2))

func _on_cancel_host_pressed() -> void:
	if network_manager:
		network_manager.stop_network()
		network_manager.start_lan_discovery()
	if host_waiting_modal:
		host_waiting_modal.hide()
	_set_status("HOSTING CANCELLED // READY")

func _on_direct_connect_pressed() -> void:
	if not network_manager:
		return
		
	var ip = direct_ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
		
	var port = 7777
	if ":" in ip:
		var parts = ip.split(":")
		ip = parts[0]
		port = int(parts[1])
		
	var c_sign = callsign_input.text.strip_edges()
	if not c_sign.is_empty():
		network_manager.player_callsign = c_sign
		
	_set_status("CONNECTING TO %s:%d..." % [ip, port], Color(1.0, 0.85, 0.1))
	var err = network_manager.join_game(ip, port)
	if err != OK:
		_set_status("CONNECT FAILED (CODE %d)" % err, Color(1.0, 0.25, 0.2))

func _on_refresh_lan_pressed() -> void:
	if network_manager:
		network_manager.stop_lan_discovery()
		network_manager.start_lan_discovery()
		_update_server_list()
		_set_status("SCANNING SUBNET BROADCASTS ON PORT 7778...")

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
		hbox.theme_override_constants["separation"] = 12
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

func _on_peer_connected(id: int) -> void:
	if network_manager and network_manager.is_host:
		_set_status("OPPONENT JOINED (PEER ID %d)!" % id, Color(0.1, 0.95, 0.4))
		if waiting_label:
			waiting_label.text = "SQUADRONS LINKED // READY TO LAUNCH ENGAGEMENT"
		# Auto-assign opponent to Squadron Bravo Pilot if empty
		if network_manager.parties["Bravo"]["pilot_callsign"] in ["EMPTY", "[OPEN SEAT]"]:
			network_manager.parties["Bravo"]["pilot_callsign"] = "BANDIT-" + str(id)
			network_manager.party_updated.emit(network_manager.parties)
		_update_party_deck()

func _on_connected_to_server() -> void:
	_set_status("CONNECTED TO HOST LOBBY!", Color(0.1, 0.95, 0.4))
	if host_waiting_modal:
		host_waiting_modal.show()
	if waiting_label:
		waiting_label.text = "CONNECTED // WAITING FOR SQUADRON COMMANDER TO LAUNCH..."
	if launch_arena_btn:
		launch_arena_btn.disabled = true
	var cfg = get_node_or_null("/root/ConfigManager")
	var is_az = cfg.is_azerty if cfg else false
	network_manager.set_my_party_role("Bravo", "pilot", "AZERTY" if is_az else "QWERTY")
	_update_party_deck()

func _on_connection_failed() -> void:
	_set_status("CONNECTION ATTEMPT FAILED // TIMEOUT OR REFUSED", Color(1.0, 0.25, 0.2))

# -----------------------------------------------------------------------------
# Squadron Party Controls & UI Sync
# -----------------------------------------------------------------------------
func _claim_pilot_seat(party_name: String) -> void:
	if not network_manager:
		return
	var my_cs = network_manager.player_callsign
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

func _on_pair_phone_lobby_pressed() -> void:
	if not qr_dialog:
		var scene = load("res://qr_join_dialog.tscn")
		if scene:
			qr_dialog = scene.instantiate()
			add_child(qr_dialog)
	if qr_dialog and qr_dialog.has_method("show_dialog"):
		# In lobby, target Controller 1 for Main Pilot!
		qr_dialog.show_dialog(1)

func _on_launch_arena_pressed() -> void:
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
			_on_launch_arena_pressed()
			get_viewport().set_input_as_handled()
