class_name AgilityCourseLevel
extends Node3D

## AgilityCourseLevel: Master Level generator and runtime controller for Agility Trials.
## Sets up the procedural or scripted course gates, target buoys, environment,
## spaceship, ghost playback, and HUD for any of the 8 trials.

@export var trial_id: String = "T01"

const GATE_SCENE: PackedScene = preload("res://agility_gate.tscn")
const TARGET_SCENE: PackedScene = preload("res://target_buoy.tscn")
const GHOST_SCENE: PackedScene = preload("res://ghost_ship.tscn")

@onready var spaceship: CharacterBody3D = $Spaceship
@onready var agility_hud: Control = $HUD/AgilityHUD
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var dir_light: DirectionalLight3D = $DirectionalLight3D
@onready var gates_container: Node3D = $GatesContainer
@onready var targets_container: Node3D = $TargetsContainer

var ghost_instance: GhostShip = null
var maneuver_detector: ManeuverDetector = null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Allow trial_id to be passed via AgilityManager if already set
	var am = get_node_or_null("/root/AgilityManager")
	if am and not am.active_trial_id.is_empty():
		trial_id = am.active_trial_id
		
	_setup_environment()
	_generate_course_trajectory()
	_setup_ghost_ship()
	_setup_maneuver_detector()
	
	# Wire HUD actions
	if agility_hud:
		if not agility_hud.retry_requested.is_connected(_on_retry):
			agility_hud.retry_requested.connect(_on_retry)
		if not agility_hud.selector_requested.is_connected(_on_exit):
			agility_hud.selector_requested.connect(_on_exit)
			
	# Start trial in manager
	if am:
		am.start_trial(trial_id, spaceship, agility_hud)

func _setup_environment() -> void:
	if not world_env or not world_env.environment:
		return
	var env = world_env.environment
	var sky_mat = env.sky.sky_material if (env and env.sky) else null
	
	match trial_id:
		"T01": # Salt Flats High Noon
			if sky_mat:
				sky_mat.sky_top_color = Color(0.15, 0.35, 0.65)
				sky_mat.sky_horizon_color = Color(0.8, 0.88, 0.98)
			env.volumetric_fog_enabled = false
		"T02": # Iron Canyon Sunset
			if sky_mat:
				sky_mat.sky_top_color = Color(0.25, 0.08, 0.05)
				sky_mat.sky_horizon_color = Color(0.95, 0.45, 0.15)
			env.volumetric_fog_enabled = false
		"T03": # Orbital Void
			if sky_mat:
				sky_mat.sky_top_color = Color(0.01, 0.02, 0.04)
				sky_mat.sky_horizon_color = Color(0.04, 0.06, 0.10)
			env.volumetric_fog_enabled = false
		"T04": # Stratosphere Twilight
			if sky_mat:
				sky_mat.sky_top_color = Color(0.08, 0.12, 0.28)
				sky_mat.sky_horizon_color = Color(0.7, 0.45, 0.85)
			env.volumetric_fog_enabled = false
		"T05": # Solar Corona Flare
			if sky_mat:
				sky_mat.sky_top_color = Color(0.35, 0.15, 0.02)
				sky_mat.sky_horizon_color = Color(1.0, 0.65, 0.1)
			env.volumetric_fog_enabled = false
		"T06": # Supersonic Polar Night
			if sky_mat:
				sky_mat.sky_top_color = Color(0.02, 0.05, 0.12)
				sky_mat.sky_horizon_color = Color(0.1, 0.85, 0.7)
			env.volumetric_fog_enabled = false
		"T07": # Blind Storm Fog
			env.volumetric_fog_enabled = true
			env.volumetric_fog_density = 0.085
			env.volumetric_fog_albedo = Color(0.45, 0.5, 0.55)
		"T08": # The Crucible Skunk Works
			if sky_mat:
				sky_mat.sky_top_color = Color(0.06, 0.08, 0.14)
				sky_mat.sky_horizon_color = Color(0.95, 0.55, 0.05)
			env.volumetric_fog_enabled = false


func _generate_course_trajectory() -> void:
	var am = get_node_or_null("/root/AgilityManager")
	var t_def = am.TRIALS_DEF.get(trial_id, {}) if am else {}
	var total_gates = int(t_def.get("total_gates", 20))
	var target_count = int(t_def.get("total_targets", 4))
	
	var points: Array[Vector3] = []
	var orientations: Array[String] = []
	var min_speeds: Array[float] = []
	
	# Generate points based on trial curriculum
	for i in range(total_gates):
		var t = float(i)
		var p = Vector3.ZERO
		var ori = "ANY"
		var spd = 0.0
		
		match trial_id:
			"T01": # Slalom S-Curve
				p.x = sin(t * 0.7) * 55.0
				p.y = 35.0 + cos(t * 0.35) * 8.0
				p.z = -120.0 - t * 115.0
			"T02": # Canyon Deck Skim (< 12m)
				p.x = sin(t * 0.9) * 35.0
				p.y = 6.5 + sin(t * 0.45) * 3.5
				p.z = -100.0 - t * 105.0
			"T03": # Knife-Edge Apertures
				p.x = cos(t * 0.5) * 45.0
				p.y = 40.0 + sin(t * 0.4) * 12.0
				p.z = -120.0 - t * 110.0
				ori = "VERTICAL" if (i % 2 == 1) else ("DIHEDRAL_45" if (i % 3 == 0) else "HORIZONTAL")
			"T04": # Vertical Loops & Corkscrew
				var loop_t = t * 0.45
				p.x = sin(loop_t) * 40.0
				p.y = 60.0 + sin(t * 0.6) * 45.0 + (50.0 if (i > 8 and i < 16) else 0.0)
				p.z = -120.0 - t * 125.0
			"T05": # Industrial Drift Hairpins
				var segment = int(t / 4)
				var sub_t = fmod(t, 4.0)
				if segment == 0:
					p = Vector3(0, 35, -120.0 - sub_t * 100.0)
				elif segment == 1:
					p = Vector3(sub_t * 90.0, 35, -520.0)
				elif segment == 2:
					p = Vector3(360.0, 35, -520.0 - sub_t * 100.0)
				else:
					p = Vector3(360.0 - sub_t * 90.0, 35, -920.0)
			"T06": # Supersonic Gauntlet
				p.x = sin(t * 0.4) * 30.0
				p.y = 45.0
				p.z = -140.0 - t * 140.0
				spd = 95.0
			"T07": # Blind Instrument Run
				p.x = sin(t * 0.6) * 50.0
				p.y = 30.0 + cos(t * 0.5) * 15.0
				p.z = -110.0 - t * 110.0
			"T08": # The Crucible Grand Prix
				if i < 8: # Sector 1: Slalom
					p.x = sin(t * 0.8) * 45.0
					p.y = 35.0
					p.z = -120.0 - t * 110.0
				elif i < 15: # Sector 2: Low Deck
					p.x = cos(t * 0.7) * 35.0
					p.y = 7.0 + sin(t * 0.5) * 3.0
					p.z = -120.0 - t * 110.0
				elif i < 22: # Sector 3: Knife Edge
					p.x = sin(t * 0.5) * 40.0
					p.y = 45.0
					p.z = -120.0 - t * 110.0
					ori = "VERTICAL" if (i % 2 == 0) else "HORIZONTAL"
				else: # Sector 4: Final Sprint
					p.x = sin(t * 0.3) * 20.0
					p.y = 35.0
					p.z = -120.0 - t * 125.0
					spd = 95.0
					
		points.append(p)
		orientations.append(ori)
		min_speeds.append(spd)

	# Instantiate Gates
	for idx in range(points.size()):
		var gate = GATE_SCENE.instantiate() as AgilityGate
		gates_container.add_child(gate)
		gate.global_position = points[idx]
		gate.gate_index = idx
		gate.required_orientation = orientations[idx]
		gate.min_required_speed = min_speeds[idx]
		
		# Orient gate toward next point or forward along -Z
		if idx < points.size() - 1:
			var next_pt = points[idx + 1]
			var look_dir = (next_pt - points[idx]).normalized()
			if look_dir.length_squared() > 0.001:
				gate.look_at(points[idx] + look_dir, Vector3.UP)
		else:
			gate.look_at(points[idx] + Vector3(0, 0, -1), Vector3.UP)

	# Instantiate Minimal Target Practice Buoys along the path
	var buoy_interval = max(2, int(total_gates / (target_count + 1)))
	var b_count = 0
	for idx in range(buoy_interval, total_gates - 1, buoy_interval):
		if b_count >= target_count:
			break
		var buoy = TARGET_SCENE.instantiate() as TargetBuoy
		targets_container.add_child(buoy)
		buoy.target_index = b_count
		
		# Offset buoy 15-20 meters to the side of gate so player can shoot it
		var gate_pos = points[idx]
		var side_offset = Vector3(22.0 if (b_count % 2 == 0) else -22.0, 4.0, 20.0)
		buoy.global_position = gate_pos + side_offset
		b_count += 1

func _setup_ghost_ship() -> void:
	ghost_instance = GHOST_SCENE.instantiate() as GhostShip
	add_child(ghost_instance)

func _setup_maneuver_detector() -> void:
	if spaceship and not spaceship.has_node("ManeuverDetector"):
		maneuver_detector = ManeuverDetector.new()
		maneuver_detector.name = "ManeuverDetector"
		maneuver_detector.ship = spaceship
		spaceship.add_child(maneuver_detector)

func _on_retry() -> void:
	get_tree().reload_current_scene()

func _on_exit() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var am = get_node_or_null("/root/AgilityManager")
	if am:
		am.is_trial_active = false
	get_tree().change_scene_to_file("res://home_menu.tscn")
