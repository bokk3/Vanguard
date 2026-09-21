extends Control

## DebriefScreen: Post-sortie debriefing & mission complete scorecard.
## Features procedural HUD decryption rollups, tally sound synthesis,
## cinematic rank stamp slam with sub-bass audio, and skip capability.

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

# Animation & Audio state
var anim_tween: Tween = null
var is_animating: bool = false
var final_stats_cache: Dictionary = {}
var final_score_cache: Dictionary = {}

var tally_audio_player: AudioStreamPlayer = null
var slam_audio_player: AudioStreamPlayer = null
var last_tally_sound_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	
	scramble_next_btn.pressed.connect(_on_scramble_next_pressed)
	replay_btn.pressed.connect(_on_replay_pressed)
	hangar_btn.pressed.connect(_on_hangar_pressed)
	
	# Audio Players for Procedural SFX
	tally_audio_player = AudioStreamPlayer.new()
	tally_audio_player.name = "TallyAudioPlayer"
	tally_audio_player.bus = "UI"
	var t_sfx = load("res://audio/sfx/sfx_debrief_tally_tick.wav")
	if t_sfx:
		tally_audio_player.stream = t_sfx
	add_child(tally_audio_player)
	
	slam_audio_player = AudioStreamPlayer.new()
	slam_audio_player.name = "SlamAudioPlayer"
	slam_audio_player.bus = "UI"
	var s_sfx = load("res://audio/sfx/sfx_debrief_rank_slam.wav")
	if s_sfx:
		slam_audio_player.stream = s_sfx
	add_child(slam_audio_player)
	
	var mm = get_node_or_null("/root/MissionManager")
	if mm:
		mm.mission_completed.connect(_on_mission_completed)
		mm.mission_failed.connect(_on_mission_failed)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if is_animating:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER]):
			skip_animation()
			get_viewport().set_input_as_handled()

func _on_mission_completed(mission_id: String, stats: Dictionary) -> void:
	current_mission_id = mission_id
	# Delay 3.0 seconds so victory comms can be heard
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
	var destroyed = int(stats.get("targets_destroyed", 0))
	var hit_rate = float(stats.get("hit_rate", 1.0)) * 100.0
	var hull_rem = float(stats.get("hull_remaining", 100.0))
	var cannon_rds = int(stats.get("cannon_expended", 0))
	var score_data = _calculate_rank(elapsed, hit_rate, hull_rem, destroyed)
	
	final_stats_cache = {
		"elapsed": elapsed,
		"destroyed": destroyed,
		"hit_rate": hit_rate,
		"hull_rem": hull_rem,
		"cannon_rds": cannon_rds
	}
	final_score_cache = score_data
	
	# Check for Next Mission
	next_mission_id = ""
	if mm and mm.mission_ids.size() > 0:
		var cur_idx = mm.mission_ids.find(current_mission_id)
		if cur_idx != -1 and cur_idx + 1 < mm.mission_ids.size():
			next_mission_id = mm.mission_ids[cur_idx + 1]
	else:
		var default_chain = ["M01", "M02", "M03", "M04", "M05", "M06", "M07", "M08"]
		var c_idx = default_chain.find(current_mission_id)
		if c_idx != -1 and c_idx + 1 < default_chain.size():
			next_mission_id = default_chain[c_idx + 1]
	
	if not next_mission_id.is_empty():
		var next_data = mm.get_mission(next_mission_id) if mm else {}
		var next_name = next_data.get("codename", "SILENT ORBIT")
		scramble_next_btn.text = "[ SCRAMBLE SORTIE %s: %s ]" % [next_mission_id, next_name]
		scramble_next_btn.visible = true
	else:
		if current_mission_id == "M08":
			scramble_next_btn.text = "[ CHAPTER 2 FINALE & EPILOGUE ]"
			scramble_next_btn.visible = true
		elif current_mission_id == "M04":
			scramble_next_btn.text = "[ CHAPTER 1 FINALE & EPILOGUE ]"
			scramble_next_btn.visible = true
		else:
			scramble_next_btn.visible = false
	
	replay_btn.text = "[ REPLAY SORTIE ]"
	hangar_btn.text = "[ RETURN TO HANGAR ]"
	
	_start_victory_animation(elapsed, destroyed, hit_rate, hull_rem, cannon_rds, score_data)

func _start_victory_animation(elapsed: float, destroyed: int, hit_rate: float, hull_rem: float, cannon_rds: int, score_data: Dictionary) -> void:
	_display_modal()
	is_animating = true
	
	if anim_tween:
		anim_tween.kill()
	
	# Initialize baseline elements
	stat_time_val.text = "00:00"
	stat_targets_val.text = "0 HOSTILES"
	stat_accuracy_val.text = "0%"
	stat_hull_val.text = "0%"
	stat_cannon_val.text = "0 ROUNDS"
	stat_score_val.text = "0 PTS"
	
	rank_badge.text = score_data["rank"]
	rank_badge.add_theme_color_override("font_color", score_data["color"])
	rank_badge.modulate.a = 0.0
	rank_badge.scale = Vector2(2.8, 2.8)
	rank_badge.pivot_offset = Vector2(30, 40)
	
	rank_title.text = score_data["title"]
	rank_title.add_theme_color_override("font_color", score_data["color"])
	rank_title.modulate.a = 0.0
	
	scramble_next_btn.modulate.a = 0.0
	replay_btn.modulate.a = 0.0
	hangar_btn.modulate.a = 0.0
	
	modal_panel.scale = Vector2(0.92, 0.92)
	modal_panel.modulate.a = 0.0
	modal_panel.pivot_offset = Vector2(370, 245)
	
	anim_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# 1. Panel spring in
	anim_tween.tween_property(modal_panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	anim_tween.parallel().tween_property(modal_panel, "modulate:a", 1.0, 0.22)
	
	# 2. Sequential Stats Rollup
	anim_tween.tween_method(_animate_time, 0.0, elapsed, 0.4)
	anim_tween.tween_method(_animate_targets, 0, destroyed, 0.3)
	anim_tween.tween_method(_animate_accuracy, 0.0, hit_rate, 0.35)
	anim_tween.tween_method(_animate_hull, 0.0, hull_rem, 0.35)
	anim_tween.tween_method(_animate_cannon, 0, cannon_rds, 0.3)
	
	# 3. Score count up with tally clicks
	anim_tween.tween_method(_animate_score, 0, score_data["score"], 0.7)
	
	# 4. Suspense pause
	anim_tween.tween_interval(0.2)
	
	# 5. Rank Stamp Slam!
	anim_tween.tween_callback(func():
		rank_badge.modulate.a = 1.0
		_play_rank_slam_sound()
	)
	anim_tween.tween_property(rank_badge, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	anim_tween.parallel().tween_property(rank_title, "modulate:a", 1.0, 0.25)
	
	# 6. Action buttons fade in
	anim_tween.tween_interval(0.15)
	anim_tween.tween_property(scramble_next_btn, "modulate:a", 1.0, 0.2)
	anim_tween.parallel().tween_property(replay_btn, "modulate:a", 1.0, 0.2)
	anim_tween.parallel().tween_property(hangar_btn, "modulate:a", 1.0, 0.2)
	
	anim_tween.tween_callback(func(): is_animating = false)

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
	
	scramble_next_btn.visible = false
	replay_btn.text = "[ RETRY SORTIE ]"
	hangar_btn.text = "[ RETURN TO HANGAR ]"
	
	_display_modal()
	is_animating = true
	
	if anim_tween:
		anim_tween.kill()
	
	modal_panel.scale = Vector2(0.92, 0.92)
	modal_panel.modulate.a = 0.0
	modal_panel.pivot_offset = Vector2(370, 245)
	
	rank_badge.text = "F"
	rank_badge.add_theme_color_override("font_color", Color(1, 0.2, 0.25, 1))
	rank_badge.modulate.a = 0.0
	rank_badge.scale = Vector2(2.8, 2.8)
	rank_badge.pivot_offset = Vector2(30, 40)
	
	rank_title.text = "SORTIE COMPROMISED // RETRY RECOMMENDED"
	rank_title.add_theme_color_override("font_color", Color(1, 0.2, 0.25, 1))
	rank_title.modulate.a = 0.0
	
	replay_btn.modulate.a = 0.0
	hangar_btn.modulate.a = 0.0
	
	anim_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	anim_tween.tween_property(modal_panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	anim_tween.parallel().tween_property(modal_panel, "modulate:a", 1.0, 0.22)
	anim_tween.tween_interval(0.2)
	
	anim_tween.tween_callback(func():
		rank_badge.modulate.a = 1.0
		_play_rank_slam_sound()
	)
	anim_tween.tween_property(rank_badge, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	anim_tween.parallel().tween_property(rank_title, "modulate:a", 1.0, 0.25)
	
	anim_tween.tween_interval(0.15)
	anim_tween.tween_property(replay_btn, "modulate:a", 1.0, 0.2)
	anim_tween.parallel().tween_property(hangar_btn, "modulate:a", 1.0, 0.2)
	anim_tween.tween_callback(func(): is_animating = false)

func skip_animation() -> void:
	if not is_animating:
		return
	if anim_tween:
		anim_tween.kill()
		anim_tween = null
	
	modal_panel.scale = Vector2.ONE
	modal_panel.modulate.a = 1.0
	
	if is_victory and not final_stats_cache.is_empty():
		_animate_time(final_stats_cache["elapsed"])
		_animate_targets(final_stats_cache["destroyed"])
		_animate_accuracy(final_stats_cache["hit_rate"])
		_animate_hull(final_stats_cache["hull_rem"])
		_animate_cannon(final_stats_cache["cannon_rds"])
		_animate_score(final_score_cache["score"])
		
		rank_badge.text = final_score_cache["rank"]
		rank_badge.scale = Vector2.ONE
		rank_badge.modulate.a = 1.0
		rank_title.text = final_score_cache["title"]
		rank_title.modulate.a = 1.0
	else:
		rank_badge.scale = Vector2.ONE
		rank_badge.modulate.a = 1.0
		rank_title.modulate.a = 1.0
	
	scramble_next_btn.modulate.a = 1.0
	replay_btn.modulate.a = 1.0
	hangar_btn.modulate.a = 1.0
	is_animating = false

# -------------------------------------------------------------
# Animation Tick Helpers
# -------------------------------------------------------------
func _animate_time(val: float) -> void:
	var mins = int(val) / 60
	var secs = int(val) % 60
	stat_time_val.text = "%02d:%02d" % [mins, secs]
	_play_tally_tick()

func _animate_targets(val: int) -> void:
	stat_targets_val.text = "%d HOSTILES SPLASHED" % val
	_play_tally_tick()

func _animate_accuracy(val: float) -> void:
	stat_accuracy_val.text = "%d%% MISSILE LOCK" % int(val)
	_play_tally_tick()

func _animate_hull(val: float) -> void:
	stat_hull_val.text = "%d%% COMPOSITE" % int(val)
	_play_tally_tick()

func _animate_cannon(val: int) -> void:
	stat_cannon_val.text = "%d ROUNDS" % val
	_play_tally_tick()

func _animate_score(val: int) -> void:
	stat_score_val.text = "%d PTS" % val
	_play_tally_tick()

func _play_tally_tick() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_tally_sound_time > 0.045:
		last_tally_sound_time = now
		if tally_audio_player:
			tally_audio_player.play()

func _play_rank_slam_sound() -> void:
	if slam_audio_player:
		slam_audio_player.play()

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
	var mm = get_node_or_null("/root/MissionManager")
	get_tree().paused = false
	
	if next_mission_id.is_empty():
		if current_mission_id == "M08":
			if mm:
				mm.pending_interlude_id = "EPILOGUE_CH2"
			get_tree().change_scene_to_file("res://interlude_cutscene.tscn")
			return
		elif current_mission_id == "M04":
			if mm:
				mm.pending_interlude_id = "EPILOGUE_CH1"
			get_tree().change_scene_to_file("res://interlude_cutscene.tscn")
			return
		_on_hangar_pressed()
		return
	
	var interlude_map = {
		"M02": "INT_M01_M02",
		"M03": "INT_M02_M03",
		"M04": "INT_M03_M04",
		"M05": "INT_M04_M05",
		"M06": "INT_M05_M06",
		"M07": "INT_M06_M07",
		"M08": "INT_M07_M08"
	}
	
	if interlude_map.has(next_mission_id):
		if mm:
			mm.pending_interlude_id = interlude_map[next_mission_id]
			mm.current_mission_id = next_mission_id
		get_tree().change_scene_to_file("res://interlude_cutscene.tscn")
	else:
		if mm:
			mm.current_mission_id = next_mission_id
		get_tree().reload_current_scene()

func _on_replay_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_hangar_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://home_menu.tscn")
