extends SceneTree

## Comprehensive Verification Suite for Agility Mode ("OPERATION KINETIC").
## Tests trial configurations, chronometer timing, radial bullseye precision,
## target buoy destruction, maneuver registration, medal & star payouts,
## avionics expertise scoring, ghost ship playback, and UI dialog integration.

var frame_count: int = 0
var test_done: bool = false
var timeout: float = 0.0

func _init() -> void:
	print("\n=======================================================")
	print(">>> Project Vanguard: Agility Mode Test Suite <<<")
	print("=======================================================\n")

func _process(delta: float) -> bool:
	if test_done:
		return true
		
	timeout += delta
	if timeout > 10.0:
		push_error("Agility mode test timed out!")
		quit(1)
		return true

	frame_count += 1
	if frame_count < 3:
		return false
		
	test_done = true
	_run_agility_tests()
	return true

func _run_agility_tests() -> void:
	print("--- STEP 1: Verify AgilityManager Autoload & Trial Definitions ---")
	var am = root.get_node_or_null("AgilityManager")
	if not am:
		am = preload("res://agility_manager.gd").new()
		am.name = "AgilityManager"
		root.add_child(am)
	
	assert(am != null, "AgilityManager must be present")
	assert(am.TRIALS_DEF.size() == 8, "All 8 trials must be defined")
	
	var trial_keys = ["T01", "T02", "T03", "T04", "T05", "T06", "T07", "T08"]
	for tid in trial_keys:
		assert(am.TRIALS_DEF.has(tid), "Trial %s must be present in TRIALS_DEF" % tid)
		var t_data = am.TRIALS_DEF[tid]
		assert(t_data.has("codename"), "Trial %s must have codename" % tid)
		assert(t_data.has("gold_time"), "Trial %s must have gold_time" % tid)
		assert(t_data.has("ace_time"), "Trial %s must have ace_time" % tid)
		assert(t_data.has("star_rewards"), "Trial %s must have star_rewards" % tid)
		assert(t_data["star_rewards"].has("GOLD"), "Trial %s must reward stars for GOLD" % tid)
	print("[PASS] 8 Standalone Trials defined with required telemetry benchmarks.")

	print("\n--- STEP 2: Verify Trial Initialization & Chronometer Reset ---")
	am.start_trial("T01")
	assert(am.is_trial_active == true, "Trial must be active after start")
	assert(am.active_trial_id == "T01", "Active trial ID must be T01")
	assert(am.current_gate_idx == 0, "Current gate index must be reset to 0")
	assert(am.penalty_time == 0.0, "Penalty time must be reset to 0.0")
	assert(am.flow_multiplier == 1.0, "Flow multiplier must start at 1.0x")
	print("[PASS] Trial start and telemetry resets verified.")

	print("\n--- STEP 3: Verify Radial Bullseye Precision & Flow Combo ---")
	# Gate 0: Perfect Bullseye (< 1.8m offset)
	var prev_score = am.trial_score
	am.on_gate_passed(0, 0.8, true)
	assert(am.perfect_apexes == 1, "Should record 1 perfect apex")
	assert(am.flow_streak == 1, "Flow streak should advance to 1")
	assert(am.trial_score > prev_score, "Score should increase on perfect gate")

	# Gate 1: Clean pass (< 4.2m offset)
	prev_score = am.trial_score
	am.on_gate_passed(1, 2.5, true)
	assert(am.clean_apexes == 1, "Should record 1 clean apex")
	assert(am.flow_streak == 2, "Flow streak should advance to 2")

	# Gate 2: Orientation clip (wrong roll angle)
	var prev_pen = am.penalty_time
	am.on_gate_passed(2, 1.0, false)
	assert(am.penalty_time > prev_pen, "Orientation clip must add penalty time (+1.5s)")
	assert(am.flow_streak == 0, "Mismatched orientation must break flow streak")

	# Gate 3: Missed gate completely
	prev_pen = am.penalty_time
	am.on_gate_missed(3)
	assert(am.missed_gates_count == 1, "Should record 1 missed gate")
	assert(am.penalty_time == prev_pen + 5.0, "Missed gate must add +5.0s penalty")
	print("[PASS] Bullseye precision, orientation clip penalties, and gate misses verified.")

	print("\n--- STEP 4: Verify Target Practice Buoys & Weapons Tracking ---")
	prev_score = am.trial_score
	prev_pen = am.penalty_time
	am.register_target_destroyed(0)
	assert(am.targets_destroyed_count == 1, "Target buoys destroyed should increment")
	assert(am.trial_score >= prev_score + 250, "Target buoy destruction awards +250 score bonus")
	assert(am.penalty_time == prev_pen - 0.5, "Target buoy destruction deducts -0.5s from final time")
	print("[PASS] Target buoy kinetic destruction and time deductions verified.")

	print("\n--- STEP 5: Verify Flight Maneuver Registration ---")
	prev_score = am.trial_score
	prev_pen = am.penalty_time
	am.register_maneuver("BARREL_ROLL", 500, 0.5)
	assert(am.maneuvers_logged.size() == 1, "Maneuver should be logged in telemetry")
	assert(am.trial_score >= prev_score + 500, "Maneuver execution awards score bonus")
	assert(am.penalty_time == prev_pen - 0.5, "Maneuver execution awards time bonus")
	print("[PASS] Maneuver telemetry detection and reward bonus verified.")

	print("\n--- STEP 6: Verify Trial Completion, Medal Calculation & Star Payout ---")
	var rm = root.get_node_or_null("RewardManager")
	if not rm:
		rm = preload("res://reward_manager.gd").new()
		rm.name = "RewardManager"
		root.add_child(rm)
		
	# Clear previous T01 record to ensure fresh medal award verification
	am.trial_records.erase("T01")
	am.is_trial_active = true
	am.active_trial_id = "T01"
	
	var initial_stars = rm.stars
	# Force fast elapsed time to guarantee GOLD medal
	am.elapsed_time = 50.0 # T01 Gold is 54.0s
	am.penalty_time = 0.0
	am.complete_trial()
	
	assert(am.is_trial_active == false, "Trial should no longer be active after completion")
	assert(am.trial_records.has("T01"), "T01 record must exist in trial_records")
	var rec = am.trial_records["T01"]
	assert(rec.has("medal"), "Record must track medal")
	assert(rec["medal"] in ["GOLD", "ACE"], "Medal earned should be GOLD or ACE for 50.0s")
	assert(rm.stars > initial_stars, "Stars should have been paid out to player wallet")
	print("[PASS] Trial completion awarded %s medal and credited %d stars." % [rec["medal"], rm.stars - initial_stars])

	print("\n--- STEP 7: Verify Avionics Expertise Ranking System ---")
	assert(am.avionics_score > 0, "Avionics expertise score should be calculated > 0")
	assert(not am.avionics_class.is_empty(), "Avionics class rank must be non-empty string")
	print("Current Avionics Score: %d PTS // Rank: %s" % [am.avionics_score, am.avionics_class])
	
	var tally = am.get_medals_tally()
	assert(tally.has("GOLD") and tally.has("BRONZE") and tally.has("ACE"), "Tally must include all tiers")
	print("[PASS] Avionics expertise score and medals tally verified.")

	print("\n--- STEP 8: Verify Ghost Ship Toggle ---")
	var initial_ghost = am.ghost_enabled
	am.toggle_ghost()
	assert(am.ghost_enabled == not initial_ghost, "Ghost toggle should invert ghost_enabled")
	am.toggle_ghost()
	assert(am.ghost_enabled == initial_ghost, "Ghost toggle again should restore initial state")
	print("[PASS] Ghost ship toggle verified.")

	print("\n--- STEP 9: Verify Disk Persistence ---")
	am._save_profile()
	var saved_score = am.avionics_score
	am.avionics_score = 0
	am._load_profile()
	assert(am.avionics_score == saved_score, "Avionics score must be restored from disk profile")
	print("[PASS] Agility profile disk persistence verified.")

	print("\n--- STEP 10: Verify AgilitySelectorDialog UI ---")
	var sel_scene = load("res://agility_selector_dialog.tscn")
	assert(sel_scene != null, "agility_selector_dialog.tscn must exist and load")
	var sel_dialog = sel_scene.instantiate()
	root.add_child(sel_dialog)
	sel_dialog.show_selector()
	assert(sel_dialog.visible == true, "AgilitySelectorDialog should be visible")
	assert(sel_dialog.trials_grid.get_child_count() == 8, "Should render all 8 trial cards in grid")
	sel_dialog.hide_selector()
	assert(sel_dialog.visible == false, "AgilitySelectorDialog should be hidden")
	sel_dialog.free()
	print("[PASS] AgilitySelectorDialog UI lifecycle and 8 cards verified.")

	print("\n--- STEP 11: Verify CombatStatsDialog Avionics Integration ---")
	var stats_scene = load("res://combat_stats_dialog.tscn")
	assert(stats_scene != null, "combat_stats_dialog.tscn must exist and load")
	var stats_dialog = stats_scene.instantiate()
	root.add_child(stats_dialog)
	stats_dialog.show_stats()
	assert(stats_dialog.visible == true, "CombatStatsDialog should be visible")
	assert(stats_dialog.avionics_score_val != null, "avionics_score_val label must exist")
	assert(stats_dialog.agility_medals_val != null, "agility_medals_val label must exist")
	assert(stats_dialog.avionics_class_val != null, "avionics_class_val label must exist")
	stats_dialog.hide_stats()
	stats_dialog.free()
	print("[PASS] CombatStatsDialog Agility & Avionics section verified.")

	print("\n--- STEP 12: Verify All 8 Course Scenes Instantiate Cleanly ---")
	for i in range(1, 9):
		var num_str = "%02d" % i
		var course_names = ["slalom", "canyon", "knife_edge", "stratosphere", "drift", "gauntlet", "blind", "crucible"]
		var c_path = "res://agility_courses/trial_%s_%s.tscn" % [num_str, course_names[i - 1]]
		var c_scene = load(c_path)
		assert(c_scene != null, "Course scene %s must load" % c_path)
		var c_inst = c_scene.instantiate()
		assert(c_inst != null, "Course scene %s must instantiate" % c_path)
		c_inst.free()
	print("[PASS] All 8 Course scenes instantiated cleanly.")

	print("\n=======================================================")
	print(">>> ALL AGILITY MODE TESTS PASSED (100% OK)! <<<")
	print("=======================================================\n")
	quit(0)
