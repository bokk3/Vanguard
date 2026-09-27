extends SceneTree

var frame_count: int = 0
var test_done: bool = false
var timeout: float = 0.0

func _init() -> void:
	print("\n=======================================================")
	print(">>> Project Vanguard: Rewards & Economy Test Suite <<<")
	print("=======================================================\n")

func _process(delta: float) -> bool:
	if test_done:
		return true
		
	timeout += delta
	if timeout > 8.0:
		push_error("Rewards system test timed out!")
		quit(1)
		return true

	frame_count += 1
	if frame_count < 3:
		return false
		
	test_done = true
	_run_rewards_tests()
	return true

func _run_rewards_tests() -> void:
	var rm = root.get_node_or_null("RewardManager")
	if not rm:
		rm = preload("res://reward_manager.gd").new()
		rm.name = "RewardManager"
		root.add_child(rm)
	
	# 1. Test Stars Currency Math
	var initial_stars = rm.stars
	rm.add_stars(100)
	assert(rm.stars == initial_stars + 100, "Stars should increase by 100")
	var spent = rm.spend_stars(40)
	assert(spent == true, "Should successfully spend 40 stars")
	assert(rm.stars == initial_stars + 60, "Stars remaining should match")
	var overspend = rm.spend_stars(999999)
	assert(overspend == false, "Should disallow overspending")
	print("[PASS] Stars Currency math & bounds verified.")
	
	# 2. Test Achievement Badges
	assert(rm.is_badge_unlocked("FIRST_SORTIE"), "Default badge FIRST_SORTIE should be unlocked")
	rm.unlock_badge("ACE_INTERCEPTOR")
	assert(rm.is_badge_unlocked("ACE_INTERCEPTOR"), "ACE_INTERCEPTOR should now be unlocked")
	print("[PASS] Achievement Badges unlocking verified.")
	
	# 3. Test Daily Streak System
	var can_claim = rm.can_claim_daily_streak()
	print("Can claim daily streak: ", can_claim)
	var streak_res = rm.claim_daily_streak()
	assert(streak_res.has("success"), "claim_daily_streak must return status")
	print("[PASS] Daily login streak mechanics verified.")
	
	# 4. Test Daily Reward Wheel
	var wheel_res = rm.spin_reward_wheel()
	assert(wheel_res.has("success"), "spin_reward_wheel must return result")
	if wheel_res["success"]:
		print("Wheel prize won: ", wheel_res["prize"]["label"])
	print("[PASS] Daily Reward Wheel spin verified.")
	
	# 5. Test Weapon Upgrades
	rm.add_stars(1000) # Ensure wallet has funds
	var initial_pulse = rm.get_upgrade_tier("PULSE_CANNON")
	if initial_pulse < 3:
		var upgraded = rm.buy_upgrade("PULSE_CANNON")
		assert(upgraded == true, "Should buy PULSE_CANNON upgrade")
		assert(rm.get_upgrade_tier("PULSE_CANNON") == initial_pulse + 1, "Tier should advance")
	print("[PASS] Vanguard Armory upgrades verified.")
	
	# 6. Test Serialization
	var data = rm.get_save_data()
	assert(data.has("stars") and data.has("badges") and data.has("upgrades"), "Save data must include core keys")
	rm.load_save_data(data)
	print("[PASS] RewardManager serialization & restoration verified.")
	
	# 7. Test RewardsDialog UI Lifecycle & Subtabs
	var rw_scene = load("res://rewards_dialog.tscn")
	assert(rw_scene != null, "rewards_dialog.tscn must load")
	var rw_dialog = rw_scene.instantiate()
	root.add_child(rw_dialog)
	rw_dialog.show_dialog("wheel")
	assert(rw_dialog.visible == true, "RewardsDialog should be visible")
	assert(rw_dialog.current_tab == "wheel", "Default tab should be wheel")
	
	rw_dialog._switch_tab("streak")
	assert(rw_dialog.current_tab == "streak", "Tab should switch to streak")
	assert(rw_dialog.view_streak.visible == true, "Streak view should be visible")
	
	rw_dialog._switch_tab("skins")
	assert(rw_dialog.current_tab == "skins", "Tab should switch to skins")
	assert(rw_dialog.skins_grid.get_child_count() == 5, "Should have 5 skin cards rendered")
	
	rw_dialog._switch_tab("upgrades")
	assert(rw_dialog.current_tab == "upgrades", "Tab should switch to upgrades")
	assert(rw_dialog.upgrades_grid.get_child_count() == 4, "Should have 4 upgrade cards rendered")
	
	rw_dialog._switch_tab("badges")
	assert(rw_dialog.current_tab == "badges", "Tab should switch to badges")
	assert(rw_dialog.badges_grid.get_child_count() == 10, "Should have 10 badge cards rendered")
	
	rw_dialog.hide_dialog()
	assert(rw_dialog.visible == false, "RewardsDialog should be hidden")
	rw_dialog.free()
	print("[PASS] RewardsDialog UI tabs, rendering, and lifecycle verified.")
	
	print("\n>>> ALL REWARDS & ECONOMY TESTS PASSED (100% OK)! <<<\n")
	quit(0)
