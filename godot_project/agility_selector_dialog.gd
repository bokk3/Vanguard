class_name AgilitySelectorDialog
extends Control

## AgilitySelectorDialog: Mission selection terminal for the 8 Agility Flight Trials.
## Displays live medal status, avionics expertise score, best lap times,
## star reward bounties, and ghost replay toggle.

signal closed()
signal trial_launched(trial_id: String)

@onready var close_btn: Button = %CloseBtn
@onready var pilot_tag_label: Label = %PilotTagLabel
@onready var avionics_score_label: Label = %AvionicsScoreLabel
@onready var medals_tally_label: Label = %MedalsTallyLabel
@onready var ghost_toggle_btn: Button = %GhostToggleBtn
@onready var trials_grid: GridContainer = %TrialsGrid

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if close_btn:
		close_btn.pressed.connect(hide_selector)
	if ghost_toggle_btn:
		ghost_toggle_btn.pressed.connect(_on_ghost_toggle_pressed)
		
	var am = get_node_or_null("/root/AgilityManager")
	if am:
		if not am.ghost_toggled.is_connected(_update_ghost_button):
			am.ghost_toggled.connect(_update_ghost_button)
		if not am.avionics_score_updated.is_connected(_on_avionics_score_updated):
			am.avionics_score_updated.connect(_on_avionics_score_updated)

func _exit_tree() -> void:
	var am = get_node_or_null("/root/AgilityManager")
	if am:
		if am.ghost_toggled.is_connected(_update_ghost_button):
			am.ghost_toggled.disconnect(_update_ghost_button)
		if am.avionics_score_updated.is_connected(_on_avionics_score_updated):
			am.avionics_score_updated.disconnect(_on_avionics_score_updated)

func _on_avionics_score_updated(_score: int, _class_rank: String) -> void:
	_refresh_header()

func show_selector() -> void:
	_refresh_header()
	_populate_trials()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_selector() -> void:
	visible = false
	closed.emit()

func _on_ghost_toggle_pressed() -> void:
	var am = get_node_or_null("/root/AgilityManager")
	if am and am.has_method("toggle_ghost"):
		am.toggle_ghost()

func _update_ghost_button(enabled: bool) -> void:
	if ghost_toggle_btn:
		ghost_toggle_btn.text = "👻 GHOST: %s" % ("ON" if enabled else "OFF")
		ghost_toggle_btn.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0) if enabled else Color(0.55, 0.6, 0.7))

func _refresh_header() -> void:
	var am = get_node_or_null("/root/AgilityManager")
	var auth_mgr = get_node_or_null("/root/AuthManager")
	
	if pilot_tag_label and auth_mgr:
		var cs = auth_mgr.callsign if not auth_mgr.callsign.is_empty() else "LOCAL-PILOT"
		pilot_tag_label.text = "PILOT: %s // %s" % [cs, auth_mgr.rank]
		
	if am:
		if avionics_score_label:
			avionics_score_label.text = "AVIONICS RATING: %d PTS // %s" % [am.avionics_score, am.avionics_class]
			
		if medals_tally_label:
			var tally = am.get_medals_tally()
			medals_tally_label.text = "MEDALS: 🏆 %d  🥇 %d  🥈 %d  🥉 %d" % [
				tally.get("ACE", 0), tally.get("GOLD", 0), tally.get("SILVER", 0), tally.get("BRONZE", 0)
			]
			
		_update_ghost_button(am.ghost_enabled)

func _populate_trials() -> void:
	if not trials_grid:
		return
		
	for c in trials_grid.get_children():
		c.queue_free()
		
	var am = get_node_or_null("/root/AgilityManager")
	if not am:
		return
		
	for t_id in ["T01", "T02", "T03", "T04", "T05", "T06", "T07", "T08"]:
		var t_data = am.TRIALS_DEF.get(t_id, {})
		var rec = am.trial_records.get(t_id, {})
		
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(260, 275)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Skunk Works Card Style
		var box = StyleBoxFlat.new()
		box.content_margin_left = 14.0
		box.content_margin_top = 12.0
		box.content_margin_right = 14.0
		box.content_margin_bottom = 12.0
		box.bg_color = Color(0.08, 0.10, 0.14, 0.95)
		box.border_width_left = 3
		box.border_width_top = 1
		box.border_width_right = 1
		box.border_width_bottom = 1
		box.border_color = Color(0.96, 0.62, 0.04, 0.75) if rec.has("medal") and rec["medal"] != "NONE" else Color(0.25, 0.30, 0.38, 0.5)
		box.corner_radius_top_left = 4
		box.corner_radius_top_right = 4
		box.corner_radius_bottom_right = 4
		box.corner_radius_bottom_left = 4
		card.add_theme_stylebox_override("panel", box)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		card.add_child(vbox)

		# Trial Tactical Preview Thumbnail
		var card_tex_path = "res://ui/trials/trial_card_%s.png" % t_id.to_lower()
		if ResourceLoader.exists(card_tex_path):
			var tex_rect = TextureRect.new()
			tex_rect.custom_minimum_size = Vector2(0, 68)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tex_rect.texture = load(card_tex_path)
			vbox.add_child(tex_rect)
		
		# Header: Trial ID & Codename
		var h_top = HBoxContainer.new()
		var id_lbl = Label.new()
		id_lbl.text = "[%s]" % t_id
		id_lbl.add_theme_color_override("font_color", Color(0.96, 0.62, 0.04))
		id_lbl.add_theme_font_size_override("font_size", 12)
		h_top.add_child(id_lbl)
		
		var name_lbl = Label.new()
		name_lbl.text = " " + t_data.get("codename", "")
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_top.add_child(name_lbl)
		
		# Current Medal Badge
		var medal_str = rec.get("medal", "NONE")
		var medal_badge = Label.new()
		var medal_icon = "⚪"
		match medal_str:
			"ACE": medal_icon = "🏆 ACE"
			"GOLD": medal_icon = "🥇 GOLD"
			"SILVER": medal_icon = "🥈 SILVER"
			"BRONZE": medal_icon = "🥉 BRONZE"
			_: medal_icon = "⚪ UNRANKED"
		medal_badge.text = medal_icon
		medal_badge.add_theme_font_size_override("font_size", 10)
		medal_badge.add_theme_color_override("font_color", Color(1, 0.85, 0.2) if medal_str in ["GOLD", "ACE"] else Color(0.7, 0.75, 0.85))
		h_top.add_child(medal_badge)
		vbox.add_child(h_top)
		
		# Description
		var desc_lbl = Label.new()
		desc_lbl.text = t_data.get("desc", "")
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
		vbox.add_child(desc_lbl)
		
		# Telemetry Row: Best Time & Targets
		var best_time = float(rec.get("best_time", 0.0))
		var time_str = "--:--.---"
		if best_time > 0.0:
			var mins = int(best_time / 60.0)
			var secs = int(fmod(best_time, 60.0))
			var ms = int(fmod(best_time * 1000.0, 1000.0))
			time_str = "%02d:%02d.%03d" % [mins, secs, ms]
			
		var stats_row = HBoxContainer.new()
		var time_lbl = Label.new()
		time_lbl.text = "BEST: %s" % time_str
		time_lbl.add_theme_color_override("font_color", Color(0.2, 0.85, 0.55) if best_time > 0.0 else Color(0.5, 0.55, 0.65))
		time_lbl.add_theme_font_size_override("font_size", 11)
		time_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_row.add_child(time_lbl)
		
		var targets_lbl = Label.new()
		targets_lbl.text = "🎯 %d BUOYS" % t_data.get("total_targets", 4)
		targets_lbl.add_theme_color_override("font_color", Color(1, 0.55, 0.2))
		targets_lbl.add_theme_font_size_override("font_size", 10)
		stats_row.add_child(targets_lbl)
		vbox.add_child(stats_row)
		
		# Benchmarks info
		var bench_lbl = Label.new()
		bench_lbl.text = "GOLD: %.1fs (⭐ 500) | ACE: %.1fs (⭐ 1000)" % [
			t_data.get("gold_time", 60.0), t_data.get("ace_time", 50.0)
		]
		bench_lbl.add_theme_font_size_override("font_size", 9)
		bench_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
		vbox.add_child(bench_lbl)
		
		# Action Button
		var fly_btn = Button.new()
		fly_btn.text = "🚀  COMMENCE TRIAL"
		fly_btn.custom_minimum_size = Vector2(0, 32)
		fly_btn.add_theme_font_size_override("font_size", 11)
		
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.85, 0.52, 0.02, 0.9)
		btn_style.border_width_left = 2
		btn_style.border_color = Color(1, 0.78, 0.15)
		btn_style.corner_radius_top_left = 3
		btn_style.corner_radius_top_right = 3
		btn_style.corner_radius_bottom_right = 3
		btn_style.corner_radius_bottom_left = 3
		fly_btn.add_theme_stylebox_override("normal", btn_style)
		fly_btn.add_theme_color_override("font_color", Color(1, 1, 1))
		
		var this_tid = t_id
		fly_btn.pressed.connect(func(): _launch_trial(this_tid))
		vbox.add_child(fly_btn)
		
		trials_grid.add_child(card)

func _launch_trial(trial_id: String) -> void:
	hide_selector()
	trial_launched.emit(trial_id)
	
	var am = get_node_or_null("/root/AgilityManager")
	if am:
		am.active_trial_id = trial_id
		
	var scene_path = "res://agility_courses/trial_%s.tscn" % (
		"01_slalom" if trial_id == "T01" else
		"02_canyon" if trial_id == "T02" else
		"03_knife_edge" if trial_id == "T03" else
		"04_stratosphere" if trial_id == "T04" else
		"05_drift" if trial_id == "T05" else
		"06_gauntlet" if trial_id == "T06" else
		"07_blind" if trial_id == "T07" else "08_crucible"
	)
	
	get_tree().change_scene_to_file(scene_path)
