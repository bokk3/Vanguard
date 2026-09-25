class_name CombatStatsDialog
extends Control

## CombatStatsDialog: Full Tactical Service Record and Battle History Modal.
## Tracks career sorties, dogfight victories, air-to-air kills, accuracy, and recent engagements.

signal closed()

@onready var callsign_label: Label = %CallsignLabel
@onready var rank_label: Label = %RankLabel
@onready var squadron_label: Label = %SquadronLabel
@onready var sorties_val: Label = %SortiesVal
@onready var wins_val: Label = %WinsVal
@onready var losses_val: Label = %LossesVal
@onready var win_ratio_val: Label = %WinRatioVal
@onready var kills_val: Label = %KillsVal
@onready var flight_time_val: Label = %FlightTimeVal
@onready var controls_badge: Label = %ControlsBadge
@onready var battles_container: VBoxContainer = %BattlesContainer
@onready var no_battles_label: Label = %NoBattlesLabel
@onready var close_btn: Button = %CloseBtn
@onready var sync_btn: Button = %SyncBtn
@onready var status_msg_label: Label = %StatusMsgLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if close_btn:
		close_btn.pressed.connect(hide_stats)
	if sync_btn:
		sync_btn.pressed.connect(_on_sync_pressed)

func show_stats() -> void:
	_populate_stats()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_stats() -> void:
	visible = false
	closed.emit()

func _populate_stats() -> void:
	var auth_mgr = get_node_or_null("/root/AuthManager")
	var cfg = get_node_or_null("/root/ConfigManager")
	var net_ctrl = get_node_or_null("/root/NetworkControllerServer")
	
	var cs = auth_mgr.callsign if (auth_mgr and not auth_mgr.callsign.is_empty()) else "VANGUARD-LEAD"
	var rk = auth_mgr.rank if auth_mgr else "LIEUTENANT"
	var sq = auth_mgr.squadron if auth_mgr else "404th Vanguard Strike Wing"
	var st = auth_mgr.stats if auth_mgr else {}
	
	if callsign_label: callsign_label.text = "CALLSIGN: %s" % cs
	if rank_label: rank_label.text = "RANK: %s" % rk
	if squadron_label: squadron_label.text = "SQUADRON: %s" % sq
	
	var sorties = int(st.get("total_sorties", 0))
	var kills = int(st.get("total_kills", 0))
	var wins = int(st.get("battles_won", 0))
	var losses = int(st.get("battles_lost", 0))
	var total_battles = wins + losses
	var win_pct = (float(wins) / float(max(1, total_battles))) * 100.0 if total_battles > 0 else 0.0
	var time_sec = float(st.get("total_flight_time_sec", 0.0))
	var hrs = int(time_sec / 3600.0)
	var mins = int(fmod(time_sec, 3600.0) / 60.0)
	
	if sorties_val: sorties_val.text = str(sorties)
	if kills_val: kills_val.text = str(kills)
	if wins_val: wins_val.text = str(wins)
	if losses_val: losses_val.text = str(losses)
	if win_ratio_val: win_ratio_val.text = "%.1f%%" % win_pct
	if flight_time_val: flight_time_val.text = "%dh %02dm" % [hrs, mins]
	
	# Determine preferred / active avionics input
	var is_phone = net_ctrl and net_ctrl.connected_clients.size() > 0
	var is_azerty = cfg and cfg.is_azerty
	var avionics_txt = "📱 PHONE GYRO HOTAS" if is_phone else ("⌨ AZERTY (ZQSD)" if is_azerty else "⌨ QWERTY (WASD)")
	if controls_badge:
		controls_badge.text = "PRIMARY AVIONICS: " + avionics_txt
		
	# Populate recent battle log
	if battles_container:
		for c in battles_container.get_children():
			c.queue_free()
			
		var history: Array = st.get("battle_history", [])
		if history.is_empty():
			if no_battles_label: no_battles_label.show()
		else:
			if no_battles_label: no_battles_label.hide()
			# Show up to 8 most recent
			var slice_count = min(8, history.size())
			for i in range(slice_count):
				var b = history[history.size() - 1 - i]
				if typeof(b) != TYPE_DICTIONARY:
					continue
				var row = HBoxContainer.new()
				row.theme_override_constants["separation"] = 10
				
				var date_lbl = Label.new()
				date_lbl.text = str(b.get("date", "RECENT"))
				date_lbl.custom_minimum_size = Vector2(100, 20)
				date_lbl.add_theme_font_size_override("font_size", 10)
				date_lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 0.85))
				row.add_child(date_lbl)
				
				var theater_lbl = Label.new()
				theater_lbl.text = str(b.get("theater", "SORTIE"))
				theater_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				theater_lbl.add_theme_font_size_override("font_size", 11)
				theater_lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
				row.add_child(theater_lbl)
				
				var outcome_lbl = Label.new()
				var out_txt = str(b.get("outcome", "COMPLETE")).to_upper()
				outcome_lbl.text = "[ %s ]" % out_txt
				outcome_lbl.add_theme_font_size_override("font_size", 11)
				if "VICTORY" in out_txt or "WON" in out_txt or "SUCCESS" in out_txt:
					outcome_lbl.add_theme_color_override("font_color", Color(0.1, 0.95, 0.4))
				elif "DEFEAT" in out_txt or "LOST" in out_txt or "MIA" in out_txt:
					outcome_lbl.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
				else:
					outcome_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
				row.add_child(outcome_lbl)
				
				var kills_lbl = Label.new()
				kills_lbl.text = "KILLS: %d" % int(b.get("kills", 0))
				kills_lbl.add_theme_font_size_override("font_size", 11)
				kills_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
				row.add_child(kills_lbl)
				
				battles_container.add_child(row)

func _on_sync_pressed() -> void:
	if status_msg_label:
		status_msg_label.text = "// SYNCHRONIZING DOSSIER WITH CLOUDFLARE EDGE... //"
		status_msg_label.modulate = Color(1.0, 0.85, 0.2)
	var auth_mgr = get_node_or_null("/root/AuthManager")
	if auth_mgr and auth_mgr.has_method("sync_cloud_save"):
		auth_mgr.sync_cloud_save()
	if is_inside_tree() and get_tree():
		get_tree().create_timer(1.2).timeout.connect(func():
			_populate_stats()
			if status_msg_label:
				status_msg_label.text = "// DOSSIER SYNCHRONIZED & SEALED //"
				status_msg_label.modulate = Color(0.1, 0.95, 0.4)
		)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_stats()
		get_viewport().set_input_as_handled()
