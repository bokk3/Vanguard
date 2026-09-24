extends Control

## PvPMenu: Main Portal for Project Vanguard PvP dogfights.
## Provides Local Split-Screen launch and LAN Peer-to-Peer hosting/joining with auto-discovery.

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
@onready var waiting_label: Label = %WaitingLabel
@onready var cancel_host_btn: Button = %CancelHostBtn

var network_manager: Node = null

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
	
	if host_waiting_modal:
		host_waiting_modal.hide()
	
	if network_manager:
		network_manager.lan_server_found.connect(_on_lan_server_found)
		network_manager.lan_server_lost.connect(_on_lan_server_lost)
		network_manager.peer_connected.connect(_on_peer_connected)
		network_manager.connected_to_server.connect(_on_connected_to_server)
		network_manager.connection_failed.connect(_on_connection_failed)
		network_manager.start_lan_discovery()
	
	_update_server_list()
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
		s_name = "VANGUARD PILOT'S SERVER"
	
	var c_sign = callsign_input.text.strip_edges()
	if not c_sign.is_empty():
		network_manager.player_callsign = c_sign
		
	var err = network_manager.host_game(s_name, 7777, 1)
	if err == OK:
		_set_status("LISTEN SERVER ACTIVE // BROADCASTING ON SUBNET", Color(0.1, 0.95, 0.4))
		if host_waiting_modal:
			waiting_label.text = "LOBBY: '%s'\nWAITING FOR OPPONENT TO CONNECT ON LAN..." % s_name
			host_waiting_modal.show()
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
		
	# Clear old items
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
			network_manager.join_game(info["ip"], info["port"])
		)
		hbox.add_child(join_btn)
		
		server_list_container.add_child(item)

func _on_peer_connected(id: int) -> void:
	if network_manager and network_manager.is_host:
		_set_status("OPPONENT JOINED (PEER ID %d)! LAUNCHING ARENA..." % id, Color(0.1, 0.95, 0.4))
		if host_waiting_modal:
			host_waiting_modal.hide()
		get_tree().change_scene_to_file("res://lan_arena.tscn")

func _on_connected_to_server() -> void:
	_set_status("CONNECTED TO HOST! LAUNCHING ARENA...", Color(0.1, 0.95, 0.4))
	get_tree().change_scene_to_file("res://lan_arena.tscn")

func _on_connection_failed() -> void:
	_set_status("CONNECTION ATTEMPT FAILED // TIMEOUT OR REFUSED", Color(1.0, 0.25, 0.2))

func _set_status(msg: String, col: Color = Color(0.0, 0.85, 1.0)) -> void:
	if status_label:
		status_label.text = "// " + msg + " //"
		status_label.modulate = col

func _on_back_pressed() -> void:
	if network_manager:
		network_manager.stop_network()
	get_tree().change_scene_to_file("res://home_menu.tscn")
