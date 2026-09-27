class_name RewardsDialog
extends Control

## RewardsDialog: In-game Hangar Armory, Daily Reward Wheel, Login Streak & Badges Showcase.
## Fully synchronized with RewardManager and Cloudflare edge persistence.

signal closed()

# Header & Dossier Elements
@onready var title_label: Label = %TitleLabel
@onready var close_btn: Button = %CloseBtn
@onready var callsign_label: Label = %CallsignLabel
@onready var stars_pill_label: Label = %StarsPillLabel
@onready var streak_pill_label: Label = %StreakPillLabel
@onready var sync_btn: Button = %SyncBtn
@onready var status_banner_label: Label = %StatusBannerLabel

# Navigation Subtabs
@onready var tab_wheel_btn: Button = %TabWheelBtn
@onready var tab_streak_btn: Button = %TabStreakBtn
@onready var tab_skins_btn: Button = %TabSkinsBtn
@onready var tab_upgrades_btn: Button = %TabUpgradesBtn
@onready var tab_badges_btn: Button = %TabBadgesBtn

# View Panels
@onready var view_wheel: Control = %ViewWheel
@onready var view_streak: Control = %ViewStreak
@onready var view_skins: Control = %ViewSkins
@onready var view_upgrades: Control = %ViewUpgrades
@onready var view_badges: Control = %ViewBadges

# Wheel View Elements
@onready var wheel_canvas: Control = %WheelCanvas
@onready var spin_btn: Button = %SpinBtn
@onready var wheel_status_label: Label = %WheelStatusLabel
@onready var wheel_prize_label: Label = %WheelPrizeLabel

# Streak View Elements
@onready var streak_track_container: HBoxContainer = %StreakTrackContainer
@onready var claim_streak_btn: Button = %ClaimStreakBtn
@onready var streak_status_label: Label = %StreakStatusLabel

# Armory Containers
@onready var skins_grid: GridContainer = %SkinsGrid
@onready var upgrades_grid: GridContainer = %UpgradesGrid
@onready var badges_grid: GridContainer = %BadgesGrid

# Audio Players
var tick_audio: AudioStreamPlayer = null
var win_audio: AudioStreamPlayer = null

# Wheel Animation State
var is_spinning: bool = false
var wheel_angle: float = 0.0 # Current wheel angle in radians
var current_tab: String = "wheel"
var last_tick_sector: int = -1

const WHEEL_COLORS: Array[Color] = [
	Color(0.0, 0.85, 0.95),  # 50 Stars (Cyan)
	Color(0.2, 0.55, 0.95),  # 100 Stars (Blue)
	Color(0.66, 0.33, 0.97), # 250 Stars (Purple)
	Color(0.95, 0.5, 0.1),   # 500 Stars (Orange)
	Color(1.0, 0.84, 0.0),   # 1000 Stars Jackpot (Gold)
	Color(0.94, 0.27, 0.27), # Solar Flare Livery (Red/Crimson)
	Color(0.1, 0.95, 0.5),   # Pulse Cannon Upgrade (Emerald)
	Color(0.92, 0.28, 0.6),  # Deflector Shield Upgrade (Neon Pink)
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	_setup_audio()
	
	if close_btn:
		close_btn.pressed.connect(hide_dialog)
	if sync_btn:
		sync_btn.pressed.connect(_on_sync_pressed)
		
	# Tab switching
	if tab_wheel_btn: tab_wheel_btn.pressed.connect(func(): _switch_tab("wheel"))
	if tab_streak_btn: tab_streak_btn.pressed.connect(func(): _switch_tab("streak"))
	if tab_skins_btn: tab_skins_btn.pressed.connect(func(): _switch_tab("skins"))
	if tab_upgrades_btn: tab_upgrades_btn.pressed.connect(func(): _switch_tab("upgrades"))
	if tab_badges_btn: tab_badges_btn.pressed.connect(func(): _switch_tab("badges"))
	
	# Action buttons
	if spin_btn:
		spin_btn.pressed.connect(_on_spin_pressed)
	if claim_streak_btn:
		claim_streak_btn.pressed.connect(_on_claim_streak_pressed)
		
	# Custom Wheel Canvas Draw hook
	if wheel_canvas:
		wheel_canvas.draw.connect(_draw_wheel_canvas)

	var rm = _get_reward_manager()
	if rm:
		if not rm.rewards_updated.is_connected(_refresh_all):
			rm.rewards_updated.connect(_refresh_all)

func _setup_audio() -> void:
	tick_audio = AudioStreamPlayer.new()
	tick_audio.name = "WheelTickAudio"
	tick_audio.bus = "SFX"
	tick_audio.volume_db = -8.0
	var s_tick = load("res://audio/sfx/sfx_debrief_tally_tick.wav")
	if s_tick: tick_audio.stream = s_tick
	add_child(tick_audio)
	
	win_audio = AudioStreamPlayer.new()
	win_audio.name = "WheelWinAudio"
	win_audio.bus = "SFX"
	win_audio.volume_db = -3.0
	var s_win = load("res://audio/sfx/sfx_debrief_rank_slam.wav")
	if s_win: win_audio.stream = s_win
	add_child(win_audio)

func _get_reward_manager() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		return get_tree().root.get_node_or_null("RewardManager")
	return null

func show_dialog(default_tab: String = "wheel") -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_switch_tab(default_tab)
	_refresh_all()

func hide_dialog() -> void:
	if is_spinning:
		return # Wait for spin to resolve safely
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	closed.emit()

func _switch_tab(tab_name: String) -> void:
	current_tab = tab_name
	
	# Tab button highlights
	var active_color = Color(0.0, 0.95, 1.0)
	var inactive_color = Color(0.65, 0.78, 0.9)
	
	if tab_wheel_btn: tab_wheel_btn.add_theme_color_override("font_color", active_color if tab_name == "wheel" else inactive_color)
	if tab_streak_btn: tab_streak_btn.add_theme_color_override("font_color", active_color if tab_name == "streak" else inactive_color)
	if tab_skins_btn: tab_skins_btn.add_theme_color_override("font_color", active_color if tab_name == "skins" else inactive_color)
	if tab_upgrades_btn: tab_upgrades_btn.add_theme_color_override("font_color", active_color if tab_name == "upgrades" else inactive_color)
	if tab_badges_btn: tab_badges_btn.add_theme_color_override("font_color", active_color if tab_name == "badges" else inactive_color)
	
	if view_wheel: view_wheel.visible = (tab_name == "wheel")
	if view_streak: view_streak.visible = (tab_name == "streak")
	if view_skins: view_skins.visible = (tab_name == "skins")
	if view_upgrades: view_upgrades.visible = (tab_name == "upgrades")
	if view_badges: view_badges.visible = (tab_name == "badges")
	
	_refresh_current_view()

func _refresh_all() -> void:
	_update_header()
	_refresh_current_view()

func _update_header() -> void:
	var auth = get_node_or_null("/root/AuthManager")
	var rm = _get_reward_manager()
	
	var callsign = auth.callsign if (auth and not auth.callsign.is_empty()) else "RECRUIT PILOT"
	var sq = auth.squadron if (auth and not auth.squadron.is_empty()) else "404th Vanguard Strike Wing"
	if callsign_label:
		callsign_label.text = "PILOT: %s // %s" % [callsign, sq]
		
	var stars = rm.stars if rm else 0
	var streak = rm.streak if rm else 1
	if stars_pill_label:
		stars_pill_label.text = "⭐ %d STARS" % stars
	if streak_pill_label:
		streak_pill_label.text = "🔥 %d-DAY STREAK" % streak

func _refresh_current_view() -> void:
	match current_tab:
		"wheel": _refresh_wheel_view()
		"streak": _refresh_streak_view()
		"skins": _refresh_skins_view()
		"upgrades": _refresh_upgrades_view()
		"badges": _refresh_badges_view()

# -----------------------------------------------------------------------------
# 1. Daily Reward Wheel
# -----------------------------------------------------------------------------
func _refresh_wheel_view() -> void:
	var rm = _get_reward_manager()
	if not rm: return
	
	var can_spin = rm.can_spin_wheel() and not is_spinning
	if spin_btn:
		spin_btn.disabled = not can_spin
		if is_spinning:
			spin_btn.text = "DEPLOYING REWARD WHEEL..."
		elif can_spin:
			spin_btn.text = "🎡 [ DEPLOY DAILY WHEEL (FREE) ]"
		else:
			spin_btn.text = "DEPLOYED TODAY // NEXT SPIN IN 24H"
			
	if wheel_status_label:
		if can_spin:
			wheel_status_label.text = "// DAILY SORTIE REWARD READY // 1 FREE SPIN AVAILABLE //"
			wheel_status_label.modulate = Color(0.1, 0.95, 0.4)
		else:
			wheel_status_label.text = "// NEXT TACTICAL WHEEL REFRESH: TOMORROW //"
			wheel_status_label.modulate = Color(1.0, 0.84, 0.0)
			
	if wheel_canvas:
		wheel_canvas.queue_redraw()

func _on_spin_pressed() -> void:
	var rm = _get_reward_manager()
	if not rm or is_spinning or not rm.can_spin_wheel():
		return
		
	is_spinning = true
	spin_btn.disabled = true
	if wheel_prize_label:
		wheel_prize_label.text = "// SATELLITE TELEMETRY ENGAGED... //"
		wheel_prize_label.modulate = Color(0.0, 0.95, 1.0)
		
	# Execute authoritative spin outcome
	var spin_data = rm.spin_reward_wheel()
	if not spin_data.get("success", false):
		is_spinning = false
		_refresh_wheel_view()
		return
		
	var chosen_idx = spin_data.get("prize_index", 0)
	var prize = spin_data.get("prize", {})
	
	# Math: 8 sectors, each is TAU / 8. Top pointer is at -PI/2 (or 3*PI/2)
	# Target rotation lands the chosen slice under the pointer
	var num_slices = 8
	var slice_angle = TAU / float(num_slices)
	# Pointer at top: angle 3*PI/2 (or -PI/2)
	# To align slice i with top pointer:
	var slice_center = (float(chosen_idx) + 0.5) * slice_angle
	var target_stop = (3.0 * PI / 2.0) - slice_center
	while target_stop < 0:
		target_stop += TAU
		
	# Multi-revolution spin (5 to 6 full turns)
	var full_turns = 5.0 * TAU
	var final_rotation = wheel_angle + full_turns + (target_stop - fposmod(wheel_angle, TAU))
	if final_rotation < wheel_angle + full_turns:
		final_rotation += TAU
		
	# Animate smooth deceleration
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_animate_wheel_step, wheel_angle, final_rotation, 4.5)
	tw.tween_callback(func(): _on_spin_finished(prize))

func _animate_wheel_step(current_rot: float) -> void:
	wheel_angle = current_rot
	if wheel_canvas:
		wheel_canvas.queue_redraw()
		
	# Play procedural ticking sound when crossing segment lines
	var num_slices = 8
	var slice_angle = TAU / float(num_slices)
	var sector = int(current_rot / slice_angle)
	if sector != last_tick_sector:
		last_tick_sector = sector
		if tick_audio:
			tick_audio.pitch_scale = randf_range(0.9, 1.15)
			tick_audio.play()

func _on_spin_finished(prize: Dictionary) -> void:
	is_spinning = false
	if win_audio:
		win_audio.play()
		
	var label = prize.get("label", "REWARD")
	if wheel_prize_label:
		wheel_prize_label.text = "🎉 GRAND PRIZE WON: %s!" % label
		wheel_prize_label.modulate = Color(1.0, 0.84, 0.0)
		
	if status_banner_label:
		status_banner_label.text = "// TACTICAL PRIZE WON: %s // WALLET UPDATED //" % label
		status_banner_label.modulate = Color(0.1, 0.95, 0.4)
		
	_refresh_all()

func _draw_wheel_canvas() -> void:
	if not wheel_canvas: return
	var size = wheel_canvas.get_size()
	var center = size * 0.5
	var radius = min(size.x, size.y) * 0.46
	
	var rm = _get_reward_manager()
	var prizes = rm.WHEEL_PRIZES if rm else []
	var count = prizes.size() if prizes.size() > 0 else 8
	var step = TAU / float(count)
	
	# Draw background circle
	wheel_canvas.draw_circle(center, radius + 4.0, Color(0.0, 0.95, 1.0, 0.8))
	wheel_canvas.draw_circle(center, radius + 2.0, Color(0.02, 0.05, 0.1))
	
	# Draw slices
	for i in range(count):
		var a1 = wheel_angle + float(i) * step
		var a2 = a1 + step
		var col = WHEEL_COLORS[i % WHEEL_COLORS.size()]
		
		# Draw sector polygon
		var pts = PackedVector2Array([center])
		var segments = 16
		for s in range(segments + 1):
			var a = lerp(a1, a2, float(s) / float(segments))
			pts.append(center + Vector2(cos(a), sin(a)) * radius)
		wheel_canvas.draw_polygon(pts, PackedColorArray([col]))
		
		# Draw separator line
		wheel_canvas.draw_line(center, center + Vector2(cos(a1), sin(a1)) * radius, Color(0.02, 0.05, 0.1, 0.8), 2.0)
		
		# Draw label / text preview in slice
		if i < prizes.size():
			var mid_a = a1 + step * 0.5
			var text_pos = center + Vector2(cos(mid_a), sin(mid_a)) * (radius * 0.65)
			var short_label = str(prizes[i].get("amount", ""))
			if short_label.is_empty():
				short_label = "★" if prizes[i].get("type") == "skin" else "UPG"
			else:
				short_label += "★"
			var font = ThemeDB.fallback_font
			wheel_canvas.draw_string(font, text_pos - Vector2(14, -4), short_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color.BLACK)
			
	# Center hub
	wheel_canvas.draw_circle(center, radius * 0.22, Color(0.03, 0.08, 0.14))
	wheel_canvas.draw_circle(center, radius * 0.18, Color(0.0, 0.95, 1.0))
	wheel_canvas.draw_circle(center, radius * 0.12, Color(0.02, 0.04, 0.08))
	
	# Top indicator needle (pointer pointing DOWN at center)
	var ptr_top = Vector2(center.x, center.y - radius - 6.0)
	var ptr_left = Vector2(center.x - 10.0, center.y - radius - 16.0)
	var ptr_right = Vector2(center.x + 10.0, center.y - radius - 16.0)
	var needle_pts = PackedVector2Array([ptr_top, ptr_left, ptr_right])
	wheel_canvas.draw_polygon(needle_pts, PackedColorArray([Color(1.0, 0.84, 0.0)]))

# -----------------------------------------------------------------------------
# 2. Daily Login Streak
# -----------------------------------------------------------------------------
func _refresh_streak_view() -> void:
	var rm = _get_reward_manager()
	if not rm or not streak_track_container: return
	
	for c in streak_track_container.get_children():
		c.queue_free()
		
	var cur_streak = rm.streak
	var can_claim = rm.can_claim_daily_streak()
	var amounts = rm.STREAK_REWARDS
	
	for i in range(7):
		var day_num = i + 1
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		
		var is_past = day_num < cur_streak or (day_num == cur_streak and not can_claim)
		var is_current = (day_num == cur_streak and can_claim)
		
		if is_current:
			style.bg_color = Color(0.12, 0.22, 0.35, 0.95)
			style.border_color = Color(1.0, 0.84, 0.0, 1.0)
		elif is_past:
			style.bg_color = Color(0.04, 0.14, 0.12, 0.85)
			style.border_color = Color(0.1, 0.95, 0.4, 0.6)
		else:
			style.bg_color = Color(0.03, 0.06, 0.10, 0.85)
			style.border_color = Color(0.2, 0.35, 0.5, 0.3)
			
		card.add_theme_stylebox_override("panel", style)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		
		var d_lbl = Label.new()
		d_lbl.text = "DAY %d" % day_num
		d_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d_lbl.add_theme_font_size_override("font_size", 11)
		d_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0) if is_current else (Color(0.1, 0.95, 0.4) if is_past else Color(0.6, 0.7, 0.8)))
		vbox.add_child(d_lbl)
		
		var amt_lbl = Label.new()
		amt_lbl.text = "+%d★" % amounts[i]
		amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amt_lbl.add_theme_font_size_override("font_size", 14)
		amt_lbl.add_theme_color_override("font_color", Color.WHITE if (is_current or is_past) else Color(0.5, 0.6, 0.7))
		vbox.add_child(amt_lbl)
		
		var status_txt = "CLAIMED ✓" if is_past else ("TODAY ▶" if is_current else "LOCKED")
		var s_lbl = Label.new()
		s_lbl.text = status_txt
		s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s_lbl.add_theme_font_size_override("font_size", 9)
		s_lbl.add_theme_color_override("font_color", Color(0.1, 0.95, 0.4) if is_past else (Color(1.0, 0.84, 0.0) if is_current else Color(0.4, 0.5, 0.6)))
		vbox.add_child(s_lbl)
		
		card.add_child(vbox)
		streak_track_container.add_child(card)
		
	if claim_streak_btn:
		claim_streak_btn.disabled = not can_claim
		if can_claim:
			var bonus = amounts[min(cur_streak - 1, 6)]
			claim_streak_btn.text = "🎁 [ CLAIM DAY %d BONUS: +%d STARS ]" % [cur_streak, bonus]
		else:
			claim_streak_btn.text = "TODAY'S BONUS ALREADY CLAIMED // RETURN TOMORROW"
			
	if streak_status_label:
		streak_status_label.text = "CURRENT STREAK: %d CONSECUTIVE DAYS // MAINTAIN DISCIPLINE TO REACH DAY 7 BONUS" % cur_streak

func _on_claim_streak_pressed() -> void:
	var rm = _get_reward_manager()
	if not rm or not rm.can_claim_daily_streak(): return
	
	var res = rm.claim_daily_streak()
	if res.get("success", false):
		if win_audio: win_audio.play()
		if status_banner_label:
			status_banner_label.text = "// %s // WALLET CREDITED //" % res.get("message", "BONUS CLAIMED")
			status_banner_label.modulate = Color(0.1, 0.95, 0.4)
		_refresh_all()

# -----------------------------------------------------------------------------
# 3. Hangar Liveries (Skins)
# -----------------------------------------------------------------------------
func _refresh_skins_view() -> void:
	var rm = _get_reward_manager()
	if not rm or not skins_grid: return
	
	for c in skins_grid.get_children():
		c.queue_free()
		
	var active_skin = rm.get_active_skin()
	var unlocked_skins = rm.unlocked_skins
	
	for s_id in rm.SKINS_DEF:
		var s_data = rm.SKINS_DEF[s_id]
		var is_unlocked = unlocked_skins.has(s_id)
		var is_equipped = (active_skin == s_id)
		var cost = int(s_data.get("cost", 0))
		var color = s_data.get("color", Color.CYAN)
		
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.border_width_left = 2
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		
		if is_equipped:
			style.bg_color = Color(0.08, 0.18, 0.26, 0.95)
			style.border_color = Color(0.0, 0.95, 1.0, 1.0)
		elif is_unlocked:
			style.bg_color = Color(0.04, 0.09, 0.15, 0.90)
			style.border_color = Color(0.1, 0.95, 0.4, 0.5)
		else:
			style.bg_color = Color(0.03, 0.05, 0.09, 0.85)
			style.border_color = Color(0.3, 0.4, 0.5, 0.3)
		card.add_theme_stylebox_override("panel", style)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		
		# Header row with color swatch
		var hbox_top = HBoxContainer.new()
		var swatch = ColorRect.new()
		swatch.custom_minimum_size = Vector2(16, 16)
		swatch.color = color
		hbox_top.add_child(swatch)
		
		var name_lbl = Label.new()
		name_lbl.text = s_data.get("name", s_id)
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox_top.add_child(name_lbl)
		
		var cost_lbl = Label.new()
		cost_lbl.text = "OWNED" if is_unlocked else ("%d★" % cost)
		cost_lbl.add_theme_font_size_override("font_size", 11)
		cost_lbl.add_theme_color_override("font_color", Color(0.1, 0.95, 0.4) if is_unlocked else Color(1.0, 0.84, 0.0))
		hbox_top.add_child(cost_lbl)
		vbox.add_child(hbox_top)
		
		var desc_lbl = Label.new()
		desc_lbl.text = s_data.get("desc", "")
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		vbox.add_child(desc_lbl)
		
		var act_btn = Button.new()
		act_btn.custom_minimum_size = Vector2(0, 32)
		act_btn.add_theme_font_size_override("font_size", 11)
		
		if is_equipped:
			act_btn.text = "ACTIVE LIVERY ✓"
			act_btn.disabled = true
		elif is_unlocked:
			act_btn.text = "EQUIP LIVERY"
			act_btn.pressed.connect(func(): _on_equip_skin(s_id))
		else:
			var can_afford = (rm.stars >= cost)
			act_btn.text = "BUY FOR %d STARS" % cost
			act_btn.disabled = not can_afford
			act_btn.pressed.connect(func(): _on_buy_skin(s_id))
			
		vbox.add_child(act_btn)
		card.add_child(vbox)
		skins_grid.add_child(card)

func _on_equip_skin(skin_id: String) -> void:
	var rm = _get_reward_manager()
	if rm and rm.equip_skin(skin_id):
		if win_audio: win_audio.play()
		if status_banner_label:
			status_banner_label.text = "// LIVERY EQUIPPED: %s // HANGAR AIRFRAME UPDATED //" % skin_id
			status_banner_label.modulate = Color(0.0, 0.95, 1.0)
		_refresh_all()

func _on_buy_skin(skin_id: String) -> void:
	var rm = _get_reward_manager()
	if rm and rm.buy_skin(skin_id):
		if win_audio: win_audio.play()
		if status_banner_label:
			status_banner_label.text = "// ACQUIRED LIVERY: %s // COMMISSIONED TO HANGAR //" % skin_id
			status_banner_label.modulate = Color(0.1, 0.95, 0.4)
		_refresh_all()

# -----------------------------------------------------------------------------
# 4. Combat Upgrades
# -----------------------------------------------------------------------------
func _refresh_upgrades_view() -> void:
	var rm = _get_reward_manager()
	if not rm or not upgrades_grid: return
	
	for c in upgrades_grid.get_children():
		c.queue_free()
		
	for u_id in rm.UPGRADES_DEF:
		var u_data = rm.UPGRADES_DEF[u_id]
		var cur_tier = rm.get_upgrade_tier(u_id)
		var tiers: Array = u_data.get("tiers", [])
		var costs: Array = u_data.get("costs", [100, 250, 600])
		var next_cost = costs[cur_tier - 1] if cur_tier < 3 else 0
		var can_upgrade = (cur_tier < 3) and (rm.stars >= next_cost)
		
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.border_width_left = 2
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		style.bg_color = Color(0.04, 0.08, 0.14, 0.90)
		style.border_color = Color(1.0, 0.84, 0.0, 0.7) if cur_tier == 3 else Color(0.0, 0.85, 1.0, 0.4)
		card.add_theme_stylebox_override("panel", style)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		
		var h_top = HBoxContainer.new()
		var name_lbl = Label.new()
		name_lbl.text = u_data.get("name", u_id)
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_top.add_child(name_lbl)
		
		var tier_badge = Label.new()
		tier_badge.text = "TIER %d / 3" % cur_tier
		tier_badge.add_theme_font_size_override("font_size", 11)
		tier_badge.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0) if cur_tier == 3 else Color(0.0, 0.95, 1.0))
		h_top.add_child(tier_badge)
		vbox.add_child(h_top)
		
		# Tier status
		var tier_desc = tiers[cur_tier - 1] if cur_tier <= tiers.size() else "ACTIVE"
		var t_lbl = Label.new()
		t_lbl.text = "CURRENT: %s" % tier_desc
		t_lbl.add_theme_font_size_override("font_size", 10)
		t_lbl.add_theme_color_override("font_color", Color(0.1, 0.95, 0.4))
		vbox.add_child(t_lbl)
		
		if cur_tier < 3:
			var next_desc = tiers[cur_tier]
			var n_lbl = Label.new()
			n_lbl.text = "NEXT: %s" % next_desc
			n_lbl.add_theme_font_size_override("font_size", 10)
			n_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
			vbox.add_child(n_lbl)
			
		var up_btn = Button.new()
		up_btn.custom_minimum_size = Vector2(0, 32)
		up_btn.add_theme_font_size_override("font_size", 11)
		
		if cur_tier >= 3:
			up_btn.text = "OVERCLOCKED TO MAX TIER III ✓"
			up_btn.disabled = true
		else:
			up_btn.text = "UPGRADE TO TIER %d (%d STARS)" % [cur_tier + 1, next_cost]
			up_btn.disabled = not can_upgrade
			up_btn.pressed.connect(func(): _on_upgrade_system(u_id))
			
		vbox.add_child(up_btn)
		card.add_child(vbox)
		upgrades_grid.add_child(card)

func _on_upgrade_system(upgrade_id: String) -> void:
	var rm = _get_reward_manager()
	if rm and rm.buy_upgrade(upgrade_id):
		if win_audio: win_audio.play()
		if status_banner_label:
			status_banner_label.text = "// COMBAT SYSTEM UPGRADED: %s // AVIONICS ENHANCED //" % upgrade_id
			status_banner_label.modulate = Color(1.0, 0.84, 0.0)
		_refresh_all()

# -----------------------------------------------------------------------------
# 5. Military Badges
# -----------------------------------------------------------------------------
func _refresh_badges_view() -> void:
	var rm = _get_reward_manager()
	if not rm or not badges_grid: return
	
	for c in badges_grid.get_children():
		c.queue_free()
		
	var unlocked = rm.unlocked_badges
	
	for b_id in rm.BADGES_DEF:
		var b_data = rm.BADGES_DEF[b_id]
		var is_unlocked = unlocked.has(b_id)
		
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.border_width_left = 2
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		
		if is_unlocked:
			style.bg_color = Color(0.06, 0.14, 0.22, 0.95)
			style.border_color = Color(1.0, 0.84, 0.0, 0.85)
		else:
			style.bg_color = Color(0.02, 0.04, 0.07, 0.80)
			style.border_color = Color(0.2, 0.3, 0.4, 0.3)
		card.add_theme_stylebox_override("panel", style)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		
		var h_top = HBoxContainer.new()
		var icon_lbl = Label.new()
		icon_lbl.text = b_data.get("icon", "🎖️")
		icon_lbl.add_theme_font_size_override("font_size", 18)
		h_top.add_child(icon_lbl)
		
		var name_lbl = Label.new()
		name_lbl.text = b_data.get("name", b_id)
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0) if is_unlocked else Color(0.6, 0.7, 0.8))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_top.add_child(name_lbl)
		
		var tag_lbl = Label.new()
		tag_lbl.text = "UNLOCKED ✓" if is_unlocked else "LOCKED"
		tag_lbl.add_theme_font_size_override("font_size", 9)
		tag_lbl.add_theme_color_override("font_color", Color(0.1, 0.95, 0.4) if is_unlocked else Color(0.4, 0.5, 0.6))
		h_top.add_child(tag_lbl)
		vbox.add_child(h_top)
		
		var desc_lbl = Label.new()
		desc_lbl.text = b_data.get("desc", "")
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 0.95) if is_unlocked else Color(0.5, 0.6, 0.7))
		vbox.add_child(desc_lbl)
		
		var cond_lbl = Label.new()
		cond_lbl.text = "CRITERIA: %s" % b_data.get("condition", "")
		cond_lbl.add_theme_font_size_override("font_size", 9)
		cond_lbl.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0, 0.8) if is_unlocked else Color(0.4, 0.55, 0.65))
		vbox.add_child(cond_lbl)
		
		card.add_child(vbox)
		badges_grid.add_child(card)

# -----------------------------------------------------------------------------
# Cloud Synchronization
# -----------------------------------------------------------------------------
func _on_sync_pressed() -> void:
	if status_banner_label:
		status_banner_label.text = "// SYNCHRONIZING WITH CLOUDFLARE EDGE... //"
		status_banner_label.modulate = Color(1.0, 0.84, 0.0)
		
	var auth = get_node_or_null("/root/AuthManager")
	if auth and auth.has_method("sync_cloud_save"):
		auth.sync_cloud_save()
		
	if is_inside_tree() and get_tree():
		get_tree().create_timer(1.2).timeout.connect(func():
			_refresh_all()
			if status_banner_label:
				status_banner_label.text = "// ARMORY & WALLET SYNCHRONIZED AND VERIFIED //"
				status_banner_label.modulate = Color(0.1, 0.95, 0.4)
		)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_dialog()
		get_viewport().set_input_as_handled()
