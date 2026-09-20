extends Node

## MissionManager: Central campaign and mission controller for Project Vanguard.
## Loads data/campaign_manifest.json, configures environmental skyboxes, overrides flight envelopes,
## spawns mission targets/waves, coordinates diegetic radio comms, and tracks campaign progress.

signal campaign_updated()
signal mission_started(mission_id: String, mission_data: Dictionary)
signal objective_updated(obj_id: String, status: String, text: String, cur_val: Variant, max_val: Variant)
signal radio_transmission_started(speaker_name: String, callsign: String, text: String, color: Color, duration: float)
signal radio_transmission_ended()
signal mission_completed(mission_id: String, stats: Dictionary)
signal mission_failed(mission_id: String, reason: String)

const MANIFEST_PATH = "res://data/campaign_manifest.json"

# Speaker Profiles for Radio Communications
const SPEAKERS = {
	"APEX_CMD": { "name": "Apex Command (AWACS)", "callsign": "APEX-CMD", "color": Color(1.0, 0.84, 0.2) },
	"AEGIS_7":  { "name": "Aegis-7 (Cockpit EVA)",  "callsign": "AEGIS-7",  "color": Color(0.0, 0.90, 1.0) },
	"VIPER_2":  { "name": "Lt. Vance Miller",       "callsign": "VIPER-2",  "color": Color(0.2, 0.95, 0.4) },
	"OLYMPUS_4":{ "name": "Transport Olympus-4",   "callsign": "OLYMPUS-4","color": Color(0.4, 0.75, 1.0) },
	"GHOST":    { "name": "Helion Commander",      "callsign": "GHOST",    "color": Color(1.0, 0.22, 0.3) }
}

# Campaign Definitions
var manifest_data: Dictionary = {}
var missions_dict: Dictionary = {}
var mission_ids: Array[String] = []

# Persistent Campaign Progression
var unlocked_missions: Array[String] = ["M01"]
var completed_missions: Dictionary = {} # mission_id -> { "best_time": float, "hit_rate": float, "stars": int }
var current_mission_id: String = "M01"

# Active Sortie State
var is_sortie_active: bool = false
var sortie_start_time: float = 0.0
var sortie_elapsed_time: float = 0.0
var missiles_fired: int = 0
var missiles_hit: int = 0
var targets_destroyed: int = 0
var targets_total: int = 0
var altitude_warning_timer: float = 0.0
var active_objectives: Array[Dictionary] = []

# Comms Queue System
var comms_queue: Array[Dictionary] = []
var current_transmission: Dictionary = {}
var transmission_timer: float = 0.0
var comms_cooldown: float = 0.0

# References to active level nodes
var active_root: Node3D = null
var active_ship: CharacterBody3D = null
var active_env: WorldEnvironment = null
var active_sun: DirectionalLight3D = null
var active_hud: Control = null
var comms_audio_player: AudioStreamPlayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	comms_audio_player = AudioStreamPlayer.new()
	comms_audio_player.name = "CommsAudioPlayer"
	comms_audio_player.bus = "Master"
	add_child(comms_audio_player)
	_load_campaign_manifest()

func _process(delta: float) -> void:
	_process_comms_queue(delta)
	
	if is_sortie_active and not get_tree().paused:
		sortie_elapsed_time += delta
		_evaluate_continuous_objectives(delta)

# -----------------------------------------------------------------------------
# 1. Manifest Loading & Retrieval
# -----------------------------------------------------------------------------
func _load_campaign_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_error("[MissionManager] Manifest not found at: " + MANIFEST_PATH)
		return
	
	var file = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if not file:
		push_error("[MissionManager] Failed to read manifest.")
		return
	
	var json_str = file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(json_str)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[MissionManager] Invalid JSON in manifest.")
		return
	
	manifest_data = parsed
	missions_dict.clear()
	mission_ids.clear()
	
	for m in manifest_data.get("missions", []):
		var id = m.get("id", "")
		if id != "":
			missions_dict[id] = m
			mission_ids.append(id)
	
	print("[MissionManager] Loaded ", missions_dict.size(), " missions from manifest.")

func get_mission(id: String) -> Dictionary:
	if missions_dict.is_empty():
		_load_campaign_manifest()
	return missions_dict.get(id, {})

func get_all_missions() -> Array:
	if missions_dict.is_empty():
		_load_campaign_manifest()
	return manifest_data.get("missions", [])

func is_mission_unlocked(id: String) -> bool:
	return id in unlocked_missions

func unlock_mission(id: String) -> void:
	if id in missions_dict and id not in unlocked_missions:
		unlocked_missions.append(id)
		campaign_updated.emit()
		print("[MissionManager] Unlocked mission: ", id)

# -----------------------------------------------------------------------------
# 2. Mission Setup & Level Initialization
# -----------------------------------------------------------------------------
func initialize_level(root_node: Node3D) -> void:
	active_root = root_node
	active_env = root_node.get_node_or_null("WorldEnvironment") as WorldEnvironment
	active_sun = root_node.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	active_ship = root_node.get_node_or_null("Spaceship") as CharacterBody3D
	active_hud = root_node.find_child("TacticalOverlay", true, false) as Control
	
	var m_data = get_mission(current_mission_id)
	if m_data.is_empty():
		push_warning("[MissionManager] No active mission found for id: " + current_mission_id + ". Using M01 default.")
		m_data = get_mission("M01")
		current_mission_id = "M01"
	
	print("[MissionManager] Initializing Sortie: [", current_mission_id, "] ", m_data.get("codename", "UNKNOWN"))
	
	# 1. Apply Skybox & Lighting
	_apply_skybox_preset(m_data.get("sky_preset", "overcast_storm"))
	
	# 2. Apply Aircraft Overrides
	if active_ship and "stall_speed" in active_ship:
		var stall = float(m_data.get("stall_speed_ms", 25.0))
		active_ship.stall_speed = stall
		print("[MissionManager] Aircraft stall speed configured to: ", stall, " m/s")
	
	# 3. Setup Objectives
	_setup_objectives(m_data)
	
	# 4. Clear Comms and Reset Sortie Metrics
	comms_queue.clear()
	current_transmission.clear()
	transmission_timer = 0.0
	is_sortie_active = true
	sortie_elapsed_time = 0.0
	missiles_fired = 0
	missiles_hit = 0
	targets_destroyed = 0
	altitude_warning_timer = 0.0
	
	# 5. Spawn Mission Specific Entities
	_spawn_mission_entities(m_data)
	
	# 6. Trigger Sortie Scripted Radio Communications
	_trigger_intro_comms(current_mission_id)
	
	mission_started.emit(current_mission_id, m_data)

func _setup_objectives(m_data: Dictionary) -> void:
	active_objectives.clear()
	var raw_objs = m_data.get("objectives", [])
	targets_total = 0
	
	for obj in raw_objs:
		var item = {
			"id": obj.get("id", ""),
			"text": obj.get("text", ""),
			"mandatory": obj.get("mandatory", true),
			"status": "IN_PROGRESS",
			"current_val": 0,
			"target_val": 1
		}
		
		# Configure numeric targets
		if item["id"] == "obj_destroy_all" or item["id"] == "obj_escorts":
			item["target_val"] = 4
			targets_total += 4
		elif item["id"] == "obj_relays":
			item["target_val"] = 3
			targets_total += 3
		elif item["id"] == "obj_boss":
			item["target_val"] = 1
			targets_total += 1
		
		active_objectives.append(item)
		objective_updated.emit(item["id"], item["status"], item["text"], item["current_val"], item["target_val"])

func _spawn_mission_entities(m_data: Dictionary) -> void:
	if not active_root:
		return
	
	# Clean up any static EnemyDroneAlpha in default main.tscn
	var default_drone = active_root.get_node_or_null("EnemyDroneAlpha")
	if default_drone:
		default_drone.queue_free()
	
	match current_mission_id:
		"M01":
			_spawn_m01_recon_drones()
		"M02":
			_spawn_m02_relays_and_patrols()
		"M03":
			_spawn_m03_transport_and_allies()
		"M04":
			_spawn_m04_boss_and_escorts()

# -----------------------------------------------------------------------------
# 3. Environment & Atmosphere Presets
# -----------------------------------------------------------------------------
func _apply_skybox_preset(preset_name: String) -> void:
	if not active_env or not active_env.environment:
		return
	
	var env = active_env.environment
	var sky_mat = ProceduralSkyMaterial.new()
	
	match preset_name:
		"overcast_storm": # M01: Low dark clouds, thunderous gloom
			sky_mat.sky_top_color = Color(0.08, 0.13, 0.20)
			sky_mat.sky_horizon_color = Color(0.35, 0.40, 0.45)
			sky_mat.ground_bottom_color = Color(0.08, 0.10, 0.12)
			sky_mat.ground_horizon_color = Color(0.24, 0.28, 0.32)
			sky_mat.sun_angle_max = 20.0
			sky_mat.sun_curve = 0.08
			if active_sun:
				active_sun.light_color = Color(0.85, 0.90, 0.95)
				active_sun.light_energy = 0.95
			env.volumetric_fog_enabled = true
			env.volumetric_fog_density = 0.008
			env.volumetric_fog_albedo = Color(0.3, 0.35, 0.4)
			
		"dusk_canyon": # M02: Golden hour amber horizon with deep canyon shadows
			sky_mat.sky_top_color = Color(0.18, 0.12, 0.28)
			sky_mat.sky_horizon_color = Color(0.92, 0.46, 0.16)
			sky_mat.ground_bottom_color = Color(0.18, 0.09, 0.08)
			sky_mat.ground_horizon_color = Color(0.52, 0.24, 0.14)
			if active_sun:
				active_sun.light_color = Color(1.0, 0.72, 0.48)
				active_sun.light_energy = 1.25
				active_sun.rotation_degrees = Vector3(-18, -45, 0)
			env.volumetric_fog_enabled = true
			env.volumetric_fog_density = 0.004
			env.volumetric_fog_albedo = Color(0.65, 0.35, 0.20)
			
		"dawn_clear": # M03: Clear indigo transition to morning gold
			sky_mat.sky_top_color = Color(0.10, 0.16, 0.38)
			sky_mat.sky_horizon_color = Color(0.96, 0.78, 0.45)
			sky_mat.ground_bottom_color = Color(0.12, 0.15, 0.18)
			sky_mat.ground_horizon_color = Color(0.38, 0.44, 0.48)
			if active_sun:
				active_sun.light_color = Color(1.0, 0.92, 0.82)
				active_sun.light_energy = 1.15
				active_sun.rotation_degrees = Vector3(-25, 30, 0)
			env.volumetric_fog_enabled = false
			
		"stratosphere_space": # M04: Near-black Karman boundary, bright sun, thin cyan limb
			sky_mat.sky_top_color = Color(0.01, 0.01, 0.03)
			sky_mat.sky_horizon_color = Color(0.06, 0.48, 0.88)
			sky_mat.ground_bottom_color = Color(0.02, 0.04, 0.08)
			sky_mat.ground_horizon_color = Color(0.04, 0.22, 0.45)
			sky_mat.sun_angle_max = 12.0
			sky_mat.sun_curve = 0.25
			if active_sun:
				active_sun.light_color = Color(1.0, 1.0, 1.0)
				active_sun.light_energy = 1.6
				active_sun.rotation_degrees = Vector3(-45, 0, 0)
			env.volumetric_fog_enabled = false
	
	var sky = Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	
	_apply_ground_preset(preset_name)

func _apply_ground_preset(preset_name: String) -> void:
	if not is_instance_valid(active_root):
		return
	var ground = active_root.find_child("Ground", true, false)
	if not ground or not ground is MeshInstance3D:
		return
	
	var mat: Material = ground.material_override
	if not mat and ground.mesh:
		mat = ground.mesh.material
	
	if not mat is ShaderMaterial:
		return
	
	var sm = mat as ShaderMaterial
	match preset_name:
		"overcast_storm": # M01: Wet coastal asphalt & dark stormy rock
			sm.set_shader_parameter("ground_color_primary", Color(0.18, 0.22, 0.26))
			sm.set_shader_parameter("ground_color_secondary", Color(0.10, 0.12, 0.15))
			sm.set_shader_parameter("ground_color_mineral", Color(0.28, 0.30, 0.34))
			sm.set_shader_parameter("grid_color", Color(0.0, 0.85, 1.0, 0.22))
			sm.set_shader_parameter("enable_corridor", true)
			sm.set_shader_parameter("corridor_width", 80.0)
			
		"dusk_canyon": # M02: Red sandstone, rich terracotta & desert mineral dust
			sm.set_shader_parameter("ground_color_primary", Color(0.55, 0.24, 0.14))
			sm.set_shader_parameter("ground_color_secondary", Color(0.30, 0.11, 0.08))
			sm.set_shader_parameter("ground_color_mineral", Color(0.74, 0.44, 0.20))
			sm.set_shader_parameter("grid_color", Color(1.0, 0.65, 0.1, 0.26))
			sm.set_shader_parameter("enable_corridor", true)
			sm.set_shader_parameter("corridor_width", 100.0)
			
		"dawn_clear": # M03: Aerospace launch corridor, clean concrete tarmac & high-contrast runway
			sm.set_shader_parameter("ground_color_primary", Color(0.22, 0.26, 0.30))
			sm.set_shader_parameter("ground_color_secondary", Color(0.13, 0.16, 0.19))
			sm.set_shader_parameter("ground_color_mineral", Color(0.36, 0.38, 0.42))
			sm.set_shader_parameter("grid_color", Color(0.0, 0.95, 1.0, 0.32))
			sm.set_shader_parameter("enable_corridor", true)
			sm.set_shader_parameter("corridor_width", 90.0)
			
		"stratosphere_space": # M04: Orbital oceanic planetary depths seen from 45,000m
			sm.set_shader_parameter("ground_color_primary", Color(0.04, 0.12, 0.28))
			sm.set_shader_parameter("ground_color_secondary", Color(0.02, 0.05, 0.14))
			sm.set_shader_parameter("ground_color_mineral", Color(0.10, 0.28, 0.45))
			sm.set_shader_parameter("grid_color", Color(0.0, 0.75, 1.0, 0.12))
			sm.set_shader_parameter("enable_corridor", false)

# -----------------------------------------------------------------------------
# 4. Spawners for Mission 01–04
# -----------------------------------------------------------------------------
func _spawn_m01_recon_drones() -> void:
	var drone_script = load("res://target_drone.gd")
	if not drone_script:
		return
	
	# Spawn 4 recon drones in distinct patrol sectors
	var drone_configs = [
		{ "pos": Vector3(0, 75, -360),    "radius": 240.0, "speed": 0.35, "alt": 75.0 },
		{ "pos": Vector3(320, 95, -420),  "radius": 280.0, "speed": -0.30, "alt": 95.0 },
		{ "pos": Vector3(-300, 85, -300), "radius": 220.0, "speed": 0.40, "alt": 85.0 },
		{ "pos": Vector3(150, 110, -550), "radius": 310.0, "speed": -0.38, "alt": 110.0 }
	]
	
	for i in range(drone_configs.size()):
		var cfg = drone_configs[i]
		var d = Node3D.new()
		d.name = "ReconDrone_0" + str(i + 1)
		d.set_script(drone_script)
		d.center_point = cfg["pos"]
		d.orbit_radius = cfg["radius"]
		d.orbit_speed = cfg["speed"]
		d.altitude = cfg["alt"]
		d.max_health = 100.0
		d.health = 100.0
		d.respawn_enabled = false # Single kill per mission objective!
		d.destroyed.connect(_on_mission_target_destroyed.bind(d, "obj_destroy_all"))
		active_root.add_child(d)
		d.position = cfg["pos"]

func _spawn_m02_relays_and_patrols() -> void:
	var relay_scene = load("res://jamming_relay.tscn")
	var drone_script = load("res://target_drone.gd")
	
	# 3 Jamming Relays along canyon floor with distinct callsigns
	var relay_configs = [
		{ "name": "JammingRelay_01", "callsign": "JAMMER ALPHA", "pos": Vector3(-80, 0, -280) },
		{ "name": "JammingRelay_02", "callsign": "JAMMER BRAVO", "pos": Vector3(120, 0, -480) },
		{ "name": "JammingRelay_03", "callsign": "JAMMER CHARLIE", "pos": Vector3(-40, 0, -720) }
	]
	
	for i in range(relay_configs.size()):
		var cfg = relay_configs[i]
		var relay: Node3D = null
		if relay_scene:
			relay = relay_scene.instantiate()
		else:
			relay = Node3D.new()
		relay.name = cfg["name"]
		if "callsign_name" in relay:
			relay.callsign_name = cfg["callsign"]
		relay.position = cfg["pos"]
		if relay.has_signal("destroyed"):
			relay.destroyed.connect(_on_mission_target_destroyed.bind(relay, "obj_relays"))
		active_root.add_child(relay)
	
	# 4 Canyon Escort Patrol Drones
	for i in range(4):
		var d = Node3D.new()
		d.name = "CanyonPatrol_0" + str(i + 1)
		d.set_script(drone_script)
		d.center_point = Vector3((i - 1.5) * 140.0, 60.0, -400.0)
		d.orbit_radius = 160.0
		d.altitude = 60.0
		d.respawn_enabled = false
		d.destroyed.connect(_on_mission_target_destroyed.bind(d, "obj_escorts"))
		active_root.add_child(d)
	
	# Spawn 180m Sandstone Canyon Walls & Choke-point Mesa Buttes
	_spawn_m02_canyon_walls()

func _spawn_m02_canyon_walls() -> void:
	var cliff_mesh = load("res://assets/meshes/environment/canyon_cliff_straight.glb")
	var mesa_mesh = load("res://assets/meshes/environment/canyon_mesa_pillar.glb")
	if not cliff_mesh or not mesa_mesh:
		return
		
	var canyon_root = Node3D.new()
	canyon_root.name = "CanyonTerrainRoot"
	active_root.add_child(canyon_root)
	
	# Left canyon wall chain (X = -220m, facing right into canyon corridor)
	for i in range(6):
		var z_pos = 150.0 - i * 245.0
		var c_left = cliff_mesh.instantiate()
		c_left.name = "CanyonCliff_L_" + str(i)
		c_left.position = Vector3(-220.0, 0.0, z_pos)
		c_left.rotation_degrees = Vector3(0, 90, 0)
		canyon_root.add_child(c_left)
		
	# Right canyon wall chain (X = +220m, facing left into canyon corridor)
	for i in range(6):
		var z_pos = 150.0 - i * 245.0
		var c_right = cliff_mesh.instantiate()
		c_right.name = "CanyonCliff_R_" + str(i)
		c_right.position = Vector3(220.0, 0.0, z_pos)
		c_right.rotation_degrees = Vector3(0, -90, 0)
		canyon_root.add_child(c_right)
		
	# Towering Mesa Pillars at corridor bends and choke points
	var mesa_positions = [
		Vector3(-140.0, 0.0, -350.0),
		Vector3(150.0, 0.0, -580.0),
		Vector3(-130.0, 0.0, -820.0),
		Vector3(140.0, 0.0, -1050.0)
	]
	for idx in range(mesa_positions.size()):
		var mesa = mesa_mesh.instantiate()
		mesa.name = "CanyonMesa_" + str(idx + 1)
		mesa.position = mesa_positions[idx]
		canyon_root.add_child(mesa)

func _spawn_m03_transport_and_allies() -> void:
	var viper_mesh = load("res://assets/meshes/vehicles/Spaceship_Viper_Supreme_HD.fbx")
	var transport_scene = load("res://transport_olympus4.tscn")
	var drone_script = load("res://target_drone.gd")
	
	# Allied Heavy Transport Olympus-4
	if transport_scene:
		var transport = transport_scene.instantiate()
		transport.name = "TransportOlympus4"
		transport.position = Vector3(0, 30, -100)
		active_root.add_child(transport)
	
	# Allied Wingman Viper 2
	if viper_mesh:
		var wingman = Node3D.new()
		wingman.name = "Wingman_Viper2"
		var v_inst = viper_mesh.instantiate()
		wingman.add_child(v_inst)
		wingman.position = Vector3(45, 42, -20)
		active_root.add_child(wingman)
	
	# Spawn 4 saturation wave drones targeting corridor
	var drone_configs = [
		{ "pos": Vector3(-200, 80, -250), "radius": 150.0, "speed": 0.4 },
		{ "pos": Vector3(200, 70, -320),  "radius": 180.0, "speed": -0.35 },
		{ "pos": Vector3(-120, 110, -450), "radius": 200.0, "speed": 0.45 },
		{ "pos": Vector3(140, 90, -520),  "radius": 160.0, "speed": -0.4 }
	]
	for i in range(drone_configs.size()):
		var cfg = drone_configs[i]
		var d = Node3D.new()
		d.name = "StrikeDrone_0" + str(i + 1)
		d.set_script(drone_script)
		d.center_point = cfg["pos"]
		d.orbit_radius = cfg["radius"]
		d.orbit_speed = cfg["speed"]
		d.altitude = cfg["pos"].y
		d.respawn_enabled = false
		d.destroyed.connect(_on_mission_target_destroyed.bind(d, "obj_destroy_all"))
		active_root.add_child(d)

func _spawn_m04_boss_and_escorts() -> void:
	var boss_scene = load("res://boss_combine_ghost.tscn")
	var drone_script = load("res://target_drone.gd")
	
	# Helion Ace Boss "Combine Ghost" (F-82 Viper Stealth Crimson)
	if boss_scene:
		var boss = boss_scene.instantiate()
		boss.name = "Boss_CombineGhost"
		boss.position = Vector3(0, 180, -600)
		boss.destroyed.connect(_on_mission_target_destroyed.bind(boss, "obj_boss"))
		active_root.add_child(boss)
	
	# 4 Elite Escort Drones
	for i in range(4):
		var d = Node3D.new()
		d.name = "EliteGuard_0" + str(i + 1)
		d.set_script(drone_script)
		d.center_point = Vector3((i - 1.5) * 80.0, 160.0, -550.0)
		d.orbit_radius = 90.0
		d.altitude = 160.0
		d.respawn_enabled = false
		d.destroyed.connect(_on_mission_target_destroyed.bind(d, "obj_escorts"))
		active_root.add_child(d)

# -----------------------------------------------------------------------------
# 5. Continuous Objective Evaluation & Altitude Monitoring
# -----------------------------------------------------------------------------
func _evaluate_continuous_objectives(delta: float) -> void:
	if not active_ship:
		return
	
	# M01: Airspeed above stall threshold
	if current_mission_id == "M01":
		var spd = active_ship.current_speed if "current_speed" in active_ship else 0.0
		var stall = active_ship.stall_speed if "stall_speed" in active_ship else 25.0
		if spd > stall:
			_set_objective_status("obj_fly", "COMPLETED", 1, 1)
		else:
			_set_objective_status("obj_fly", "IN_PROGRESS", 0, 1)
	
	# M02: Altitude below 120m (Canyon radar masking)
	if current_mission_id == "M02":
		var alt = active_ship.global_position.y
		if alt > 120.0:
			altitude_warning_timer += delta
			if altitude_warning_timer > 1.5 and altitude_warning_timer - delta <= 1.5:
				queue_transmission("AEGIS_7", "CAUTION: Altitude exceeding 120m. Enemy radar paint detected. Dive immediately!", 3.0, "res://audio/comms/m02_aegis_altitude_warning.mp3")
			if alt > 180.0 and altitude_warning_timer > 5.0:
				fail_mission("SAM_BARRAGE", "Altitude ceiling breached! Surface-to-air missile barrage intercepted airframe.")
		else:
			altitude_warning_timer = max(0.0, altitude_warning_timer - delta * 2.0)
			_set_objective_status("obj_canyon", "COMPLETED", 1, 1)
	
	# M04: Near-vacuum altitude monitoring & thin air advisory
	if current_mission_id == "M04":
		var alt = active_ship.global_position.y
		if alt > 150.0 and altitude_warning_timer == 0.0:
			altitude_warning_timer = 1.0
			queue_transmission("AEGIS_7", "Atmospheric density below 5%. Aero-surfaces stalling. Switch to reaction thrusters.", 4.0, "res://audio/comms/m04_aegis_thin_air.mp3")

func _set_objective_status(obj_id: String, status: String, cur: Variant = 0, target: Variant = 1) -> void:
	for obj in active_objectives:
		if obj["id"] == obj_id:
			if obj["status"] != status or obj["current_val"] != cur:
				obj["status"] = status
				obj["current_val"] = cur
				obj["target_val"] = target
				objective_updated.emit(obj_id, status, obj["text"], cur, target)
			break

func _on_mission_target_destroyed(a = null, b = null, c = null) -> void:
	var obj_id = ""
	var target_node: Node = null
	if typeof(a) == TYPE_STRING:
		obj_id = a
	elif typeof(b) == TYPE_STRING:
		obj_id = b
		target_node = a as Node
	elif typeof(c) == TYPE_STRING:
		obj_id = c
		target_node = b as Node
	
	targets_destroyed += 1
	for obj in active_objectives:
		if obj["id"] == obj_id:
			obj["current_val"] = min(obj["target_val"], obj["current_val"] + 1)
			if obj["current_val"] >= obj["target_val"]:
				obj["status"] = "COMPLETED"
				# Special mission audio triggers upon objective completion
				if current_mission_id == "M02" and obj_id == "obj_relays":
					queue_transmission("APEX_CMD", "Jamming network collapsed! Radar uplink re-established. Sweep remaining patrols.", 4.5, "res://audio/comms/m02_apex_relays_down.mp3")
				elif current_mission_id == "M03" and obj_id == "obj_destroy_all":
					queue_transmission("APEX_CMD", "Air corridor sanitized. Olympus-4, fire your booster stage!", 4.0, "res://audio/comms/m03_apex_wave_cleared.mp3")
			objective_updated.emit(obj_id, obj["status"], obj["text"], obj["current_val"], obj["target_val"])
			break
	
	# Check if all mandatory objectives are completed
	_check_mission_completion()

func record_shot_fired(is_missile: bool = true) -> void:
	if is_missile:
		missiles_fired += 1

func record_hit(is_missile: bool = true) -> void:
	if is_missile:
		missiles_hit += 1
		# Update accuracy objective if exists
		var acc = float(missiles_hit) / float(max(1, missiles_fired))
		if acc >= 1.0:
			_set_objective_status("obj_accuracy", "COMPLETED", 1, 1)
		else:
			_set_objective_status("obj_accuracy", "FAILED", 0, 1)

func _check_mission_completion() -> void:
	if not is_sortie_active:
		return
	
	var all_mandatory_done = true
	for obj in active_objectives:
		if obj["mandatory"] and obj["status"] != "COMPLETED":
			all_mandatory_done = false
			break
	
	if all_mandatory_done:
		complete_mission()

func complete_mission() -> void:
	if not is_sortie_active:
		return
	
	is_sortie_active = false
	var hit_rate = float(missiles_hit) / float(max(1, missiles_fired)) if missiles_fired > 0 else 1.0
	var final_hull = 100.0
	var cannon_spent = 0
	if active_ship:
		var telem = active_ship.get_node_or_null("CombatTelemetry")
		if telem:
			final_hull = telem.current_hull
			cannon_spent = max(0, 600 - telem.cannon_rounds)
	
	var stats = {
		"mission_id": current_mission_id,
		"elapsed_time": sortie_elapsed_time,
		"missiles_fired": missiles_fired,
		"missiles_hit": missiles_hit,
		"hit_rate": hit_rate,
		"targets_destroyed": targets_destroyed,
		"hull_remaining": final_hull,
		"cannon_expended": cannon_spent
	}
	
	# Unlock next mission
	var cur_idx = mission_ids.find(current_mission_id)
	if cur_idx != -1 and cur_idx + 1 < mission_ids.size():
		var next_id = mission_ids[cur_idx + 1]
		unlock_mission(next_id)
	
	completed_missions[current_mission_id] = stats
	print("[MissionManager] Sortie SUCCESS: ", current_mission_id, " in ", round(sortie_elapsed_time), "s (Accuracy: ", int(hit_rate * 100), "%)")
	
	# Play debrief comms
	_trigger_victory_comms(current_mission_id)
	
	# Auto-save campaign state
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("save_game"):
		sm.save_game()
	
	mission_completed.emit(current_mission_id, stats)

func fail_mission(reason_code: String, reason_text: String) -> void:
	if not is_sortie_active:
		return
	
	is_sortie_active = false
	print("[MissionManager] Sortie FAILED: ", reason_code, " - ", reason_text)
	queue_transmission("APEX_CMD", "Vanguard 1, telemetry lost! Scramble search-and-rescue immediately!", 4.0)
	mission_failed.emit(current_mission_id, reason_text)

# -----------------------------------------------------------------------------
# 6. Diegetic Radio Comms Pipeline
# -----------------------------------------------------------------------------
func queue_transmission(speaker_key: String, message_text: String, duration: float = 4.0, audio_path: String = "") -> void:
	var profile = SPEAKERS.get(speaker_key, { "name": "Radio", "callsign": "COMMS", "color": Color.WHITE })
	var item = {
		"speaker_name": profile["name"],
		"callsign": profile["callsign"],
		"text": message_text,
		"color": profile["color"],
		"duration": duration,
		"audio_path": audio_path
	}
	comms_queue.append(item)

func _process_comms_queue(delta: float) -> void:
	if transmission_timer > 0.0:
		transmission_timer -= delta
		if transmission_timer <= 0.0:
			current_transmission.clear()
			radio_transmission_ended.emit()
			comms_cooldown = 0.4
			return
	
	if comms_cooldown > 0.0:
		comms_cooldown -= delta
		if comms_cooldown > 0.0:
			return
	
	if transmission_timer <= 0.0 and comms_queue.size() > 0:
		current_transmission = comms_queue.pop_front()
		transmission_timer = current_transmission["duration"]
		
		# Play vocal audio track if attached
		var a_path = current_transmission.get("audio_path", "")
		if a_path != "" and comms_audio_player:
			var stream = load(a_path)
			if stream:
				comms_audio_player.stream = stream
				comms_audio_player.play()
		
		radio_transmission_started.emit(
			current_transmission["speaker_name"],
			current_transmission["callsign"],
			current_transmission["text"],
			current_transmission["color"],
			current_transmission["duration"]
		)

func _trigger_intro_comms(mission_id: String) -> void:
	match mission_id:
		"M01":
			queue_transmission("APEX_CMD", "Vanguard 1, Apex Command on secure freq. Catapult pressure nominal. You are cleared for hot scramble.", 4.5, "res://audio/comms/m01_apex_scramble.mp3")
			queue_transmission("AEGIS_7", "Catapult release confirmed. Main thrusters engaged. Flight telemetry online.", 3.5, "res://audio/comms/m01_aegis_launch.mp3")
			queue_transmission("APEX_CMD", "Hostiles confirmed autonomous Marauder drones. Weapons free, Vanguard 1. Sanitize the corridor.", 4.5, "res://audio/comms/m01_apex_weapons_free.mp3")
		"M02":
			queue_transmission("APEX_CMD", "Vanguard 1, you're dropping into the Red Sinks. Keep your belly to the rock under 120 meters.", 4.5, "res://audio/comms/m02_apex_briefing.mp3")
			queue_transmission("AEGIS_7", "Terrain proximity active. Scanning canyon floor for jamming repeaters.", 3.5, "res://audio/comms/m02_aegis_terrain.mp3")
		"M03":
			queue_transmission("VIPER_2", "Miller on your wing, Vanguard 1. Look at that bird... Olympus-4 is charging capacitors. Let's make sure she makes orbit.", 4.5, "res://audio/comms/m03_viper_wingman.mp3")
			queue_transmission("APEX_CMD", "Threat grid lit up! Wave one incoming bearing one-eight-zero, angels four. Intercept!", 4.0, "res://audio/comms/m03_apex_swarm_warning.mp3")
		"M04":
			queue_transmission("APEX_CMD", "Vanguard 1, crossing forty thousand meters. Skies are turning black. You are on vectoring thrusters.", 4.5, "res://audio/comms/m04_apex_vacuum_entry.mp3")
			queue_transmission("GHOST", "So the Directorate sent their prized pilot to freeze in the vacuum. Let's see how your V-hull handles true zero-G!", 5.0, "res://audio/comms/m04_ghost_challenge.mp3")

func _trigger_victory_comms(mission_id: String) -> void:
	match mission_id:
		"M01":
			queue_transmission("AEGIS_7", "All four target signatures purged from polar radar disc.", 3.5)
			queue_transmission("APEX_CMD", "Good splashes, Vanguard 1! The corridor is clear. Form up and RTB for debrief.", 4.5, "res://audio/comms/m01_apex_mission_complete.mp3")
		"M02":
			queue_transmission("APEX_CMD", "All jamming relays eliminated. Early-warning radar grid restored across the Red Sinks. Great flying, Ace.", 4.5, "res://audio/comms/m02_apex_victory.mp3")
		"M03":
			queue_transmission("OLYMPUS_4", "Main rocket ignition confirmed! Passing Mach 5 and climbing through fifty thousand feet. Thanks for the escort, Vanguard!", 5.0, "res://audio/comms/m03_olympus_liftoff.mp3")
		"M04":
			queue_transmission("AEGIS_7", "Catastrophic core rupture on target. Threat destroyed.", 3.5, "res://audio/comms/m04_aegis_target_rupture.mp3")
			queue_transmission("APEX_CMD", "Combine Ghost is down! The entire drone network is offline. Outstanding work, Vanguard 1... You saved Ascension!", 5.5, "res://audio/comms/m04_apex_ace_victory.mp3")

# -----------------------------------------------------------------------------
# 7. Persistence Integration
# -----------------------------------------------------------------------------
func get_save_data() -> Dictionary:
	return {
		"unlocked_missions": unlocked_missions,
		"completed_missions": completed_missions,
		"current_mission_id": current_mission_id
	}

func restore_save_data(data: Dictionary) -> void:
	if data.has("unlocked_missions"):
		unlocked_missions.clear()
		for id in data["unlocked_missions"]:
			unlocked_missions.append(str(id))
	if data.has("completed_missions") and typeof(data["completed_missions"]) == TYPE_DICTIONARY:
		completed_missions = data["completed_missions"]
	if data.has("current_mission_id"):
		current_mission_id = str(data["current_mission_id"])
	campaign_updated.emit()
	print("[MissionManager] Restored campaign progression: ", unlocked_missions.size(), " missions unlocked.")
