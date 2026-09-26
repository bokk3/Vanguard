extends Node3D

## Main: Level scene controller for Project Vanguard.
## Coordinates scene setup with MissionManager autoload on initialization.
## Features dynamic drop-in split-screen co-op when Player 2 presses secondary controls.

@onready var ship_p1: CharacterBody3D = $Spaceship
@onready var single_cam: Camera3D = $Camera3D
@onready var single_hud_layer: CanvasLayer = $HUD
@onready var single_hud: Control = $HUD/TacticalOverlay

var is_coop_active: bool = false
var is_horizontal_split: bool = true

var p2_ship: CharacterBody3D = null
var coop_layer: CanvasLayer = null
var split_ui: Control = null
var container_p1: SubViewportContainer = null
var container_p2: SubViewportContainer = null
var sub_viewport_1: SubViewport = null
var sub_viewport_2: SubViewport = null
var cam_p1: Camera3D = null
var cam_p2: Camera3D = null
var hud_p1: Control = null
var hud_p2: Control = null

var p1_respawn_timer: float = 0.0
var p2_respawn_timer: float = 0.0
const COOP_RESPAWN_DELAY: float = 5.0

func _ready() -> void:
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("initialize_level"):
		mm.initialize_level(self)
	
	# Non-intrusive hint after sortie launch
	if is_inside_tree() and get_tree():
		get_tree().create_timer(3.5).timeout.connect(func():
			if not is_coop_active and is_inside_tree() and single_hud and single_hud.has_method("notify_combat_event"):
				single_hud.notify_combat_event("// CO-OP READY // PRESS F3 OR SCAN QR ON PHONE TO FLY //", Color(0.65, 0.85, 1.0))
		)
		
	# Mobile Web HOTAS Server Integration
	var net_ctrl = get_node_or_null("/root/NetworkControllerServer")
	if net_ctrl:
		net_ctrl.start_server(8080)
		net_ctrl.register_ship(1, ship_p1)
		if not net_ctrl.pilot_connected.is_connected(_on_mobile_pilot_joined):
			net_ctrl.pilot_connected.connect(_on_mobile_pilot_joined)

var qr_dialog: Control = null

func _toggle_qr_dialog() -> void:
	if not qr_dialog:
		var scene = load("res://qr_join_dialog.tscn")
		if scene:
			qr_dialog = scene.instantiate()
			add_child(qr_dialog)
	if qr_dialog and qr_dialog.has_method("toggle_dialog"):
		qr_dialog.toggle_dialog()

func _on_mobile_pilot_joined(callsign: String, p_id: int) -> void:
	if p_id == 1:
		if single_hud and single_hud.has_method("notify_combat_event"):
			single_hud.notify_combat_event("// CONTROLLER 1 LINKED: PHONE GYRO HOTAS (%s) //" % callsign, Color(0.0, 0.95, 1.0))
		return

	if not is_coop_active:
		join_player_2()
	var hud = hud_p2 if hud_p2 else single_hud
	if hud and hud.has_method("notify_combat_event"):
		hud.notify_combat_event("// WINGMAN JOINED: MOBILE PILOT %s //" % callsign, Color(0.0, 0.95, 1.0))

func _unhandled_input(event: InputEvent) -> void:
	# F3: Toggle Mobile QR Scan-to-Fly dialog
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_toggle_qr_dialog()
		get_viewport().set_input_as_handled()
		return

	if not is_coop_active:
		if _is_secondary_control_event(event):
			join_player_2()
			get_viewport().set_input_as_handled()
	else:
		if event is InputEventKey and event.pressed and event.keycode == KEY_F2:
			toggle_split_layout()
			get_viewport().set_input_as_handled()

func _is_secondary_control_event(event: InputEvent) -> bool:
	var cfg = get_node_or_null("/root/ConfigManager")
	if cfg and "P2_ACTIONS" in cfg:
		for action in cfg.P2_ACTIONS:
			if event.is_action_pressed(action):
				return true
	
	# Device index >= 1 (Second controller button or thumbstick)
	if event is InputEventJoypadButton and event.pressed and event.device >= 1:
		return true
	if event is InputEventJoypadMotion and abs(event.axis_value) > 0.6 and event.device >= 1:
		return true
		
	# Keyboard keys for Player 2 (IJKL, YH, UO, N, M, P, Enter, NumPad)
	if event is InputEventKey and event.pressed:
		var k = event.keycode
		var p2_keys = [
			KEY_I, KEY_K, KEY_J, KEY_L, KEY_U, KEY_O, KEY_Y, KEY_H,
			KEY_N, KEY_M, KEY_P, KEY_ENTER, KEY_KP_ENTER,
			KEY_KP_8, KEY_KP_2, KEY_KP_4, KEY_KP_6, KEY_KP_5, KEY_KP_7, KEY_KP_9, KEY_KP_0
		]
		if k in p2_keys:
			return true
			
	return false

func join_player_2() -> void:
	if is_coop_active:
		return
	is_coop_active = true
	print(">>> [Campaign Co-Op] Secondary control keypress verified! Player 2 joining sortie...")
	
	if not ship_p1:
		ship_p1 = get_node_or_null("Spaceship")
	if not ship_p1:
		push_error("[Campaign Co-Op] Spaceship P1 not found!")
		return
	
	# 1. Instantiate Player 2 Wingman Interceptor
	p2_ship = CharacterBody3D.new()
	p2_ship.name = "SpaceshipP2"
	p2_ship.set_script(load("res://spaceship_controller.gd"))
	p2_ship.collision_layer = 2
	p2_ship.collision_mask = 29
	p2_ship.player_id = 2
	p2_ship.is_split_screen = true
	p2_ship.pvp_mode = false # Friendly co-op wingman!
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(9.8, 2.7, 10.3)
	col.shape = box
	p2_ship.add_child(col)
	
	var telem = Node.new()
	telem.name = "CombatTelemetry"
	telem.set_script(load("res://combat_telemetry.gd"))
	p2_ship.add_child(telem)
	
	var model_packed = load("res://Spaceship_Sculpted_V_Hull.glb")
	if model_packed:
		var model = model_packed.instantiate()
		model.name = "Model"
		p2_ship.add_child(model)
	
	add_child(p2_ship)
	
	var net_ctrl = get_node_or_null("/root/NetworkControllerServer")
	if net_ctrl:
		net_ctrl.register_ship(2, p2_ship)
	
	# Formation spawn alongside Player 1
	var fwd = -ship_p1.global_transform.basis.z.normalized()
	var right = ship_p1.global_transform.basis.x.normalized()
	p2_ship.global_position = ship_p1.global_position + (right * 22.0) - (fwd * 6.0)
	p2_ship.rotation = ship_p1.rotation
	p2_ship.current_speed = ship_p1.current_speed
	
	p2_ship.add_to_group("player")
	p2_ship.add_to_group("radar_targets")
	
	# 2. Build Dual Split Viewports
	coop_layer = CanvasLayer.new()
	coop_layer.name = "CoopSplitLayer"
	coop_layer.layer = 1
	add_child(coop_layer)
	
	split_ui = Control.new()
	split_ui.name = "SplitUI"
	split_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	coop_layer.add_child(split_ui)
	
	var shared_world = get_world_3d()
	var hud_script = load("res://hud.gd")
	
	# Viewport 1 (Player 1)
	container_p1 = SubViewportContainer.new()
	container_p1.name = "ViewportP1"
	container_p1.stretch = true
	split_ui.add_child(container_p1)
	
	sub_viewport_1 = SubViewport.new()
	sub_viewport_1.name = "SubViewport"
	sub_viewport_1.handle_input_locally = false
	sub_viewport_1.size = Vector2i(1920, 540)
	sub_viewport_1.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport_1.world_3d = shared_world
	container_p1.add_child(sub_viewport_1)
	
	cam_p1 = Camera3D.new()
	cam_p1.name = "CameraP1"
	cam_p1.fov = 75.0
	sub_viewport_1.add_child(cam_p1)
	cam_p1.current = true
	
	var hud1_layer = CanvasLayer.new()
	hud1_layer.name = "HUD1"
	sub_viewport_1.add_child(hud1_layer)
	
	hud_p1 = Control.new()
	hud_p1.name = "TacticalOverlay"
	hud_p1.set_script(hud_script)
	hud_p1.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud1_layer.add_child(hud_p1)
	
	# Viewport 2 (Player 2)
	container_p2 = SubViewportContainer.new()
	container_p2.name = "ViewportP2"
	container_p2.stretch = true
	split_ui.add_child(container_p2)
	
	sub_viewport_2 = SubViewport.new()
	sub_viewport_2.name = "SubViewport"
	sub_viewport_2.handle_input_locally = false
	sub_viewport_2.size = Vector2i(1920, 540)
	sub_viewport_2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport_2.world_3d = shared_world
	container_p2.add_child(sub_viewport_2)
	
	cam_p2 = Camera3D.new()
	cam_p2.name = "CameraP2"
	cam_p2.fov = 75.0
	sub_viewport_2.add_child(cam_p2)
	cam_p2.current = true
	
	var hud2_layer = CanvasLayer.new()
	hud2_layer.name = "HUD2"
	sub_viewport_2.add_child(hud2_layer)
	
	hud_p2 = Control.new()
	hud_p2.name = "TacticalOverlay"
	hud_p2.set_script(hud_script)
	hud_p2.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud2_layer.add_child(hud_p2)
	
	# 3. Bind Avionics & HUDs
	ship_p1.is_split_screen = true
	ship_p1.custom_camera = cam_p1
	hud_p1.bind_to_ship(ship_p1, cam_p1, 1)
	
	p2_ship.custom_camera = cam_p2
	hud_p2.bind_to_ship(p2_ship, cam_p2, 2)
	
	# 4. Hide Single-Player HUD Overlay and Camera
	if single_hud:
		single_hud.hide()
	if single_cam:
		single_cam.current = false
		
	# 5. Apply Default Horizontal Split Layout
	_apply_split_layout(is_horizontal_split)
	
	# 6. Audio / Visual Notifications
	hud_p1.notify_combat_event("// WINGMAN VANGUARD-2 JOINED THE SORTIE // CO-OP ACTIVE //", Color(0.0, 0.95, 1.0))
	hud_p2.notify_combat_event("// WINGMAN ONLINE // FORMATION ESTABLISHED // [F2] TOGGLE SPLIT //", Color(1.0, 0.85, 0.1))
	
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("play_radio_transmission"):
		mm.play_radio_transmission("APEX_CMD", "Vanguard-2 has joined the battlespace. Wingman formation established.", 4.5)
	
	print(">>> [Campaign Co-Op] Dual Viewports Active! Wingman Vanguard-2 engaged.")

func toggle_split_layout() -> void:
	is_horizontal_split = not is_horizontal_split
	_apply_split_layout(is_horizontal_split)

func _apply_split_layout(horizontal: bool) -> void:
	if not container_p1 or not container_p2:
		return
	if horizontal:
		container_p1.anchor_left = 0.0
		container_p1.anchor_right = 1.0
		container_p1.anchor_top = 0.0
		container_p1.anchor_bottom = 0.5
		
		container_p2.anchor_left = 0.0
		container_p2.anchor_right = 1.0
		container_p2.anchor_top = 0.5
		container_p2.anchor_bottom = 1.0
		if hud_p1:
			hud_p1.notify_combat_event("// SPLIT LAYOUT: HORIZONTAL (TOP / BOTTOM) //", Color(0.6, 0.8, 1.0))
		if hud_p2:
			hud_p2.notify_combat_event("// SPLIT LAYOUT: HORIZONTAL (TOP / BOTTOM) //", Color(0.6, 0.8, 1.0))
	else:
		container_p1.anchor_left = 0.0
		container_p1.anchor_right = 0.5
		container_p1.anchor_top = 0.0
		container_p1.anchor_bottom = 1.0
		
		container_p2.anchor_left = 0.5
		container_p2.anchor_right = 1.0
		container_p2.anchor_top = 0.0
		container_p2.anchor_bottom = 1.0
		if hud_p1:
			hud_p1.notify_combat_event("// SPLIT LAYOUT: VERTICAL (LEFT / RIGHT) //", Color(0.6, 0.8, 1.0))
		if hud_p2:
			hud_p2.notify_combat_event("// SPLIT LAYOUT: VERTICAL (LEFT / RIGHT) //", Color(0.6, 0.8, 1.0))

func _process(delta: float) -> void:
	if not is_coop_active:
		return
	
	# Respawn loop for Wingman Player 2
	if p2_respawn_timer > 0.0:
		p2_respawn_timer -= delta
		if p2_respawn_timer <= 0.0 and is_instance_valid(p2_ship) and is_instance_valid(ship_p1):
			var fwd = -ship_p1.global_transform.basis.z.normalized()
			var right = ship_p1.global_transform.basis.x.normalized()
			var spawn_pos = ship_p1.global_position + (right * 20.0) - (fwd * 6.0)
			p2_ship.pvp_respawn(spawn_pos, ship_p1.rotation)
			p2_ship.current_speed = ship_p1.current_speed
			if hud_p2:
				hud_p2.notify_combat_event("// AIRFRAME REPAIRED // RE-ENGAGING SORTIE //", Color(0.1, 0.95, 0.4))
			if hud_p1:
				hud_p1.notify_combat_event("// WINGMAN VANGUARD-2 REJOINED FORMATION //", Color(0.1, 0.95, 0.4))

	# Respawn loop for Flight Leader Player 1
	if p1_respawn_timer > 0.0:
		p1_respawn_timer -= delta
		if p1_respawn_timer <= 0.0 and is_instance_valid(ship_p1) and is_instance_valid(p2_ship):
			var fwd = -p2_ship.global_transform.basis.z.normalized()
			var left = -p2_ship.global_transform.basis.x.normalized()
			var spawn_pos = p2_ship.global_position + (left * 20.0) - (fwd * 6.0)
			ship_p1.pvp_respawn(spawn_pos, p2_ship.rotation)
			ship_p1.current_speed = p2_ship.current_speed
			if hud_p1:
				hud_p1.notify_combat_event("// AIRFRAME REPAIRED // FLIGHT LEAD REJOINED //", Color(0.1, 0.95, 0.4))
			if hud_p2:
				hud_p2.notify_combat_event("// FLIGHT LEAD BACK ONLINE // FORMATION SECURE //", Color(0.1, 0.95, 0.4))

func _on_coop_player_destroyed(ship: CharacterBody3D, reason_code: String, reason_text: String) -> void:
	if not is_coop_active:
		var mm = get_node_or_null("/root/MissionManager")
		if mm and mm.has_method("fail_mission"):
			mm.fail_mission(reason_code, reason_text)
		return
	
	var p1_dead = ship_p1.is_airframe_destroyed if is_instance_valid(ship_p1) else true
	var p2_dead = p2_ship.is_airframe_destroyed if is_instance_valid(p2_ship) else true
	
	if p1_dead and p2_dead:
		print("[Campaign Co-Op] Both flight elements destroyed! Sortie failed.")
		var mm = get_node_or_null("/root/MissionManager")
		if mm and mm.has_method("fail_mission"):
			mm.fail_mission("SORTIE_WIPED", "Both flight elements lost in combat.")
		return
	
	if ship == p2_ship:
		p2_respawn_timer = COOP_RESPAWN_DELAY
		if hud_p2:
			hud_p2.notify_combat_event("// AIRFRAME CRITICAL // RESPAWNING IN 5s //", Color(1.0, 0.25, 0.2))
		if hud_p1:
			hud_p1.notify_combat_event("// WINGMAN VANGUARD-2 DOWN // REBUILDING IN 5s //", Color(1.0, 0.45, 0.2))
	elif ship == ship_p1:
		p1_respawn_timer = COOP_RESPAWN_DELAY
		if hud_p1:
			hud_p1.notify_combat_event("// AIRFRAME CRITICAL // RESPAWNING IN 5s //", Color(1.0, 0.25, 0.2))
		if hud_p2:
			hud_p2.notify_combat_event("// FLIGHT LEAD DOWN // COVERING AREA // RESPAWNING IN 5s //", Color(1.0, 0.45, 0.2))
