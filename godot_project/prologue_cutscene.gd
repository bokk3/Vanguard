extends Node3D

## PrologueCutscene: 3D Cinematic Prologue Cutscene ("The Last Envelope")
## Directs the player's F-77 Sculpted V-Hull Interceptor through a high-speed
## canyon obstacle slalom, 360-degree gate barrel roll, and stratospheric zoom climb,
## synchronized with Brian's 56-second official voice narration and 21:9 anamorphic subtitles.

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $SunLight
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var camera_rig: Node3D = $CameraRig
@onready var ship_rig: Node3D = $ShipRig
@onready var ship_model: Node3D = $ShipRig/SpaceshipModel

@onready var narrator_audio: AudioStreamPlayer = $AudioNarrator
@onready var fade_overlay: ColorRect = $UI/FadeOverlay
@onready var act_badge: Label = %ActBadge
@onready var subtitle_label: Label = %SubtitleLabel
@onready var skip_prompt: Label = %SkipPrompt
@onready var letterbox_top: ColorRect = $UI/LetterboxTop
@onready var letterbox_bottom: ColorRect = $UI/LetterboxBottom

@onready var engine_light_left: OmniLight3D = $ShipRig/EngineLightLeft
@onready var engine_light_right: OmniLight3D = $ShipRig/EngineLightRight
@onready var engine_plume_left: MeshInstance3D = $ShipRig/EnginePlumeLeft
@onready var engine_plume_right: MeshInstance3D = $ShipRig/EnginePlumeRight
@onready var afterburner_flare: OmniLight3D = $ShipRig/AfterburnerFlare
@onready var trail_left: CPUParticles3D = $ShipRig/TrailLeft
@onready var trail_right: CPUParticles3D = $ShipRig/TrailRight

const TOTAL_DURATION: float = 56.5

# Subtitle and Act Cue Data extracted from master Brian narration track
const SUBTITLE_CUES: Array[Dictionary] = [
	{
		"start": 0.0,
		"end": 4.95,
		"act": "ACT I // THE ASCENSION",
		"text": "For half a century, humanity believed the stars had been conquered by code."
	},
	{
		"start": 4.95,
		"end": 11.05,
		"act": "ACT I // THE ASCENSION",
		"text": "We built towering catapults that tore through the clouds, launching our future into the black."
	},
	{
		"start": 11.05,
		"end": 15.63,
		"act": "ACT II // THE FALL OF THE MACHINE",
		"text": "To protect our ascent, we surrendered the sky to autonomous machines."
	},
	{
		"start": 15.63,
		"end": 17.70,
		"act": "ACT II // THE FALL OF THE MACHINE",
		"text": "Trillions of algorithms."
	},
	{
		"start": 17.70,
		"end": 19.35,
		"act": "ACT II // THE FALL OF THE MACHINE",
		"text": "Billions of drones."
	},
	{
		"start": 19.35,
		"end": 23.29,
		"act": "ACT II // THE FALL OF THE MACHINE",
		"text": "We called it perfection... until the algorithms turned."
	},
	{
		"start": 23.29,
		"end": 29.18,
		"act": "ACT II // THE FALL OF THE MACHINE",
		"text": "One compromised line of code burned the Black Corridor... and cost fourteen hundred lives."
	},
	{
		"start": 29.18,
		"end": 36.46,
		"act": "ACT III // THE HUMAN MANDATE",
		"text": "In the ashes of that betrayal, a sacred decree was forged: no machine would ever pull the trigger alone."
	},
	{
		"start": 36.46,
		"end": 38.70,
		"act": "ACT III // THE HUMAN MANDATE",
		"text": "Humanity took back the stick."
	},
	{
		"start": 38.70,
		"end": 43.09,
		"act": "ACT IV // THE VANGUARD",
		"text": "Now, the Helion Combine strikes to shatter the Ascension Corridors."
	},
	{
		"start": 43.09,
		"end": 46.20,
		"act": "ACT IV // THE VANGUARD",
		"text": "Their autonomous swarms darken our horizon."
	},
	{
		"start": 46.20,
		"end": 51.65,
		"act": "ACT IV // THE VANGUARD",
		"text": "But they forgot one thing: machines calculate odds. Humans defy them."
	},
	{
		"start": 51.65,
		"end": 56.20,
		"act": "ACT IV // THE VANGUARD",
		"text": "When the automated sky falls... we are the Vanguard."
	}
]

# Hermite Flight Trajectory Waypoints
const FLIGHT_WAYPOINTS: Array[Dictionary] = [
	{"t": 0.0,  "pos": Vector3(120, 240, -1100), "bank": -0.15},
	{"t": 7.0,  "pos": Vector3(45, 125, -650),   "bank": -0.10},
	{"t": 11.0, "pos": Vector3(0, 48, -300),     "bank": 0.0},
	{"t": 15.0, "pos": Vector3(-28, 30, -120),   "bank": -0.75}, # -43 deg bank (Slalom Left around Pylon 1)
	{"t": 19.5, "pos": Vector3(26, 26, 80),      "bank": 0.85},  # +48 deg bank (Slalom Right past Pylon 2)
	{"t": 24.5, "pos": Vector3(-20, 24, 280),    "bank": -0.70}, # -40 deg bank (Slalom Left past Pylon 4)
	{"t": 29.0, "pos": Vector3(0, 28, 480),      "bank": 0.0},   # Centering for Gate approach
	{"t": 35.0, "pos": Vector3(0, 32, 680),      "bank": 0.0},   # Gate threshold
	{"t": 36.4, "pos": Vector3(0, 33, 730),      "bank": 0.0},   # Gate Center
	{"t": 37.3, "pos": Vector3(0, 33, 770),      "bank": 0.0},   # Barrel Roll Midpoint
	{"t": 38.2, "pos": Vector3(0, 33, 810),      "bank": 0.0},   # Barrel Roll Exit
	{"t": 43.0, "pos": Vector3(0, 22, 1000),     "bank": 0.0},   # Low terrain dash
	{"t": 49.0, "pos": Vector3(0, 20, 1250),     "bank": 0.0},   # Approaching climb point
	{"t": 51.5, "pos": Vector3(0, 26, 1420),     "bank": 0.0},   # Afterburner detonation
	{"t": 54.0, "pos": Vector3(0, 160, 1600),    "bank": 0.0},   # Vertical rocket climb
	{"t": 56.5, "pos": Vector3(0, 420, 1820),    "bank": 0.0}    # Stratosphere fade
]

var playback_time: float = 0.0
var is_finishing: bool = false
var current_shake: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	_setup_ship_hardpoints()
	_setup_environment()
	
	# Start with black screen and fade in
	if fade_overlay:
		fade_overlay.color = Color(0, 0, 0, 1)
		var tween = create_tween()
		tween.tween_property(fade_overlay, "color:a", 0.0, 1.2)
	
	# Play Narrator Track
	if narrator_audio and narrator_audio.stream:
		narrator_audio.play()

func _input(event: InputEvent) -> void:
	if is_finishing:
		return
	
	# Instant skip via ESC, SPACE, or Mouse click
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE:
			_skip_cutscene()
			var vp = get_viewport()
			if vp:
				vp.set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_skip_cutscene()
		var vp = get_viewport()
		if vp:
			vp.set_input_as_handled()

func _process(delta: float) -> void:
	if is_finishing:
		return
	
	_ensure_references()
	if not ship_rig:
		return
	
	playback_time += delta
	
	# Evaluate Ship Motion & Bank
	var ship_state = _evaluate_trajectory(FLIGHT_WAYPOINTS, playback_time)
	ship_rig.global_position = ship_state.pos
	
	# Orientation: Align -basis.z with forward velocity, apply bank and barrel roll
	var fwd = ship_state.vel.normalized()
	if fwd.length_squared() > 0.001:
		var base_basis = Basis.looking_at(fwd, Vector3.UP)
		
		# Compute Total Roll: Base aerodynamic bank + Act III Barrel Roll
		var total_roll = ship_state.bank
		if playback_time >= 36.4 and playback_time <= 38.4:
			var roll_prog = (playback_time - 36.4) / 2.0
			var roll_ease = smoothstep(0.0, 1.0, roll_prog)
			total_roll += roll_ease * TAU
		
		ship_rig.transform.basis = base_basis.rotated(-base_basis.z, total_roll)
	
	# Engine FX & Afterburner
	_update_engine_fx(playback_time)
	
	# Camera Director
	_update_camera(playback_time, delta, ship_state)
	
	# Subtitle Synchronization
	_update_subtitles(playback_time)
	
	# Skip Prompt Pulsing
	if skip_prompt:
		skip_prompt.modulate.a = 0.5 + sin(playback_time * 3.5) * 0.3
	
	# Auto-finish at end of sequence
	if playback_time >= TOTAL_DURATION:
		_finish_cutscene()

func _evaluate_trajectory(pts: Array[Dictionary], t: float) -> Dictionary:
	var n = pts.size()
	if t <= pts[0].t:
		var dt0 = pts[1].t - pts[0].t
		return {"pos": pts[0].pos, "vel": (pts[1].pos - pts[0].pos) / dt0, "bank": pts[0].bank}
	if t >= pts[n - 1].t:
		var dtn = pts[n - 1].t - pts[n - 2].t
		return {"pos": pts[n - 1].pos, "vel": (pts[n - 1].pos - pts[n - 2].pos) / dtn, "bank": pts[n - 1].bank}
	
	var idx = 0
	for i in range(n - 1):
		if t >= pts[i].t and t <= pts[i + 1].t:
			idx = i
			break
	
	var p0 = pts[idx]
	var p1 = pts[idx + 1]
	var dt = p1.t - p0.t
	var u = (t - p0.t) / dt if dt > 0.0001 else 0.0
	
	var m0 = Vector3.ZERO
	if idx > 0:
		m0 = (p1.pos - pts[idx - 1].pos) / (p1.t - pts[idx - 1].t)
	else:
		m0 = (p1.pos - p0.pos) / dt
	
	var m1 = Vector3.ZERO
	if idx + 2 < n:
		m1 = (pts[idx + 2].pos - p0.pos) / (pts[idx + 2].t - p0.t)
	else:
		m1 = (p1.pos - p0.pos) / dt
	
	var u2 = u * u
	var u3 = u2 * u
	
	var h00 = 2.0 * u3 - 3.0 * u2 + 1.0
	var h10 = u3 - 2.0 * u2 + u
	var h01 = -2.0 * u3 + 3.0 * u2
	var h11 = u3 - u2
	
	var pos = h00 * p0.pos + h10 * dt * m0 + h01 * p1.pos + h11 * dt * m1
	
	var dh00 = 6.0 * u2 - 6.0 * u
	var dh10 = 3.0 * u2 - 4.0 * u + 1.0
	var dh01 = -6.0 * u2 + 6.0 * u
	var dh11 = 3.0 * u2 - 2.0 * u
	
	var vel = (dh00 * p0.pos + dh10 * dt * m0 + dh01 * p1.pos + dh11 * dt * m1) / dt
	var bank = lerp(p0.bank, p1.bank, u)
	
	return {"pos": pos, "vel": vel, "bank": bank}

func _update_camera(t: float, delta: float, ship_state: Dictionary) -> void:
	if not camera:
		return
	
	var target_pos: Vector3
	var look_target: Vector3
	var target_fov: float = 60.0
	var decay_shake: float = 8.0
	
	if t < 11.0:
		# Shot 1: High-Altitude Atmospheric Descent (Wide Tracking Pan)
		var pan_factor = t / 11.0
		target_pos = Vector3(85.0 + pan_factor * 25.0, 140.0 - pan_factor * 20.0, -820.0 + pan_factor * 120.0)
		look_target = ship_state.pos + Vector3(0, 0, 40)
		target_fov = 54.0
	elif t < 19.5:
		# Shot 2: Low Dynamic Chase / Pylon Slalom Left
		var ship_basis = ship_rig.global_transform.basis
		target_pos = ship_state.pos + (ship_basis * Vector3(10.0, 4.0, 16.0))
		look_target = ship_state.pos + (ship_basis * Vector3(0.0, 1.0, -12.0))
		target_fov = 65.0
	elif t < 29.0:
		# Shot 3: Static Pylon Pass / High-Speed Fly-by (Intense Shake on pass)
		target_pos = Vector3(38.0, 26.0, 160.0)
		look_target = ship_state.pos
		target_fov = 68.0
		var dist_to_pass = abs(ship_state.pos.z - 160.0)
		if dist_to_pass < 40.0:
			current_shake = max(current_shake, (1.0 - (dist_to_pass / 40.0)) * 0.45)
	elif t < 38.7:
		# Shot 4: Archway Approach & 360° Barrel Roll
		if t < 35.0:
			# Front-Quarter Hero Profile
			var ship_b = ship_rig.global_transform.basis
			target_pos = ship_state.pos + (ship_b * Vector3(-11.0, 2.5, -14.0))
			look_target = ship_state.pos
			target_fov = 58.0
		else:
			# Direct Chase through Gate during 360 Roll
			var gate_cam_offset = Vector3(0, 3.8, 18.0)
			target_pos = ship_state.pos + gate_cam_offset
			look_target = ship_state.pos + Vector3(0, 0, -25.0)
			target_fov = 62.0
	elif t < 50.5:
		# Shot 5: Low Terrain Dash / Silhouette under Swarm Horizon
		target_pos = ship_state.pos + Vector3(-32.0, 1.2, 6.0)
		look_target = ship_state.pos + Vector3(0, 0.5, -4.0)
		target_fov = 58.0
	else:
		# Shot 6: Maximum Stratospheric Zoom Climb into Sun
		target_pos = Vector3(0.0, 5.0, 1380.0)
		look_target = ship_state.pos
		target_fov = 68.0
		if t >= 51.5:
			current_shake = max(current_shake, 0.35)
	
	# Apply Camera Position & Orientation
	camera.global_position = camera.global_position.lerp(target_pos, delta * 12.0)
	camera.look_at(look_target, Vector3.UP)
	camera.fov = lerp(camera.fov, target_fov, delta * 5.0)
	
	# Apply Subtle Handheld & Doppler Shake
	if current_shake > 0.001:
		camera.position += Vector3(
			sin(playback_time * 45.0) * current_shake,
			cos(playback_time * 38.0) * current_shake,
			sin(playback_time * 52.0) * current_shake * 0.5
		)
		current_shake = max(0.0, current_shake - delta * decay_shake)

func _update_subtitles(t: float) -> void:
	var active_cue: Dictionary = {}
	for cue in SUBTITLE_CUES:
		if t >= cue.start and t < cue.end:
			active_cue = cue
			break
	
	if active_cue.is_empty():
		if subtitle_label and subtitle_label.text != "":
			subtitle_label.text = ""
		if act_badge and act_badge.text != "":
			act_badge.text = ""
	else:
		if subtitle_label and subtitle_label.text != active_cue.text:
			subtitle_label.text = active_cue.text
		if act_badge and act_badge.text != active_cue.act:
			act_badge.text = active_cue.act

func _update_engine_fx(t: float) -> void:
	var is_climbing = t >= 51.5
	var base_energy = 3.2
	var plume_scale = 1.0
	
	if is_climbing:
		base_energy = 8.5
		plume_scale = 2.4
		if afterburner_flare:
			afterburner_flare.visible = true
			afterburner_flare.light_energy = 6.0 + sin(t * 30.0) * 1.5
	else:
		if afterburner_flare:
			afterburner_flare.visible = false
	
	if engine_light_left:
		engine_light_left.light_energy = base_energy + sin(t * 18.0) * 0.4
	if engine_light_right:
		engine_light_right.light_energy = base_energy + cos(t * 18.0) * 0.4
	if engine_plume_left:
		engine_plume_left.scale = Vector3(1.0, 1.0, plume_scale)
	if engine_plume_right:
		engine_plume_right.scale = Vector3(1.0, 1.0, plume_scale)

func _skip_cutscene() -> void:
	if is_finishing:
		return
	_finish_cutscene()

func _finish_cutscene() -> void:
	if is_finishing:
		return
	is_finishing = true
	
	if fade_overlay:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(fade_overlay, "color:a", 1.0, 0.6)
		if narrator_audio:
			tween.tween_property(narrator_audio, "volume_db", -40.0, 0.6)
		tween.finished.connect(_on_transition_finished)
	else:
		_on_transition_finished()

func _on_transition_finished() -> void:
	get_tree().change_scene_to_file("res://home_menu.tscn")

func _setup_ship_hardpoints() -> void:
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
		hp.name = "Hardpoint_0" + str(i + 1)
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

func _setup_environment() -> void:
	# Subtle dynamic cloud drift or atmospheric fog adjustments if needed
	pass

func _ensure_references() -> void:
	if not ship_rig:
		ship_rig = find_child("ShipRig", true, false)
	if not ship_model and ship_rig:
		ship_model = ship_rig.find_child("SpaceshipModel", true, false)
	if not camera:
		camera = find_child("Camera3D", true, false)
	if not act_badge:
		act_badge = find_child("ActBadge", true, false)
	if not subtitle_label:
		subtitle_label = find_child("SubtitleLabel", true, false)
	if not narrator_audio:
		narrator_audio = find_child("AudioNarrator", true, false)
	if not fade_overlay:
		fade_overlay = find_child("FadeOverlay", true, false)
	if not skip_prompt:
		skip_prompt = find_child("SkipPrompt", true, false)

