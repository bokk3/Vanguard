extends Node3D

## LAMArena: Online / LAN Networked 1v1 PvP Dogfight Arena.
## Manages listen-server & peer synchronization, 6-DOF state replication,
## networked weapon bursts, synchronized scoring, and rematch cycle.

@export var max_kills_to_win: int = 5
@export var respawn_delay: float = 3.0

@onready var cam: Camera3D = $Camera3D
@onready var hud: Control = $HUD/TacticalOverlay
@onready var ship_p1: CharacterBody3D = $WorldContainer/SpaceshipP1
@onready var ship_p2: CharacterBody3D = $WorldContainer/SpaceshipP2

@onready var score_label: Label = %ScoreLabel
@onready var match_status_label: Label = %MatchStatusLabel
@onready var victory_modal: Control = %VictoryModal
@onready var victory_title: Label = %VictoryTitle
@onready var victory_detail: Label = %VictoryDetail
@onready var rematch_btn: Button = %RematchBtn
@onready var exit_hangar_btn: Button = %ExitHangarBtn

var p1_score: int = 0
var p2_score: int = 0
var match_over: bool = false
var local_player_id: int = 1
var local_ship: CharacterBody3D = null
var remote_ship: CharacterBody3D = null

var respawn_timer: float = 0.0
var is_waiting_respawn: bool = false

const SPAWN_P1_POS = Vector3(0, 65, 350)
const SPAWN_P1_ROT = Vector3(0, 0, 0)
const SPAWN_P2_POS = Vector3(0, 65, -350)
const SPAWN_P2_ROT = Vector3(0, PI, 0)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	var nm = get_node_or_null("/root/NetworkManager")
	var is_host = nm.is_host if nm else true
	local_player_id = 1 if is_host else 2
	
	# Determine Local vs Remote Ship
	if local_player_id == 1:
		local_ship = ship_p1
		remote_ship = ship_p2
		
		ship_p1.player_id = 1
		ship_p1.is_network_remote = false
		ship_p1.pvp_mode = true
		ship_p1.custom_camera = cam
		
		ship_p2.player_id = 2
		ship_p2.is_network_remote = true
		ship_p2.pvp_mode = true
		
		cam.global_position = SPAWN_P1_POS + Vector3(0, 4, 14)
		cam.look_at(SPAWN_P1_POS + Vector3(0, 0, -8), Vector3.UP)
	else:
		local_ship = ship_p2
		remote_ship = ship_p1
		
		ship_p2.player_id = 2
		ship_p2.is_network_remote = false
		ship_p2.pvp_mode = true
		ship_p2.custom_camera = cam
		
		ship_p1.player_id = 1
		ship_p1.is_network_remote = true
		ship_p1.pvp_mode = true
		
		cam.global_position = SPAWN_P2_POS + Vector3(0, 4, -14)
		cam.look_at(SPAWN_P2_POS + Vector3(0, 0, 8), Vector3.UP)
	
	hud.bind_to_ship(local_ship, cam, local_player_id)
	
	# Initial Spawns
	ship_p1.global_position = SPAWN_P1_POS
	ship_p1.rotation = SPAWN_P1_ROT
	ship_p2.global_position = SPAWN_P2_POS
	ship_p2.rotation = SPAWN_P2_ROT
	
	local_ship.pvp_destroyed.connect(_on_local_destroyed)
	
	if nm:
		nm.peer_disconnected.connect(_on_peer_disconnected)
		nm.disconnected_from_server.connect(_on_peer_disconnected)
	
	# Connect UI buttons
	if rematch_btn and not rematch_btn.pressed.is_connected(_on_rematch_pressed):
		rematch_btn.pressed.connect(_on_rematch_pressed)
	if exit_hangar_btn and not exit_hangar_btn.pressed.is_connected(_on_exit_hangar_pressed):
		exit_hangar_btn.pressed.connect(_on_exit_hangar_pressed)
	
	if victory_modal:
		victory_modal.hide()
	
	_update_score_ui()
	print(">>> LAN Dogfight Arena Active: Role: %s (Player %d)" % ["HOST" if is_host else "CLIENT", local_player_id])

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if match_over:
			_on_exit_hangar_pressed()
		else:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if match_over:
		return
	
	# Local Respawn countdown
	if is_waiting_respawn:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			is_waiting_respawn = false
			var my_spawn_pos = SPAWN_P1_POS if local_player_id == 1 else SPAWN_P2_POS
			var my_spawn_rot = SPAWN_P1_ROT if local_player_id == 1 else SPAWN_P2_ROT
			local_ship.pvp_respawn(my_spawn_pos, my_spawn_rot)
			hud.notify_combat_event("// AIRFRAME RECONFIGURED // RE-ENGAGING //", Color(0.1, 0.95, 0.4))
			rpc("rpc_notify_respawn", local_player_id)

func _on_local_destroyed(killer: Node) -> void:
	if match_over:
		return
	
	var other_id = 2 if local_player_id == 1 else 1
	hud.notify_combat_event("// AIRFRAME DESTROYED // RESPAWNING IN 3s //", Color(1.0, 0.2, 0.2))
	is_waiting_respawn = true
	respawn_timer = respawn_delay
	
	# Report kill to both peers via reliable RPC
	rpc("rpc_report_kill", other_id)

@rpc("any_peer", "call_local", "reliable")
func rpc_report_kill(scorer_player_id: int) -> void:
	if match_over:
		return
		
	if scorer_player_id == 1:
		p1_score += 1
	else:
		p2_score += 1
	
	_update_score_ui()
	
	if scorer_player_id == local_player_id:
		hud.notify_combat_event("// HOSTILE AIRFRAME DESTROYED // +1 KILL //", Color(0.1, 0.95, 0.4))
		
	if p1_score >= max_kills_to_win:
		_end_match(1)
	elif p2_score >= max_kills_to_win:
		_end_match(2)

@rpc("any_peer", "call_local", "reliable")
func rpc_notify_respawn(player_id: int) -> void:
	if player_id != local_player_id and remote_ship:
		var opp_pos = SPAWN_P1_POS if player_id == 1 else SPAWN_P2_POS
		var opp_rot = SPAWN_P1_ROT if player_id == 1 else SPAWN_P2_ROT
		remote_ship.pvp_respawn(opp_pos, opp_rot)

func _update_score_ui() -> void:
	if score_label:
		score_label.text = "P1 [ %d ]  -  [ %d ] P2" % [p1_score, p2_score]

func _end_match(winner_id: int) -> void:
	match_over = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if victory_title:
		if winner_id == local_player_id:
			victory_title.text = "VICTORY: AIR SUPREMACY ACHIEVED"
			victory_title.modulate = Color(0.0, 0.95, 0.4)
		else:
			victory_title.text = "DEFEAT: AIRFRAME OVERRUN"
			victory_title.modulate = Color(1.0, 0.25, 0.2)
	
	if victory_detail:
		victory_detail.text = "FINAL SCORE: PLAYER 1 [ %d ] — PLAYER 2 [ %d ]" % [p1_score, p2_score]
	
	if victory_modal:
		victory_modal.show()
	if rematch_btn:
		rematch_btn.grab_focus()

func _on_rematch_pressed() -> void:
	rpc("rpc_start_rematch")

@rpc("any_peer", "call_local", "reliable")
func rpc_start_rematch() -> void:
	match_over = false
	p1_score = 0
	p2_score = 0
	_update_score_ui()
	if victory_modal:
		victory_modal.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	ship_p1.pvp_respawn(SPAWN_P1_POS, SPAWN_P1_ROT)
	ship_p2.pvp_respawn(SPAWN_P2_POS, SPAWN_P2_ROT)

func _on_peer_disconnected(_id: int = 0) -> void:
	if hud:
		hud.notify_combat_event("// OPPONENT DISCONNECTED FROM ARENA //", Color(1.0, 0.8, 0.1))
	if victory_title:
		victory_title.text = "OPPONENT DISCONNECTED"
		victory_title.modulate = Color(1.0, 0.8, 0.1)
	if victory_detail:
		victory_detail.text = "Sortie session terminated by peer."
	if victory_modal:
		victory_modal.show()

func _on_exit_hangar_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		nm.stop_network()
	get_tree().change_scene_to_file("res://home_menu.tscn")
