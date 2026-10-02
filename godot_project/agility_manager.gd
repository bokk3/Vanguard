extends Node

## AgilityManager: Central controller for Agility Mode ("OPERATION KINETIC").
## Manages 8 standalone flight mastery trials, high-resolution millisecond chronometer,
## gate progression, bullseye precision scoring, target practice tracking,
## ghost telemetry recording/playback, and avionics expertise ranking.

signal trial_started(trial_id: String, trial_data: Dictionary)
signal trial_completed(trial_id: String, stats: Dictionary)
signal trial_failed(trial_id: String, reason: String)
signal gate_passed(gate_idx: int, total_gates: int, grade: String, radial_offset: float, flow_mult: float)
signal maneuver_detected(type: String, score_bonus: int, time_bonus: float)
signal target_destroyed(target_idx: int, remaining: int)
signal medal_earned(trial_id: String, medal_tier: String, stars_earned: int)
signal ghost_toggled(enabled: bool)
signal avionics_score_updated(new_score: int, class_rank: String)

const SAVE_PATH = "user://agility_profile.json"

# All 8 trials are unlocked and playable from game start!
const TRIALS_DEF: Dictionary = {
	"T01": {
		"id": "T01",
		"codename": "SLALOM VECTOR",
		"subtitle": "HIGH-SPEED PYLON DANCE & BANK CADENCE",
		"desc": "Navigate 20 alternating high-g tactical pylons across the proving ground salt flats.",
		"bronze_time": 75.0,
		"silver_time": 62.0,
		"gold_time": 54.0,
		"ace_time": 48.5,
		"total_gates": 20,
		"total_targets": 4,
		"star_rewards": { "BRONZE": 100, "SILVER": 250, "GOLD": 500, "ACE": 1000 },
		"required_maneuvers": ["HIGH_G_DRIFT"],
		"scene_path": "res://agility_courses/trial_01_slalom.tscn"
	},
	"T02": {
		"id": "T02",
		"codename": "CANYON NEEDLE",
		"subtitle": "LOW-ALTITUDE DECK SKIMMING",
		"desc": "Thread razor trench crevices under a 20m ceiling without touching ground or rock walls.",
		"bronze_time": 85.0,
		"silver_time": 72.0,
		"gold_time": 62.0,
		"ace_time": 55.0,
		"total_gates": 22,
		"total_targets": 5,
		"star_rewards": { "BRONZE": 100, "SILVER": 250, "GOLD": 500, "ACE": 1000 },
		"required_maneuvers": ["DECK_SKIM"],
		"scene_path": "res://agility_courses/trial_02_canyon.tscn"
	},
	"T03": {
		"id": "T03",
		"codename": "KNIFE-EDGE CORRIDOR",
		"subtitle": "ANGULAR & VERTICAL ORIENTATION SLITS",
		"desc": "Pass narrow structural apertures requiring exact 90° and 45° wing roll alignments.",
		"bronze_time": 95.0,
		"silver_time": 80.0,
		"gold_time": 68.0,
		"ace_time": 60.0,
		"total_gates": 20,
		"total_targets": 4,
		"star_rewards": { "BRONZE": 100, "SILVER": 250, "GOLD": 500, "ACE": 1000 },
		"required_maneuvers": ["KNIFE_EDGE"],
		"scene_path": "res://agility_courses/trial_03_knife_edge.tscn"
	},
	"T04": {
		"id": "T04",
		"codename": "STRATOSPHERE ROLLER",
		"subtitle": "VERTICAL LOOPS & HELICAL BARREL ROLLS",
		"desc": "Conquer a 3D stratospheric roller-coaster trail with vertical loops and corkscrews.",
		"bronze_time": 105.0,
		"silver_time": 90.0,
		"gold_time": 78.0,
		"ace_time": 69.5,
		"total_gates": 24,
		"total_targets": 6,
		"star_rewards": { "BRONZE": 100, "SILVER": 250, "GOLD": 500, "ACE": 1000 },
		"required_maneuvers": ["BARREL_ROLL"],
		"scene_path": "res://agility_courses/trial_04_stratosphere.tscn"
	},
	"T05": {
		"id": "T05",
		"codename": "INDUSTRIAL DRIFT",
		"subtitle": "HIGH-G AIRBRAKING & RUDDER WHIPS",
		"desc": "Master right-angle corridor hairpins with hard airbrake vector drift and boost breakout.",
		"bronze_time": 90.0,
		"silver_time": 76.0,
		"gold_time": 66.0,
		"ace_time": 58.0,
		"total_gates": 18,
		"total_targets": 5,
		"star_rewards": { "BRONZE": 100, "SILVER": 250, "GOLD": 500, "ACE": 1000 },
		"required_maneuvers": ["HIGH_G_DRIFT"],
		"scene_path": "res://agility_courses/trial_05_drift.tscn"
	},
	"T06": {
		"id": "T06",
		"codename": "SUPERSONIC GAUNTLET",
		"subtitle": "CONTINUOUS AFTERBURNER MACH SPRINT",
		"desc": "High-velocity speed gates requiring sustained boost above 95 m/s with nitro pacing.",
		"bronze_time": 65.0,
		"silver_time": 54.0,
		"gold_time": 46.5,
		"ace_time": 41.0,
		"total_gates": 20,
		"total_targets": 4,
		"star_rewards": { "BRONZE": 100, "SILVER": 250, "GOLD": 500, "ACE": 1000 },
		"required_maneuvers": ["HIGH_G_DRIFT"],
		"scene_path": "res://agility_courses/trial_06_gauntlet.tscn"
	},
	"T07": {
		"id": "T07",
		"codename": "BLIND INSTRUMENT RUN",
		"subtitle": "ZERO-VISIBILITY SYNTHETIC APEX",
		"desc": "Dense storm flight with zero landmarks; navigate solely via 3D audio beacons and HUD tunnel.",
		"bronze_time": 100.0,
		"silver_time": 85.0,
		"gold_time": 74.0,
		"ace_time": 65.0,
		"total_gates": 20,
		"total_targets": 4,
		"star_rewards": { "BRONZE": 100, "SILVER": 250, "GOLD": 500, "ACE": 1000 },
		"required_maneuvers": ["DECK_SKIM"],
		"scene_path": "res://agility_courses/trial_07_blind.tscn"
	},
	"T08": {
		"id": "T08",
		"codename": "THE CRUCIBLE // TOP GUN",
		"subtitle": "MULTI-DISCIPLINE MASTER GRAND PRIX",
		"desc": "The ultimate flight qualification combining all 7 aerobatic disciplines and carrier flare.",
		"bronze_time": 160.0,
		"silver_time": 135.0,
		"gold_time": 118.0,
		"ace_time": 104.0,
		"total_gates": 30,
		"total_targets": 8,
		"star_rewards": { "BRONZE": 150, "SILVER": 350, "GOLD": 750, "ACE": 1500 },
		"required_maneuvers": ["BARREL_ROLL", "KNIFE_EDGE", "HIGH_G_DRIFT", "DECK_SKIM"],
		"scene_path": "res://agility_courses/trial_08_crucible.tscn"
	}
}

# Active Trial Telemetry State
var active_trial_id: String = ""
var is_trial_active: bool = false
var start_ticks_usec: int = 0
var elapsed_time: float = 0.0
var penalty_time: float = 0.0

var current_gate_idx: int = 0
var total_gates_in_trial: int = 0
var perfect_apexes: int = 0
var clean_apexes: int = 0
var marginal_apexes: int = 0
var missed_gates_count: int = 0

var targets_destroyed_count: int = 0
var total_targets_in_trial: int = 0

var flow_multiplier: float = 1.0
var flow_streak: int = 0
var maneuvers_logged: Array[Dictionary] = []
var trial_score: int = 0

# Ghost Telemetry
var ghost_enabled: bool = true
var ghost_playback_samples: Array = [] # [ { "time": float, "pos": Vector3, "rot": Vector3 } ]
var ghost_recording_samples: Array = []
var ghost_sample_timer: float = 0.0
const GHOST_SAMPLE_INTERVAL: float = 0.05 # 20 Hz recording

# Pilot Profile Agility Records
var trial_records: Dictionary = {}
var avionics_score: int = 0
var avionics_class: String = "CLASS-E ROOKIE"

var active_ship_node: Node3D = null
var active_hud_node: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_profile()
	_recalculate_avionics_expertise()

func _process(delta: float) -> void:
	if not is_trial_active:
		return
		
	elapsed_time = float(Time.get_ticks_usec() - start_ticks_usec) / 1000000.0
	
	# Sample ghost telemetry from active ship
	if active_ship_node and is_instance_valid(active_ship_node):
		ghost_sample_timer += delta
		if ghost_sample_timer >= GHOST_SAMPLE_INTERVAL:
			ghost_sample_timer = 0.0
			ghost_recording_samples.append({
				"time": elapsed_time,
				"pos": active_ship_node.global_position,
				"rot": active_ship_node.global_rotation
			})

## Starts a designated Agility Trial
func start_trial(trial_id: String, ship_node: Node3D = null, hud_node: Control = null) -> void:
	if not TRIALS_DEF.has(trial_id):
		push_error("[AgilityManager] Unknown trial ID: %s" % trial_id)
		return
		
	var t_data = TRIALS_DEF[trial_id]
	active_trial_id = trial_id
	active_ship_node = ship_node
	active_hud_node = hud_node
	
	start_ticks_usec = Time.get_ticks_usec()
	elapsed_time = 0.0
	penalty_time = 0.0
	current_gate_idx = 0
	total_gates_in_trial = t_data.get("total_gates", 20)
	total_targets_in_trial = t_data.get("total_targets", 4)
	
	perfect_apexes = 0
	clean_apexes = 0
	marginal_apexes = 0
	missed_gates_count = 0
	targets_destroyed_count = 0
	flow_multiplier = 1.0
	flow_streak = 0
	maneuvers_logged.clear()
	trial_score = 0
	
	# Load existing ghost playback for this trial
	ghost_recording_samples.clear()
	ghost_sample_timer = 0.0
	_load_ghost_playback(trial_id)
	
	is_trial_active = true
	trial_started.emit(trial_id, t_data)
	print(">>> [AgilityManager] Started Agility Trial: [%s] %s" % [trial_id, t_data["codename"]])

## Called when player ship enters an AgilityGate
func on_gate_passed(gate_idx: int, radial_offset: float, orientation_match: bool) -> void:
	if not is_trial_active:
		return
		
	var grade = "MARGINAL"
	var pts = 50
	
	if orientation_match:
		if radial_offset <= 1.8:
			grade = "PERFECT APEX"
			pts = 300
			perfect_apexes += 1
			_advance_flow(true)
		elif radial_offset <= 4.2:
			grade = "CLEAN"
			pts = 150
			clean_apexes += 1
			_advance_flow(true)
		else:
			grade = "MARGINAL"
			pts = 50
			marginal_apexes += 1
			_advance_flow(false)
	else:
		# Wrong orientation penalty
		grade = "ORIENTATION CLIP"
		pts = 20
		penalty_time += 1.5
		_advance_flow(false)
		
	trial_score += int(pts * flow_multiplier)
	current_gate_idx = max(current_gate_idx, gate_idx + 1)
	
	gate_passed.emit(current_gate_idx, total_gates_in_trial, grade, radial_offset, flow_multiplier)
	
	if current_gate_idx >= total_gates_in_trial:
		complete_trial()

## Called when player misses a gate completely
func on_gate_missed(gate_idx: int) -> void:
	if not is_trial_active:
		return
	missed_gates_count += 1
	penalty_time += 5.0
	_advance_flow(false)
	
	gate_passed.emit(gate_idx + 1, total_gates_in_trial, "MISSED (+5.0s)", 15.0, flow_multiplier)
	
	if missed_gates_count >= 3:
		trial_failed.emit(active_trial_id, "DISQUALIFIED // 3 GATES MISSED")
		is_trial_active = false

## Advances flow state combo
func _advance_flow(is_clean: bool) -> void:
	if is_clean:
		flow_streak += 1
		if flow_streak >= 8:
			flow_multiplier = 3.0
		elif flow_streak >= 5:
			flow_multiplier = 2.5
		elif flow_streak >= 3:
			flow_multiplier = 2.0
		elif flow_streak >= 1:
			flow_multiplier = 1.5
	else:
		flow_streak = 0
		flow_multiplier = 1.0

## Logs a detected flight maneuver (barrel roll, drift, knife edge, etc.)
func register_maneuver(m_type: String, score_bonus: int = 500, time_bonus: float = 0.5) -> void:
	if not is_trial_active:
		return
		
	var entry = {
		"type": m_type,
		"time": elapsed_time,
		"score": score_bonus
	}
	maneuvers_logged.append(entry)
	trial_score += int(score_bonus * flow_multiplier)
	
	# Subtract small time bonus for stylish maneuvers
	if time_bonus > 0.0:
		penalty_time = max(-10.0, penalty_time - time_bonus)
		
	maneuver_detected.emit(m_type, score_bonus, time_bonus)
	print(">>> [AgilityManager] Maneuver Executed: %s (+%d pts, -%.1fs)" % [m_type, score_bonus, time_bonus])

## Called when a target practice buoy is destroyed
func register_target_destroyed(target_idx: int) -> void:
	if not is_trial_active:
		return
		
	targets_destroyed_count += 1
	var score_bonus = 250
	var time_bonus = 0.5
	trial_score += int(score_bonus * flow_multiplier)
	penalty_time = max(-15.0, penalty_time - time_bonus)
	
	var rem = max(0, total_targets_in_trial - targets_destroyed_count)
	target_destroyed.emit(target_idx, rem)

## Completes the active trial, awards medals, stars, updates profile & ghost
func complete_trial() -> void:
	if not is_trial_active:
		return
	is_trial_active = false
	
	var final_time = max(0.01, elapsed_time + penalty_time)
	var t_def = TRIALS_DEF.get(active_trial_id, {})
	var medal = _calculate_medal(active_trial_id, final_time)
	
	var total_scored_gates = max(1, perfect_apexes + clean_apexes + marginal_apexes + missed_gates_count)
	var precision_pct = (float(perfect_apexes * 100 + clean_apexes * 65 + marginal_apexes * 25) / float(total_scored_gates * 100)) * 100.0
	
	var stats = {
		"trial_id": active_trial_id,
		"final_time": final_time,
		"raw_time": elapsed_time,
		"penalty_time": penalty_time,
		"medal": medal,
		"precision_pct": precision_pct,
		"perfect_apexes": perfect_apexes,
		"clean_apexes": clean_apexes,
		"missed_gates": missed_gates_count,
		"targets_hit": targets_destroyed_count,
		"total_targets": total_targets_in_trial,
		"maneuvers_count": maneuvers_logged.size(),
		"final_score": trial_score
	}
	
	# Process Medal Awards & Stars
	_process_medal_rewards(active_trial_id, medal, final_time, precision_pct)
	
	# Save ghost replay if this is a personal best
	_evaluate_ghost_record(active_trial_id, final_time)
	
	# Update avionics expertise rating
	_recalculate_avionics_expertise()
	
	_save_profile()
	
	trial_completed.emit(active_trial_id, stats)
	print(">>> [AgilityManager] Trial [%s] Completed in %.3fs // Medal: %s // Precision: %.1f%%" % [
		active_trial_id, final_time, medal, precision_pct
	])

func _calculate_medal(t_id: String, time_val: float) -> String:
	var t_def = TRIALS_DEF.get(t_id, {})
	if time_val <= t_def.get("ace_time", 999.0):
		return "ACE"
	elif time_val <= t_def.get("gold_time", 999.0):
		return "GOLD"
	elif time_val <= t_def.get("silver_time", 999.0):
		return "SILVER"
	elif time_val <= t_def.get("bronze_time", 999.0):
		return "BRONZE"
	return "NONE"

func _process_medal_rewards(t_id: String, medal: String, final_time: float, precision_pct: float) -> void:
	if not trial_records.has(t_id):
		trial_records[t_id] = {
			"best_time": final_time,
			"medal": medal,
			"claimed_medals": [],
			"precision_pct": precision_pct,
			"maneuvers": maneuvers_logged.size(),
			"score": trial_score
		}
	
	var rec: Dictionary = trial_records[t_id]
	if final_time < rec.get("best_time", 9999.0):
		rec["best_time"] = final_time
		rec["precision_pct"] = precision_pct
		rec["score"] = max(rec.get("score", 0), trial_score)
		
	var cur_medal = rec.get("medal", "NONE")
	if _medal_rank(medal) > _medal_rank(cur_medal):
		rec["medal"] = medal
		
	# Award Stars for newly earned medals
	var claimed: Array = rec.get("claimed_medals", [])
	var t_def = TRIALS_DEF.get(t_id, {})
	var star_rewards: Dictionary = t_def.get("star_rewards", {})
	
	var tiers_to_check = ["BRONZE", "SILVER", "GOLD", "ACE"]
	var earned_rank = _medal_rank(medal)
	
	var total_stars_earned = 0
	for t in tiers_to_check:
		if earned_rank >= _medal_rank(t) and not claimed.has(t):
			claimed.append(t)
			var stars = star_rewards.get(t, 100)
			total_stars_earned += stars
			medal_earned.emit(t_id, t, stars)
			
			var rm = get_node_or_null("/root/RewardManager")
			if rm and rm.has_method("add_stars"):
				rm.add_stars(stars, "Agility Trial %s %s Medal" % [t_id, t])
				
	rec["claimed_medals"] = claimed
	trial_records[t_id] = rec

func _medal_rank(m: String) -> int:
	match m:
		"ACE": return 4
		"GOLD": return 3
		"SILVER": return 2
		"BRONZE": return 1
		_: return 0

## Recalculates pilot's overall Avionics Expertise Score
func _recalculate_avionics_expertise() -> void:
	var total_score = 0
	var medal_weights = { "ACE": 1200, "GOLD": 800, "SILVER": 450, "BRONZE": 200, "NONE": 0 }
	
	for t_id in TRIALS_DEF.keys():
		if trial_records.has(t_id):
			var rec = trial_records[t_id]
			var m = rec.get("medal", "NONE")
			total_score += medal_weights.get(m, 0)
			
			# Add precision bonus
			var prec = float(rec.get("precision_pct", 0.0))
			total_score += int(prec * 5.0) # up to +500 pts per trial
			
			# Add maneuvers executed
			var man = int(rec.get("maneuvers", 0))
			total_score += man * 25
			
	avionics_score = total_score
	
	if avionics_score >= 8500:
		avionics_class = "CLASS-S TOP GUN VIRTUOSO"
	elif avionics_score >= 6000:
		avionics_class = "CLASS-A ACE NAVIGATOR"
	elif avionics_score >= 4000:
		avionics_class = "CLASS-B AVIONICS SPECIALIST"
	elif avionics_score >= 2000:
		avionics_class = "CLASS-C PRECISION PILOT"
	elif avionics_score >= 800:
		avionics_class = "CLASS-D FLIGHT APPRENTICE"
	else:
		avionics_class = "CLASS-E ROOKIE"
		
	# Sync into AuthManager if authenticated
	var auth_mgr = get_node_or_null("/root/AuthManager")
	if auth_mgr and "stats" in auth_mgr and typeof(auth_mgr.stats) == TYPE_DICTIONARY:
		auth_mgr.stats["avionics_expertise_score"] = avionics_score
		auth_mgr.stats["avionics_class"] = avionics_class
		
	avionics_score_updated.emit(avionics_score, avionics_class)

func toggle_ghost() -> void:
	ghost_enabled = not ghost_enabled
	ghost_toggled.emit(ghost_enabled)

func _evaluate_ghost_record(t_id: String, time_val: float) -> void:
	var rec = trial_records.get(t_id, {})
	if time_val <= rec.get("best_time", 9999.0) and ghost_recording_samples.size() > 10:
		ghost_playback_samples = ghost_recording_samples.duplicate(true)

func _load_ghost_playback(t_id: String) -> void:
	# Keep in memory or reload
	if ghost_playback_samples.is_empty():
		pass

func _save_profile() -> void:
	var data = {
		"trial_records": trial_records,
		"avionics_score": avionics_score,
		"avionics_class": avionics_class,
		"ghost_enabled": ghost_enabled
	}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
		f.close()

func _load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		trial_records = parsed.get("trial_records", {})
		avionics_score = int(parsed.get("avionics_score", 0))
		avionics_class = str(parsed.get("avionics_class", "CLASS-E ROOKIE"))
		ghost_enabled = bool(parsed.get("ghost_enabled", true))

## Returns total medals count by tier: { "bronze": int, "silver": int, "gold": int, "ace": int }
func get_medals_tally() -> Dictionary:
	var tally = { "BRONZE": 0, "SILVER": 0, "GOLD": 0, "ACE": 0 }
	for t_id in trial_records.keys():
		var rec = trial_records[t_id]
		var claimed: Array = rec.get("claimed_medals", [])
		for m in claimed:
			if tally.has(m):
				tally[m] += 1
	return tally
