class_name AgilityHUD
extends Control

## AgilityHUD: Flight Chronometer & Aerobatic Telemetry Cockpit Overlay.
## Displays millisecond lap times, apex precision ratings, Flow State combo gauge,
## maneuver popups, split delta benchmarks, and debrief summary.

signal retry_requested()
signal selector_requested()

# Top Telemetry
@onready var chrono_label: Label = %ChronoLabel
@onready var delta_label: Label = %DeltaLabel
@onready var gate_label: Label = %GateLabel
@onready var apex_grade_label: Label = %ApexGradeLabel

# Flow & Maneuvers
@onready var flow_label: Label = %FlowLabel
@onready var flow_bar: ProgressBar = %FlowBar
@onready var maneuver_banner: PanelContainer = %ManeuverBanner
@onready var maneuver_label: Label = %ManeuverLabel
@onready var targets_label: Label = %TargetsLabel
@onready var ghost_status_label: Label = %GhostStatusLabel

# Debrief Modal
@onready var debrief_panel: PanelContainer = %DebriefPanel
@onready var debrief_title: Label = %DebriefTitle
@onready var debrief_medal: Label = %DebriefMedal
@onready var debrief_time: Label = %DebriefTime
@onready var debrief_precision: Label = %DebriefPrecision
@onready var debrief_maneuvers: Label = %DebriefManeuvers
@onready var debrief_stars: Label = %DebriefStars
@onready var debrief_score: Label = %DebriefScore
@onready var retry_btn: Button = %RetryBtn
@onready var exit_btn: Button = %ExitBtn

var banner_hide_timer: float = 0.0
var apex_hide_timer: float = 0.0
var _cached_am: Node = null

func _get_am() -> Node:
	if not is_instance_valid(_cached_am):
		_cached_am = get_node_or_null("/root/AgilityManager")
	return _cached_am

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if debrief_panel: debrief_panel.hide()
	if maneuver_banner: maneuver_banner.hide()
	if apex_grade_label: apex_grade_label.hide()
	
	if retry_btn: retry_btn.pressed.connect(func(): retry_requested.emit())
	if exit_btn: exit_btn.pressed.connect(func(): selector_requested.emit())
	
	var am = _get_am()
	if am:
		if not am.gate_passed.is_connected(_on_gate_passed):
			am.gate_passed.connect(_on_gate_passed)
		if not am.maneuver_detected.is_connected(_on_maneuver_detected):
			am.maneuver_detected.connect(_on_maneuver_detected)
		if not am.target_destroyed.is_connected(_on_target_destroyed):
			am.target_destroyed.connect(_on_target_destroyed)
		if not am.trial_completed.is_connected(_on_trial_completed):
			am.trial_completed.connect(_on_trial_completed)
		if not am.trial_failed.is_connected(_on_trial_failed):
			am.trial_failed.connect(_on_trial_failed)
		if not am.ghost_toggled.is_connected(_on_ghost_toggled):
			am.ghost_toggled.connect(_on_ghost_toggled)
		_update_ghost_ui(am.ghost_enabled)

func _exit_tree() -> void:
	var am = _get_am()
	if am:
		if am.gate_passed.is_connected(_on_gate_passed):
			am.gate_passed.disconnect(_on_gate_passed)
		if am.maneuver_detected.is_connected(_on_maneuver_detected):
			am.maneuver_detected.disconnect(_on_maneuver_detected)
		if am.target_destroyed.is_connected(_on_target_destroyed):
			am.target_destroyed.disconnect(_on_target_destroyed)
		if am.trial_completed.is_connected(_on_trial_completed):
			am.trial_completed.disconnect(_on_trial_completed)
		if am.trial_failed.is_connected(_on_trial_failed):
			am.trial_failed.disconnect(_on_trial_failed)
		if am.ghost_toggled.is_connected(_on_ghost_toggled):
			am.ghost_toggled.disconnect(_on_ghost_toggled)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			var am = _get_am()
			if am and am.has_method("toggle_ghost"):
				am.toggle_ghost()
				get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var am = _get_am()
	if am and am.is_trial_active:
		# Format Chronometer: MM:SS.mmm
		var total_s = am.elapsed_time + am.penalty_time
		var mins = int(total_s / 60.0)
		var secs = int(fmod(total_s, 60.0))
		var ms = int(fmod(total_s * 1000.0, 1000.0))
		if chrono_label:
			chrono_label.text = "%02d:%02d.%03d" % [mins, secs, ms]
			
		# Update Split Delta against Gold benchmark
		var t_def = am.TRIALS_DEF.get(am.active_trial_id, {})
		var gold_time = t_def.get("gold_time", 60.0)
		var progress = float(am.current_gate_idx) / float(max(1, am.total_gates_in_trial))
		var expected_time = gold_time * progress
		var diff = total_s - expected_time
		if delta_label:
			if diff <= 0.0:
				delta_label.text = "▼ %.2fs [GOLD PACE]" % diff
				delta_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.55))
			else:
				delta_label.text = "▲ +%.2fs" % diff
				delta_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.2))
				
		# Update Flow State
		if flow_label:
			flow_label.text = "FLOW: %.1fx" % am.flow_multiplier
		if flow_bar:
			flow_bar.value = (am.flow_multiplier - 1.0) / 2.0 * 100.0
			
	# Fade banners
	if banner_hide_timer > 0.0:
		banner_hide_timer -= delta
		if banner_hide_timer <= 0.0 and maneuver_banner:
			maneuver_banner.hide()
			
	if apex_hide_timer > 0.0:
		apex_hide_timer -= delta
		if apex_hide_timer <= 0.0 and apex_grade_label:
			apex_grade_label.hide()

func _on_gate_passed(cur_gate: int, total_gates: int, grade: String, _rad: float, _mult: float) -> void:
	if gate_label:
		gate_label.text = "GATE %02d / %02d" % [cur_gate, total_gates]
	if apex_grade_label:
		apex_grade_label.text = "[ %s ]" % grade
		if grade == "PERFECT APEX":
			apex_grade_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
		elif grade == "CLEAN":
			apex_grade_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.55))
		else:
			apex_grade_label.add_theme_color_override("font_color", Color(0.96, 0.62, 0.04))
		apex_grade_label.show()
		apex_hide_timer = 1.6

func _on_maneuver_detected(m_type: String, score_bonus: int, time_bonus: float) -> void:
	if maneuver_banner and maneuver_label:
		maneuver_label.text = "⚡ SPECIAL MANEUVER: %s [ +%d PTS // -%.1fs ]" % [
			m_type.replace("_", " "), score_bonus, time_bonus
		]
		maneuver_banner.show()
		banner_hide_timer = 2.4

func _on_target_destroyed(_idx: int, remaining: int) -> void:
	if targets_label:
		targets_label.text = "🎯 TARGETS REMAINING: %d" % remaining

func _on_ghost_toggled(enabled: bool) -> void:
	_update_ghost_ui(enabled)

func _update_ghost_ui(enabled: bool) -> void:
	if ghost_status_label:
		ghost_status_label.text = "👻 GHOST: %s [G]" % ("ON" if enabled else "OFF")
		ghost_status_label.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0) if enabled else Color(0.5, 0.55, 0.65))

func _on_trial_completed(_t_id: String, stats: Dictionary) -> void:
	if not debrief_panel:
		return
		
	var final_time = float(stats.get("final_time", 0.0))
	var mins = int(final_time / 60.0)
	var secs = int(fmod(final_time, 60.0))
	var ms = int(fmod(final_time * 1000.0, 1000.0))
	
	var medal_str = str(stats.get("medal", "NONE"))
	var medal_icon = "🥉"
	var medal_color = Color(0.85, 0.55, 0.25)
	match medal_str:
		"ACE":
			medal_icon = "🏆"
			medal_color = Color(0.4, 0.9, 1.0)
		"GOLD":
			medal_icon = "🥇"
			medal_color = Color(1.0, 0.85, 0.2)
		"SILVER":
			medal_icon = "🥈"
			medal_color = Color(0.85, 0.9, 0.95)
		"BRONZE":
			medal_icon = "🥉"
			medal_color = Color(0.85, 0.55, 0.25)
		_:
			medal_icon = "⚪"
			medal_color = Color(0.6, 0.65, 0.75)
			
	if debrief_title:
		debrief_title.text = "TRIAL DEBRIEF: %s" % stats.get("trial_id", "T01")
	if debrief_medal:
		debrief_medal.text = "%s %s MEDAL AWARDED" % [medal_icon, medal_str]
		debrief_medal.add_theme_color_override("font_color", medal_color)
	if debrief_time:
		debrief_time.text = "TIME: %02d:%02d.%03d (Penalties: +%.1fs)" % [mins, secs, ms, stats.get("penalty_time", 0.0)]
	if debrief_precision:
		debrief_precision.text = "APEX PRECISION: %.1f%% (Perfect: %d, Clean: %d, Miss: %d)" % [
			stats.get("precision_pct", 0.0),
			stats.get("perfect_apexes", 0),
			stats.get("clean_apexes", 0),
			stats.get("missed_gates", 0)
		]
	if debrief_maneuvers:
		debrief_maneuvers.text = "MANEUVERS & TARGETS: %d Stunts | %d/%d Buoys Destroyed" % [
			stats.get("maneuvers_count", 0),
			stats.get("targets_hit", 0),
			stats.get("total_targets", 0)
		]
	if debrief_score:
		debrief_score.text = "TOTAL FLIGHT SCORE: %d PTS" % stats.get("final_score", 0)
		
	var am = get_node_or_null("/root/AgilityManager")
	if debrief_stars and am:
		debrief_stars.text = "AVIONICS RATING: %d PTS // %s" % [am.avionics_score, am.avionics_class]
		
	debrief_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_trial_failed(trial_id: String, reason: String) -> void:
	if not debrief_panel:
		return
		
	var am = get_node_or_null("/root/AgilityManager")
	var final_time = am.elapsed_time if am else 0.0
	var mins = int(final_time / 60.0)
	var secs = int(fmod(final_time, 60.0))
	var ms = int(fmod(final_time * 1000.0, 1000.0))
	
	if chrono_label:
		chrono_label.text = "%02d:%02d.%03d" % [mins, secs, ms]
	if delta_label:
		delta_label.text = "▲ AIRFRAME LOST"
		delta_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	if debrief_title:
		debrief_title.text = "TRIAL ABORTED // %s" % trial_id
		debrief_title.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	if debrief_medal:
		debrief_medal.text = "💥 %s" % reason.to_upper()
		debrief_medal.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	if debrief_time:
		debrief_time.text = "TERMINATION TIME: %02d:%02d.%03d" % [mins, secs, ms]
	if debrief_precision:
		debrief_precision.text = "STATUS: FLIGHT RECORDER TERMINATED"
		debrief_precision.add_theme_color_override("font_color", Color(0.85, 0.45, 0.45))
	if debrief_maneuvers:
		debrief_maneuvers.text = "GATES CLEARED: %d / %d" % [
			am.current_gate_idx if am else 0,
			am.total_gates_in_trial if am else 0
		]
	if debrief_score:
		debrief_score.text = "TOTAL FLIGHT SCORE: 0 PTS [DISQUALIFIED]"
		debrief_score.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	if debrief_stars and am:
		debrief_stars.text = "AVIONICS RATING: %d PTS // %s" % [am.avionics_score, am.avionics_class]
		
	debrief_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

