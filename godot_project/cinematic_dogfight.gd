extends Node3D

## Cinematic Dogfight Director: Broadcast-Quality 1080p60 Combat Choreography.
## Features:
## - 8 distinct dynamic director camera shots with cinematic depth, banking, and shake.
## - Hero Jet (Vanguard 1 V-Hull) vs Crimson Viper Supreme ace.
## - Afterburner boost flares, wingtip aerodynamic vapor vortex trails.
## - Hostile red tracer fire & hero 20mm rotary autocannon streams.
## - Guided Strike Missile launch sequence with rocket motor smoke trail.
## - Massive multi-stage catastrophic fireball explosion with debris & shockwave.
## - Real-time synchronized SFX, cockpit radio comms, and holographic HUD.

var cam: Camera3D
var hero_jet: Node3D
var enemy_jet: Node3D
var hero_plume_cruise_l: MeshInstance3D
var hero_plume_cruise_r: MeshInstance3D
var hero_plume_boost_l: MeshInstance3D
var hero_plume_boost_r: MeshInstance3D
var hero_vapor_l: CPUParticles3D
var hero_vapor_r: CPUParticles3D
var hero_missile_l: Node3D
var hero_missile_r: Node3D

var enemy_damage_fire: CPUParticles3D
var enemy_damage_smoke: CPUParticles3D

var missile_in_flight: Node3D
var missile_plume: CPUParticles3D
var missile_smoke: CPUParticles3D

var hero_tracers: CPUParticles3D
var enemy_tracers: CPUParticles3D

var explosion_anchor: Node3D
var explosion_light: OmniLight3D
var explosion_fire: CPUParticles3D
var explosion_debris: CPUParticles3D
var explosion_smoke: CPUParticles3D

var speed_label: Label
var alt_label: Label
var gforce_label: Label
var banner_label: Label
var target_diamond: Label
var subtitles_label: Label
var fade_overlay: ColorRect

var audio_engine_hero: AudioStreamPlayer
var audio_afterburner: AudioStreamPlayer
var audio_flyby: AudioStreamPlayer
var audio_cannon: AudioStreamPlayer
var audio_lock: AudioStreamPlayer
var audio_missile: AudioStreamPlayer
var audio_explosion: AudioStreamPlayer
var audio_high_g: AudioStreamPlayer
var audio_bullet_whiz: AudioStreamPlayer
var audio_radio: AudioStreamPlayer
var audio_music: AudioStreamPlayer

var current_time: float = 0.0
const TOTAL_DURATION: float = 26.0

# Dynamic camera state
var cam_target_pos: Vector3 = Vector3.ZERO
var cam_look_target: Vector3 = Vector3.ZERO
var cam_target_fov: float = 65.0
var cam_roll: float = 0.0
var trauma: float = 0.0

var missile_launched: bool = false
var explosion_triggered: bool = false
var hero_boosting: bool = false

func _ensure_nodes() -> void:
	if hero_jet != null and enemy_jet != null and cam != null:
		return
	
	cam = get_node_or_null("CameraRig/Camera3D")
	hero_jet = get_node_or_null("HeroJet")
	enemy_jet = get_node_or_null("EnemyJet")
	
	if hero_jet:
		hero_plume_cruise_l = hero_jet.get_node_or_null("PlumeCruisingL")
		hero_plume_cruise_r = hero_jet.get_node_or_null("PlumeCruisingR")
		hero_plume_boost_l = hero_jet.get_node_or_null("PlumeBoostL")
		hero_plume_boost_r = hero_jet.get_node_or_null("PlumeBoostR")
		hero_vapor_l = hero_jet.get_node_or_null("WingVaporL")
		hero_vapor_r = hero_jet.get_node_or_null("WingVaporR")
		hero_missile_l = hero_jet.get_node_or_null("MountedMissileL")
		hero_missile_r = hero_jet.get_node_or_null("MountedMissileR")
	
	if enemy_jet:
		enemy_damage_fire = enemy_jet.get_node_or_null("DamageFire")
		enemy_damage_smoke = enemy_jet.get_node_or_null("DamageSmoke")
	
	missile_in_flight = get_node_or_null("MissileInFlight")
	if missile_in_flight:
		missile_plume = missile_in_flight.get_node_or_null("MissilePlume")
		missile_smoke = missile_in_flight.get_node_or_null("MissileSmoke")
		
	hero_tracers = get_node_or_null("HeroTracers")
	enemy_tracers = get_node_or_null("EnemyTracers")
	
	explosion_anchor = get_node_or_null("ExplosionAnchor")
	if explosion_anchor:
		explosion_light = explosion_anchor.get_node_or_null("ExplosionLight")
		explosion_fire = explosion_anchor.get_node_or_null("ExplosionFire")
		explosion_debris = explosion_anchor.get_node_or_null("ExplosionDebris")
		explosion_smoke = explosion_anchor.get_node_or_null("ExplosionSmoke")
		
	speed_label = get_node_or_null("%SpeedLabel")
	if not speed_label:
		speed_label = get_node_or_null("HUDLayer/TacticalOverlay/TelemetryPanel/SpeedLabel")
	alt_label = get_node_or_null("%AltLabel")
	if not alt_label:
		alt_label = get_node_or_null("HUDLayer/TacticalOverlay/TelemetryPanel/AltLabel")
	gforce_label = get_node_or_null("%GForceLabel")
	if not gforce_label:
		gforce_label = get_node_or_null("HUDLayer/TacticalOverlay/TelemetryPanel/GForceLabel")
	banner_label = get_node_or_null("%BannerLabel")
	if not banner_label:
		banner_label = get_node_or_null("HUDLayer/TacticalOverlay/BannerPanel/BannerLabel")
	target_diamond = get_node_or_null("%TargetDiamond")
	if not target_diamond:
		target_diamond = get_node_or_null("HUDLayer/TacticalOverlay/TargetReticle/TargetDiamond")
	subtitles_label = get_node_or_null("%SubtitlesLabel")
	if not subtitles_label:
		subtitles_label = get_node_or_null("HUDLayer/TacticalOverlay/SubtitlesLabel")
	fade_overlay = get_node_or_null("%FadeOverlay")
	if not fade_overlay:
		fade_overlay = get_node_or_null("HUDLayer/FadeOverlay")

func _ready() -> void:
	_ensure_nodes()
	
	var vp = get_viewport()
	if vp:
		vp.size = Vector2i(1920, 1080)
	
	_setup_audio_players()
	_apply_crimson_livery_to_enemy()
	_spawn_background_terrain_props()
	
	if fade_overlay:
		fade_overlay.color = Color(0, 0, 0, 1)
		var tw = create_tween()
		if tw:
			tw.tween_property(fade_overlay, "color:a", 0.0, 1.2)

func _setup_audio_players() -> void:
	audio_engine_hero = _create_audio_player("AudioEngineHero", "res://audio/sfx/sfx_engine_exhaust_loop.wav", -16.0, true)
	audio_afterburner = _create_audio_player("AudioAfterburner", "res://audio/sfx/sfx_engine_boost_ignite.wav", -6.0)
	audio_flyby = _create_audio_player("AudioFlyby", "res://audio/sfx/sfx_flyby_enemy_doppler.wav", -4.0)
	audio_cannon = _create_audio_player("AudioCannon", "res://audio/sfx/sfx_autocannon_brr_loop.wav", -5.0)
	audio_lock = _create_audio_player("AudioLock", "res://audio/sfx/sfx_hud_target_locked.wav", -7.0)
	audio_missile = _create_audio_player("AudioMissile", "res://audio/sfx/sfx_weapon_missile_launch.wav", -4.0)
	audio_explosion = _create_audio_player("AudioExplosion", "res://audio/sfx/sfx_capital_ship_core_explosion.wav", 2.0)
	audio_high_g = _create_audio_player("AudioHighG", "res://audio/sfx/sfx_flight_high_g_whoosh.wav", -9.0)
	audio_bullet_whiz = _create_audio_player("AudioBulletWhiz", "res://audio/sfx/sfx_near_miss_bullet_whiz.wav", -5.0)
	audio_radio = _create_audio_player("AudioRadio", "", -2.0)
	audio_music = _create_audio_player("AudioMusic", "res://audio/music/menu_soundscape.mp3", -12.0, true)

	if audio_engine_hero: audio_engine_hero.play()
	if audio_music: audio_music.play()

func _create_audio_player(p_name: String, stream_path: String, vol_db: float, loop: bool = false) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.name = p_name
	player.bus = "SFX" if p_name != "AudioMusic" else "Music"
	player.volume_db = vol_db
	if not stream_path.is_empty() and ResourceLoader.exists(stream_path):
		var s = load(stream_path)
		player.stream = s
	if loop:
		player.finished.connect(func(): if is_inside_tree() and player: player.play())
	add_child(player)
	return player

func _play_radio(voice_path: String, subtitle_text: String) -> void:
	if subtitles_label:
		subtitles_label.text = subtitle_text
	if audio_radio and ResourceLoader.exists(voice_path):
		audio_radio.stream = load(voice_path)
		audio_radio.play()

func _apply_crimson_livery_to_enemy() -> void:
	if not enemy_jet:
		return
	var crimson_mat = StandardMaterial3D.new()
	crimson_mat.albedo_color = Color(0.78, 0.12, 0.14, 1.0)
	crimson_mat.metallic = 0.90
	crimson_mat.roughness = 0.28
	crimson_mat.emission_enabled = true
	crimson_mat.emission = Color(0.95, 0.18, 0.08)
	crimson_mat.emission_energy_multiplier = 0.8
	
	for child in enemy_jet.find_children("*", "MeshInstance3D", true, false):
		var m = child as MeshInstance3D
		if m and m.mesh:
			m.material_override = crimson_mat

func _spawn_background_terrain_props() -> void:
	# Add atmospheric distant mountains to ground horizon
	var terrain_node = get_node_or_null("TerrainRidges")
	if not terrain_node: return
	
	var mountain_mat = StandardMaterial3D.new()
	mountain_mat.albedo_color = Color(0.18, 0.14, 0.18, 1.0)
	mountain_mat.roughness = 0.9
	
	for i in range(16):
		var mesh_inst = MeshInstance3D.new()
		var prism = PrismMesh.new()
		prism.size = Vector3(randf_range(600, 1400), randf_range(300, 750), randf_range(600, 1200))
		prism.material = mountain_mat
		mesh_inst.mesh = prism
		mesh_inst.position = Vector3(randf_range(-4000, 4000), randf_range(-1200, -600), randf_range(-5000, 2000))
		terrain_node.add_child(mesh_inst)

func _process(delta: float) -> void:
	_ensure_nodes()
	if not hero_jet or not enemy_jet:
		return

	current_time += delta
	
	# Execute dynamic multi-shot choreography
	if current_time < 3.5:
		_shot_1_sunset_patrol_ambush(current_time, delta)
	elif current_time < 6.8:
		_shot_2_wingtip_high_g_break(current_time, delta)
	elif current_time < 10.5:
		_shot_3_rolling_scissors_reversal(current_time, delta)
	elif current_time < 14.5:
		_shot_4_nose_gun_camera_shred(current_time, delta)
	elif current_time < 18.0:
		_shot_5_low_flyby_missile_lock(current_time, delta)
	elif current_time < 21.5:
		_shot_6_underwing_pylon_launch(current_time, delta)
	elif current_time < 24.5:
		_shot_7_terminal_impact_explosion(current_time, delta)
	else:
		_shot_8_victory_flythrough_zoom(current_time, delta)
		
	_apply_camera_motion(delta)
	
	if current_time >= TOTAL_DURATION:
		get_tree().quit(0)

# =============================================================================
# DIRECTOR SHOT 1 (0.0s - 3.5s): Sunset Cruise -> Sudden Ambush
# =============================================================================
func _shot_1_sunset_patrol_ambush(t: float, delta: float) -> void:
	var p = clamp(t / 3.5, 0.0, 1.0)
	
	# Hero cruises forward
	var hero_start = Vector3(0, 480, 0)
	var hero_end = Vector3(0, 480, -280)
	hero_jet.global_position = hero_start.lerp(hero_end, p)
	hero_jet.rotation = Vector3(0, 0, sin(t * 1.5) * 0.05)
	
	# Enemy dives from 6 o'clock high
	var enemy_start = Vector3(60, 680, 180)
	var enemy_end = Vector3(15, 510, -60)
	enemy_jet.global_position = enemy_start.lerp(enemy_end, p * p)
	enemy_jet.rotation = Vector3(deg_to_rad(-22), deg_to_rad(-165), deg_to_rad(25))
	
	# Camera: Wide tracking sweep from right side
	cam_target_pos = hero_jet.global_position + Vector3(22, 6, 28)
	cam_look_target = hero_jet.global_position + Vector3(0, 1, -10)
	cam_target_fov = 60.0
	cam_roll = -0.05
	
	# Telemetry
	if speed_label: speed_label.text = "SPD: 420 M/S  [CRUISE]"
	if alt_label: alt_label.text = "ALT: 4,800 M  [ANGELS 16]"
	if gforce_label: gforce_label.text = "G-LOAD: +1.0 G"
	if banner_label: banner_label.text = "// COMBAT AIR PATROL // DUSK CORRIDOR //"
	if target_diamond: target_diamond.hide()
	
	if t > 1.2 and subtitles_label and subtitles_label.text == "":
		_play_radio("res://audio/comms/m01_aegis_contact.mp3", "AEGIS 7: Contact! Bandit closing fast on your six! Break break!")

# =============================================================================
# DIRECTOR SHOT 2 (3.5s - 6.8s): Wingtip Action Cam & High-G Break
# =============================================================================
func _shot_2_wingtip_high_g_break(t: float, delta: float) -> void:
	var sub_t = t - 3.5
	var p = clamp(sub_t / 3.3, 0.0, 1.0)
	
	# Enemy opens fire with red tracers
	if enemy_tracers:
		if sub_t < 1.4:
			enemy_tracers.emitting = true
			enemy_tracers.global_position = enemy_jet.global_position + Vector3(0, 0, -2)
			enemy_tracers.direction = (hero_jet.global_position - enemy_jet.global_position).normalized()
			if audio_bullet_whiz and not audio_bullet_whiz.playing:
				audio_bullet_whiz.play()
		else:
			enemy_tracers.emitting = false
	
	# Hero ignites afterburners, rolls hard, and pulls vertical break
	if not hero_boosting:
		hero_boosting = true
		if hero_plume_cruise_l: hero_plume_cruise_l.hide()
		if hero_plume_cruise_r: hero_plume_cruise_r.hide()
		if hero_plume_boost_l: hero_plume_boost_l.show()
		if hero_plume_boost_r: hero_plume_boost_r.show()
		if hero_vapor_l: hero_vapor_l.emitting = true
		if hero_vapor_r: hero_vapor_r.emitting = true
		if audio_afterburner: audio_afterburner.play()
		if audio_high_g: audio_high_g.play()
	
	# 90 deg roll + steep pitch up
	hero_jet.position += Vector3(-12.0 * delta * p, 45.0 * delta * p * p, -95.0 * delta)
	hero_jet.rotation_degrees = Vector3(
		lerp(0.0, 48.0, p),
		lerp(0.0, -18.0, p),
		lerp(0.0, -85.0, p)
	)
	
	# Enemy overshoots forward
	enemy_jet.position += Vector3(0, -15.0 * delta, -160.0 * delta)
	
	# Camera mounted on Hero's port wingtip looking across airframe
	var wing_offset = hero_jet.global_transform.basis * Vector3(-5.2, 0.4, 0.6)
	cam_target_pos = hero_jet.global_position + wing_offset
	cam_look_target = hero_jet.global_position + (hero_jet.global_transform.basis * Vector3(1.2, 0.3, -4.0))
	cam_target_fov = 72.0
	cam_roll = deg_to_rad(-15)
	trauma = 0.55 # Intense aerodynamic buffeting
	
	if speed_label: speed_label.text = "SPD: 610 M/S  [AFTERBURNER]"
	if alt_label: alt_label.text = "ALT: 5,140 M  [ZOOM CLIMB]"
	if gforce_label:
		gforce_label.text = "G-LOAD: +6.8 G  [HIGH-G BREAK]"
		gforce_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	if banner_label:
		banner_label.text = "// CAUTION: HIGH-G EVASIVE BREAK // +6.8G //"

	if subtitles_label and sub_t > 0.4 and sub_t < 0.6:
		subtitles_label.text = "APEX CMD: Full nitro afterburner! Slice into his blindspot!"

# =============================================================================
# DIRECTOR SHOT 3 (6.8s - 10.5s): Rolling Scissors & Aerodynamic Reversal
# =============================================================================
func _shot_3_rolling_scissors_reversal(t: float, delta: float) -> void:
	var sub_t = t - 6.8
	var p = clamp(sub_t / 3.7, 0.0, 1.0)
	
	if hero_vapor_l: hero_vapor_l.emitting = false
	if hero_vapor_r: hero_vapor_r.emitting = false
	
	# Hero reverses roll and slices behind the overshooting Viper
	hero_jet.position += Vector3(28.0 * delta * (1.0 - p), 8.0 * delta, -85.0 * delta)
	hero_jet.rotation_degrees = Vector3(
		lerp(48.0, 6.0, p),
		lerp(-18.0, 8.0, p),
		lerp(-85.0, 22.0, p)
	)
	
	# Viper struggling to turn back, crossing left to right
	enemy_jet.position += Vector3(32.0 * delta * p, 4.0 * delta, -80.0 * delta)
	enemy_jet.rotation_degrees = Vector3(deg_to_rad(-8), deg_to_rad(35), deg_to_rad(-45))
	
	# Audio flyby whoosh on overshoot
	if audio_flyby and sub_t > 0.1 and sub_t < 0.25 and not audio_flyby.playing:
		audio_flyby.play()
	
	# Camera: Dynamic over-the-shoulder 3rd person tracking the scissors
	cam_target_pos = hero_jet.global_position + (hero_jet.global_transform.basis * Vector3(-3.5, 3.2, 14.0))
	cam_look_target = enemy_jet.global_position
	cam_target_fov = 58.0
	cam_roll = deg_to_rad(6.0)
	trauma = 0.15
	
	if speed_label: speed_label.text = "SPD: 520 M/S  [ENERGY REVERSAL]"
	if alt_label: alt_label.text = "ALT: 5,280 M"
	if gforce_label:
		gforce_label.text = "G-LOAD: +3.2 G"
		gforce_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	if banner_label:
		banner_label.text = "// SCISSORS REVERSAL // ENEMY OVERSHOOT CONFIRMED //"
	if target_diamond:
		target_diamond.show()
		target_diamond.text = "[ TRACKING ]"
		target_diamond.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0))
		
	if subtitles_label and sub_t > 0.3 and sub_t < 0.5:
		subtitles_label.text = "VANGUARD 1: Overshot! Reversing into his six o'clock..."

# =============================================================================
# DIRECTOR SHOT 4 (10.5s - 14.5s): Nose Gun Camera & 20mm Autocannon Shred
# =============================================================================
func _shot_4_nose_gun_camera_shred(t: float, delta: float) -> void:
	var sub_t = t - 10.5
	var p = clamp(sub_t / 4.0, 0.0, 1.0)
	
	# Both fly in tight formation with Hero on enemy's tail
	hero_jet.position += Vector3(12.0 * delta, 0.0, -92.0 * delta)
	hero_jet.rotation_degrees = Vector3(2.0, 5.0, 8.0)
	
	enemy_jet.position = hero_jet.position + Vector3(
		sin(t * 4.0) * 1.8 + 1.5,
		cos(t * 3.5) * 1.2 - 0.4,
		-42.0
	)
	enemy_jet.rotation_degrees = Vector3(sin(t * 3.0) * 8.0, 12.0, cos(t * 4.0) * 18.0)
	
	# Autocannon burst active
	if hero_tracers:
		hero_tracers.emitting = true
		hero_tracers.global_position = hero_jet.global_position + (hero_jet.global_transform.basis * Vector3(0, 0.1, -4.5))
		hero_tracers.direction = (enemy_jet.global_position - hero_tracers.global_position).normalized()
	
	if audio_cannon and not audio_cannon.playing:
		audio_cannon.play()
		
	# Enemy takes damage: fire and smoke erupt from starboard engine
	if sub_t > 0.8:
		if enemy_damage_fire: enemy_damage_fire.emitting = true
		if enemy_damage_smoke: enemy_damage_smoke.emitting = true
	
	# Camera: Aligned with hero's nose looking directly along gun bore
	cam_target_pos = hero_jet.global_position + (hero_jet.global_transform.basis * Vector3(0, 0.85, -1.8))
	cam_look_target = enemy_jet.global_position
	cam_target_fov = 48.0 # Narrow telephoto gun camera
	cam_roll = 0.0
	trauma = 0.28 # Autocannon recoil vibration
	
	if speed_label: speed_label.text = "SPD: 540 M/S  [AUTOCANNON ACTIVE]"
	if alt_label: alt_label.text = "ALT: 5,310 M"
	if gforce_label: gforce_label.text = "G-LOAD: +1.8 G"
	if banner_label:
		banner_label.text = "// ROTARY AUTOCANNON FIRING // DIRECT KINETIC HITS //"
	if target_diamond:
		target_diamond.text = "[ LEAD HIT ★★★ ]"
		target_diamond.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		
	if subtitles_label and sub_t > 0.2 and sub_t < 0.4:
		subtitles_label.text = "AEGIS 7: Gun solution locked! Rotary cannon shredding starboard turbine!"

# =============================================================================
# DIRECTOR SHOT 5 (14.5s - 18.0s): Low Dynamic Flyby & Seeker Lock
# =============================================================================
func _shot_5_low_flyby_missile_lock(t: float, delta: float) -> void:
	var sub_t = t - 14.5
	var p = clamp(sub_t / 3.5, 0.0, 1.0)
	
	if audio_cannon and audio_cannon.playing:
		audio_cannon.stop()
	if hero_tracers:
		hero_tracers.emitting = false
	
	# Enemy damaged and banking hard into the sun
	enemy_jet.position += Vector3(-18.0 * delta, 6.0 * delta, -98.0 * delta)
	enemy_jet.rotation_degrees = Vector3(-6.0, -18.0, 48.0)
	
	# Hero pursuing aggressively
	hero_jet.position += Vector3(-16.0 * delta, 5.0 * delta, -96.0 * delta)
	hero_jet.rotation_degrees = Vector3(-4.0, -15.0, 42.0)
	
	# Camera: Low-angle dramatic cinematic flyby looking up into sun glare
	var cam_base = hero_jet.global_position + Vector3(35, -12, -18)
	cam_target_pos = cam_base + Vector3(-8.0 * sub_t, 2.0 * sub_t, 5.0 * sub_t)
	cam_look_target = hero_jet.global_position + Vector3(0, 2, -15)
	cam_target_fov = 52.0
	cam_roll = deg_to_rad(-18.0)
	trauma = 0.08
	
	if audio_lock and not audio_lock.playing and sub_t < 1.0:
		audio_lock.play()
		
	if speed_label: speed_label.text = "SPD: 575 M/S  [MISSILE SEEKER ACTIVE]"
	if alt_label: alt_label.text = "ALT: 5,420 M"
	if gforce_label: gforce_label.text = "G-LOAD: +3.8 G"
	if banner_label:
		banner_label.text = "// FOX TWO SEEKER LOCKED // MISSILE CLEARED FOR LAUNCH //"
	if target_diamond:
		target_diamond.text = ">>> FOX TWO READY <<<"
		target_diamond.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
		
	if subtitles_label and sub_t > 0.2 and sub_t < 0.4:
		_play_radio("res://audio/comms/m01_aegis_lock_confirmed.mp3", "AEGIS 7: Tone solid! Lock confirmed! Weapons free, Vanguard 1!")

# =============================================================================
# DIRECTOR SHOT 6 (18.0s - 21.5s): Under-Wing Hardpoint Cam & Fox Two Launch
# =============================================================================
func _shot_6_underwing_pylon_launch(t: float, delta: float) -> void:
	var sub_t = t - 18.0
	var p = clamp(sub_t / 3.5, 0.0, 1.0)
	
	# Launch missile from starboard rack at sub_t = 0.4
	if sub_t >= 0.4 and not missile_launched:
		missile_launched = true
		if hero_missile_r: hero_missile_r.hide() # Detach from pylon
		if missile_in_flight:
			missile_in_flight.show()
			missile_in_flight.global_position = hero_jet.global_position + (hero_jet.global_transform.basis * Vector3(2.4, -0.4, 0.3))
			missile_in_flight.global_rotation = hero_jet.global_rotation
		if missile_plume: missile_plume.emitting = true
		if missile_smoke: missile_smoke.emitting = true
		if audio_missile: audio_missile.play()
	
	# Propagate live missile toward enemy engine
	if missile_launched and missile_in_flight:
		var target_loc = enemy_jet.global_position + Vector3(0, 0, 1.2)
		var dir = (target_loc - missile_in_flight.global_position).normalized()
		missile_in_flight.global_position += dir * (180.0 * delta * (1.0 + (sub_t - 0.4) * 2.2))
		if not missile_in_flight.global_position.is_equal_approx(target_loc):
			missile_in_flight.look_at(target_loc, Vector3.UP)
	
	# Hero and Enemy continue forward
	hero_jet.position += Vector3(0, 0, -90.0 * delta)
	enemy_jet.position += Vector3(0, 0, -90.0 * delta)
	
	# Camera: Under-wing pylon perspective
	var pylon_cam_offset = hero_jet.global_transform.basis * Vector3(3.2, -0.6, 2.8)
	cam_target_pos = hero_jet.global_position + pylon_cam_offset
	cam_look_target = hero_jet.global_position + (hero_jet.global_transform.basis * Vector3(2.0, -0.2, -18.0))
	cam_target_fov = 68.0
	cam_roll = deg_to_rad(8.0)
	trauma = 0.22 if sub_t > 0.4 and sub_t < 0.8 else 0.05
	
	if speed_label: speed_label.text = "SPD: 590 M/S"
	if alt_label: alt_label.text = "ALT: 5,490 M"
	if gforce_label: gforce_label.text = "G-LOAD: +1.5 G"
	if banner_label:
		banner_label.text = "// FOX TWO AWAY // MISSILE TRACKING HIGH-ASPECT //"
	if target_diamond:
		target_diamond.text = "[ MISSILE INTERCEPT ]"
		target_diamond.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))
		
	if subtitles_label and sub_t > 0.5 and sub_t < 0.7:
		subtitles_label.text = "VANGUARD 1: Fox Two away! Missile tracking true!"

# =============================================================================
# DIRECTOR SHOT 7 (21.5s - 24.5s): Terminal Impact & Catastrophic Explosion!
# =============================================================================
func _shot_7_terminal_impact_explosion(t: float, delta: float) -> void:
	var sub_t = t - 21.5
	
	# Impact occurs at sub_t = 0.3s
	if sub_t >= 0.3 and not explosion_triggered:
		explosion_triggered = true
		if missile_in_flight: missile_in_flight.hide()
		if enemy_jet: enemy_jet.hide() # Vaporize target
		if explosion_anchor:
			explosion_anchor.global_position = enemy_jet.global_position
		if explosion_fire: explosion_fire.emitting = true
		if explosion_debris: explosion_debris.emitting = true
		if explosion_smoke: explosion_smoke.emitting = true
		if explosion_light: explosion_light.light_energy = 38.0
		if audio_explosion: audio_explosion.play()
		trauma = 1.0 # Maximum explosion shockwave trauma
	
	if explosion_triggered and explosion_light:
		explosion_light.light_energy = max(0.0, explosion_light.light_energy - delta * 45.0)
	
	# Hero continues screaming forward toward the fireball
	hero_jet.position += Vector3(0, 0, -110.0 * delta)
	
	# Camera: Long-lens cinematic telephoto tracking the impact
	var target_anchor_pos = explosion_anchor.global_position if explosion_anchor else enemy_jet.global_position
	cam_target_pos = target_anchor_pos + Vector3(28, 8, 55)
	cam_look_target = target_anchor_pos
	cam_target_fov = 42.0 # Cinematic telephoto compression
	cam_roll = deg_to_rad(-4.0)
	
	if speed_label: speed_label.text = "SPD: 640 M/S  [MAX THRUST]"
	if alt_label: alt_label.text = "ALT: 5,550 M"
	if gforce_label: gforce_label.text = "G-LOAD: +2.0 G"
	if banner_label:
		banner_label.text = "★★★ TARGET DESTROYED // SPLASH ONE BANDIT ★★★"
		banner_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	if target_diamond:
		target_diamond.text = "★ SPLASH ONE ★"
		target_diamond.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
		
	if subtitles_label and sub_t > 0.4 and sub_t < 0.6:
		subtitles_label.text = "APEX CMD: Direct hit! Splash one bandit! Target completely vaporized!"

# =============================================================================
# DIRECTOR SHOT 8 (24.5s - 26.0s): Victory Flythrough & Sunset Zoom Climb
# =============================================================================
func _shot_8_victory_flythrough_zoom(t: float, delta: float) -> void:
	var sub_t = t - 24.5
	var p = clamp(sub_t / 1.5, 0.0, 1.0)
	
	# Vanguard 1 punches right through the smoke and fireball, pulling up into sun
	hero_jet.position += Vector3(0, 55.0 * delta * p, -135.0 * delta)
	hero_jet.rotation_degrees = Vector3(lerp(2.0, -55.0, p), 0, lerp(8.0, 0.0, p))
	
	# Wide beauty camera looking up as Vanguard 1 zooms overhead toward stratosphere
	cam_target_pos = hero_jet.global_position + Vector3(12, -14, 26)
	cam_look_target = hero_jet.global_position + Vector3(0, 15, -20)
	cam_target_fov = 70.0
	cam_roll = deg_to_rad(12.0)
	trauma = max(0.0, trauma - delta * 2.0)
	
	# Fade to black in final 0.8s
	if sub_t > 0.7 and fade_overlay:
		var fade_p = clamp((sub_t - 0.7) / 0.8, 0.0, 1.0)
		fade_overlay.color = Color(0, 0, 0, fade_p)
		
	if speed_label: speed_label.text = "SPD: 720 M/S  [SUPERSONIC CLIMB]"
	if alt_label: alt_label.text = "ALT: 6,850 M  [STRATOSPHERE ESCAPE]"
	if gforce_label: gforce_label.text = "G-LOAD: +4.2 G"
	if banner_label:
		banner_label.text = "// SORTIE COMPLETE // RETURNING TO BASE //"
	if target_diamond: target_diamond.hide()
	
	if subtitles_label and sub_t > 0.1 and sub_t < 0.3:
		_play_radio("res://audio/comms/m01_apex_mission_complete.mp3", "APEX CMD: Superb flying Vanguard 1! Air corridor secure. Return to base for debrief.")

# =============================================================================
# CAMERA & TRAUMA SHAKE SYSTEM
# =============================================================================
func _apply_camera_motion(delta: float) -> void:
	if not cam: return
	
	# Smooth camera tracking
	cam.global_position = cam.global_position.lerp(cam_target_pos, clamp(10.0 * delta, 0.0, 1.0))
	cam.fov = lerp(cam.fov, cam_target_fov, clamp(6.0 * delta, 0.0, 1.0))
	
	# Camera shake from G-force and explosion shockwave
	var shake_offset = Vector3.ZERO
	if trauma > 0.0:
		var sq = trauma * trauma
		shake_offset = Vector3(
			randf_range(-sq * 1.8, sq * 1.8),
			randf_range(-sq * 1.8, sq * 1.8),
			randf_range(-sq * 1.8, sq * 1.8)
		)
		trauma = max(0.0, trauma - delta * 0.9)
	
	var final_look = cam_look_target + shake_offset
	if not cam.global_position.is_equal_approx(final_look):
		var up_vec = Vector3.UP.rotated(Vector3.FORWARD, cam_roll)
		cam.look_at(final_look, up_vec)
