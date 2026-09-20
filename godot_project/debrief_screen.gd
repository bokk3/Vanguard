extends Control

## DebriefScreen: Post-sortie debriefing & mission complete scorecard.
## Displays mission performance stats, calculates pilot rank (S/A/B/C),
## and offers options to advance to the next mission, replay, or RTB.

@onready var modal_panel: PanelContainer = %ModalPanel
@onready var banner_title: Label = %BannerTitle
@onready var banner_subtitle: Label = %BannerSubtitle

@onready var stat_time_val: Label = %StatTimeVal
@onready var stat_targets_val: Label = %StatTargetsVal
@onready var stat_accuracy_val: Label = %StatAccuracyVal
@onready var stat_hull_val: Label = %StatHullVal
@onready var stat_cannon_val: Label = %StatCannonVal
@onready var stat_score_val: Label = %StatScoreVal

@onready var rank_badge: Label = %RankBadge
@onready var rank_title: Label = %RankTitle

@onready var scramble_next_btn: Button = %ScrambleNextBtn
@onready var replay_btn: Button = %ReplayBtn
@onready var hangar_btn: Button = %HangarBtn

var next_mission_id: String = ""
var current_mission_id: String = "M01"
var is_victory: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	
	scramble_next_btn.pressed.connect(_on_scramble_next_pressed)
	replay_btn.pressed.connect(_on_replay_pressed)
	hangar_btn.pressed.connect(_on_hangar_pressed)
	
	var mm = get_node_or_null("/root/MissionManager")
	if mm:
		mm.mission_completed.connect(_on_mission_completed)
		mm.mission_failed.connect(_on_mission_failed)

func _on_mission_completed(mission_id: String, stats: Dictionary) -> void:
	current_mission_id = mission_id
	# Delay 3.0 seconds so victory comms ("Good splashes, Vanguard 1...") can be heard
	get_tree().create_timer(3.0, true, false, true).timeout.connect(func():
		show_victory_debrief(stats)
	)

func _on_mission_failed(mission_id: String, reason: String) -> void:
	current_mission_id = mission_id
	# Delay 2.2 seconds so failure comms finish
	get_tree().create_timer(2.2, true, false, true).timeout.connect(func():
		show_failure_debrief(reason)
	)

func _ensure_references() -> void:
	if not modal_panel: modal_panel = find_child("ModalPanel", true, false)
	if not banner_title: banner_title = find_child("BannerTitle", true, false)
	if not banner_subtitle: banner_subtitle = find_child("BannerSubtitle", true, false)
	if not stat_time_val: stat_time_val = find_child("StatTimeVal", true, false)
	if not stat_targets_val: stat_targets_val = find_child("StatTargetsVal", true, false)
	if not stat_accuracy_val: stat_accuracy_val = find_child("StatAccuracyVal", true, false)
	if not stat_hull_val: stat_hull_val = find_child("StatHullVal", true, false)
	if not stat_cannon_val: stat_cannon_val = find_child("StatCannonVal", true, false)
	if not stat_score_val: stat_score_val = find_child("StatScoreVal", true, false)
	if not rank_badge: rank_badge = find_child("RankBadge", true, false)
	if not rank_title: rank_title = find_child("RankTitle", true, false)
	if not scramble_next_btn: scramble_next_btn = find_child("ScrambleNextBtn", true, false)
	if not replay_btn: replay_btn = find_child("ReplayBtn", true, false)
	if not hangar_btn: hangar_btn = find_child("HangarBtn", true, false)

func show_victory_debrief(stats: Dictionary) -> void:
	_ensure_references()
	is_victory = true
	var mm = get_node_or_null("/root/MissionManager") if is_inside_tree() else null
	var mission_data = mm.get_mission(current_mission_id) if mm else {}
	var codename = mission_data.get("codename", "CLOUDBURST")
	
	banner_title.text = "◈ MISSION ACCOMPLISHED // CORRIDOR SECURED ◈"
	banner_title.add_theme_color_override("font_color", Color(0, 0.95, 1, 1))
	banner_subtitle.text = "SORTIE [%s] %s — ALL MANDATORY OBJECTIVES NOMINAL" % [current_mission_id, codename]
	
	var elapsed = float(stats.get("elapsed_time", 0.0))
	var mins = int(elapsed) / 60
	var secs = int(elapsed) % 60
	stat_time_val.text = "%02d:%02d" % [mins, secs]
	
	var destroyed = int(stats.get("targets_destroyed", 0))
	stat_targets_val.text = "%d HOSTILES SPLASHED" % destroyed
	
	var hit_rate = float(stats.get("hit_rate", 1.0)) * 100.0
	stat_accuracy_val.text = "%d%% MISSILE LOCK" % int(hit_rate)
	
	var hull_rem = float(stats.get("hull_remaining", 100.0))
	stat_hull_val.text = "%d%% COMPOSITE" % int(hull_rem)
	
	var cannon_rds = int(stats.get("cannon_expended", 0))
	stat_cannon_val.text = "%d ROUNDS" % cannon_rds
	
	# Score & Rank Calculation
	var score_data = _calculate_rank(elapsed, hit_rate, hull_rem, destroyed)
	stat_score_val.text = "%d PTS" % score_data["score"]
	rank_badge.text = score_data["rank"]
	rank_badge.add_theme_color_override("font_color", score_data["color"])
	rank_title.text = score_data["title"]
	rank_title.add_theme_color_override("font_color", score_data["color"])
	
	# Check for Next Mission
	next_mission_id = ""
	if mm and mm.mission_ids.size() > 0:
		var cur_idx = mm.mission_ids.find(current_mission_id)
		if cur_idx != -1 and cur_idx + 1 < mm.mission_ids.size():
			next_mission_id = mm.mission_ids[cur_idx + 1]
	else:
		var default_chain = ["M01", "M02", "M03", "M04"]
		var c_idx = default_chain.find(current_mission_id)
		if c_idx != -1 and c_idx + 1 < default_chain.size():
			next_mission_id = default_chain[c_idx + 1]
	
	if not next_mission_id.is_empty():
		var next_data = mm.get_mission(next_mission_id) if mm else {}
		var next_name = next_data.get("codename", "IRON CANYON")
		scramble_next_btn.text = "[ SCRAMBLE SORTIE %s: %s ]" % [next_mission_id, next_name]
		scramble_next_btn.visible = true
	else:
		scramble_next_btn.visible = false
	
	replay_btn.text = "[ REPLAY SORTIE ]"
	hangar_btn.text = "[ RETURN TO HANGAR ]"
	
	_display_modal()

func show_failure_debrief(reason: String) -> void:
	_ensure_references()
	is_victory = false
	banner_title.text = "◈ MISSION FAILED // TELEMETRY LOST ◈"
	banner_title.add_theme_color_override("font_color", Color(1, 0.2, 0.25, 1))
	banner_subtitle.text = "SORTIE [%s] ABORTED — REASON: %s" % [current_mission_id, reason.to_upper()]
	
	stat_time_val.text = "--:--"
	stat_targets_val.text = "OBJECTIVE UNMET"
	stat_accuracy_val.text = "OFFLINE"
	stat_hull_val.text = "0% BREACHED"
	stat_cannon_val.text = "--"
	stat_score_val.text = "0 PTS"
	
	rank_badge.text = "F"
	rank_badge.add_theme_color_override("font_color", Color(1, 0.2, 0.25, 1))
	rank_title.text = "SORTIE COMPROMISED // RETRY RECOMMENDED"
	rank_title.add_theme_color_override("font_color", Color(1, 0.2, 0.25, 1))
	
	scramble_next_btn.visible = false
	replay_btn.text = "[ RETRY SORTIE ]"
	hangar_btn.text = "[ RETURN TO HANGAR ]"
	
	_display_modal()

func _calculate_rank(elapsed: float, accuracy: float, hull: float, _kills: int) -> Dictionary:
	var base_score = 10000
	var time_bonus = max(0, int((150.0 - elapsed) * 60.0))
	var acc_bonus = int((accuracy / 100.0) * 4000.0)
	var hull_bonus = int((hull / 100.0) * 3000.0)
	var total = base_score + time_bonus + acc_bonus + hull_bonus
	
	if total >= 18000 and accuracy >= 75.0 and hull >= 75.0:
		return {
			"rank": "S",
			"title": "APEX PREDATOR // S-RANK ACCOMPLISHMENT",
			"color": Color(1.0, 0.84, 0.0, 1.0),
			"score": total
		}
	elif total >= 14000:
		return {
			"rank": "A",
			"title": "VANGUARD ACE // SUPERIOR COMBAT READINESS",
			"color": Color(0.0, 0.92, 1.0, 1.0),
			"score": total
		}
	elif total >= 10000:
		return {
			"rank": "B",
			"title": "TACTICAL PASS // MISSION OBJECTIVES SATISFIED",
			"color": Color(0.2, 1.0, 0.4, 1.0),
			"score": total
		}
	else:
		return {
			"rank": "C",
			"title": "COMBAT EFFECTIVE // QUALIFIED COMPLETION",
			"color": Color(1.0, 0.6, 0.2, 1.0),
			"score": total
		}

func _display_modal() -> void:
	if is_inside_tree() and get_tree():
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()

func _on_scramble_next_pressed() -> void:
	if next_mission_id.is_empty():
		_on_hangar_pressed()
		return
	
	var mm = get_node_or_null("/root/MissionManager")
	if mm:
		mm.current_mission_id = next_mission_id
	
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_replay_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_hangar_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://home_menu.tscn")
