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

var server: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if close_btn:
		close_btn.pressed.connect(hide_dialog)
		
	# Find or attach NetworkControllerServer
	_ensure_server()

func _ensure_server() -> void:
	server = get_node_or_null("/root/NetworkControllerServer")
	if not server:
		# Check if already a child
		server = get_node_or_null("NetworkControllerServer")
		if not server:
			server = NetworkControllerServer.new()
			server.name = "NetworkControllerServer"
			add_child(server)
			
	if server:
		if not server.pilot_connected.is_connected(_on_pilot_connected):
			server.pilot_connected.connect(_on_pilot_connected)
		if not server.pilot_disconnected.is_connected(_on_pilot_disconnected):
			server.pilot_disconnected.connect(_on_pilot_disconnected)

func show_dialog() -> void:
	_ensure_server()
	if not server:
		return
		
	server.start_server(8080)
	
	# Generate QR code texture
	var tex = server.get_qr_texture(6)
	if texture_rect and tex:
		texture_rect.texture = tex
		
	if url_label:
		url_label.text = server.get_controller_url()
		
	if room_code_label:
		room_code_label.text = "SESSION: %s" % server.session_room_code
		
	if status_label:
		if server.connected_clients.is_empty():
			status_label.text = "// WAITING FOR SMARTPHONE SCAN... //"
			status_label.modulate = Color(1.0, 0.75, 0.2) # Amber
		else:
			var cs = server.connected_clients[0].get("callsign", "PILOT")
			status_label.text = "// PILOT [%s] LINKED & ARMED //" % cs
			status_label.modulate = Color(0.1, 0.95, 0.4) # Emerald
			
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_dialog() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()

func toggle_dialog() -> void:
	if visible:
		hide_dialog()
	else:
		show_dialog()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		toggle_dialog()
		get_viewport().set_input_as_handled()
		return
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_dialog()
		get_viewport().set_input_as_handled()

func _on_pilot_connected(callsign: String, player_id: int) -> void:
	if status_label:
		status_label.text = "// PILOT [%s] COMMISSIONED AS PLAYER %d! //" % [callsign, player_id]
		status_label.modulate = Color(0.0, 0.95, 1.0) # Cyan
		
	# Play confirmation sound / flash
	if visible:
		# Auto-minimize after 2.5 seconds so pilots can jump straight into flight!
		var timer = get_tree().create_timer(2.5)
		timer.timeout.connect(func():
			if visible:
				hide_dialog()
		)

func _on_pilot_disconnected(callsign: String, _player_id: int) -> void:
	if status_label:
		status_label.text = "// PILOT [%s] DISCONNECTED // WAITING FOR SCAN... //" % callsign
		status_label.modulate = Color(1.0, 0.2, 0.2) # Crimson
