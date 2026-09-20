extends Node3D

## InterludeCutscene: Dynamic ~20-Second Cinematic Cutscene System
## Plays between-mission interludes and the Chapter 1 Finale.
## Synchronized with Brian's voice narration, dynamic 3D camera cinematography,
## 21:9 letterboxing, and seamless progression to the next mission.

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $SunLight
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var ship_rig: Node3D = $ShipRig
@onready var wingman_rig: Node3D = $WingmanRig
@onready var transport_rig: Node3D = $TransportRig

@onready var narrator_audio: AudioStreamPlayer = $AudioNarrator
@onready var fade_overlay: ColorRect = $UI/FadeOverlay
@onready var act_badge: Label = %ActBadge
@onready var subtitle_label: Label = %SubtitleLabel
@onready var skip_prompt: Label = %SkipPrompt
@onready var finale_card: Control = %FinaleCard
@onready var finale_title: Label = %FinaleTitle
@onready var finale_subtitle: Label = %FinaleSubtitle

@onready var engine_light_left: OmniLight3D = $ShipRig/EngineLightLeft
@onready var engine_light_right: OmniLight3D = $ShipRig/EngineLightRight
@onready var engine_plume_left: MeshInstance3D = $ShipRig/EnginePlumeLeft
@onready var engine_plume_right: MeshInstance3D = $ShipRig/EnginePlumeRight
@onready var afterburner_flare: OmniLight3D = $ShipRig/AfterburnerFlare

const INTERLUDES: Dictionary = {
	"INT_M01_M02": {
		"title": "CHAPTER 1 // INTERLUDE 01",
		"subtitle": "INTO THE RED SINKS",
		"audio_path": "res://audio/narrator/interlude_01_red_sinks.mp3",
		"duration": 17.5,
		"sky_preset": "dusk_canyon",
		"next_mission": "M02",
		"is_finale": false,
		"cues": [
			{"start": 0.0, "end": 5.2, "text": "The cloud corridor was secure, but the silence was short-lived."},
			{"start": 5.2, "end": 11.8, "text": "Beneath the radar horizon, in the deep rifts of the Red Sinks, the Combine planted their roots."},
			{"start": 11.8, "end": 17.0, "text": "Vanguard 1... dive beneath the radar shadow. Sanitize the canyon."}
		]
	},
	"INT_M02_M03": {
		"title": "CHAPTER 1 // INTERLUDE 02",
		"subtitle": "THE LIFTOFF PROTOCOL",
		"audio_path": "res://audio/narrator/interlude_02_apex_liftoff.mp3",
		"duration": 19.5,
		"sky_preset": "dawn_clear",
		"next_mission": "M03",
		"is_finale": false,
		"cues": [
			{"start": 0.0, "end": 5.0, "text": "With the jamming towers shattered, the radar net screamed to life."},
			{"start": 5.0, "end": 10.2, "text": "The Helion swarm was already falling on the Ascension Catapult."},
			{"start": 10.2, "end": 14.2, "text": "The transport Olympus-4 is vulnerable on the rail."},
			{"start": 14.2, "end": 19.0, "text": "Scramble flight lead Vanguard 1 and wingman Miller. Protect the liftoff at all costs."}
		]
	},
	"INT_M03_M04": {
		"title": "CHAPTER 1 // INTERLUDE 03",
		"subtitle": "THE KARMAN ZENITH",
		"audio_path": "res://audio/narrator/interlude_03_karman_zenith.mp3",
		"duration": 20.5,
		"sky_preset": "stratosphere_space",
		"next_mission": "M04",
		"is_finale": false,
		"cues": [
			{"start": 0.0, "end": 5.0, "text": "Olympus-4 made orbit, but telemetry revealed the puppeteer."},
			{"start": 5.0, "end": 10.8, "text": "High above the atmosphere, where the sky turns to black, the Combine Ghost commands the swarm."},
			{"start": 10.8, "end": 14.2, "text": "Forty-five thousand meters. No air. No second chances."},
			{"start": 14.2, "end": 20.0, "text": "Ignite afterburners, Vanguard 1. Breach the void."}
		]
	},
	"EPILOGUE_CH1": {
		"title": "CHAPTER 1 // EPILOGUE FINALE",
		"subtitle": "THE BROKEN SWARM",
		"audio_path": "res://audio/narrator/epilogue_chapter1_finale.mp3",
		"duration": 21.0,
		"sky_preset": "stratosphere_space",
		"next_mission": "",
		"is_finale": true,
		"cues": [
			{"start": 0.0, "end": 4.5, "text": "The Combine Ghost burned across the mesosphere."},
			{"start": 4.5, "end": 9.2, "text": "With its core shattered, the swarm collapsed into the sea."},
			{"start": 9.2, "end": 12.8, "text": "The Ascension Corridors held. Chapter One is won..."},
			{"start": 12.8, "end": 17.5, "text": "...but deep in the Asteroid Belt, Helion shipyards are already waking up."},
			{"start": 17.5, "end": 21.0, "text": "Rest while you can, Ace. Chapter Two has just begun."}
		]
	},
	"INT_M04_M05": {
		"title": "CHAPTER 2 // INTERLUDE 04",
		"subtitle": "INTO THE ASTEROID BELT",
		"audio_path": "res://audio/narrator/interlude_04_asteroid_belt.mp3",
		"duration": 19.5,
		"sky_preset": "deep_space_belt",
		"next_mission": "M05",
		"is_finale": false,
		"cues": [
			{"start": 0.0, "end": 6.5, "text": "Beyond the Karman line, gravity releases its grip. The Sol Directorate launched the Dauntless into the Gordian Belt to sever the Combine's supply lines."},
			{"start": 6.5, "end": 12.0, "text": "Ahead lies a silent graveyard of stone and iron."},
			{"start": 12.0, "end": 19.5, "text": "Check your thrusters, Vanguard 1. Out here, there is no air to catch your fall."}
		]
	},
	"INT_M05_M06": {
		"title": "CHAPTER 2 // INTERLUDE 05",
		"subtitle": "THE IRON HOLLOW",
		"audio_path": "res://audio/narrator/interlude_05_iron_hollow.mp3",
		"duration": 18.8,
		"sky_preset": "asteroid_cavern",
		"next_mission": "M06",
		"is_finale": false,
		"cues": [
			{"start": 0.0, "end": 5.8, "text": "Telemetry from the perimeter probes unveiled the Combine's secret foundry."},
			{"start": 5.8, "end": 11.5, "text": "Deep within the hollowed heart of Asteroid Eros, automated smelters forge weapons in silence."},
			{"start": 11.5, "end": 18.8, "text": "Penetrate the excavation trench. Shatter their geothermal reactors, and burn your way back into the stars."}
		]
	},
	"INT_M06_M07": {
		"title": "CHAPTER 2 // INTERLUDE 06",
		"subtitle": "DISTRESS IN THE DARK",
		"audio_path": "res://audio/narrator/interlude_06_distress_dark.mp3",
		"duration": 19.2,
		"sky_preset": "carrier_orbit",
		"next_mission": "M07",
		"is_finale": false,
		"cues": [
			{"start": 0.0, "end": 5.8, "text": "The explosion inside Eros sent shockwaves through the belt. But the Combine retaliated without mercy."},
			{"start": 5.8, "end": 12.2, "text": "A wolfpack of heavy bombers has intercepted the Dauntless while her catapults were cold."},
			{"start": 12.2, "end": 19.2, "text": "All callsigns scramble! Protect the flagship, or the fleet dies in the dark."}
		]
	},
	"INT_M07_M08": {
		"title": "CHAPTER 2 // INTERLUDE 07",
		"subtitle": "THE CELESTIAL FORGE",
		"audio_path": "res://audio/narrator/interlude_07_celestial_forge.mp3",
		"duration": 20.0,
		"sky_preset": "crucible_forge",
		"next_mission": "M08",
		"is_finale": false,
		"cues": [
			{"start": 0.0, "end": 6.8, "text": "The carrier stood her ground. Tracing the bombers' flight paths led directly to the Combine's command nexus: the Celestial Forge."},
			{"start": 6.8, "end": 13.0, "text": "Guarding the shipyard is their supreme flagship... the Dreadnought Nemesis-9."},
			{"start": 13.0, "end": 20.0, "text": "This is where their war machine ends, Ace. Strike the leviathan down."}
		]
	},
	"EPILOGUE_CH2": {
		"title": "CHAPTER 2 // EPILOGUE FINALE",
		"subtitle": "BEYOND THE KUIPER VEIL",
		"audio_path": "res://audio/narrator/epilogue_chapter2_finale.mp3",
		"duration": 20.5,
		"sky_preset": "crucible_forge",
		"next_mission": "",
		"is_finale": true,
		"cues": [
			{"start": 0.0, "end": 5.8, "text": "The Nemesis-9 burned like a newborn star, scattering the Combine's fleet to dust."},
			{"start": 5.8, "end": 9.5, "text": "The Belt is liberated. Chapter Two is won."},
			{"start": 9.5, "end": 15.5, "text": "Yet as the dreadnought shattered, her black box transmitted one final quantum pulse toward the deep Kuiper Veil."},
			{"start": 15.5, "end": 20.5, "text": "Someone answered. Prepare your wings, Vanguard. Chapter Three will take us into the unknown."}
		]
	}
}

var current_id: String = "INT_M01_M02"
var config: Dictionary = {}
var playback_time: float = 0.0
var total_duration: float = 20.0
var is_finishing: bool = false

func _ensure_references() -> void:
	if not world_env and has_node("WorldEnvironment"):
		world_env = $WorldEnvironment
	if not sun_light and has_node("SunLight"):
		sun_light = $SunLight
	if not camera_rig and has_node("CameraRig"):
		camera_rig = $CameraRig
	if not camera and has_node("CameraRig/Camera3D"):
		camera = $CameraRig/Camera3D
	if not ship_rig and has_node("ShipRig"):
		ship_rig = $ShipRig
	if not wingman_rig and has_node("WingmanRig"):
		wingman_rig = $WingmanRig
	if not transport_rig and has_node("TransportRig"):
		transport_rig = $TransportRig
	if not narrator_audio and has_node("AudioNarrator"):
		narrator_audio = $AudioNarrator
	if not fade_overlay and has_node("UI/FadeOverlay"):
		fade_overlay = $UI/FadeOverlay
	if not act_badge and has_node("%ActBadge"):
		act_badge = %ActBadge
	if not subtitle_label and has_node("%SubtitleLabel"):
		subtitle_label = %SubtitleLabel
	if not skip_prompt and has_node("%SkipPrompt"):
		skip_prompt = %SkipPrompt
	if not finale_card and has_node("%FinaleCard"):
		finale_card = %FinaleCard
	if not engine_light_left and has_node("ShipRig/EngineLightLeft"):
		engine_light_left = $ShipRig/EngineLightLeft
	if not engine_light_right and has_node("ShipRig/EngineLightRight"):
		engine_light_right = $ShipRig/EngineLightRight
	if not engine_plume_left and has_node("ShipRig/EnginePlumeLeft"):
		engine_plume_left = $ShipRig/EnginePlumeLeft
	if not engine_plume_right and has_node("ShipRig/EnginePlumeRight"):
		engine_plume_right = $ShipRig/EnginePlumeRight
	if not afterburner_flare and has_node("ShipRig/AfterburnerFlare"):
		afterburner_flare = $ShipRig/AfterburnerFlare

func setup(interlude_id: String) -> void:
	_ensure_references()
	current_id = interlude_id
	config = INTERLUDES.get(current_id, INTERLUDES["INT_M01_M02"])
	total_duration = config.get("duration", 20.0)
	_apply_skybox(config.get("sky_preset", "dusk_canyon"))
	_setup_actors()
	_setup_ui()

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Determine active interlude from MissionManager
	var mm = null
	if is_inside_tree():
		mm = get_node_or_null("/root/MissionManager")
	if mm and "pending_interlude_id" in mm and not mm.pending_interlude_id.is_empty():
		current_id = mm.pending_interlude_id
	
	setup(current_id)
	
	if skip_prompt:
		skip_prompt.text = "[ SPACE / CONTROLLER (A) / CLICK : SKIP ]"
	
	# Fade in from black
	if fade_overlay and is_inside_tree():
		fade_overlay.color = Color(0, 0, 0, 1)
		var tween = create_tween()
		if tween:
			tween.tween_property(fade_overlay, "color:a", 0.0, 1.0)
	
	# Play Audio Narration
	var a_path = config.get("audio_path", "")
	if ResourceLoader.exists(a_path) and narrator_audio and is_inside_tree() and narrator_audio.is_inside_tree():
		narrator_audio.stream = load(a_path)
		narrator_audio.play()

func _input(event: InputEvent) -> void:
	if is_finishing:
		return
	var is_skip_key = event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER]
	var is_skip_click = event is InputEventMouseButton and event.pressed
	var is_skip_pad = event is InputEventJoypadButton and event.pressed
	if is_skip_key or is_skip_click or is_skip_pad:
		_finish_cutscene()
		if get_viewport():
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if is_finishing:
		return
	
	playback_time += delta
	
	_update_cinematography(playback_time, delta)
	_update_subtitles(playback_time)
	
	if skip_prompt:
		skip_prompt.modulate.a = 0.5 + sin(playback_time * 4.0) * 0.3
	
	if playback_time >= total_duration:
		_finish_cutscene()

func _update_cinematography(t: float, delta: float) -> void:
	if not is_inside_tree() or not ship_rig or not camera:
		return
	match current_id:
		"INT_M01_M02":
			_cine_red_sinks(t, delta)
		"INT_M02_M03":
			_cine_apex_liftoff(t, delta)
		"INT_M03_M04":
			_cine_karman_zenith(t, delta)
		"EPILOGUE_CH1":
			_cine_chapter1_epilogue(t, delta)
		"INT_M04_M05":
			_cine_asteroid_belt(t, delta)
		"INT_M05_M06":
			_cine_iron_hollow(t, delta)
		"INT_M06_M07":
			_cine_carrier_distress(t, delta)
		"INT_M07_M08":
			_cine_celestial_forge(t, delta)
		"EPILOGUE_CH2":
			_cine_chapter2_epilogue(t, delta)

# -----------------------------------------------------------------------------
# 1. Interlude 1: Into the Red Sinks (Dusk descent into canyon rifts)
# -----------------------------------------------------------------------------
func _cine_red_sinks(t: float, delta: float) -> void:
	var progress = clamp(t / total_duration, 0.0, 1.0)
	# Ship dives from high altitude down to 40m into canyon
	var start_pos = Vector3(60, 220, -500)
	var end_pos = Vector3(0, 35, 600)
	ship_rig.global_position = start_pos.lerp(end_pos, progress)
	
	# Bank ship into dynamic turn
	var bank = sin(t * 1.2) * 0.55
	var pitch = -0.25 if t < 8.0 else 0.05
	ship_rig.rotation = Vector3(pitch, 0, bank)
	
	# Camera: Front quarter tracking to low chase
	if t < 7.0:
		var cam_target = ship_rig.global_position + Vector3(25, 12, 35)
		camera.global_position = camera.global_position.lerp(cam_target, delta * 6.0)
		camera.look_at(ship_rig.global_position + Vector3(0, 0, -20), Vector3.UP)
	else:
		var cam_target = ship_rig.global_position + Vector3(-18, 6, 28)
		camera.global_position = camera.global_position.lerp(cam_target, delta * 6.0)
		camera.look_at(ship_rig.global_position + Vector3(0, 0, -30), Vector3.UP)
	
	_pulse_engines(t, 1.0)

# -----------------------------------------------------------------------------
# 2. Interlude 2: The Liftoff Protocol (Dawn flight over Olympus-4 on catapult)
# -----------------------------------------------------------------------------
func _cine_apex_liftoff(t: float, delta: float) -> void:
	var progress = clamp(t / total_duration, 0.0, 1.0)
	
	# Transport sits majestically charging thrusters
	if transport_rig:
		transport_rig.visible = true
		transport_rig.global_position = Vector3(0, 15, 0)
	
	# Vanguard 1 and Wingman Miller fly echelon formation overhead
	var ship_start = Vector3(-25, 45, -350)
	var ship_end = Vector3(-25, 55, 450)
	ship_rig.global_position = ship_start.lerp(ship_end, progress)
	
	if wingman_rig:
		wingman_rig.visible = true
		var wing_start = Vector3(25, 48, -370)
		var wing_end = Vector3(25, 58, 430)
		wingman_rig.global_position = wing_start.lerp(wing_end, progress)
		wingman_rig.rotation = Vector3(0.02, 0, -0.15)
	
	# Camera pans across transport up to the flying echelon
	if t < 8.0:
		camera.global_position = Vector3(40, 28, -60)
		camera.look_at(Vector3(0, 18, 0), Vector3.UP)
	else:
		var cam_target = ship_rig.global_position + Vector3(15, 4, 30)
		camera.global_position = camera.global_position.lerp(cam_target, delta * 5.0)
		camera.look_at(ship_rig.global_position, Vector3.UP)
	
	_pulse_engines(t, 1.2)

# -----------------------------------------------------------------------------
# 3. Interlude 3: The Karman Zenith (Zoom climb into mesosphere black space)
# -----------------------------------------------------------------------------
func _cine_karman_zenith(t: float, delta: float) -> void:
	var progress = clamp(t / total_duration, 0.0, 1.0)
	
	# High-thrust vertical zoom climb
	var start_pos = Vector3(0, 60, -200)
	var end_pos = Vector3(0, 480, 200)
	ship_rig.global_position = start_pos.lerp(end_pos, progress * progress) # Accelerating up
	ship_rig.rotation = Vector3(-0.85, 0, 0) # 50 deg steep climb
	
	# Camera follows from below looking up into starfield
	var cam_offset = Vector3(12, -18, 35)
	camera.global_position = ship_rig.global_position + cam_offset
	camera.look_at(ship_rig.global_position + Vector3(0, 20, 0), Vector3.UP)
	
	_pulse_engines(t, 2.5) # Intense afterburner flare in vacuum

# -----------------------------------------------------------------------------
# 4. Epilogue: Chapter 1 Finale & Chapter 2 Teaser
# -----------------------------------------------------------------------------
func _cine_chapter1_epilogue(t: float, delta: float) -> void:
	# Slow, graceful orbital drift over curved Earth horizon
	var orbit_angle = t * 0.08
	ship_rig.global_position = Vector3(sin(orbit_angle) * 40.0, 180.0, cos(orbit_angle) * 40.0)
	ship_rig.rotation = Vector3(0.05, orbit_angle + PI * 0.5, 0.1)
	
	# Slow cinematic camera orbit
	var cam_angle = orbit_angle + 0.35
	camera.global_position = ship_rig.global_position + Vector3(cos(cam_angle) * 26.0, 6.0, sin(cam_angle) * 26.0)
	camera.look_at(ship_rig.global_position, Vector3.UP)
	
	_pulse_engines(t, 0.4)
	
	# Reveal Chapter 1 Finale Card at t > 12.0
	if t >= 12.0 and finale_card:
		finale_card.visible = true
		var alpha_prog = clamp((t - 12.0) / 2.0, 0.0, 1.0)
		finale_card.modulate.a = alpha_prog

# -------------------------------------------------------------
# 5. Interlude 4: Into the Asteroid Belt
# -------------------------------------------------------------
func _cine_asteroid_belt(t: float, delta: float) -> void:
	var progress = clamp(t / total_duration, 0.0, 1.0)
	var start_pos = Vector3(40, 100, -450)
	var end_pos = Vector3(-20, 120, 450)
	ship_rig.global_position = start_pos.lerp(end_pos, progress)
	ship_rig.rotation = Vector3(0.04, 0.1, sin(t * 0.8) * 0.25)
	
	var cam_target = ship_rig.global_position + Vector3(20, 8, 30)
	camera.global_position = camera.global_position.lerp(cam_target, delta * 4.0)
	camera.look_at(ship_rig.global_position, Vector3.UP)
	_pulse_engines(t, 1.0)

# -------------------------------------------------------------
# 6. Interlude 5: The Iron Hollow (Cavern Infiltration)
# -------------------------------------------------------------
func _cine_iron_hollow(t: float, delta: float) -> void:
	var progress = clamp(t / total_duration, 0.0, 1.0)
	var start_pos = Vector3(0, 140, -400)
	var end_pos = Vector3(0, 30, 400)
	ship_rig.global_position = start_pos.lerp(end_pos, progress)
	ship_rig.rotation = Vector3(-0.15, 0, sin(t * 1.5) * 0.45)
	
	var cam_target = ship_rig.global_position + Vector3(0, 12, 28)
	camera.global_position = camera.global_position.lerp(cam_target, delta * 5.0)
	camera.look_at(ship_rig.global_position + Vector3(0, 0, -25), Vector3.UP)
	_pulse_engines(t, 1.3)

# -------------------------------------------------------------
# 7. Interlude 6: Distress in the Dark (Fleet Alert)
# -------------------------------------------------------------
func _cine_carrier_distress(t: float, delta: float) -> void:
	var progress = clamp(t / total_duration, 0.0, 1.0)
	var start_pos = Vector3(-30, 50, -350)
	var end_pos = Vector3(-30, 70, 450)
	ship_rig.global_position = start_pos.lerp(end_pos, progress)
	
	if wingman_rig:
		wingman_rig.visible = true
		wingman_rig.global_position = Vector3(30, 55, -350).lerp(Vector3(30, 75, 450), progress)
		wingman_rig.rotation = Vector3(0, 0, -0.2)
		
	var cam_target = ship_rig.global_position + Vector3(18, 6, 32)
	camera.global_position = camera.global_position.lerp(cam_target, delta * 5.0)
	camera.look_at(ship_rig.global_position, Vector3.UP)
	_pulse_engines(t, 1.8)

# -------------------------------------------------------------
# 8. Interlude 7: The Celestial Forge
# -------------------------------------------------------------
func _cine_celestial_forge(t: float, delta: float) -> void:
	var progress = clamp(t / total_duration, 0.0, 1.0)
	var start_pos = Vector3(0, 80, -500)
	var end_pos = Vector3(0, 90, 400)
	ship_rig.global_position = start_pos.lerp(end_pos, progress)
	ship_rig.rotation = Vector3(0.05, 0, 0)
	
	var cam_target = ship_rig.global_position + Vector3(-22, 10, 36)
	camera.global_position = camera.global_position.lerp(cam_target, delta * 4.0)
	camera.look_at(ship_rig.global_position + Vector3(0, 0, -50), Vector3.UP)
	_pulse_engines(t, 2.2)

# -------------------------------------------------------------
# 9. Epilogue Chapter 2: Beyond the Kuiper Veil
# -------------------------------------------------------------
func _cine_chapter2_epilogue(t: float, delta: float) -> void:
	var orbit_angle = t * 0.09
	ship_rig.global_position = Vector3(sin(orbit_angle) * 50.0, 120.0, cos(orbit_angle) * 50.0)
	ship_rig.rotation = Vector3(0.05, orbit_angle + PI * 0.5, 0.1)
	
	var cam_angle = orbit_angle + 0.4
	camera.global_position = ship_rig.global_position + Vector3(cos(cam_angle) * 30.0, 8.0, sin(cam_angle) * 30.0)
	camera.look_at(ship_rig.global_position, Vector3.UP)
	_pulse_engines(t, 0.5)
	
	if t >= 12.0 and finale_card:
		finale_card.visible = true
		var alpha_prog = clamp((t - 12.0) / 2.0, 0.0, 1.0)
		finale_card.modulate.a = alpha_prog

func _pulse_engines(t: float, multiplier: float) -> void:
	var pulse = (4.0 + sin(t * 24.0) * 1.2) * multiplier
	if engine_light_left: engine_light_left.light_energy = pulse
	if engine_light_right: engine_light_right.light_energy = pulse
	if engine_plume_left: engine_plume_left.scale = Vector3(1.0, 1.0, 1.0 + multiplier * 0.6)
	if engine_plume_right: engine_plume_right.scale = Vector3(1.0, 1.0, 1.0 + multiplier * 0.6)
	if afterburner_flare:
		afterburner_flare.visible = multiplier > 1.4
		afterburner_flare.light_energy = pulse * 1.5

func _update_subtitles(t: float) -> void:
	var cues = config.get("cues", [])
	var active_text = ""
	for c in cues:
		if t >= c["start"] and t < c["end"]:
			active_text = c["text"]
			break
	
	if subtitle_label:
		subtitle_label.text = active_text

func _setup_ui() -> void:
	if act_badge:
		act_badge.text = "%s  |  %s" % [config.get("title", ""), config.get("subtitle", "")]
	if finale_card:
		finale_card.visible = false
		if current_id == "EPILOGUE_CH2":
			if finale_title:
				finale_title.text = "PROJECT VANGUARD // CHAPTER 2 COMPLETE"
			if finale_subtitle:
				finale_subtitle.text = "CHAPTER 3: BEYOND THE KUIPER VEIL // COMING SOON"
		elif current_id == "EPILOGUE_CH1":
			if finale_title:
				finale_title.text = "PROJECT VANGUARD // CHAPTER 1 COMPLETE"
			if finale_subtitle:
				finale_subtitle.text = "CHAPTER 2: BELT INVASION // COMING SOON"

func _setup_actors() -> void:
	if wingman_rig:
		wingman_rig.visible = (current_id in ["INT_M02_M03", "INT_M06_M07"])
	if transport_rig:
		transport_rig.visible = (current_id == "INT_M02_M03")

func _apply_skybox(preset: String) -> void:
	if not world_env or not world_env.environment:
		return
	var env = world_env.environment
	var sky_mat = ProceduralSkyMaterial.new()
	match preset:
		"dusk_canyon":
			sky_mat.sky_top_color = Color(0.18, 0.12, 0.28)
			sky_mat.sky_horizon_color = Color(0.92, 0.46, 0.16)
			sky_mat.ground_bottom_color = Color(0.18, 0.09, 0.08)
			sky_mat.ground_horizon_color = Color(0.52, 0.24, 0.14)
			if sun_light:
				sun_light.light_color = Color(1.0, 0.72, 0.48)
				sun_light.light_energy = 1.3
				sun_light.rotation_degrees = Vector3(-18, -45, 0)
		"dawn_clear":
			sky_mat.sky_top_color = Color(0.10, 0.16, 0.38)
			sky_mat.sky_horizon_color = Color(0.96, 0.78, 0.45)
			sky_mat.ground_bottom_color = Color(0.12, 0.15, 0.18)
			sky_mat.ground_horizon_color = Color(0.38, 0.44, 0.48)
			if sun_light:
				sun_light.light_color = Color(1.0, 0.92, 0.82)
				sun_light.light_energy = 1.2
				sun_light.rotation_degrees = Vector3(-25, 30, 0)
		"stratosphere_space":
			sky_mat.sky_top_color = Color(0.01, 0.01, 0.03)
			sky_mat.sky_horizon_color = Color(0.06, 0.48, 0.88)
			sky_mat.ground_bottom_color = Color(0.02, 0.04, 0.08)
			sky_mat.ground_horizon_color = Color(0.04, 0.22, 0.45)
			if sun_light:
				sun_light.light_color = Color(1.0, 1.0, 1.0)
				sun_light.light_energy = 1.6
				sun_light.rotation_degrees = Vector3(-45, 0, 0)
		"deep_space_belt":
			sky_mat.sky_top_color = Color(0.01, 0.01, 0.02)
			sky_mat.sky_horizon_color = Color(0.12, 0.08, 0.04)
			sky_mat.ground_bottom_color = Color(0.005, 0.005, 0.01)
			sky_mat.ground_horizon_color = Color(0.08, 0.05, 0.03)
			if sun_light:
				sun_light.light_color = Color(1.0, 0.95, 0.85)
				sun_light.light_energy = 1.8
				sun_light.rotation_degrees = Vector3(-35, 120, 0)
		"asteroid_cavern":
			sky_mat.sky_top_color = Color(0.05, 0.03, 0.02)
			sky_mat.sky_horizon_color = Color(0.65, 0.22, 0.08)
			sky_mat.ground_bottom_color = Color(0.08, 0.02, 0.01)
			sky_mat.ground_horizon_color = Color(0.50, 0.15, 0.05)
			if sun_light:
				sun_light.light_color = Color(1.0, 0.45, 0.15)
				sun_light.light_energy = 0.9
				sun_light.rotation_degrees = Vector3(-80, 0, 0)
		"carrier_orbit":
			sky_mat.sky_top_color = Color(0.01, 0.02, 0.05)
			sky_mat.sky_horizon_color = Color(0.08, 0.25, 0.45)
			sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.03)
			sky_mat.ground_horizon_color = Color(0.05, 0.15, 0.30)
			if sun_light:
				sun_light.light_color = Color(0.9, 0.95, 1.0)
				sun_light.light_energy = 1.5
				sun_light.rotation_degrees = Vector3(-45, -30, 0)
		"crucible_forge":
			sky_mat.sky_top_color = Color(0.02, 0.01, 0.02)
			sky_mat.sky_horizon_color = Color(0.70, 0.10, 0.15)
			sky_mat.ground_bottom_color = Color(0.03, 0.01, 0.01)
			sky_mat.ground_horizon_color = Color(0.40, 0.05, 0.08)
			if sun_light:
				sun_light.light_color = Color(1.0, 0.3, 0.35)
				sun_light.light_energy = 1.6
				sun_light.rotation_degrees = Vector3(-55, 45, 0)
	
	var sky = Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY

func _finish_cutscene() -> void:
	if is_finishing:
		return
	is_finishing = true
	
	if fade_overlay:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(fade_overlay, "color:a", 1.0, 0.5)
		if narrator_audio:
			tween.tween_property(narrator_audio, "volume_db", -40.0, 0.5)
		tween.finished.connect(_transition_to_next)
	else:
		_transition_to_next()

func _transition_to_next() -> void:
	var next_m = config.get("next_mission", "")
	var mm = get_node_or_null("/root/MissionManager")
	
	if config.get("is_finale", false) or next_m.is_empty():
		# Return to Hangar Menu after Chapter 1 Finale
		if mm:
			mm.pending_interlude_id = ""
		get_tree().change_scene_to_file("res://home_menu.tscn")
	else:
		# Launch next sortie
		if mm:
			mm.current_mission_id = next_m
			mm.pending_interlude_id = ""
		get_tree().change_scene_to_file("res://main.tscn")
