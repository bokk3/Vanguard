class_name QRJoinDialog
extends Control

## QRJoinDialog: In-game tactical QR code dialog for "Scan-to-Fly" Mobile HOTAS.
## Displays the dynamic QR code, connection instructions, and live pilot status.

signal closed()

@onready var texture_rect: TextureRect = %QRTextureRect
@onready var url_label: Label = %UrlLabel
@onready var status_label: Label = %StatusLabel
@onready var close_btn: Button = %CloseBtn
@onready var room_code_label: Label = %RoomCodeLabel
@onready var role_pilot_btn: Button = %RolePilotBtn
@onready var role_wingman_btn: Button = %RoleWingmanBtn
@onready var gateway_toggle_btn: Button = %GatewayToggleBtn

var server: Node = null
var selected_target_pid: int = 1 # 1 = Command Pilot (Controller 1), 2 = Wingman
var use_web_gateway: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if close_btn:
		close_btn.pressed.connect(hide_dialog)
		
	if role_pilot_btn:
		role_pilot_btn.pressed.connect(func(): set_target_role(1))
	if role_wingman_btn:
		role_wingman_btn.pressed.connect(func(): set_target_role(2))
	if gateway_toggle_btn:
		gateway_toggle_btn.pressed.connect(_toggle_gateway)
		
	# Find or attach NetworkControllerServer
	_ensure_server()

func _ensure_server() -> void:
	server = get_node_or_null("/root/NetworkControllerServer")
	if not server:
		server = get_node_or_null("NetworkControllerServer")
		if not server:
			var server_script = load("res://network_controller_server.gd")
			if server_script:
				server = server_script.new()
				server.name = "NetworkControllerServer"
				add_child(server)
			
	if server:
		if not server.pilot_connected.is_connected(_on_pilot_connected):
			server.pilot_connected.connect(_on_pilot_connected)
		if not server.pilot_disconnected.is_connected(_on_pilot_disconnected):
			server.pilot_disconnected.connect(_on_pilot_disconnected)

func set_target_role(pid: int) -> void:
	selected_target_pid = pid
	_refresh_qr()

func _toggle_gateway() -> void:
	use_web_gateway = not use_web_gateway
	_refresh_qr()

func _refresh_qr() -> void:
	_ensure_server()
	if not server:
		return
		
	var role_name = "pilot" if selected_target_pid == 1 else "wingman"
	
	if role_pilot_btn:
		if selected_target_pid == 1:
			role_pilot_btn.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
			role_pilot_btn.text = "★ CONTROLLER 1 (ACTIVE)"
		else:
			role_pilot_btn.remove_theme_color_override("font_color")
			role_pilot_btn.text = "CONTROLLER 1 (SOLO)"
			
	if role_wingman_btn:
		if selected_target_pid == 2:
			role_wingman_btn.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
			role_wingman_btn.text = "★ WINGMAN 2 (ACTIVE)"
		else:
			role_wingman_btn.remove_theme_color_override("font_color")
			role_wingman_btn.text = "WINGMAN (CO-OP)"
			
	if gateway_toggle_btn:
		if use_web_gateway:
			gateway_toggle_btn.text = "🌐 GATEWAY: PAGES.DEV (HANDOFF TO LAN) [TOGGLE]"
		else:
			gateway_toggle_btn.text = "🔌 GATEWAY: DIRECT LAN IP (%s) [TOGGLE]" % server.get_local_ip()
	
	# Generate QR code texture with parameters
	var tex = server.get_qr_texture(selected_target_pid, role_name, use_web_gateway, 6)
	if texture_rect and tex:
		texture_rect.texture = tex
		
	if url_label:
		url_label.text = server.get_controller_url(selected_target_pid, role_name, use_web_gateway)
		
	if room_code_label:
		room_code_label.text = "SESSION: %s // TARGET: P%d (%s)" % [
			server.session_room_code, selected_target_pid, "MAIN PILOT" if selected_target_pid == 1 else "WINGMAN"
		]

var previous_mouse_mode: int = Input.MOUSE_MODE_VISIBLE

func show_dialog(target_pid: int = 1) -> void:
	_ensure_server()
	if not server:
		return
		
	selected_target_pid = target_pid
	server.start_server(8080)
	_refresh_qr()
		
	if status_label:
		if server.connected_clients.is_empty():
			status_label.text = "// WAITING FOR SMARTPHONE SCAN... //"
			status_label.modulate = Color(1.0, 0.75, 0.2) # Amber
		else:
			var cs = server.connected_clients[0].get("callsign", "PILOT")
			var pid = server.connected_clients[0].get("player_id", 1)
			status_label.text = "// PILOT [%s] LINKED AS CONTROLLER %d //" % [cs, pid]
			status_label.modulate = Color(0.1, 0.95, 0.4) # Emerald
			
	visible = true
	previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_dialog() -> void:
	visible = false
	var scene = get_tree().current_scene if (is_inside_tree() and get_tree()) else null
	var is_in_flight_sortie = false
	if scene:
		var scene_name = scene.name
		if scene_name in ["Main", "Level", "SplitScreenArena", "LANArena"]:
			is_in_flight_sortie = true
			
	if is_in_flight_sortie and previous_mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	closed.emit()

func toggle_dialog(target_pid: int = 1) -> void:
	if visible:
		hide_dialog()
	else:
		show_dialog(target_pid)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		toggle_dialog(selected_target_pid)
		get_viewport().set_input_as_handled()
		return
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_dialog()
		get_viewport().set_input_as_handled()

func _on_pilot_connected(callsign: String, player_id: int) -> void:
	if status_label:
		status_label.text = "// PILOT [%s] COMMISSIONED AS CONTROLLER %d! //" % [callsign, player_id]
		status_label.modulate = Color(0.0, 0.95, 1.0) # Cyan
		
	if visible:
		var timer = get_tree().create_timer(2.2)
		timer.timeout.connect(func():
			if visible:
				hide_dialog()
		)

func _on_pilot_disconnected(callsign: String, _player_id: int) -> void:
	if status_label:
		status_label.text = "// PILOT [%s] DISCONNECTED // WAITING FOR SCAN... //" % callsign
		status_label.modulate = Color(1.0, 0.2, 0.2) # Crimson
