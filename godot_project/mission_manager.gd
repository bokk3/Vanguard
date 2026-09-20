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
	"GHOST":    { "name": "Helion Commander",      "callsign": "GHOST",    "color": Color(1.0, 0.22, 0.3) },
	"ROSS":     { "name": "Captain Ross (Carrier)", "callsign": "DAUNTLESS","color": Color(0.35, 0.75, 1.0) },
	"VANE":     { "name": "Warlord Vane (Boss)",    "callsign": "NEMESIS-9","color": Color(1.0, 0.15, 0.25) }
}

# Campaign Definitions
var manifest_data: Dictionary = {}
var missions_dict: Dictionary = {}
var mission_ids: Array[String] = []

# Persistent Campaign Progression (Chapter 1: The Ascension War)
var unlocked_missions: Array[String] = ["M01"]
var completed_missions: Dictionary = {} # mission_id -> { "best_time": float, "hit_rate": float, "stars": int }
var current_mission_id: String = "M01"
var pending_interlude_id: String = ""

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

# M03 Saturation Wave State
var m03_current_wave: int = 1
var m03_wave_drones_alive: int = 0
var m03_transport_node: Node3D = null
var m03_is_cleared: bool = false

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
		if item["id"] in ["obj_destroy_all", "obj_escorts", "obj_mines", "obj_skirmishers", "obj_flak_pods"]:
			item["target_val"] = 4
			targets_total += 4
		elif item["id"] in ["obj_relays", "obj_generators"]:
			item["target_val"] = 3
			targets_total += 3
		elif item["id"] == "obj_shield_domes":
			item["target_val"] = 2
			targets_total += 2
		elif item["id"] == "obj_laser_sentries":
			item["target_val"] = 6
			targets_total += 6
		elif item["id"] == "obj_intercept_torps":
			item["target_val"] = 8
			targets_total += 8
		elif item["id"] in ["obj_boss", "obj_protect", "obj_defend_carrier", "obj_destroy_dreadnought"]:
			item["target_val"] = 1
			targets_total += 1
		elif item["id"] == "obj_waves":
			item["target_val"] = 12
			targets_total += 12
		
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
		"M05":
			_spawn_m05_mines_and_skirmishers()
		"M06":
			_spawn_m06_cavern_trench()
		"M07":
			_spawn_m07_carrier_and_torpedoes()
		"M08":
			_spawn_m08_dreadnought_boss()

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
			
		"deep_space_belt": # M05: Dark starfield, amber solar backlighting, rocky dust ring
			sky_mat.sky_top_color = Color(0.01, 0.01, 0.02)
			sky_mat.sky_horizon_color = Color(0.12, 0.08, 0.04)
			sky_mat.ground_bottom_color = Color(0.005, 0.005, 0.01)
			sky_mat.ground_horizon_color = Color(0.08, 0.05, 0.03)
			sky_mat.sun_angle_max = 8.0
			if active_sun:
				active_sun.light_color = Color(1.0, 0.95, 0.85)
				active_sun.light_energy = 1.8
				active_sun.rotation_degrees = Vector3(-35, 120, 0)
			env.volumetric_fog_enabled = false
			
		"asteroid_cavern": # M06: Enclosed subterranean cavern with magma glow & steel bulkheads
			sky_mat.sky_top_color = Color(0.05, 0.03, 0.02)
			sky_mat.sky_horizon_color = Color(0.65, 0.22, 0.08)
			sky_mat.ground_bottom_color = Color(0.08, 0.02, 0.01)
			sky_mat.ground_horizon_color = Color(0.50, 0.15, 0.05)
			if active_sun:
				active_sun.light_color = Color(1.0, 0.45, 0.15)
				active_sun.light_energy = 0.9
				active_sun.rotation_degrees = Vector3(-80, 0, 0)
			env.volumetric_fog_enabled = true
			env.volumetric_fog_density = 0.006
			env.volumetric_fog_albedo = Color(0.7, 0.25, 0.08)
			
		"carrier_orbit": # M07: Fleet defense orbit, deep navy space with carrier illumination
			sky_mat.sky_top_color = Color(0.01, 0.02, 0.05)
			sky_mat.sky_horizon_color = Color(0.08, 0.25, 0.45)
			sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.03)
			sky_mat.ground_horizon_color = Color(0.05, 0.15, 0.30)
			if active_sun:
				active_sun.light_color = Color(0.9, 0.95, 1.0)
				active_sun.light_energy = 1.5
				active_sun.rotation_degrees = Vector3(-45, -30, 0)
			env.volumetric_fog_enabled = false
			
		"crucible_forge": # M08: Ominous crimson shipyard industrial zone
			sky_mat.sky_top_color = Color(0.02, 0.01, 0.02)
			sky_mat.sky_horizon_color = Color(0.70, 0.10, 0.15)
			sky_mat.ground_bottom_color = Color(0.03, 0.01, 0.01)
			sky_mat.ground_horizon_color = Color(0.40, 0.05, 0.08)
			if active_sun:
				active_sun.light_color = Color(1.0, 0.3, 0.35)
				active_sun.light_energy = 1.6
				active_sun.rotation_degrees = Vector3(-55, 45, 0)
			env.volumetric_fog_enabled = true
			env.volumetric_fog_density = 0.003
			env.volumetric_fog_albedo = Color(0.8, 0.1, 0.15)
	
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
		d.drone_type = "recon"
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
	
	# 4 Canyon Escort Patrol Drones (Stalker-4 Recon)
	for i in range(4):
		var d = Node3D.new()
		d.name = "CanyonPatrol_0" + str(i + 1)
		d.set_script(drone_script)
		d.drone_type = "recon"
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
		_add_static_box_collision(c_left, Vector3(80, 180, 250), Vector3(0, 90, 0))
		canyon_root.add_child(c_left)
		
	# Right canyon wall chain (X = +220m, facing left into canyon corridor)
	for i in range(6):
		var z_pos = 150.0 - i * 245.0
		var c_right = cliff_mesh.instantiate()
		c_right.name = "CanyonCliff_R_" + str(i)
		c_right.position = Vector3(220.0, 0.0, z_pos)
		c_right.rotation_degrees = Vector3(0, -90, 0)
		_add_static_box_collision(c_right, Vector3(80, 180, 250), Vector3(0, 90, 0))
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
		_add_static_box_collision(mesa, Vector3(65, 160, 65), Vector3(0, 80, 0))
		canyon_root.add_child(mesa)

func _spawn_m03_transport_and_allies() -> void:
	var viper_mesh = load("res://assets/meshes/vehicles/Spaceship_Viper_Supreme_HD.fbx")
	var transport_scene = load("res://transport_olympus4.tscn")
	
	m03_current_wave = 1
	m03_wave_drones_alive = 0
	m03_is_cleared = false
	
	# Allied Heavy Transport Olympus-4
	if transport_scene:
		var transport = transport_scene.instantiate()
		transport.name = "TransportOlympus4"
		transport.position = Vector3(0, 30, -100)
		m03_transport_node = transport
		active_root.add_child(transport)
		transport.destroyed.connect(func():
			fail_mission("TRANSPORT_LOST", "Catastrophic hull failure on Olympus-4. The orbital payload was destroyed.")
		)
	
	# Allied Wingman Viper 2
	if viper_mesh:
		var wingman = Node3D.new()
		wingman.name = "Wingman_Viper2"
		var v_inst = viper_mesh.instantiate()
		wingman.add_child(v_inst)
		wingman.position = Vector3(45, 42, -20)
		active_root.add_child(wingman)
	
	# Spawn Wave 1
	_spawn_m03_wave(1)

func _spawn_m03_wave(wave_num: int) -> void:
	if not active_root:
		return
	
	var drone_script = load("res://target_drone.gd")
	var drone_configs: Array = []
	
	match wave_num:
		1:
			# Wave 1: 2x Dive Bombers + 2x Skirmishers
			drone_configs = [
				{ "pos": Vector3(-180, 80, -250), "radius": 140.0, "speed": 0.4, "type": "bomber" },
				{ "pos": Vector3(180, 75, -320),  "radius": 150.0, "speed": -0.35, "type": "bomber" },
				{ "pos": Vector3(-120, 110, -420), "radius": 180.0, "speed": 0.45, "type": "skirmisher" },
				{ "pos": Vector3(130, 95, -480),  "radius": 160.0, "speed": -0.4, "type": "skirmisher" }
			]
		2:
			# Wave 2: 2x Dive Bombers + 2x Skirmishers flanking from X = ±240
			drone_configs = [
				{ "pos": Vector3(-240, 95, -580), "radius": 160.0, "speed": 0.4, "type": "bomber" },
				{ "pos": Vector3(240, 90, -650),  "radius": 170.0, "speed": -0.4, "type": "bomber" },
				{ "pos": Vector3(-160, 125, -720), "radius": 190.0, "speed": 0.5, "type": "skirmisher" },
				{ "pos": Vector3(170, 115, -780),  "radius": 175.0, "speed": -0.45, "type": "skirmisher" }
			]
		3:
			# Wave 3: Final heavy assault wave closing on catapult pad
			drone_configs = [
				{ "pos": Vector3(-100, 110, -880), "radius": 140.0, "speed": 0.45, "type": "bomber" },
				{ "pos": Vector3(110, 105, -920),  "radius": 150.0, "speed": -0.45, "type": "bomber" },
				{ "pos": Vector3(-200, 135, -980), "radius": 180.0, "speed": 0.55, "type": "skirmisher" },
				{ "pos": Vector3(200, 130, -1020), "radius": 180.0, "speed": -0.5, "type": "skirmisher" }
			]
	
	m03_wave_drones_alive = drone_configs.size()
	
	for i in range(drone_configs.size()):
		var cfg = drone_configs[i]
		var d = Node3D.new()
		d.name = "StrikeDrone_W" + str(wave_num) + "_" + str(i + 1)
		d.set_script(drone_script)
		d.drone_type = cfg.get("type", "skirmisher")
		d.center_point = cfg["pos"]
		d.orbit_radius = cfg["radius"]
		d.orbit_speed = cfg["speed"]
		d.altitude = cfg["pos"].y
		d.respawn_enabled = false
		d.destroyed.connect(_on_m03_drone_destroyed.bind(d))
		active_root.add_child(d)

func _on_m03_drone_destroyed(drone: Node) -> void:
	_on_mission_target_destroyed(drone, "obj_waves")
	m03_wave_drones_alive -= 1
	
	if m03_wave_drones_alive <= 0:
		if m03_current_wave == 1:
			m03_current_wave = 2
			queue_transmission("APEX_CMD", "Wave 1 neutralized! Second hostile formation incoming from bearing 090!", 4.0)
			_spawn_m03_wave(2)
		elif m03_current_wave == 2:
			m03_current_wave = 3
			queue_transmission("VIPER_2", "Good hits Vanguard! Final strike wave closing on Olympus... Hold the perimeter!", 4.0)
			_spawn_m03_wave(3)
		elif m03_current_wave == 3:
			m03_is_cleared = true
			_set_objective_status("obj_waves", "COMPLETED", 12, 12)
			queue_transmission("APEX_CMD", "Air corridor sanitized. Olympus-4, fire your booster stage!", 4.0, "res://audio/comms/m03_apex_wave_cleared.mp3")
			
			if is_instance_valid(m03_transport_node) and m03_transport_node.has_method("engage_booster_liftoff"):
				m03_transport_node.engage_booster_liftoff()
			
			_trigger_victory_comms("M03")
			
			if is_inside_tree():
				var t = create_tween()
				t.tween_interval(5.5)
				t.tween_callback(func():
					_set_objective_status("obj_protect", "COMPLETED", 1, 1)
					complete_mission()
				)
			else:
				_set_objective_status("obj_protect", "COMPLETED", 1, 1)
				complete_mission()

func _spawn_m04_boss_and_escorts() -> void:
	var boss_scene = load("res://boss_combine_ghost.tscn")
	var drone_script = load("res://target_drone.gd")
	
	# Helion Ace Boss "Combine Ghost" (F-82 Viper Stealth Crimson)
	if boss_scene:
		var boss = boss_scene.instantiate()
		boss.name = "Boss_CombineGhost"
		boss.position = Vector3(0, 85, -360)
		boss.rotation = Vector3(0, PI, 0)
		boss.destroyed.connect(_on_mission_target_destroyed.bind(boss, "obj_boss"))
		active_root.add_child(boss)
	
	# 4 Elite Escort Drones (Razor Skirmishers) in tactical escort formation
	for i in range(4):
		var d = Node3D.new()
		d.name = "EliteGuard_0" + str(i + 1)
		d.set_script(drone_script)
		d.drone_type = "skirmisher"
		d.center_point = Vector3((i - 1.5) * 60.0, 95.0, -320.0)
		d.orbit_radius = 50.0
		d.altitude = 95.0
		d.respawn_enabled = false
		d.destroyed.connect(_on_mission_target_destroyed.bind(d, "obj_escorts"))
		active_root.add_child(d)

func _spawn_m05_mines_and_skirmishers() -> void:
	var drone_script = load("res://target_drone.gd")
	var mine_mesh = load("res://assets/meshes/environment/asteroid_tether_mine.glb")
	var ast_med = load("res://assets/meshes/environment/asteroid_boulder_medium.glb")
	var ast_lrg = load("res://assets/meshes/environment/asteroid_cluster_large.glb")
	
	var belt_root = Node3D.new()
	belt_root.name = "AsteroidBeltRoot"
	active_root.add_child(belt_root)
	
	# 1. Spawn asteroid field
	var ast_locs = [
		Vector3(-140, 20, -320), Vector3(160, -15, -400),
		Vector3(-80, 55, -500), Vector3(120, 40, -580),
		Vector3(0, -30, -360), Vector3(-200, -10, -450),
		Vector3(220, 25, -520), Vector3(-50, 70, -650)
	]
	for i in range(ast_locs.size()):
		var m = (ast_lrg if i % 3 == 0 else ast_med)
		if m:
			var inst = m.instantiate()
			inst.name = "Asteroid_" + str(i + 1)
			inst.position = ast_locs[i]
			inst.rotation = Vector3(i * 0.4, i * 0.7, i * 0.2)
			_add_static_box_collision(inst, Vector3(55, 55, 55) if i % 3 == 0 else Vector3(28, 28, 28))
			belt_root.add_child(inst)
			
	# 2. Spawn 4 Tether-Mines
	var mine_locs = [
		Vector3(-90, 30, -300), Vector3(80, 10, -380),
		Vector3(-30, 45, -480), Vector3(110, 20, -600)
	]
	for i in range(mine_locs.size()):
		var m = Node3D.new()
		m.name = "TetherMine_0" + str(i + 1)
		m.set_script(drone_script)
		m.drone_type = "mine"
		m.center_point = mine_locs[i]
		m.orbit_radius = 0.0
		m.orbit_speed = 0.0
		m.altitude = mine_locs[i].y
		m.max_health = 60.0
		m.health = 60.0
		m.respawn_enabled = false
		m.destroyed.connect(_on_mission_target_destroyed.bind(m, "obj_mines"))
		active_root.add_child(m)
		m.position = mine_locs[i]
		
		if mine_mesh:
			var vis = mine_mesh.instantiate()
			m.add_child(vis)
			
	# 3. Spawn 4 Cloaked Stealth Skirmishers
	for i in range(4):
		var d = Node3D.new()
		d.name = "StealthSkirmisher_0" + str(i + 1)
		d.set_script(drone_script)
		d.drone_type = "skirmisher"
		d.center_point = Vector3((i - 1.5) * 120.0, 40.0, -420.0)
		d.orbit_radius = 140.0
		d.orbit_speed = 0.45 * (-1 if i % 2 == 1 else 1)
		d.altitude = 40.0
		d.respawn_enabled = false
		d.destroyed.connect(_on_mission_target_destroyed.bind(d, "obj_skirmishers"))
		active_root.add_child(d)

func _spawn_m06_cavern_trench() -> void:
	var ring_mesh = load("res://assets/meshes/environment/cavern_tunnel_straight.glb")
	var gen_mesh = load("res://assets/meshes/environment/cavern_generator_core.glb")
	var sentry_mesh = load("res://assets/meshes/environment/laser_sentry_turret.glb")
	var drone_script = load("res://target_drone.gd")
	
	var cavern_root = Node3D.new()
	cavern_root.name = "CavernTrenchRoot"
	active_root.add_child(cavern_root)
	
	# 1. Spawn 6 Tunnel Segments along Z axis
	if ring_mesh:
		for i in range(7):
			var r = ring_mesh.instantiate()
			r.name = "CavernRing_" + str(i + 1)
			r.position = Vector3(0, 50, -i * 110.0)
			_add_static_box_collision(r, Vector3(50, 45, 100))
			cavern_root.add_child(r)
			
	# 2. Spawn 3 Geothermal Extraction Generators
	var gen_locs = [
		Vector3(-35, 30, -220),
		Vector3(40, 45, -440),
		Vector3(0, 25, -620)
	]
	for i in range(gen_locs.size()):
		var g = Node3D.new()
		g.name = "GeothermalGen_0" + str(i + 1)
		g.set_script(drone_script)
		g.drone_type = "generator"
		g.center_point = gen_locs[i]
		g.orbit_radius = 0.0
		g.orbit_speed = 0.0
		g.altitude = gen_locs[i].y
		g.max_health = 150.0
		g.health = 150.0
		g.respawn_enabled = false
		g.destroyed.connect(_on_mission_target_destroyed.bind(g, "obj_generators"))
		active_root.add_child(g)
		g.position = gen_locs[i]
		
		if gen_mesh:
			var vis = gen_mesh.instantiate()
			g.add_child(vis)
			
	# 3. Spawn 6 Automated Laser Sentries
	var sentry_locs = [
		Vector3(-55, 65, -150), Vector3(55, 65, -150),
		Vector3(-55, 35, -330), Vector3(55, 35, -330),
		Vector3(-55, 50, -520), Vector3(55, 50, -520)
	]
	for i in range(sentry_locs.size()):
		var s = Node3D.new()
		s.name = "LaserSentry_0" + str(i + 1)
		s.set_script(drone_script)
		s.drone_type = "sentry"
		s.center_point = sentry_locs[i]
		s.orbit_radius = 0.0
		s.orbit_speed = 0.0
		s.altitude = sentry_locs[i].y
		s.max_health = 80.0
		s.health = 80.0
		s.respawn_enabled = false
		s.destroyed.connect(_on_mission_target_destroyed.bind(s, "obj_laser_sentries"))
		active_root.add_child(s)
		s.position = sentry_locs[i]
		
		if sentry_mesh:
			var vis = sentry_mesh.instantiate()
			s.add_child(vis)

func _spawn_m07_carrier_and_torpedoes() -> void:
	var carrier_mesh = load("res://assets/meshes/vehicles/carrier_soc_dauntless.glb")
	var torp_mesh = load("res://assets/meshes/vehicles/heavy_anti_ship_torpedo.glb")
	var drone_script = load("res://target_drone.gd")
	
	# 1. Spawn SOC Dauntless Carrier
	var carrier = Node3D.new()
	carrier.name = "SOC_Dauntless"
	carrier.position = Vector3(0, 60, 200)
	carrier.add_to_group("friendlies")
	_add_static_box_collision(carrier, Vector3(90, 40, 280), Vector3.ZERO, 16) # Layer 5: Allies
	active_root.add_child(carrier)
	if carrier_mesh:
		var vis = carrier_mesh.instantiate()
		carrier.add_child(vis)
		
	# 2. Spawn Wingman Viper 2 (Miller)
	var viper_mesh = load("res://assets/meshes/vehicles/Spaceship_Viper_Supreme_HD.fbx")
	var wingman = Node3D.new()
	wingman.name = "Wingman_Miller"
	wingman.position = Vector3(45, 65, 80)
	wingman.add_to_group("friendlies")
	active_root.add_child(wingman)
	if viper_mesh:
		var v_vis = viper_mesh.instantiate()
		wingman.add_child(v_vis)
		
	# 3. Spawn 8 Heavy Anti-Ship Fusion Torpedoes
	var torp_origins = [
		Vector3(-180, 80, -600), Vector3(180, 75, -650),
		Vector3(-240, 95, -720), Vector3(240, 85, -750),
		Vector3(-120, 110, -820), Vector3(120, 100, -840),
		Vector3(-300, 90, -900), Vector3(300, 90, -920)
	]
	for i in range(torp_origins.size()):
		var t = Node3D.new()
		t.name = "FusionTorpedo_0" + str(i + 1)
		t.set_script(drone_script)
		t.drone_type = "bomber"
		t.center_point = torp_origins[i]
		t.orbit_radius = 60.0
		t.orbit_speed = 0.35
		t.altitude = torp_origins[i].y
		t.max_health = 75.0
		t.health = 75.0
		t.respawn_enabled = false
		t.destroyed.connect(_on_mission_target_destroyed.bind(t, "obj_intercept_torps"))
		active_root.add_child(t)
		t.position = torp_origins[i]
		
		if torp_mesh:
			var vis = torp_mesh.instantiate()
			t.add_child(vis)

func _spawn_m08_dreadnought_boss() -> void:
	var dread_mesh = load("res://assets/meshes/vehicles/dreadnought_nemesis9.glb")
	var drone_script = load("res://target_drone.gd")
	
	# 1. Spawn Dreadnought Nemesis-9
	var dread = Node3D.new()
	dread.name = "Dreadnought_Nemesis9"
	dread.position = Vector3(0, 80, -420)
	dread.add_to_group("enemies")
	_add_static_box_collision(dread, Vector3(100, 45, 260), Vector3.ZERO, 4) # Layer 3: Enemies
	active_root.add_child(dread)
	if dread_mesh:
		var vis = dread_mesh.instantiate()
		dread.add_child(vis)
		
	# 2. Phase 1: 4 Rotary Flak Pods
	var flak_offsets = [
		Vector3(-32, 22, -40), Vector3(32, 22, -40),
		Vector3(-32, 22, 50), Vector3(32, 22, 50)
	]
	for i in range(flak_offsets.size()):
		var fp = Node3D.new()
		fp.name = "FlakPod_0" + str(i + 1)
		fp.set_script(drone_script)
		fp.drone_type = "sentry"
		fp.center_point = dread.position + flak_offsets[i]
		fp.orbit_radius = 0.0
		fp.orbit_speed = 0.0
		fp.altitude = (dread.position + flak_offsets[i]).y
		fp.max_health = 100.0
		fp.health = 100.0
		fp.respawn_enabled = false
		fp.destroyed.connect(_on_mission_target_destroyed.bind(fp, "obj_flak_pods"))
		active_root.add_child(fp)
		fp.position = dread.position + flak_offsets[i]
		
	# 3. Phase 2: 2 Ventral Shield Generators
	for i in range(2):
		var sg = Node3D.new()
		sg.name = "ShieldDome_0" + str(i + 1)
		sg.set_script(drone_script)
		sg.drone_type = "generator"
		var offset = Vector3(-28.0 if i == 0 else 28.0, -20.0, 0.0)
		sg.center_point = dread.position + offset
		sg.orbit_radius = 0.0
		sg.orbit_speed = 0.0
		sg.altitude = (dread.position + offset).y
		sg.max_health = 150.0
		sg.health = 150.0
		sg.respawn_enabled = false
		sg.destroyed.connect(_on_mission_target_destroyed.bind(sg, "obj_shield_domes"))
		active_root.add_child(sg)
		sg.position = dread.position + offset
		
	# 4. Phase 3: Core Reactor
	var core = Node3D.new()
	core.name = "ReactorCore"
	core.set_script(drone_script)
	core.drone_type = "boss"
	core.center_point = dread.position + Vector3(0, -18, 20)
	core.orbit_radius = 0.0
	core.orbit_speed = 0.0
	core.altitude = (dread.position + Vector3(0, -18, 20)).y
	core.max_health = 350.0
	core.health = 350.0
	core.respawn_enabled = false
	core.destroyed.connect(_on_mission_target_destroyed.bind(core, "obj_destroy_dreadnought"))
	active_root.add_child(core)
	core.position = dread.position + Vector3(0, -18, 20)

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
	
	# M04: Near-vacuum altitude monitoring & thin air advisory + boss intercept tracking
	if current_mission_id == "M04":
		var alt = active_ship.global_position.y
		if alt > 150.0 and altitude_warning_timer == 0.0:
			altitude_warning_timer = 1.0
			queue_transmission("AEGIS_7", "Atmospheric density below 5%. Aero-surfaces stalling. Switch to reaction thrusters.", 4.0, "res://audio/comms/m04_aegis_thin_air.mp3")
		
		# Intercept objective evaluation
		var boss = active_root.get_node_or_null("Boss_CombineGhost")
		if is_instance_valid(boss):
			var d_boss = active_ship.global_position.distance_to(boss.global_position)
			if d_boss < 480.0:
				_set_objective_status("obj_intercept", "COMPLETED", 1, 1)

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
	if obj_id == "obj_boss":
		_set_objective_status("obj_intercept", "COMPLETED", 1, 1)
	
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
	var sm = get_tree().root.get_node_or_null("SaveManager") if (is_inside_tree() and get_tree() and get_tree().root) else null
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
		"M05":
			queue_transmission("APEX_CMD", "Vanguard 1, Apex Command. You are clear of the Dauntless hangar bay. Watch your RCS thrusters.", 4.5, "res://audio/comms/m05_apex_carrier_launch.mp3")
			queue_transmission("AEGIS_7", "Orbital vacuum confirmed. Inertial drift compensators online.", 3.5, "res://audio/comms/m05_aegis_vacuum_online.mp3")
			queue_transmission("VIPER_2", "Look at this junk field, Lead. The Combine seeded the rim with magnetic tether-mines.", 4.5, "res://audio/comms/m05_miller_tether_warning.mp3")
		"M06":
			queue_transmission("APEX_CMD", "Vanguard 1, you're entering the Iron Hollow. Trench clearance is less than 150 meters.", 4.5, "res://audio/comms/m06_apex_enter_cavern.mp3")
			queue_transmission("AEGIS_7", "Warning: Multiple automated laser cutting arrays active along cavern bulkheads.", 3.5, "res://audio/comms/m06_aegis_laser_warning.mp3")
		"M07":
			queue_transmission("ROSS", "All stations, general quarters! Combine bombers jumping in! They've launched heavy torpedoes!", 4.5, "res://audio/comms/m07_ross_general_quarters.mp3")
			queue_transmission("APEX_CMD", "Vanguard Flight, priority one is fleet defense! Splash those fusion warheads!", 4.5, "res://audio/comms/m07_apex_defend_carrier.mp3")
		"M08":
			queue_transmission("APEX_CMD", "There she is... the Nemesis-9. Look at the armor plating on that monster.", 4.5, "res://audio/comms/m08_apex_nemesis_visual.mp3")
			queue_transmission("VANE", "Directorate lapdogs. You bled for this rock, and here you shall be buried! Fire flak batteries!", 5.0, "res://audio/comms/m08_vane_challenge.mp3")

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
		"M05":
			queue_transmission("VIPER_2", "Splash two! You got the others, Lead! Perimeter corridor is clean.", 4.0, "res://audio/comms/m05_miller_perimeter_clear.mp3")
			queue_transmission("APEX_CMD", "Good hunting, Vanguard. Telemetry decoded coordinates to their internal foundry. Prep for cavern infiltration.", 5.0, "res://audio/comms/m05_apex_foundry_coords.mp3")
		"M06":
			queue_transmission("APEX_CMD", "Hit full afterburners, Vanguard 1! Get out of that rock before the shaft collapses!", 4.0, "res://audio/comms/m06_apex_afterburners_escape.mp3")
			queue_transmission("VIPER_2", "Punch it, Lead! I see your exhaust plume breaking through the exit fissure!", 4.0, "res://audio/comms/m06_miller_exit_visual.mp3")
		"M07":
			queue_transmission("ROSS", "Direct hit on the final bomber! All torpedo tracks dissipated. The Dauntless owes you her life!", 4.5, "res://audio/comms/m07_ross_carrier_saved.mp3")
			queue_transmission("APEX_CMD", "We tracked the bombers' telemetry back to the Celestial Forge. We're taking the fight to their front door!", 5.0, "res://audio/comms/m07_apex_forge_tracking.mp3")
		"M08":
			queue_transmission("AEGIS_7", "Thermal core breached! Critical containment failure imminent!", 3.5, "res://audio/comms/m08_aegis_core_rupture.mp3")
			queue_transmission("VANE", "Impossible... My forge... my empire... CURSE YOU, VANGUARD!", 4.0, "res://audio/comms/m08_vane_death_cry.mp3")
			queue_transmission("APEX_CMD", "Confirmed! Dreadnought Nemesis-9 is detonating! The Celestial Forge is broken! Chapter Two is ours!", 5.5, "res://audio/comms/m08_apex_chapter2_victory.mp3")

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

func _add_static_box_collision(parent_node: Node3D, box_size: Vector3, box_offset: Vector3 = Vector3.ZERO, layer: int = 1) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.name = "StaticCollision"
	body.collision_layer = layer
	body.collision_mask = 0
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = box_size
	col.shape = shape
	col.position = box_offset
	body.add_child(col)
	parent_node.add_child(body)
	return body
