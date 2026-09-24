extends Node3D

## HomeMenu: Main Menu controller for Project Vanguard.
## Handles eerie white hangar presentation, turntable ship, repair FX, and left-aligned menu.

@onready var camera_3d: Camera3D = $Camera3D
@onready var ship_pivot: Node3D = $HangarScene/ShipTurntable
@onready var scan_ring: Node3D = $HangarScene/ShipTurntable/ScanRing
@onready var repair_sparks: CPUParticles3D = $HangarScene/ShipTurntable/RepairSparks
@onready var scan_light: OmniLight3D = $HangarScene/ShipTurntable/ScanRing/ScanLight

@onready var continue_btn: Button = %ContinueBtn
@onready var deploy_btn: Button = %DeployBtn
@onready var prologue_btn: Button = %PrologueBtn
@onready var pvp_btn: Button = %PvPBtn
@onready var config_btn: Button = %ConfigBtn
@onready var specs_btn: Button = %SpecsBtn
@onready var quit_btn: Button = %QuitBtn

@onready var specs_panel: PanelContainer = %SpecsPanel
@onready var close_specs_btn: Button = %CloseSpecsBtn
@onready var settings_modal: Control = %SettingsMenu
@onready var mission_selector: Control = %MissionSelector
@onready var update_badge_btn: Button = %UpdateBadgeBtn
@onready var update_dialog: Control = %UpdateDialog
@onready var fade_overlay: ColorRect = %FadeOverlay
@onready var warp_audio: AudioStreamPlayer = %WarpAudio
@onready var menu_music_player: AudioStreamPlayer = %MenuMusicPlayer
@onready var sidebar: PanelContainer = $UI/Sidebar

@onready var repair_progress_bar: ProgressBar = %RepairProgressBar
@onready var repair_status_label: Label = %RepairStatusLabel
@onready var telemetry_summary: Label = %TelemetrySummary
@onready var footer_label: Label = %FooterLabel
@onready var title_box_right: Control = %TitleBoxRight

var anim_time: float = 0.0
var repair_percent: float = 84.0
var initial_title_y: float = 28.0
var is_launching: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Dynamic version string from project settings
	var ver = ProjectSettings.get_setting("application/config/version", "0.8.0")
	if footer_label:
		footer_label.text = "PROJECT VANGUARD v%s\nSYSTEMS INITIALIZED // READY" % ver
	
	# Connect buttons
	if not continue_btn.pressed.is_connected(_on_continue_pressed):
		continue_btn.pressed.connect(_on_continue_pressed)
	if not deploy_btn.pressed.is_connected(_on_deploy_pressed):
		deploy_btn.pressed.connect(_on_deploy_pressed)
	if prologue_btn and not prologue_btn.pressed.is_connected(_on_prologue_pressed):
		prologue_btn.pressed.connect(_on_prologue_pressed)
	if pvp_btn and not pvp_btn.pressed.is_connected(_on_pvp_pressed):
		pvp_btn.pressed.connect(_on_pvp_pressed)
	if not config_btn.pressed.is_connected(_on_config_pressed):
		config_btn.pressed.connect(_on_config_pressed)
	if not specs_btn.pressed.is_connected(_on_specs_pressed):
		specs_btn.pressed.connect(_on_specs_pressed)
	if not quit_btn.pressed.is_connected(_on_quit_pressed):
		quit_btn.pressed.connect(_on_quit_pressed)
	if close_specs_btn and not close_specs_btn.pressed.is_connected(func(): specs_panel.hide()):
		close_specs_btn.pressed.connect(func(): specs_panel.hide())
	
	if update_badge_btn:
		if not update_badge_btn.pressed.is_connected(_on_update_badge_pressed):
			update_badge_btn.pressed.connect(_on_update_badge_pressed)
		update_badge_btn.hide()
	
	if update_dialog:
		update_dialog.hide()
	
	var updater = get_node_or_null("/root/Updater")
	if updater:
		if not updater.update_available.is_connected(_on_update_available):
			updater.update_available.connect(_on_update_available)
		if not updater.available_version.is_empty():
			_show_update_notification(updater.available_version)
	
	if not settings_modal.closed.is_connected(_on_settings_closed):
		settings_modal.closed.connect(_on_settings_closed)
	specs_panel.hide()
	settings_modal.hide()
	if mission_selector:
		mission_selector.hide()
		if not mission_selector.mission_scrambled.is_connected(_on_mission_selector_scrambled):
			mission_selector.mission_scrambled.connect(_on_mission_selector_scrambled)
	
	if title_box_right:
		initial_title_y = title_box_right.position.y
	
	_setup_turntable_hardpoints()
	_check_save_game_state()
	_setup_menu_music()

func _setup_menu_music() -> void:
	if not menu_music_player:
		menu_music_player = get_node_or_null("%MenuMusicPlayer")
	if not menu_music_player:
		menu_music_player = AudioStreamPlayer.new()
		menu_music_player.name = "MenuMusicPlayer"
		menu_music_player.bus = "Music"
		add_child(menu_music_player)
	
	if not menu_music_player.stream:
		var stream = load("res://audio/music/menu_soundscape.mp3")
		if stream:
			menu_music_player.stream = stream
	
	if is_inside_tree() and menu_music_player and menu_music_player.stream and not menu_music_player.playing:
		menu_music_player.volume_db = -4.0
		menu_music_player.play()

func _setup_turntable_hardpoints() -> void:
	var ship_model = ship_pivot.get_node_or_null("SpaceshipModel")
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
		hp.name = "HangarHardpoint_0" + str(i + 1)
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

func _check_save_game_state() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_save():
		var info = sm.get_save_info()
		var date_str = info.get("display_date", "UNKNOWN")
		var telem = info.get("telemetry", {})
		var hull_val = telem.get("current_hull", 100.0)
		var missiles_val = telem.get("missiles_remaining", 4)
		
		continue_btn.visible = true
		continue_btn.text = "  [ 01 ]  RESUME SORTIE"
		deploy_btn.text = "  [ 02 ]  MISSION SELECTOR"
		if prologue_btn:
			prologue_btn.text = "  [ 03 ]  WATCH PROLOGUE"
		config_btn.text = "  [ 04 ]  AVIONICS CONFIG"
		specs_btn.text = "  [ 05 ]  FIGHTER SPECS"
		quit_btn.text = "  [ 06 ]  ABORT / QUIT"
		
		if telemetry_summary:
			telemetry_summary.text = "ACTIVE SORTIE: %s\nHULL INTEGRITY: %d%%\nMISSILES ARMED: %d/4" % [date_str, int(hull_val), int(missiles_val)]
	else:
		continue_btn.visible = false
		deploy_btn.text = "  [ 01 ]  MISSION SELECTOR"
		if prologue_btn:
			prologue_btn.text = "  [ 02 ]  WATCH PROLOGUE"
		config_btn.text = "  [ 03 ]  AVIONICS CONFIG"
		specs_btn.text = "  [ 04 ]  FIGHTER SPECS"
		quit_btn.text = "  [ 05 ]  ABORT / QUIT"

func _process(delta: float) -> void:
	anim_time += delta
	
	# Turntable slow rotation
	if ship_pivot:
		ship_pivot.rotation.y += delta * 0.12
		# Subtle hydraulic hover breathing
		ship_pivot.position.y = 0.9 + sin(anim_time * 1.5) * 0.03
	
	# Diagnostic Scan Ring moves fore-and-aft across the ship
	if scan_ring:
		var scan_z = sin(anim_time * 1.8) * 4.5
		scan_ring.position.z = scan_z
		if scan_light:
			scan_light.light_energy = 1.8 + sin(anim_time * 8.0) * 0.4
	
	# Simulate repairing progress incrementing slowly
	repair_percent += delta * 0.4
	if repair_percent > 100.0:
		repair_percent = 78.0
	
	if repair_progress_bar:
		repair_progress_bar.value = repair_percent
	if repair_status_label:
		repair_status_label.text = "DIAGNOSTIC CYCLE: %d%% NOMINAL" % int(repair_percent)
	
	# Title overlay subtle floating hover
	if title_box_right and not is_launching:
		title_box_right.position.y = initial_title_y + sin(anim_time * 1.4) * 4.0

func _on_continue_pressed() -> void:
	var target_mid = "M01"
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_save():
		var info = sm.get_save_info()
		target_mid = info.get("mission_id", "M01")
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.current_mission_id:
		target_mid = mm.current_mission_id
	_launch_game_animation(target_mid, true)

func _on_deploy_pressed() -> void:
	if mission_selector:
		mission_selector.open_selector()
	else:
		_launch_game_animation("M01", false)

func _on_mission_selector_scrambled(mission_id: String) -> void:
	_launch_game_animation(mission_id, false)

func _on_prologue_pressed() -> void:
	var mm = get_node_or_null("/root/MissionManager")
	if mm:
		mm.is_prologue_preview_only = true
	_launch_game_animation("M01", false)

func _on_pvp_pressed() -> void:
	get_tree().change_scene_to_file("res://pvp_menu.tscn")

func _launch_game_animation(mission_id: String, is_resume: bool) -> void:
	if is_launching:
		return
	is_launching = true
	
	# Disable UI buttons to prevent double activation
	continue_btn.disabled = true
	deploy_btn.disabled = true
	if prologue_btn:
		prologue_btn.disabled = true
	if pvp_btn:
		pvp_btn.disabled = true
	config_btn.disabled = true
	specs_btn.disabled = true
	quit_btn.disabled = true
	if mission_selector:
		mission_selector.hide()
	if specs_panel:
		specs_panel.hide()
	
	# Play launch whoosh/warp audio
	if warp_audio and warp_audio.is_inside_tree():
		var sfx_stream = load("res://audio/sfx/sfx_flight_high_g_whoosh.wav")
		if sfx_stream:
			warp_audio.stream = sfx_stream
			warp_audio.pitch_scale = 0.85
			warp_audio.play()
	
	var duration: float = 1.35
	var tween_ui = create_tween().set_parallel(true)
	
	# Smoothly fade out menu music as launch begins
	if menu_music_player and menu_music_player.playing:
		var music_tween = create_tween()
		music_tween.tween_property(menu_music_player, "volume_db", -45.0, duration * 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Slide sidebar off-screen to the left
	if sidebar:
		tween_ui.tween_property(sidebar, "position:x", -460.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Camera rushes toward and through the right side of the hangar
	var cam_tween = create_tween().set_parallel(true)
	if camera_3d:
		var target_cam_pos = camera_3d.position + Vector3(3.5, -0.4, -14.0)
		cam_tween.tween_property(camera_3d, "position", target_cam_pos, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		cam_tween.tween_property(camera_3d, "fov", 110.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Vanguard logo zoom & fly-through: scales up 22x centered so letters rush past camera edges
	if title_box_right:
		title_box_right.pivot_offset = title_box_right.size * 0.5
		var vp_rect = get_viewport().get_visible_rect() if is_inside_tree() and get_viewport() else Rect2(0, 0, 1920, 1080)
		var center_dest = (vp_rect.size - title_box_right.size) * 0.5
		cam_tween.tween_property(title_box_right, "global_position", center_dest, duration * 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		cam_tween.tween_property(title_box_right, "scale", Vector2(22.0, 22.0), duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		cam_tween.tween_property(title_box_right, "modulate:a", 0.0, 0.25).set_delay(duration * 0.80)
	
	# Cut/Fade to pure black as camera pierces the letters
	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.color = Color(0, 0, 0, 0)
		cam_tween.tween_property(fade_overlay, "color:a", 1.0, 0.50).set_delay(duration * 0.60)
	
	cam_tween.finished.connect(func():
		_on_launch_animation_finished(mission_id, is_resume)
	)

func _on_launch_animation_finished(mission_id: String, is_resume: bool) -> void:
	var mm = get_node_or_null("/root/MissionManager")
	if mm:
		mm.current_mission_id = mission_id
	
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		sm.should_load_on_start = is_resume
	
	# Always show the intro when starting the first mission!
	if mission_id == "M01" or (mm and mm.is_prologue_preview_only):
		get_tree().change_scene_to_file("res://prologue_cutscene.tscn")
	else:
		get_tree().change_scene_to_file("res://main.tscn")

func _on_config_pressed() -> void:
	settings_modal.open_menu()

func _on_settings_closed() -> void:
	# Resume normal home menu focus
	pass

func _on_specs_pressed() -> void:
	specs_panel.visible = not specs_panel.visible

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_update_available(version: String, _changelog: String, _url: String, _size: int) -> void:
	_show_update_notification(version)

func _show_update_notification(version: String) -> void:
	if update_badge_btn:
		update_badge_btn.text = "◈ UPGRADE READY // %s" % version
		update_badge_btn.visible = true
	
	var updater = get_node_or_null("/root/Updater")
	if updater and not updater.has_dismissed_prompt:
		if update_dialog:
			update_dialog.show_update_prompt()

func _on_update_badge_pressed() -> void:
	if update_dialog:
		update_dialog.show_update_prompt()

