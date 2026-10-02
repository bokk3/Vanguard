extends SceneTree

## Automated Headless Test Suite for Pilot Profile HUD & Live Telemetry
## Validates PilotHUDCard, sidebar dossier metrics, real-time label population,
## and quick navigation buttons (Combat Dossier, Armory).

var frame_count: int = 0
var test_done: bool = false
var timeout: float = 0.0

func _init() -> void:
	print("=================================================================")
	print(">>> Project Vanguard: Pilot Profile HUD & Telemetry Test <<<")
	print("=================================================================")

func _process(delta: float) -> bool:
	if test_done:
		return true
		
	timeout += delta
	if timeout > 8.0:
		push_error("Pilot profile HUD test timed out!")
		quit(1)
		return true

	frame_count += 1
	if frame_count < 2:
		return false
		
	test_done = true
	_run_hud_tests()
	return true

func _run_hud_tests() -> void:
	var auth_mgr = root.get_node_or_null("AuthManager")
	if not auth_mgr:
		auth_mgr = preload("res://auth_manager.gd").new()
		root.add_child(auth_mgr)
	
	var reward_mgr = root.get_node_or_null("RewardManager")
	if not reward_mgr:
		reward_mgr = preload("res://reward_manager.gd").new()
		root.add_child(reward_mgr)

	# 1. Setup known pilot telemetry
	auth_mgr.login_local("VIPER-ONE", "501st Black Aces", true)
	auth_mgr.rank = "COMMANDER"
	auth_mgr.stats = {
		"total_sorties": 10,
		"total_kills": 45,
		"battles_won": 8,
		"battles_lost": 2,
		"total_flight_time_sec": 1200.0,
		"preferred_controls": "AZERTY",
		"battle_history": []
	}
	reward_mgr.stars = 750
	reward_mgr.streak = 4
	reward_mgr.unlocked_badges.clear()
	reward_mgr.unlocked_badges.append("FIRST_SORTIE")
	reward_mgr.unlocked_badges.append("ACE_INTERCEPTOR")
	reward_mgr.unlocked_badges.append("LUCKY_STRIKE")

	# 2. Instantiate HomeMenu
	var menu_scene = preload("res://home_menu.tscn")
	var menu = menu_scene.instantiate()
	root.add_child(menu)
	menu._ready()

	# 3. Verify HUD node presence
	assert(menu.pilot_hud_card != null, "PilotHUDCard must exist")
	assert(menu.hud_pilot_callsign_label != null, "HUDPilotCallsignLabel must exist")
	assert(menu.hud_pilot_rank_label != null, "HUDPilotRankLabel must exist")
	assert(menu.hud_stars_label != null, "HUDStarsLabel must exist")
	assert(menu.hud_streak_label != null, "HUDStreakLabel must exist")
	assert(menu.hud_badges_label != null, "HUDBadgesLabel must exist")
	assert(menu.hud_sorties_label != null, "HUDSortiesLabel must exist")
	assert(menu.hud_kills_label != null, "HUDKillsLabel must exist")
	assert(menu.hud_win_rate_label != null, "HUDWinRateLabel must exist")
	assert(menu.hud_stats_btn != null, "HUDStatsBtn must exist")
	assert(menu.hud_armory_btn != null, "HUDArmoryBtn must exist")
	assert(menu.hud_profile_btn != null, "HUDProfileBtn must exist")
	assert(menu.stats_quick_btn != null, "StatsQuickBtn must exist in sidebar")
	print("[PASS] Pilot HUD Card and sidebar dossier nodes exist.")

	# 4. Trigger dossier update and verify populated text
	menu._update_pilot_dossier_ui()
	assert("VIPER-ONE" in menu.hud_pilot_callsign_label.text, "HUD callsign matches")
	assert("COMMANDER" in menu.hud_pilot_rank_label.text, "HUD rank matches")
	assert("750" in menu.hud_stars_label.text, "HUD stars count matches")
	assert("4" in menu.hud_streak_label.text, "HUD streak count matches")
	assert("3/10" in menu.hud_badges_label.text, "HUD badges count matches (3 unlocked)")
	assert("10" in menu.hud_sorties_label.text, "HUD sorties count matches")
	assert("45" in menu.hud_kills_label.text, "HUD kills count matches")
	assert("80.0%" in menu.hud_win_rate_label.text, "HUD win rate matches (8/10 = 80.0%)")
	print("[PASS] Top-right Pilot HUD Card telemetry correctly populated:")
	print("       %s | %s | %s" % [menu.hud_pilot_callsign_label.text, menu.hud_stars_label.text, menu.hud_win_rate_label.text])

	# 5. Verify Sidebar dossier sync
	assert("VIPER-ONE" in menu.pilot_label.text, "Sidebar pilot label matches")
	assert("750" in menu.pilot_stars_label.text, "Sidebar stars label matches")
	assert("4D" in menu.pilot_streak_label.text, "Sidebar streak label matches")
	assert("3/10" in menu.pilot_badges_label.text, "Sidebar badges label matches")
	print("[PASS] Sidebar Pilot Dossier synchronized with live profile telemetry.")

	# 6. Test Quick Action button routing
	assert(menu.combat_stats != null, "CombatStatsDialog reference exists")
	menu.hud_stats_btn.pressed.emit()
	assert(menu.combat_stats.visible == true, "CombatStatsDialog opened via HUD button")
	menu.combat_stats.hide_stats()

	menu.stats_quick_btn.pressed.emit()
	assert(menu.combat_stats.visible == true, "CombatStatsDialog opened via Sidebar button")
	menu.combat_stats.hide_stats()

	assert(menu.rewards_dialog != null, "RewardsDialog reference exists")
	menu.hud_armory_btn.pressed.emit()
	assert(menu.rewards_dialog.visible == true, "RewardsDialog opened via Armory HUD button")
	menu.rewards_dialog.hide_dialog()
	print("[PASS] Quick action buttons (Combat Dossier & Armory) functional.")

	menu.queue_free()
	print("=================================================================")
	print(">>> ALL PILOT PROFILE HUD TESTS PASSED (100%)                <<<")
	print("=================================================================")
	quit(0)
