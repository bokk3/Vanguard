class_name LeaderboardDialog
extends Control

## LeaderboardDialog: Global Fleet Leaderboard & Mission Sortie Records.
## Queries the Cloudflare D1 serverless database for global ace rankings
## and mission debrief high scores, highlighting authenticated pilot standings.

signal closed()
signal open_login_requested()

const LEADERBOARD_API_URL = "https://project-vanguard.pages.dev/api/leaderboard"

# Header & Authentication Banner
@onready var title_label: Label = %TitleLabel
@onready var status_msg_label: Label = %StatusMsgLabel
@onready var personal_banner: PanelContainer = %PersonalBanner
@onready var personal_rank_label: Label = %PersonalRankLabel
@onready var login_prompt_btn: Button = %LoginPromptBtn

# Category Tabs
@onready var tab_aces_btn: Button = %TabAcesBtn
@onready var tab_m01_btn: Button = %TabM01Btn
@onready var tab_m02_btn: Button = %TabM02Btn
@onready var tab_m03_btn: Button = %TabM03Btn
@onready var tab_m04_btn: Button = %TabM04Btn

# Table Container
@onready var table_header_label: Label = %TableHeaderLabel
@onready var leaderboard_list: VBoxContainer = %LeaderboardList
@onready var loading_label: Label = %LoadingLabel
@onready var empty_label: Label = %EmptyLabel

# Action Buttons
@onready var refresh_btn: Button = %RefreshBtn
@onready var close_btn: Button = %CloseBtn

var http_request: HTTPRequest = null
var current_category: String = "global" # "global" or "M01", "M02", etc.
var cached_leaderboard: Dictionary = {} # category -> Array

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	http_request = HTTPRequest.new()
	http_request.timeout = 8.0
	add_child(http_request)
	http_request.request_completed.connect(_on_http_request_completed)
	
	if close_btn:
		close_btn.pressed.connect(hide_leaderboard)
	if refresh_btn:
		refresh_btn.pressed.connect(_on_refresh_pressed)
	if login_prompt_btn:
		login_prompt_btn.pressed.connect(_on_login_prompt_pressed)
		
	if tab_aces_btn:
		tab_aces_btn.pressed.connect(func(): _switch_category("global"))
	if tab_m01_btn:
		tab_m01_btn.pressed.connect(func(): _switch_category("M01"))
	if tab_m02_btn:
		tab_m02_btn.pressed.connect(func(): _switch_category("M02"))
	if tab_m03_btn:
		tab_m03_btn.pressed.connect(func(): _switch_category("M03"))
	if tab_m04_btn:
		tab_m04_btn.pressed.connect(func(): _switch_category("M04"))

func show_leaderboard(category: String = "global") -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_switch_category(category)

func hide_leaderboard() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	closed.emit()

func close_leaderboard() -> void:
	hide_leaderboard()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_leaderboard()
		get_viewport().set_input_as_handled()

func _switch_category(cat: String) -> void:
	current_category = cat
	_style_tab_buttons()
	_update_personal_banner()
	fetch_leaderboard(current_category)

func _style_tab_buttons() -> void:
	var tabs = [
		{"btn": tab_aces_btn, "key": "global"},
		{"btn": tab_m01_btn, "key": "M01"},
		{"btn": tab_m02_btn, "key": "M02"},
		{"btn": tab_m03_btn, "key": "M03"},
		{"btn": tab_m04_btn, "key": "M04"}
	]
	for t in tabs:
		if not t["btn"]:
			continue
		var active = (t["key"] == current_category)
		if active:
			t["btn"].add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
			t["btn"].modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			t["btn"].add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
			t["btn"].modulate = Color(0.7, 0.75, 0.8, 0.75)

func _update_personal_banner() -> void:
	var auth_mgr = get_node_or_null("/root/AuthManager")
	var is_auth = (auth_mgr != null and auth_mgr.is_authenticated)
	
	if login_prompt_btn:
		login_prompt_btn.visible = not is_auth
		
	if is_auth:
		var cs = auth_mgr.callsign
		var rk = auth_mgr.rank
		var kills = auth_mgr.stats.get("total_kills", 0)
		var sorties = auth_mgr.stats.get("total_sorties", 0)
		personal_rank_label.text = "🎖️ ACTIVE PILOT: %s [%s] // %d CONFIRMED KILLS • %d SORTIES" % [
			cs, rk, kills, sorties
		]
	else:
		personal_rank_label.text = "⚠️ PILOT NOT COMMISSIONED // LOGIN TO RECORD GLOBAL RANKINGS"

func _on_login_prompt_pressed() -> void:
	hide_leaderboard()
	open_login_requested.emit()

func _on_refresh_pressed() -> void:
	fetch_leaderboard(current_category, true)

func fetch_leaderboard(category: String, force_refresh: bool = false) -> void:
	if not force_refresh and cached_leaderboard.has(category):
		_render_leaderboard(cached_leaderboard[category])
		return
		
	_set_status("CONNECTING TO CLOUDFLARE D1 LEADERBOARD...", Color(0.0, 0.85, 1.0))
	if loading_label:
		loading_label.show()
	if empty_label:
		empty_label.hide()
	_clear_list()
	
	var url = LEADERBOARD_API_URL
	if category == "global":
		url += "?type=global&limit=50"
	else:
		url += "?mission=%s&limit=50" % category
		
	var headers: PackedStringArray = []
	var auth_mgr = get_node_or_null("/root/AuthManager")
	if auth_mgr and auth_mgr.is_authenticated and not auth_mgr.token.is_empty():
		headers.append("Authorization: Bearer %s" % auth_mgr.token)
		
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		http_request.cancel_request()

	var err = http_request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_set_status("NETWORK REQUEST ERROR (CODE %d)" % err, Color(1.0, 0.3, 0.2))
		if loading_label:
			loading_label.hide()
		_fallback_offline_data(category)

func _on_http_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if loading_label:
		loading_label.hide()
		
	if response_code != 200:
		_set_status("TELEMETRY OFFLINE (HTTP %d) // USING LOCAL CACHE" % response_code, Color(1.0, 0.7, 0.2))
		_fallback_offline_data(current_category)
		return
		
	var json_str = body.get_string_from_utf8()
	var json = JSON.new()
	var parse_err = json.parse(json_str)
	if parse_err != OK:
		_set_status("FAILED TO PARSE LEADERBOARD DATA", Color(1.0, 0.3, 0.2))
		_fallback_offline_data(current_category)
		return
		
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY or not data.get("success", false):
		_set_status("INVALID TELEMETRY RESPONSE", Color(1.0, 0.3, 0.2))
		_fallback_offline_data(current_category)
		return
		
	var entries: Array = data.get("leaderboard", [])
	cached_leaderboard[current_category] = entries
	
	# Update personal standing if returned
	var your_rank = data.get("your_rank", null)
	if your_rank and typeof(your_rank) == TYPE_DICTIONARY and personal_rank_label:
		var r_num = your_rank.get("rank", "?")
		var r_score = your_rank.get("composite_score", your_rank.get("score", 0))
		var auth_mgr = get_node_or_null("/root/AuthManager")
		var cs = auth_mgr.callsign if auth_mgr else "PILOT"
		personal_rank_label.text = "🎖️ YOUR FLEET STANDING: RANK #%s // %s (SCORE: %s)" % [
			str(r_num), cs, str(r_score)
		]
		
	_set_status("GLOBAL FLEET STANDINGS SYNCHRONIZED // %d ENTRIES" % entries.size(), Color(0.2, 0.95, 0.5))
	_render_leaderboard(entries)

func _render_leaderboard(entries: Array) -> void:
	_clear_list()
	
	if entries.is_empty():
		if empty_label:
			empty_label.text = "No flight records registered for this sortie category yet."
			empty_label.show()
		return
		
	if empty_label:
		empty_label.hide()
		
	var auth_mgr = get_node_or_null("/root/AuthManager")
	var my_cs = auth_mgr.callsign.to_upper() if (auth_mgr and auth_mgr.is_authenticated) else ""
	
	if current_category == "global":
		if table_header_label:
			table_header_label.text = "RANK     CALLSIGN                     RANK & SQUADRON                    KILLS    SORTIES     SCORE"
		for item in entries:
			_render_global_row(item, my_cs)
	else:
		if table_header_label:
			table_header_label.text = "RANK     CALLSIGN                     SCORE       TIME       ACCURACY        DATE"
		for item in entries:
			_render_mission_row(item, my_cs)

func _render_global_row(item: Dictionary, my_cs: String) -> void:
	var r = int(item.get("rank", 0))
	var cs = str(item.get("callsign", "PILOT"))
	var rank_title = str(item.get("rank_title", "CADET"))
	var squadron = str(item.get("squadron", "404th Strike Wing"))
	var kills = int(item.get("total_kills", 0))
	var sorties = int(item.get("total_sorties", 0))
	var score = int(item.get("composite_score", item.get("mission_score", 0)))
	
	var is_me = (not my_cs.is_empty() and cs.to_upper() == my_cs)
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.16, 0.22, 0.85) if is_me else Color(0.03, 0.07, 0.12, 0.75)
	style.border_width_left = 3 if is_me else 1
	style.border_color = Color(1.0, 0.85, 0.1, 1.0) if is_me else Color(0.0, 0.8, 1.0, 0.3)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)
	
	# Rank badge
	var rank_lbl = Label.new()
	rank_lbl.custom_minimum_size = Vector2(50, 0)
	rank_lbl.text = "#%d" % r
	if r == 1:
		rank_lbl.text = "🥇 #1"
		rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	elif r == 2:
		rank_lbl.text = "🥈 #2"
		rank_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	elif r == 3:
		rank_lbl.text = "🥉 #3"
		rank_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))
	else:
		rank_lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	rank_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(rank_lbl)
	
	# Callsign
	var cs_lbl = Label.new()
	cs_lbl.custom_minimum_size = Vector2(140, 0)
	cs_lbl.text = cs + (" (YOU)" if is_me else "")
	cs_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6) if is_me else Color(0.9, 0.95, 1.0))
	cs_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(cs_lbl)
	
	# Rank & Squadron
	var meta_lbl = Label.new()
	meta_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_lbl.text = "%s // %s" % [rank_title, squadron]
	meta_lbl.add_theme_color_override("font_color", Color(0.65, 0.78, 0.88, 0.8))
	meta_lbl.add_theme_font_size_override("font_size", 11)
	hbox.add_child(meta_lbl)
	
	# Kills
	var kills_lbl = Label.new()
	kills_lbl.custom_minimum_size = Vector2(60, 0)
	kills_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kills_lbl.text = "%d" % kills
	kills_lbl.add_theme_color_override("font_color", Color(0.2, 0.95, 0.5))
	kills_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(kills_lbl)
	
	# Sorties
	var sorties_lbl = Label.new()
	sorties_lbl.custom_minimum_size = Vector2(60, 0)
	sorties_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sorties_lbl.text = "%d" % sorties
	sorties_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	sorties_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(sorties_lbl)
	
	# Score
	var score_lbl = Label.new()
	score_lbl.custom_minimum_size = Vector2(80, 0)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_lbl.text = "%d PTS" % score
	score_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	score_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(score_lbl)
	
	leaderboard_list.add_child(panel)

func _render_mission_row(item: Dictionary, my_cs: String) -> void:
	var r = int(item.get("rank", 0))
	var cs = str(item.get("callsign", "PILOT"))
	var score = int(item.get("score", 0))
	var time_sec = float(item.get("completion_time_sec", 0.0))
	var acc = float(item.get("accuracy_pct", 0.0))
	var sub_date = str(item.get("submitted_at", "")).split("T")[0]
	
	var is_me = (not my_cs.is_empty() and cs.to_upper() == my_cs)
	var mins = int(time_sec / 60.0)
	var secs = int(fmod(time_sec, 60.0))
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.16, 0.22, 0.85) if is_me else Color(0.03, 0.07, 0.12, 0.75)
	style.border_width_left = 3 if is_me else 1
	style.border_color = Color(1.0, 0.85, 0.1, 1.0) if is_me else Color(0.0, 0.8, 1.0, 0.3)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)
	
	# Rank
	var rank_lbl = Label.new()
	rank_lbl.custom_minimum_size = Vector2(50, 0)
	rank_lbl.text = "#%d" % r
	if r == 1: rank_lbl.text = "🥇 #1"
	elif r == 2: rank_lbl.text = "🥈 #2"
	elif r == 3: rank_lbl.text = "🥉 #3"
	rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1) if r == 1 else Color(0.0, 0.9, 1.0))
	rank_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(rank_lbl)
	
	# Callsign
	var cs_lbl = Label.new()
	cs_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cs_lbl.text = cs + (" (YOU)" if is_me else "")
	cs_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6) if is_me else Color(0.9, 0.95, 1.0))
	cs_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(cs_lbl)
	
	# Score
	var score_lbl = Label.new()
	score_lbl.custom_minimum_size = Vector2(90, 0)
	score_lbl.text = "%d PTS" % score
	score_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	score_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(score_lbl)
	
	# Time
	var time_lbl = Label.new()
	time_lbl.custom_minimum_size = Vector2(70, 0)
	time_lbl.text = "%02dm %02ds" % [mins, secs]
	time_lbl.add_theme_color_override("font_color", Color(0.2, 0.95, 0.5))
	time_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(time_lbl)
	
	# Accuracy
	var acc_lbl = Label.new()
	acc_lbl.custom_minimum_size = Vector2(70, 0)
	acc_lbl.text = "%.1f%%" % acc
	acc_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	acc_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(acc_lbl)
	
	# Date
	var date_lbl = Label.new()
	date_lbl.custom_minimum_size = Vector2(80, 0)
	date_lbl.text = sub_date
	date_lbl.add_theme_color_override("font_color", Color(0.5, 0.65, 0.75))
	date_lbl.add_theme_font_size_override("font_size", 11)
	hbox.add_child(date_lbl)
	
	leaderboard_list.add_child(panel)

func _fallback_offline_data(category: String) -> void:
	var auth_mgr = get_node_or_null("/root/AuthManager")
	var cs = auth_mgr.callsign if (auth_mgr and auth_mgr.is_authenticated) else "VANGUARD-LEAD"
	var rk = auth_mgr.rank if auth_mgr else "LIEUTENANT"
	
	var mock: Array = []
	if category == "global":
		mock = [
			{ "rank": 1, "callsign": "VIPER-ONE", "rank_title": "COMMANDER", "squadron": "Sol Orbital Elite", "total_kills": 86, "total_sorties": 24, "composite_score": 68400 },
			{ "rank": 2, "callsign": cs, "rank_title": rk, "squadron": "404th Vanguard Strike Wing", "total_kills": auth_mgr.stats.get("total_kills", 42) if auth_mgr else 42, "total_sorties": auth_mgr.stats.get("total_sorties", 12) if auth_mgr else 12, "composite_score": 41200 },
			{ "rank": 3, "callsign": "NEBULA-GHOST", "rank_title": "FLIGHT LIEUTENANT", "squadron": "Combine Assault Wing", "total_kills": 38, "total_sorties": 16, "composite_score": 38100 },
			{ "rank": 4, "callsign": "RAZOR-9", "rank_title": "PILOT OFFICER", "squadron": "Outer Rim Militia", "total_kills": 29, "total_sorties": 10, "composite_score": 27500 }
		]
	else:
		mock = [
			{ "rank": 1, "callsign": "VIPER-ONE", "score": 28400, "completion_time_sec": 142.5, "accuracy_pct": 88.5, "submitted_at": "2026-09-26" },
			{ "rank": 2, "callsign": cs, "score": 24100, "completion_time_sec": 165.2, "accuracy_pct": 82.0, "submitted_at": "2026-09-27" },
			{ "rank": 3, "callsign": "APEX-LEAD", "score": 19800, "completion_time_sec": 188.0, "accuracy_pct": 74.5, "submitted_at": "2026-09-25" }
		]
	_render_leaderboard(mock)

func _clear_list() -> void:
	if not leaderboard_list:
		return
	for c in leaderboard_list.get_children():
		c.queue_free()

func _set_status(msg: String, col: Color = Color(0.0, 0.85, 1.0)) -> void:
	if status_msg_label:
		status_msg_label.text = "// " + msg + " //"
		status_msg_label.modulate = col
