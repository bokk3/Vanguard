extends Node3D

## SplitScreenArena: Dedicated local 1v1 PvP dogfight manager.
## Handles dual-viewport rendering with shared World3D, dynamic Horizontal/Vertical
## layout toggle (F2), score tracking (first to 5), and 3-second respawn loop.

@export var max_kills_to_win: int = 5
@export var respawn_delay: float = 3.0

@onready var container_p1: SubViewportContainer = $SplitUI/ViewportP1
@onready var container_p2: SubViewportContainer = $SplitUI/ViewportP2
@onready var viewport_p1: SubViewport = $SplitUI/ViewportP1/SubViewport
@onready var viewport_p2: SubViewport = $SplitUI/ViewportP2/SubViewport

@onready var cam_p1: Camera3D = $SplitUI/ViewportP1/SubViewport/CameraP1
@onready var cam_p2: Camera3D = $SplitUI/ViewportP2/SubViewport/CameraP2
@onready var hud_p1: Control = $SplitUI/ViewportP1/SubViewport/HUD1/TacticalOverlay
@onready var hud_p2: Control = $SplitUI/ViewportP2/SubViewport/HUD2/TacticalOverlay

@onready var ship_p1: CharacterBody3D = $WorldContainer/SpaceshipP1
@onready var ship_p2: CharacterBody3D = $WorldContainer/SpaceshipP2

@onready var score_label: Label = %ScoreLabel
@onready var match_status_label: Label = %MatchStatusLabel
@onready var victory_modal: Control = %VictoryModal
@onready var victory_title: Label = %VictoryTitle
@onready var victory_detail: Label = %VictoryDetail
@onready var rematch_btn: Button = %RematchBtn
@onready var exit_hangar_btn: Button = %ExitHangarBtn
@onready var layout_info_label: Label = %LayoutInfoLabel

var p1_score: int = 0
var p2_score: int = 0
var is_horizontal_split: bool = true
var match_over: bool = false

var p1_respawn_timer: float = 0.0
var p2_respawn_timer: float = 0.0

const SPAWN_P1_POS = Vector3(0, 65, 350)
const SPAWN_P1_ROT = Vector3(0, 0, 0)
const SPAWN_P2_POS = Vector3(0, 65, -350)
const SPAWN_P2_ROT = Vector3(0, PI, 0)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Crucial: Share the 3D world from Viewport 1 to Viewport 2
	viewport_p2.world_3d = viewport_p1.find_world_3d()
	
	# Setup Player 1
	ship_p1.player_id = 1
	ship_p1.is_split_screen = true
	ship_p1.pvp_mode = true
	ship_p1.custom_camera = cam_p1
	ship_p1.pvp_destroyed.connect(_on_p1_destroyed)
	hud_p1.bind_to_ship(ship_p1, cam_p1, 1)
	
	# Setup Player 2
	ship_p2.player_id = 2
	ship_p2.is_split_screen = true
	ship_p2.pvp_mode = true
	ship_p2.custom_camera = cam_p2
	ship_p2.pvp_destroyed.connect(_on_p2_destroyed)
	hud_p2.bind_to_ship(ship_p2, cam_p2, 2)
	
	# Initial Spawns
	ship_p1.global_position = SPAWN_P1_POS
	ship_p1.rotation = SPAWN_P1_ROT
	ship_p2.global_position = SPAWN_P2_POS
	ship_p2.rotation = SPAWN_P2_ROT
	
	# Connect UI buttons
	if rematch_btn and not rematch_btn.pressed.is_connected(_on_rematch_pressed):
		rematch_btn.pressed.connect(_on_rematch_pressed)
	if exit_hangar_btn and not exit_hangar_btn.pressed.is_connected(_on_exit_hangar_pressed):
		exit_hangar_btn.pressed.connect(_on_exit_hangar_pressed)
	
	if victory_modal:
		victory_modal.hide()
	
	_apply_split_layout(is_horizontal_split)
	_update_score_ui()
	print(">>> Split-Screen Dogfight Arena Initialized: First to %d Kills!" % max_kills_to_win)
	
	# Mobile Web HOTAS Server Integration
	var net_ctrl = get_node_or_null("/root/NetworkControllerServer")
	if net_ctrl:
		net_ctrl.start_server(8080)
		net_ctrl.register_ship(2, ship_p2)
		if not net_ctrl.pilot_connected.is_connected(_on_mobile_pilot_joined):
			net_ctrl.pilot_connected.connect(_on_mobile_pilot_joined)

var qr_dialog: Control = null

func _toggle_qr_dialog() -> void:
	if not qr_dialog:
		var scene = load("res://qr_join_dialog.tscn")
		if scene:
			qr_dialog = scene.instantiate()
			$SplitUI.add_child(qr_dialog)
	if qr_dialog and qr_dialog.has_method("toggle_dialog"):
		qr_dialog.toggle_dialog()

func _on_mobile_pilot_joined(callsign: String, player_id: int) -> void:
	if match_status_label:
		match_status_label.text = "// MOBILE PILOT [%s] COMMISSIONED AS PLAYER %d //" % [callsign, player_id]
	if hud_p2 and hud_p2.has_method("notify_combat_event"):
		hud_p2.notify_combat_event("// MOBILE HOTAS ONLINE: PILOT %s //" % callsign, Color(0.0, 0.95, 1.0))

func _unhandled_input(event: InputEvent) -> void:
	# F3: Toggle Mobile QR Scan-to-Fly dialog
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_toggle_qr_dialog()
		get_viewport().set_input_as_handled()
		return

	# F2: Toggle Split Screen Orientation (Horizontal / Vertical)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F2:
		is_horizontal_split = not is_horizontal_split
		_apply_split_layout(is_horizontal_split)
		get_viewport().set_input_as_handled()
	
	# ESC: Return to Menu if match is over or release mouse
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if match_over:
			_on_exit_hangar_pressed()
		else:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _apply_split_layout(horizontal: bool) -> void:
	if not container_p1:
		container_p1 = get_node_or_null("SplitUI/ViewportP1")
	if not container_p2:
		container_p2 = get_node_or_null("SplitUI/ViewportP2")
	if not container_p1 or not container_p2:
		return

	if horizontal:
		# Top / Bottom
		container_p1.anchor_left = 0.0
		container_p1.anchor_right = 1.0
		container_p1.anchor_top = 0.0
		container_p1.anchor_bottom = 0.5
		
		container_p2.anchor_left = 0.0
		container_p2.anchor_right = 1.0
		container_p2.anchor_top = 0.5
		container_p2.anchor_bottom = 1.0
		
		if layout_info_label:
			layout_info_label.text = "[F2] LAYOUT: HORIZONTAL (TOP / BOTTOM)"
	else:
		# Left / Right
		container_p1.anchor_left = 0.0
		container_p1.anchor_right = 0.5
		container_p1.anchor_top = 0.0
		container_p1.anchor_bottom = 1.0
		
		container_p2.anchor_left = 0.5
		container_p2.anchor_right = 1.0
		container_p2.anchor_top = 0.0
		container_p2.anchor_bottom = 1.0
		
		if layout_info_label:
			layout_info_label.text = "[F2] LAYOUT: VERTICAL (LEFT / RIGHT)"

func _process(delta: float) -> void:
	if match_over:
		return
	
	# Respawn loop for Player 1
	if p1_respawn_timer > 0.0:
		p1_respawn_timer -= delta
		if p1_respawn_timer <= 0.0:
			ship_p1.pvp_respawn(SPAWN_P1_POS, SPAWN_P1_ROT)
			hud_p1.notify_combat_event("// AIRFRAME READY // ENGAGING //", Color(0.1, 0.95, 0.4))
	
	# Respawn loop for Player 2
	if p2_respawn_timer > 0.0:
		p2_respawn_timer -= delta
		if p2_respawn_timer <= 0.0:
			ship_p2.pvp_respawn(SPAWN_P2_POS, SPAWN_P2_ROT)
			hud_p2.notify_combat_event("// AIRFRAME READY // ENGAGING //", Color(1.0, 0.4, 0.2))

func _on_p1_destroyed(killer: Node) -> void:
	if match_over:
		return
	
	p2_score += 1
	hud_p2.notify_combat_event("// HOSTILE AIRFRAME CONFIRMED DESTROYED! // +1 KILL //", Color(0.1, 0.95, 0.4))
	hud_p1.notify_combat_event("// CRITICAL: AIRFRAME LOST // RESPAWNING IN 3s //", Color(1.0, 0.2, 0.2))
	
	_update_score_ui()
	
	if p2_score >= max_kills_to_win:
		_end_match(2)
	else:
		p1_respawn_timer = respawn_delay

func _on_p2_destroyed(killer: Node) -> void:
	if match_over:
		return
	
	p1_score += 1
	hud_p1.notify_combat_event("// HOSTILE AIRFRAME CONFIRMED DESTROYED! // +1 KILL //", Color(0.1, 0.95, 0.4))
	hud_p2.notify_combat_event("// CRITICAL: AIRFRAME LOST // RESPAWNING IN 3s //", Color(1.0, 0.2, 0.2))
	
	_update_score_ui()
	
	if p1_score >= max_kills_to_win:
		_end_match(1)
	else:
		p2_respawn_timer = respawn_delay

func _update_score_ui() -> void:
	if score_label:
		score_label.text = "P1 [ %d ]  -  [ %d ] P2" % [p1_score, p2_score]

func _end_match(winner_id: int) -> void:
	match_over = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if victory_title:
		victory_title.text = "VICTORY: PLAYER %d DOMINATES" % winner_id
		victory_title.modulate = Color(0.0, 0.9, 1.0) if winner_id == 1 else Color(1.0, 0.35, 0.2)
	if victory_detail:
		victory_detail.text = "FINAL SCORE: PLAYER 1 [ %d ] — PLAYER 2 [ %d ]\nAIR COMBAT SORTIE TERMINATED" % [p1_score, p2_score]
	if victory_modal:
		victory_modal.show()
	if rematch_btn:
		rematch_btn.grab_focus()

func _on_rematch_pressed() -> void:
	match_over = false
	p1_score = 0
	p2_score = 0
	_update_score_ui()
	if victory_modal:
		victory_modal.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	ship_p1.pvp_respawn(SPAWN_P1_POS, SPAWN_P1_ROT)
	ship_p2.pvp_respawn(SPAWN_P2_POS, SPAWN_P2_ROT)

func _on_exit_hangar_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://home_menu.tscn")
