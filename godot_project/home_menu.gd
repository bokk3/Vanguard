extends Node3D

## HomeMenu: Main Menu controller for Project Vanguard.
## Handles eerie white hangar presentation, turntable ship, repair FX, and left-aligned menu.

@onready var camera_3d: Camera3D = $Camera3D
@onready var ship_pivot: Node3D = $HangarScene/ShipTurntable
@onready var scan_ring: Node3D = $HangarScene/ShipTurntable/ScanRing
@onready var repair_sparks: CPUParticles3D = $HangarScene/ShipTurntable/RepairSparks
@onready var scan_light: OmniLight3D = $HangarScene/ShipTurntable/ScanRing/ScanLight

@onready var continue_btn: Button = %ContinueBtn
@onready var deploy_btn: Button = %DeployBtn
@onready var prologue_btn: Button = %PrologueBtn
@onready var pvp_btn: Button = %PvPBtn
@onready var mobile_hotas_btn: Button = %MobileHotasBtn
@onready var config_btn: Button = %ConfigBtn
@onready var specs_btn: Button = %SpecsBtn
@onready var quit_btn: Button = %QuitBtn

@onready var root_menu: VBoxContainer = %RootMenu
@onready var submenu_campaign: VBoxContainer = %SubmenuCampaign
@onready var submenu_multiplayer: VBoxContainer = %SubmenuMultiplayer
@onready var submenu_intel: VBoxContainer = %SubmenuIntel
@onready var submenu_settings: VBoxContainer = %SubmenuSettings

@onready var category_campaign_btn: Button = %CategoryCampaignBtn
@onready var category_agility_btn: Button = %CategoryAgilityBtn
@onready var category_multiplayer_btn: Button = %CategoryMultiplayerBtn
@onready var category_intel_btn: Button = %CategoryIntelBtn
@onready var category_settings_btn: Button = %CategorySettingsBtn

@onready var sub_campaign_back_btn: Button = %SubCampaignBackBtn
@onready var sub_multiplayer_back_btn: Button = %SubMultiplayerBackBtn
@onready var sub_intel_back_btn: Button = %SubIntelBackBtn
@onready var sub_settings_back_btn: Button = %SubSettingsBackBtn

@onready var leaderboard_btn: Button = %LeaderboardBtn
@onready var leaderboard_dialog: Control = %LeaderboardDialog
@onready var rewards_btn: Button = get_node_or_null("%RewardsBtn")
@onready var sub_intel_rewards_btn: Button = %SubIntelRewardsBtn
@onready var rewards_dialog: Control = %RewardsDialog
@onready var agility_selector: Control = %AgilitySelectorDialog

@onready var specs_panel: PanelContainer = %SpecsPanel
@onready var close_specs_btn: Button = %CloseSpecsBtn
@onready var settings_modal: Control = %SettingsMenu
@onready var mission_selector: Control = %MissionSelector
@onready var update_badge_btn: Button = %UpdateBadgeBtn
@onready var update_dialog: Control = %UpdateDialog
@onready var login_dialog: Control = %LoginDialog
@onready var mode_selector: Control = %ModeSelectorDialog
@onready var combat_stats: Control = %CombatStatsDialog
@onready var theater_badge_label: Label = %TheaterBadgeLabel
@onready var switch_theater_btn: Button = %SwitchTheaterBtn
@onready var stats_btn: Button = %StatsBtn
@onready var layout_toggle_btn: Button = %LayoutToggleBtn

@onready var pilot_dossier_box: PanelContainer = %PilotDossierBox
@onready var pilot_label: Label = %PilotLabel
@onready var pilot_rank_label: Label = %PilotRankLabel
@onready var pilot_stars_label: Label = %PilotStarsLabel
@onready var pilot_streak_label: Label = %PilotStreakLabel
@onready var pilot_badges_label: Label = %PilotBadgesLabel
@onready var pilot_avionics_label: Label = %PilotAvionicsLabel
@onready var stats_quick_btn: Button = %StatsQuickBtn
@onready var switch_pilot_btn: Button = get_node_or_null("%SwitchPilotBtn")
@onready var fleet_stats_label: Label = %FleetStatsLabel
@onready var fade_overlay: ColorRect = %FadeOverlay
@onready var warp_audio: AudioStreamPlayer = %WarpAudio
@onready var menu_music_player: AudioStreamPlayer = %MenuMusicPlayer
@onready var sidebar: PanelContainer = $UI/Sidebar

@onready var pilot_hud_card: Control = %PilotHUDCard
@onready var hud_pilot_callsign_label: Label = %HUDPilotCallsignLabel
@onready var hud_pilot_rank_label: Label = %HUDPilotRankLabel
@onready var hud_avionics_label: Label = %HUDAvionicsLabel
@onready var hud_online_status_label: Label = %HUDOnlineStatusLabel
@onready var hud_stars_label: Label = %HUDStarsLabel
@onready var hud_streak_label: Label = %HUDStreakLabel
@onready var hud_badges_label: Label = %HUDBadgesLabel
@onready var hud_sorties_label: Label = %HUDSortiesLabel
@onready var hud_kills_label: Label = %HUDKillsLabel
@onready var hud_win_rate_label: Label = %HUDWinRateLabel
@onready var hud_stats_btn: Button = %HUDStatsBtn
@onready var hud_armory_btn: Button = %HUDArmoryBtn
@onready var hud_profile_btn: Button = %HUDProfileBtn
@onready var hud_agility_btn: Button = %HUDAgilityBtn

@onready var repair_progress_bar: ProgressBar = %RepairProgressBar
@onready var repair_status_label: Label = %RepairStatusLabel
@onready var telemetry_summary: Label = %TelemetrySummary
@onready var footer_label: Label = %FooterLabel
@onready var title_box_right: Control = %TitleBoxRight
@onready var title_logo: TextureRect = %TitleLogo
@onready var hangar_tagline: Label = %HangarTagline
@onready var squadron_badge: TextureRect = %SquadronBadge

var anim_time: float = 0.0
var repair_percent: float = 84.0
var initial_title_y: float = 28.0
var is_launching: bool = false
var qr_dialog: Control = null
var current_theater: String = "SOLO"
var has_chosen_theater: bool = false
var current_active_submenu: Control = null

func _get_autoload_node(node_name: String) -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/" + node_name)
	elif Engine.get_main_loop() and "root" in Engine.get_main_loop() and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null(node_name)
	return null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Dynamic version string from project settings
	var ver = ProjectSettings.get_setting("application/config/version", "0.9.3")
	if footer_label:
		footer_label.text = "PROJECT VANGUARD v%s\nSYSTEMS INITIALIZED // READY" % ver
	
	# Connect category navigation buttons
	if category_campaign_btn and not category_campaign_btn.pressed.is_connected(func(): _open_submenu("campaign")):
		category_campaign_btn.pressed.connect(func(): _open_submenu("campaign"))
	if category_agility_btn and not category_agility_btn.pressed.is_connected(_show_agility_selector):
		category_agility_btn.pressed.connect(_show_agility_selector)
	if category_multiplayer_btn and not category_multiplayer_btn.pressed.is_connected(func(): _open_submenu("multiplayer")):
		category_multiplayer_btn.pressed.connect(func(): _open_submenu("multiplayer"))
	if category_intel_btn and not category_intel_btn.pressed.is_connected(func(): _open_submenu("intel")):
		category_intel_btn.pressed.connect(func(): _open_submenu("intel"))
	if category_settings_btn and not category_settings_btn.pressed.is_connected(func(): _open_submenu("settings")):
		category_settings_btn.pressed.connect(func(): _open_submenu("settings"))

	# Connect submenu return buttons
	if sub_campaign_back_btn and not sub_campaign_back_btn.pressed.is_connected(_close_submenu):
		sub_campaign_back_btn.pressed.connect(_close_submenu)
	if sub_multiplayer_back_btn and not sub_multiplayer_back_btn.pressed.is_connected(_close_submenu):
		sub_multiplayer_back_btn.pressed.connect(_close_submenu)
	if sub_intel_back_btn and not sub_intel_back_btn.pressed.is_connected(_close_submenu):
		sub_intel_back_btn.pressed.connect(_close_submenu)
	if sub_settings_back_btn and not sub_settings_back_btn.pressed.is_connected(_close_submenu):
		sub_settings_back_btn.pressed.connect(_close_submenu)

	# Connect action buttons
	if not continue_btn.pressed.is_connected(_on_continue_pressed):
		continue_btn.pressed.connect(_on_continue_pressed)
	if not deploy_btn.pressed.is_connected(_on_deploy_pressed):
		deploy_btn.pressed.connect(_on_deploy_pressed)
	if prologue_btn and not prologue_btn.pressed.is_connected(_on_prologue_pressed):
		prologue_btn.pressed.connect(_on_prologue_pressed)
	if pvp_btn and not pvp_btn.pressed.is_connected(_on_pvp_pressed):
		pvp_btn.pressed.connect(_on_pvp_pressed)
	if mobile_hotas_btn and not mobile_hotas_btn.pressed.is_connected(_toggle_qr_dialog):
		mobile_hotas_btn.pressed.connect(func(): _toggle_qr_dialog(1))
	if leaderboard_btn and not leaderboard_btn.pressed.is_connected(_show_leaderboard_dialog):
		leaderboard_btn.pressed.connect(_show_leaderboard_dialog)
	if rewards_btn and not rewards_btn.pressed.is_connected(func(): _show_rewards_dialog("wheel")):
		rewards_btn.pressed.connect(func(): _show_rewards_dialog("wheel"))
	if sub_intel_rewards_btn and not sub_intel_rewards_btn.pressed.is_connected(func(): _show_rewards_dialog("skins")):
		sub_intel_rewards_btn.pressed.connect(func(): _show_rewards_dialog("skins"))
	if not config_btn.pressed.is_connected(_on_config_pressed):
		config_btn.pressed.connect(_on_config_pressed)
	if not specs_btn.pressed.is_connected(_on_specs_pressed):
		specs_btn.pressed.connect(_on_specs_pressed)
	if not quit_btn.pressed.is_connected(_on_quit_pressed):
		quit_btn.pressed.connect(_on_quit_pressed)
	if close_specs_btn and not close_specs_btn.pressed.is_connected(func(): specs_panel.hide()):
		close_specs_btn.pressed.connect(func(): specs_panel.hide())
	
	if switch_theater_btn and not switch_theater_btn.pressed.is_connected(_show_mode_selector):
		switch_theater_btn.pressed.connect(_show_mode_selector)
	if stats_btn and not stats_btn.pressed.is_connected(_show_stats_dialog):
		stats_btn.pressed.connect(_show_stats_dialog)
	if layout_toggle_btn and not layout_toggle_btn.pressed.is_connected(_toggle_keyboard_layout):
		layout_toggle_btn.pressed.connect(_toggle_keyboard_layout)

	if mode_selector:
		if not mode_selector.theater_selected.is_connected(_on_theater_selected):
			mode_selector.theater_selected.connect(_on_theater_selected)
		if not mode_selector.pair_controller1_requested.is_connected(_on_pair_controller1_requested):
			mode_selector.pair_controller1_requested.connect(_on_pair_controller1_requested)
		if not mode_selector.layout_toggled.is_connected(_on_layout_toggled):
			mode_selector.layout_toggled.connect(_on_layout_toggled)
		if not mode_selector.switch_pilot_requested.is_connected(_on_switch_pilot_pressed):
			mode_selector.switch_pilot_requested.connect(_on_switch_pilot_pressed)

	if combat_stats and not combat_stats.open_rewards_requested.is_connected(func(): _show_rewards_dialog("wheel")):
		combat_stats.open_rewards_requested.connect(func(): _show_rewards_dialog("wheel"))

	var net_ctrl = _get_autoload_node("NetworkControllerServer")
	if net_ctrl:
		if not net_ctrl.pilot_connected.is_connected(_on_mobile_pilot_joined):
			net_ctrl.pilot_connected.connect(_on_mobile_pilot_joined)

	var net_mgr = _get_autoload_node("NetworkManager")
	if net_mgr:
		if not net_mgr.network_stats_updated.is_connected(_on_network_stats_updated):
			net_mgr.network_stats_updated.connect(_on_network_stats_updated)
		_update_fleet_stats_ui(net_mgr.registered_pilots, net_mgr.online_pilots, net_mgr.active_lobbies)

	_update_layout_ui()
	
	if update_badge_btn:
		if not update_badge_btn.pressed.is_connected(_on_update_badge_pressed):
			update_badge_btn.pressed.connect(_on_update_badge_pressed)
		update_badge_btn.hide()
	
	if update_dialog:
		update_dialog.hide()
	
	var updater = _get_autoload_node("Updater")
	if updater:
		if not updater.update_available.is_connected(_on_update_available):
			updater.update_available.connect(_on_update_available)
		if not updater.available_version.is_empty():
			_show_update_notification(updater.available_version)
	
	if not settings_modal.closed.is_connected(_on_settings_closed):
		settings_modal.closed.connect(_on_settings_closed)
	specs_panel.hide()
	settings_modal.hide()
	if mission_selector:
		mission_selector.hide()
		if not mission_selector.mission_scrambled.is_connected(_on_mission_selector_scrambled):
			mission_selector.mission_scrambled.connect(_on_mission_selector_scrambled)
	
	if title_box_right:
		initial_title_y = title_box_right.position.y
	
	if switch_pilot_btn and not switch_pilot_btn.pressed.is_connected(_on_switch_pilot_pressed):
		switch_pilot_btn.pressed.connect(_on_switch_pilot_pressed)
	if stats_quick_btn and not stats_quick_btn.pressed.is_connected(_show_stats_dialog):
		stats_quick_btn.pressed.connect(_show_stats_dialog)

	if hud_stats_btn and not hud_stats_btn.pressed.is_connected(_show_stats_dialog):
		hud_stats_btn.pressed.connect(_show_stats_dialog)
	if hud_armory_btn and not hud_armory_btn.pressed.is_connected(func(): _show_rewards_dialog("skins")):
		hud_armory_btn.pressed.connect(func(): _show_rewards_dialog("skins"))
	if hud_profile_btn and not hud_profile_btn.pressed.is_connected(_on_switch_pilot_pressed):
		hud_profile_btn.pressed.connect(_on_switch_pilot_pressed)
	if hud_agility_btn and not hud_agility_btn.pressed.is_connected(_show_agility_selector):
		hud_agility_btn.pressed.connect(_show_agility_selector)

	if agility_selector:
		agility_selector.hide()

	if combat_stats and combat_stats.has_signal("login_requested"):
		if not combat_stats.login_requested.is_connected(func(): _show_login_dialog(true, "// PILOT LOGIN REQUIRED FOR CLOUD SYNC //")):
			combat_stats.login_requested.connect(func(): _show_login_dialog(true, "// PILOT LOGIN REQUIRED FOR CLOUD SYNC //"))

	if rewards_dialog and rewards_dialog.has_signal("login_requested"):
		if not rewards_dialog.login_requested.is_connected(func(): _show_login_dialog(true, "// PILOT LOGIN REQUIRED TO SYNC WALLET //")):
			rewards_dialog.login_requested.connect(func(): _show_login_dialog(true, "// PILOT LOGIN REQUIRED TO SYNC WALLET //"))

	if login_dialog and not login_dialog.login_completed.is_connected(_on_login_completed):
		login_dialog.login_completed.connect(_on_login_completed)

	var auth_mgr = _get_autoload_node("AuthManager")
	if auth_mgr:
		if not auth_mgr.auth_success.is_connected(_on_auth_success):
			auth_mgr.auth_success.connect(_on_auth_success)
		if not auth_mgr.logged_out.is_connected(_on_logged_out):
			auth_mgr.logged_out.connect(_on_logged_out)
			
		_update_pilot_dossier_ui()
		if login_dialog: login_dialog.hide()
	else:
		if login_dialog: login_dialog.hide()


	var reward_mgr = _get_autoload_node("RewardManager")
	if reward_mgr:
		if not reward_mgr.rewards_updated.is_connected(_update_pilot_dossier_ui):
			reward_mgr.rewards_updated.connect(_update_pilot_dossier_ui)
		if reward_mgr.has_signal("stars_changed") and not reward_mgr.stars_changed.is_connected(func(_amt): _update_pilot_dossier_ui()):
			reward_mgr.stars_changed.connect(func(_amt): _update_pilot_dossier_ui())
		_apply_hangar_skin()

	var agility_mgr = _get_autoload_node("AgilityManager")
	if agility_mgr:
		if agility_mgr.has_signal("avionics_score_updated") and not agility_mgr.avionics_score_updated.is_connected(func(_s, _c): _update_pilot_dossier_ui()):
			agility_mgr.avionics_score_updated.connect(func(_s, _c): _update_pilot_dossier_ui())
		if agility_mgr.has_signal("medal_earned") and not agility_mgr.medal_earned.is_connected(func(_t, _m, _st): _update_pilot_dossier_ui()):
			agility_mgr.medal_earned.connect(func(_t, _m, _st): _update_pilot_dossier_ui())

	_setup_turntable_hardpoints()
	_check_save_game_state()
	_setup_menu_music()

	if get_viewport():
		if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
			get_viewport().size_changed.connect(_on_viewport_size_changed)
	_update_responsive_layout()

func _on_viewport_size_changed() -> void:
	_update_responsive_layout()

func _update_responsive_layout() -> void:
	if not is_inside_tree():
		return
	var vp = get_viewport()
	if not vp:
		return
	var vp_size = vp.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	
	# Reference base resolution is 1152 x 648
	var scale_x: float = vp_size.x / 1152.0
	var scale_y: float = vp_size.y / 648.0
	var scale_min: float = minf(scale_x, scale_y)
	var ui_scale: float = clampf(scale_min, 1.0, 1.75)
	
	# 1. 404 Badge scaling (+25% base = 100px, dynamically scaled)
	if squadron_badge:
		var badge_dim = roundf(100.0 * clampf(scale_min, 1.0, 1.45))
		squadron_badge.custom_minimum_size = Vector2(badge_dim, badge_dim)
	
	# 2. Right Title Box & Vanguard Logo dynamic scaling
	var base_width: float = 620.0
	var right_width = roundf(clampf(base_width * scale_x, 620.0, 960.0))
	var right_margin = roundf(clampf(40.0 * scale_x, 40.0, 72.0))
	var top_offset = roundf(clampf(28.0 * scale_y, 28.0, 56.0))
	
	if title_box_right:
		title_box_right.offset_left = - (right_width + right_margin)
		title_box_right.offset_right = - right_margin
		title_box_right.offset_top = top_offset
		initial_title_y = top_offset
	
	if title_logo:
		var logo_h = roundf(clampf(130.0 * ui_scale, 130.0, 220.0))
		title_logo.custom_minimum_size = Vector2(0, logo_h)
	
	if hangar_tagline:
		var tag_size = int(roundf(clampf(11.0 * ui_scale, 11.0, 15.0)))
		hangar_tagline.add_theme_font_size_override("font_size", tag_size)
	
	# 3. Pilot overview card (PilotHUDCard) anchored to the bottom of the viewport
	#    Sticks to the bottom-right so it never obscures the rotating hangar airplane animation.
	if pilot_hud_card:
		pilot_hud_card.anchor_left = 1.0
		pilot_hud_card.anchor_right = 1.0
		pilot_hud_card.anchor_top = 1.0
		pilot_hud_card.anchor_bottom = 1.0
		pilot_hud_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		pilot_hud_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
		
		pilot_hud_card.offset_left = - (right_width + right_margin)
		pilot_hud_card.offset_right = - right_margin
		
		var hud_h = roundf(clampf(156.0 * ui_scale, 156.0, 220.0))
		var bottom_margin = roundf(clampf(24.0 * scale_y, 20.0, 44.0))
		pilot_hud_card.offset_bottom = - bottom_margin
		pilot_hud_card.offset_top = - (bottom_margin + hud_h)

		
		# Dynamically scale font sizes inside PilotHUDCard
		var f_callsign = int(roundf(clampf(13.0 * ui_scale, 13.0, 18.0)))
		var f_sub = int(roundf(clampf(10.0 * ui_scale, 10.0, 14.0)))
		var f_chip = int(roundf(clampf(10.0 * ui_scale, 10.0, 13.0)))
		var f_btn = int(roundf(clampf(10.0 * ui_scale, 10.0, 13.0)))
		
		if hud_pilot_callsign_label:
			hud_pilot_callsign_label.add_theme_font_size_override("font_size", f_callsign)
		if hud_pilot_rank_label:
			hud_pilot_rank_label.add_theme_font_size_override("font_size", f_sub)
		if hud_avionics_label:
			hud_avionics_label.add_theme_font_size_override("font_size", f_sub)
		if hud_online_status_label:
			var f_status = int(roundf(clampf(9.0 * ui_scale, 9.0, 12.0)))
			hud_online_status_label.add_theme_font_size_override("font_size", f_status)
		
		for chip_lbl in [hud_stars_label, hud_streak_label, hud_badges_label, hud_sorties_label, hud_kills_label, hud_win_rate_label]:
			if chip_lbl:
				chip_lbl.add_theme_font_size_override("font_size", f_chip)
		
		var btn_h = roundf(clampf(26.0 * ui_scale, 26.0, 36.0))
		for btn in [hud_stats_btn, hud_armory_btn, hud_profile_btn, hud_agility_btn]:
			if btn:
				btn.add_theme_font_size_override("font_size", f_btn)
				btn.custom_minimum_size = Vector2(0, btn_h)



func _show_login_dialog(cloud_mode: bool = true, prompt_msg: String = "") -> void:
	if login_dialog:
		if cloud_mode and "is_cloud_mode" in login_dialog:
			login_dialog.is_cloud_mode = true
			if login_dialog.has_method("_update_mode_ui"):
				login_dialog._update_mode_ui()
		if not prompt_msg.is_empty() and login_dialog.has_method("set_prompt_message"):
			login_dialog.set_prompt_message(prompt_msg)
		login_dialog.show()
		if settings_modal: settings_modal.hide()
		if specs_panel: specs_panel.hide()
		if mission_selector: mission_selector.hide()
		if mode_selector: mode_selector.hide_selector()
		if combat_stats: combat_stats.hide_stats()
		if agility_selector and agility_selector.has_method("hide_selector"): agility_selector.hide_selector()
		if leaderboard_dialog and leaderboard_dialog.has_method("close_leaderboard"):
			leaderboard_dialog.close_leaderboard()


func _show_mode_selector() -> void:
	if mode_selector:
		mode_selector.show_selector()
		if settings_modal: settings_modal.hide()
		if specs_panel: specs_panel.hide()
		if mission_selector: mission_selector.hide()
		if combat_stats: combat_stats.hide_stats()
		if agility_selector and agility_selector.has_method("hide_selector"): agility_selector.hide_selector()
		if leaderboard_dialog and leaderboard_dialog.has_method("close_leaderboard"):
			leaderboard_dialog.close_leaderboard()

func _show_stats_dialog() -> void:
	if combat_stats:
		combat_stats.show_stats()
		if settings_modal: settings_modal.hide()
		if specs_panel: specs_panel.hide()
		if mission_selector: mission_selector.hide()
		if mode_selector: mode_selector.hide_selector()
		if agility_selector and agility_selector.has_method("hide_selector"): agility_selector.hide_selector()
		if leaderboard_dialog and leaderboard_dialog.has_method("close_leaderboard"):
			leaderboard_dialog.close_leaderboard()

func _show_leaderboard_dialog() -> void:
	if leaderboard_dialog and leaderboard_dialog.has_method("show_leaderboard"):
		if settings_modal: settings_modal.hide()
		if specs_panel: specs_panel.hide()
		if mission_selector: mission_selector.hide()
		if mode_selector: mode_selector.hide_selector()
		if combat_stats: combat_stats.hide_stats()
		if agility_selector and agility_selector.has_method("hide_selector"): agility_selector.hide_selector()
		if rewards_dialog: rewards_dialog.hide_dialog()
		leaderboard_dialog.show_leaderboard("global")

func _show_rewards_dialog(default_tab: String = "wheel") -> void:
	if rewards_dialog and rewards_dialog.has_method("show_dialog"):
		if settings_modal: settings_modal.hide()
		if specs_panel: specs_panel.hide()
		if mission_selector: mission_selector.hide()
		if mode_selector: mode_selector.hide_selector()
		if combat_stats: combat_stats.hide_stats()
		if agility_selector and agility_selector.has_method("hide_selector"): agility_selector.hide_selector()
		if leaderboard_dialog: leaderboard_dialog.hide()
		rewards_dialog.show_dialog(default_tab)

func _show_agility_selector() -> void:
	if agility_selector and agility_selector.has_method("show_selector"):
		if settings_modal: settings_modal.hide()
		if specs_panel: specs_panel.hide()
		if mission_selector: mission_selector.hide()
		if mode_selector: mode_selector.hide_selector()
		if combat_stats: combat_stats.hide_stats()
		if leaderboard_dialog and leaderboard_dialog.has_method("close_leaderboard"):
			leaderboard_dialog.close_leaderboard()
		if rewards_dialog and rewards_dialog.has_method("hide_dialog"):
			rewards_dialog.hide_dialog()
		agility_selector.show_selector()

func _open_submenu(submenu_name: String) -> void:
	if root_menu:
		root_menu.hide()
	if submenu_campaign:
		submenu_campaign.hide()
	if submenu_multiplayer:
		submenu_multiplayer.hide()
	if submenu_intel:
		submenu_intel.hide()
	if submenu_settings:
		submenu_settings.hide()
	
	match submenu_name:
		"campaign":
			if submenu_campaign:
				submenu_campaign.show()
				current_active_submenu = submenu_campaign
				if continue_btn and continue_btn.visible:
					continue_btn.grab_focus()
				elif deploy_btn:
					deploy_btn.grab_focus()
		"multiplayer":
			if submenu_multiplayer:
				submenu_multiplayer.show()
				current_active_submenu = submenu_multiplayer
				if pvp_btn:
					pvp_btn.grab_focus()
		"intel":
			if submenu_intel:
				submenu_intel.show()
				current_active_submenu = submenu_intel
				if leaderboard_btn:
					leaderboard_btn.grab_focus()
		"settings":
			if submenu_settings:
				submenu_settings.show()
				current_active_submenu = submenu_settings
				if config_btn:
					config_btn.grab_focus()

func _close_submenu() -> void:
	if submenu_campaign:
		submenu_campaign.hide()
	if submenu_multiplayer:
		submenu_multiplayer.hide()
	if submenu_intel:
		submenu_intel.hide()
	if submenu_settings:
		submenu_settings.hide()
	
	current_active_submenu = null
	if root_menu:
		root_menu.show()
		if category_campaign_btn:
			category_campaign_btn.grab_focus()

func _on_theater_selected(mode: String) -> void:
	has_chosen_theater = true
	current_theater = mode
	var net_ctrl = get_node_or_null("/root/NetworkControllerServer")
	if mode == "SOLO":
		if theater_badge_label:
			theater_badge_label.text = "THEATER: SOLO // VS AI"
			theater_badge_label.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
		if net_ctrl:
			net_ctrl.is_solo_mode = true
			net_ctrl.default_player_id = 1
	elif mode == "ONLINE":
		if net_ctrl:
			net_ctrl.is_solo_mode = false
			net_ctrl.default_player_id = 1
		get_tree().change_scene_to_file("res://pvp_menu.tscn")
	elif mode == "AGILITY":
		_show_agility_selector()

func _on_pair_controller1_requested() -> void:
	_toggle_qr_dialog(1)

func _on_layout_toggled(_is_az: bool) -> void:
	_update_layout_ui()

func _toggle_keyboard_layout() -> void:
	var cfg = get_node_or_null("/root/ConfigManager")
	if cfg:
		cfg.reset_keybindings_preset(not cfg.is_azerty)
		_update_layout_ui()
		if mode_selector and mode_selector.has_method("_update_layout_button_text"):
			mode_selector._update_layout_button_text()

func _update_layout_ui() -> void:
	var cfg = _get_autoload_node("ConfigManager")
	var is_az = cfg.is_azerty if cfg else false
	if layout_toggle_btn:
		layout_toggle_btn.text = "  [ ⌨ ]  LAYOUT: %s" % ("AZERTY (ZQSD)" if is_az else "QWERTY (WASD)")

func _on_mobile_pilot_joined(cs: String, pid: int) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if mobile_hotas_btn:
		mobile_hotas_btn.text = "  [ 📱 ]  CONTROLLER %d: %s (LINKED)" % [pid, cs]
		mobile_hotas_btn.add_theme_color_override("font_color", Color(0.1, 0.95, 0.4))

func _update_pilot_dossier_ui() -> void:
	var auth_mgr = _get_autoload_node("AuthManager")
	var reward_mgr = _get_autoload_node("RewardManager")
	if not auth_mgr:
		return
	var stars_count = reward_mgr.stars if reward_mgr else 0
	var streak_days = reward_mgr.streak if (reward_mgr and "streak" in reward_mgr) else 0
	var badges_count = reward_mgr.unlocked_badges.size() if reward_mgr else 0
	var is_cloud_auth = auth_mgr.is_cloud_authenticated()
	var callsign_text = auth_mgr.callsign if not auth_mgr.callsign.is_empty() else "RECRUIT-CALLSIGN"
	var rank_text = auth_mgr.rank if not auth_mgr.rank.is_empty() else "FLIGHT CADET"
	var squad_text = auth_mgr.squadron if not auth_mgr.squadron.is_empty() else "404th Vanguard Strike Wing"

	var stats_dict: Dictionary = auth_mgr.stats if ("stats" in auth_mgr and typeof(auth_mgr.stats) == TYPE_DICTIONARY) else {}
	var sorties_count = int(stats_dict.get("total_sorties", 0))
	var kills_count = int(stats_dict.get("total_kills", 0))
	var wins_count = int(stats_dict.get("battles_won", 0))
	var win_rate_val = (float(wins_count) / float(sorties_count) * 100.0) if sorties_count > 0 else 0.0

	# 1. Update Sidebar Pilot Dossier
	if pilot_label:
		pilot_label.text = "PILOT: %s  |  ⭐ %d" % [callsign_text, stars_count]
	if pilot_rank_label:
		if is_cloud_auth:
			pilot_rank_label.text = "RANK: %s // %s" % [rank_text, squad_text]
		else:
			pilot_rank_label.text = "CLEARANCE: LOCAL GUEST // %s" % squad_text
	if pilot_stars_label:
		pilot_stars_label.text = "⭐ %d" % stars_count
	if pilot_streak_label:
		pilot_streak_label.text = "🔥 %dD" % streak_days
	if pilot_badges_label:
		pilot_badges_label.text = "🎖️ %d/10" % badges_count
	
	var agility_mgr = _get_autoload_node("AgilityManager")
	var av_score = agility_mgr.avionics_score if agility_mgr else 0
	var av_class = agility_mgr.avionics_class if agility_mgr else "CLASS-E ROOKIE"
	if pilot_avionics_label:
		pilot_avionics_label.text = "AVIONICS: %s // %s PTS" % [av_class, _format_number(av_score)]

	if switch_pilot_btn:
		switch_pilot_btn.text = "🚪 LOGOUT" if is_cloud_auth else "🔑 LOGIN"

	# 2. Update Top-Right Tactical Pilot HUD Card
	if hud_pilot_callsign_label:
		hud_pilot_callsign_label.text = "CALLSIGN: %s" % callsign_text
	if hud_pilot_rank_label:
		hud_pilot_rank_label.text = "RANK: %s // %s" % [rank_text, squad_text]
	if hud_avionics_label:
		hud_avionics_label.text = "AVIONICS: %s (%s PTS)" % [av_class, _format_number(av_score)]
	if hud_online_status_label:
		if is_cloud_auth:
			hud_online_status_label.text = "● CLOUD ONLINE // VERIFIED"
			hud_online_status_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.5, 1.0))
		else:
			hud_online_status_label.text = "○ GUEST // NOT LOGGED IN"
			hud_online_status_label.add_theme_color_override("font_color", Color(0.96, 0.62, 0.04, 0.9))
	if hud_stars_label:
		hud_stars_label.text = "⭐ %d STARS" % stars_count
	if hud_streak_label:
		hud_streak_label.text = "🔥 %d-DAY STREAK" % streak_days
	if hud_badges_label:
		hud_badges_label.text = "🎖️ %d/10 MEDALS" % badges_count
	if hud_sorties_label:
		hud_sorties_label.text = "🚀 SORTIES: %d" % sorties_count
	if hud_kills_label:
		hud_kills_label.text = "🎯 KILLS: %d" % kills_count
	if hud_win_rate_label:
		hud_win_rate_label.text = "⚡ WIN: %.1f%%" % win_rate_val
	if hud_profile_btn:
		hud_profile_btn.text = "🚪 LOGOUT" if is_cloud_auth else "🔑 LOGIN"

	_apply_hangar_skin()

func _apply_hangar_skin() -> void:
	var reward_mgr = _get_autoload_node("RewardManager")
	if not reward_mgr:
		return
	var skin_id = reward_mgr.get_active_skin()
	var turntable_ship = get_node_or_null("HangarScene/ShipTurntable/SpaceshipModel")
	if not turntable_ship:
		return
		
	var custom_mat = StandardMaterial3D.new()
	match skin_id:
		"SOLAR_FLARE":
			custom_mat.albedo_color = Color(1.0, 0.78, 0.05, 1.0)
			custom_mat.metallic = 0.92
			custom_mat.roughness = 0.2
			custom_mat.emission_enabled = true
			custom_mat.emission = Color(1.0, 0.8, 0.1)
			custom_mat.emission_energy_multiplier = 1.2
		"VOID_STEALTH":
			custom_mat.albedo_color = Color(0.12, 0.12, 0.15, 1.0)
			custom_mat.metallic = 0.5
			custom_mat.roughness = 0.6
			custom_mat.emission_enabled = true
			custom_mat.emission = Color(0.66, 0.33, 0.97)
			custom_mat.emission_energy_multiplier = 1.4
		"CRIMSON_FURY":
			custom_mat.albedo_color = Color(0.88, 0.15, 0.15, 1.0)
			custom_mat.metallic = 0.85
			custom_mat.roughness = 0.25
			custom_mat.emission_enabled = true
			custom_mat.emission = Color(1.0, 0.2, 0.1)
			custom_mat.emission_energy_multiplier = 1.2
		"CYBER_NEON":
			custom_mat.albedo_color = Color(0.08, 0.08, 0.14, 1.0)
			custom_mat.metallic = 0.6
			custom_mat.roughness = 0.28
			custom_mat.emission_enabled = true
			custom_mat.emission = Color(0.92, 0.28, 0.6)
			custom_mat.emission_energy_multiplier = 2.0
		_:
			custom_mat = null
			
	for child in turntable_ship.find_children("*", "MeshInstance3D", true, false):
		var m = child as MeshInstance3D
		if m and m.mesh:
			m.material_override = custom_mat

func _on_login_completed(_profile: Dictionary) -> void:
	_update_pilot_dossier_ui()

func _on_auth_success(_profile: Dictionary) -> void:
	_update_pilot_dossier_ui()

func _on_logged_out() -> void:
	_update_pilot_dossier_ui()
	_show_login_dialog()

func _on_switch_pilot_pressed() -> void:
	var auth_mgr = get_node_or_null("/root/AuthManager")
	if auth_mgr and auth_mgr.is_cloud_authenticated():
		auth_mgr.logout()
	else:
		_show_login_dialog(true, "// SIGN IN TO ACCESS CLOUD DOSSIER & SYNC //")


func _on_network_stats_updated(reg: int, online: int, lobbies: int) -> void:
	_update_fleet_stats_ui(reg, online, lobbies)

func _update_fleet_stats_ui(reg: int, online: int, lobbies: int) -> void:
	if fleet_stats_label:
		fleet_stats_label.text = "ONLINE: %d  |  LOBBIES: %d  |  ROSTER: %s" % [online, lobbies, _format_number(reg)]

func _format_number(n: int) -> String:
	var s = str(n)
	var out = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out

func _setup_menu_music() -> void:
	if not menu_music_player:
		menu_music_player = get_node_or_null("%MenuMusicPlayer")
	if not menu_music_player:
		menu_music_player = AudioStreamPlayer.new()
		menu_music_player.name = "MenuMusicPlayer"
		menu_music_player.bus = "Music"
		add_child(menu_music_player)
	
	if not menu_music_player.stream:
		var stream = load("res://audio/music/menu_soundscape.mp3")
		if stream:
			menu_music_player.stream = stream
	
	if is_inside_tree() and menu_music_player and menu_music_player.stream and not menu_music_player.playing:
		menu_music_player.volume_db = -4.0
		menu_music_player.play()

func _setup_turntable_hardpoints() -> void:
	var ship_model = ship_pivot.get_node_or_null("SpaceshipModel")
	if not ship_model:
		return
	
	var station_positions = [
		Vector3(-3.2, -0.22, 1.2),  # Station 0: Left Outer
		Vector3(-2.2, -0.26, 0.4),  # Station 1: Left Inner
		Vector3(2.2, -0.26, 0.4),   # Station 2: Right Inner
		Vector3(3.2, -0.22, 1.2)    # Station 3: Right Outer
	]
	
	var missile_packed = load("res://Vanguard_Strike_Missile.fbx")
	var pylon_mat = StandardMaterial3D.new()
	pylon_mat.albedo_color = Color(0.12, 0.14, 0.16, 1.0)
	pylon_mat.metallic = 0.85
	pylon_mat.roughness = 0.35
	
	for i in range(station_positions.size()):
		var hp = Node3D.new()
		hp.name = "HangarHardpoint_0" + str(i + 1)
		hp.position = station_positions[i]
		ship_model.add_child(hp)
		
		var pylon = MeshInstance3D.new()
		var pylon_mesh = BoxMesh.new()
		pylon_mesh.size = Vector3(0.06, 0.12, 1.35)
		pylon_mesh.material = pylon_mat
		pylon.mesh = pylon_mesh
		pylon.position = Vector3(0, 0.05, 0)
		hp.add_child(pylon)
		
		if missile_packed:
			var m_inst = missile_packed.instantiate()
			m_inst.position = Vector3(0, -0.10, -0.3)
			hp.add_child(m_inst)

func _check_save_game_state() -> void:
	var sm = _get_autoload_node("SaveManager")
	if sm and sm.has_save():
		var info = sm.get_save_info()
		var date_str = info.get("display_date", "UNKNOWN")
		var telem = info.get("telemetry", {})
		var hull_val = telem.get("current_hull", 100.0)
		var missiles_val = telem.get("missiles_remaining", 4)
		
		continue_btn.visible = true
		continue_btn.text = "  [ 01 ]  RESUME SORTIE"
		deploy_btn.text = "  [ 02 ]  MISSION SELECTOR"
		if prologue_btn:
			prologue_btn.text = "  [ 03 ]  WATCH PROLOGUE"
		
		if telemetry_summary:
			telemetry_summary.text = "ACTIVE SORTIE: %s\nHULL INTEGRITY: %d%%\nMISSILES ARMED: %d/4" % [date_str, int(hull_val), int(missiles_val)]
	else:
		continue_btn.visible = false
		deploy_btn.text = "  [ 01 ]  MISSION SELECTOR"
		if prologue_btn:
			prologue_btn.text = "  [ 02 ]  WATCH PROLOGUE"

func _process(delta: float) -> void:
	anim_time += delta
	
	# Turntable slow rotation
	if ship_pivot:
		ship_pivot.rotation.y += delta * 0.12
		# Subtle hydraulic hover breathing
		ship_pivot.position.y = 0.9 + sin(anim_time * 1.5) * 0.03
	
	# Diagnostic Scan Ring moves fore-and-aft across the ship
	if scan_ring:
		var scan_z = sin(anim_time * 1.8) * 4.5
		scan_ring.position.z = scan_z
		if scan_light:
			scan_light.light_energy = 1.8 + sin(anim_time * 8.0) * 0.4
	
	# Simulate repairing progress incrementing slowly
	repair_percent += delta * 0.4
	if repair_percent > 100.0:
		repair_percent = 78.0
	
	if repair_progress_bar:
		repair_progress_bar.value = repair_percent
	if repair_status_label:
		repair_status_label.text = "DIAGNOSTIC CYCLE: %d%% NOMINAL" % int(repair_percent)
	
	# Title overlay subtle floating hover
	if title_box_right and not is_launching:
		title_box_right.position.y = initial_title_y + sin(anim_time * 1.4) * 4.0

	# Keep mouse cursor visible at all times during menu navigation
	if not is_launching and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_continue_pressed() -> void:
	var target_mid = "M01"
	var sm = _get_autoload_node("SaveManager")
	if sm and sm.has_save():
		var info = sm.get_save_info()
		target_mid = info.get("mission_id", "M01")
	var mm = _get_autoload_node("MissionManager")
	if mm and mm.current_mission_id:
		target_mid = mm.current_mission_id
	_launch_game_animation(target_mid, true)

func _on_deploy_pressed() -> void:
	if mission_selector:
		mission_selector.open_selector()
	else:
		_launch_game_animation("M01", false)

func _on_mission_selector_scrambled(mission_id: String) -> void:
	_launch_game_animation(mission_id, false)

func _on_prologue_pressed() -> void:
	var mm = _get_autoload_node("MissionManager")
	if mm:
		mm.is_prologue_preview_only = true
	_launch_game_animation("M01", false)

func _on_pvp_pressed() -> void:
	get_tree().change_scene_to_file("res://pvp_menu.tscn")

func _launch_game_animation(mission_id: String, is_resume: bool) -> void:
	if is_launching:
		return
	is_launching = true
	
	# Disable UI buttons to prevent double activation
	if category_campaign_btn: category_campaign_btn.disabled = true
	if category_agility_btn: category_agility_btn.disabled = true
	if category_multiplayer_btn: category_multiplayer_btn.disabled = true
	if category_intel_btn: category_intel_btn.disabled = true
	if category_settings_btn: category_settings_btn.disabled = true
	if sub_campaign_back_btn: sub_campaign_back_btn.disabled = true
	if sub_multiplayer_back_btn: sub_multiplayer_back_btn.disabled = true
	if sub_intel_back_btn: sub_intel_back_btn.disabled = true
	if sub_settings_back_btn: sub_settings_back_btn.disabled = true
	if leaderboard_btn: leaderboard_btn.disabled = true
	continue_btn.disabled = true
	deploy_btn.disabled = true
	if prologue_btn:
		prologue_btn.disabled = true
	if pvp_btn:
		pvp_btn.disabled = true
	if mobile_hotas_btn:
		mobile_hotas_btn.disabled = true
	if qr_dialog:
		qr_dialog.hide()
	config_btn.disabled = true
	specs_btn.disabled = true
	quit_btn.disabled = true
	if mission_selector:
		mission_selector.hide()
	if specs_panel:
		specs_panel.hide()
	if agility_selector and agility_selector.has_method("hide_selector"):
		agility_selector.hide_selector()
	if leaderboard_dialog and leaderboard_dialog.has_method("close_leaderboard"):
		leaderboard_dialog.close_leaderboard()
	
	# Play launch whoosh/warp audio
	if warp_audio and warp_audio.is_inside_tree():
		var sfx_stream = load("res://audio/sfx/sfx_flight_high_g_whoosh.wav")
		if sfx_stream:
			warp_audio.stream = sfx_stream
			warp_audio.pitch_scale = 0.85
			warp_audio.play()
	
	var duration: float = 1.35
	var tween_ui = create_tween().set_parallel(true)
	
	# Smoothly fade out menu music as launch begins
	if menu_music_player and menu_music_player.playing:
		var music_tween = create_tween()
		music_tween.tween_property(menu_music_player, "volume_db", -45.0, duration * 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Slide sidebar off-screen to the left and fade HUD card
	if sidebar:
		tween_ui.tween_property(sidebar, "position:x", -460.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if pilot_hud_card:
		tween_ui.tween_property(pilot_hud_card, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Camera rushes toward and through the right side of the hangar
	var cam_tween = create_tween().set_parallel(true)
	if camera_3d:
		var target_cam_pos = camera_3d.position + Vector3(3.5, -0.4, -14.0)
		cam_tween.tween_property(camera_3d, "position", target_cam_pos, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		cam_tween.tween_property(camera_3d, "fov", 110.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Vanguard logo zoom & fly-through: scales up 22x centered so letters rush past camera edges
	if title_box_right:
		title_box_right.pivot_offset = title_box_right.size * 0.5
		var vp_rect = get_viewport().get_visible_rect() if is_inside_tree() and get_viewport() else Rect2(0, 0, 1920, 1080)
		var center_dest = (vp_rect.size - title_box_right.size) * 0.5
		cam_tween.tween_property(title_box_right, "global_position", center_dest, duration * 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		cam_tween.tween_property(title_box_right, "scale", Vector2(22.0, 22.0), duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		cam_tween.tween_property(title_box_right, "modulate:a", 0.0, 0.25).set_delay(duration * 0.80)
	
	# Cut/Fade to pure black as camera pierces the letters
	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.color = Color(0, 0, 0, 0)
		cam_tween.tween_property(fade_overlay, "color:a", 1.0, 0.50).set_delay(duration * 0.60)
	
	cam_tween.finished.connect(func():
		_on_launch_animation_finished(mission_id, is_resume)
	)

func _on_launch_animation_finished(mission_id: String, is_resume: bool) -> void:
	var mm = get_node_or_null("/root/MissionManager")
	if mm:
		mm.current_mission_id = mission_id
	
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		sm.should_load_on_start = is_resume
	
	# Always show the intro when starting the first mission!
	if mission_id == "M01" or (mm and mm.is_prologue_preview_only):
		get_tree().change_scene_to_file("res://prologue_cutscene.tscn")
	else:
		get_tree().change_scene_to_file("res://main.tscn")

func _on_config_pressed() -> void:
	settings_modal.open_menu()

func _on_settings_closed() -> void:
	# Resume normal home menu focus
	pass

func _on_specs_pressed() -> void:
	specs_panel.visible = not specs_panel.visible

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_update_available(version: String, _changelog: String, _url: String, _size: int) -> void:
	_show_update_notification(version)

func _show_update_notification(version: String) -> void:
	if update_badge_btn:
		update_badge_btn.text = "◈ UPGRADE READY // %s" % version
		update_badge_btn.visible = true
	
	var updater = get_node_or_null("/root/Updater")
	if updater and not updater.has_dismissed_prompt:
		if update_dialog:
			update_dialog.show_update_prompt()

func _on_update_badge_pressed() -> void:
	if update_dialog:
		update_dialog.show_update_prompt()

func _toggle_qr_dialog(target_pid: int = 1) -> void:
	if not qr_dialog:
		var scene = load("res://qr_join_dialog.tscn")
		if scene:
			qr_dialog = scene.instantiate()
			$UI.add_child(qr_dialog)
			if not qr_dialog.closed.is_connected(_on_qr_dialog_closed):
				qr_dialog.closed.connect(_on_qr_dialog_closed)
	if qr_dialog and qr_dialog.has_method("toggle_dialog"):
		qr_dialog.toggle_dialog(target_pid)

func _on_qr_dialog_closed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if leaderboard_dialog and leaderboard_dialog.visible:
				leaderboard_dialog.close_leaderboard()
				get_viewport().set_input_as_handled()
				return
			if agility_selector and agility_selector.visible:
				if agility_selector.has_method("hide_selector"):
					agility_selector.hide_selector()
				else:
					agility_selector.hide()
				get_viewport().set_input_as_handled()
				return
			if specs_panel and specs_panel.visible:
				specs_panel.hide()
				get_viewport().set_input_as_handled()
				return
			if current_active_submenu != null:
				_close_submenu()
				get_viewport().set_input_as_handled()
				return
		elif event.keycode == KEY_F3:
			_toggle_qr_dialog(1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F1:
			_toggle_keyboard_layout()
			get_viewport().set_input_as_handled()

