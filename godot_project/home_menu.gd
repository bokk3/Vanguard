extends Node3D

## HomeMenu: Main Menu controller for Project Vanguard.
## Handles eerie white hangar presentation, turntable ship, repair FX, and left-aligned menu.

@onready var ship_pivot: Node3D = $HangarScene/ShipTurntable
@onready var scan_ring: Node3D = $HangarScene/ShipTurntable/ScanRing
@onready var repair_sparks: CPUParticles3D = $HangarScene/ShipTurntable/RepairSparks
@onready var scan_light: OmniLight3D = $HangarScene/ShipTurntable/ScanRing/ScanLight

@onready var continue_btn: Button = %ContinueBtn
@onready var deploy_btn: Button = %DeployBtn
@onready var prologue_btn: Button = %PrologueBtn
@onready var config_btn: Button = %ConfigBtn
@onready var specs_btn: Button = %SpecsBtn
@onready var quit_btn: Button = %QuitBtn

@onready var specs_panel: PanelContainer = %SpecsPanel
@onready var close_specs_btn: Button = %CloseSpecsBtn
@onready var settings_modal: Control = %SettingsMenu
@onready var mission_selector: Control = %MissionSelector

@onready var repair_progress_bar: ProgressBar = %RepairProgressBar
@onready var repair_status_label: Label = %RepairStatusLabel
@onready var telemetry_summary: Label = %TelemetrySummary
@onready var footer_label: Label = %FooterLabel
@onready var title_box_right: Control = %TitleBoxRight

var anim_time: float = 0.0
var repair_percent: float = 84.0
var initial_title_y: float = 28.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Dynamic version string from project settings
	var ver = ProjectSettings.get_setting("application/config/version", "0.5.0")
	if footer_label:
		footer_label.text = "PROJECT VANGUARD v%s\nSYSTEMS INITIALIZED // READY" % ver
	
	# Connect buttons
	continue_btn.pressed.connect(_on_continue_pressed)
	deploy_btn.pressed.connect(_on_deploy_pressed)
	if prologue_btn:
		prologue_btn.pressed.connect(_on_prologue_pressed)
	config_btn.pressed.connect(_on_config_pressed)
	specs_btn.pressed.connect(_on_specs_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	close_specs_btn.pressed.connect(func(): specs_panel.hide())
	
	settings_modal.closed.connect(_on_settings_closed)
	specs_panel.hide()
	settings_modal.hide()
	if mission_selector:
		mission_selector.hide()
	
	if title_box_right:
		initial_title_y = title_box_right.position.y
	
	_setup_turntable_hardpoints()
	_check_save_game_state()

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
		continue_btn.text = "  [ 01 ]  CONTINUE SORTIE"
		deploy_btn.text = "  [ 02 ]  NEW SORTIE"
		if prologue_btn:
			prologue_btn.text = "  [ 03 ]  WATCH PROLOGUE"
		config_btn.text = "  [ 04 ]  AVIONICS CONFIG"
		specs_btn.text = "  [ 05 ]  FIGHTER SPECS"
		quit_btn.text = "  [ 06 ]  ABORT / QUIT"
		
		if telemetry_summary:
			telemetry_summary.text = "ACTIVE SORTIE: %s\nHULL INTEGRITY: %d%%\nMISSILES ARMED: %d/4" % [date_str, int(hull_val), int(missiles_val)]
	else:
		continue_btn.visible = false
		deploy_btn.text = "  [ 01 ]  DEPLOY SORTIE"
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
	if title_box_right:
		title_box_right.position.y = initial_title_y + sin(anim_time * 1.4) * 4.0

func _on_continue_pressed() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		sm.should_load_on_start = true
	get_tree().change_scene_to_file("res://main.tscn")

func _on_deploy_pressed() -> void:
	if mission_selector:
		mission_selector.open_selector()
	else:
		var sm = get_node_or_null("/root/SaveManager")
		if sm:
			sm.should_load_on_start = false
		get_tree().change_scene_to_file("res://main.tscn")

func _on_prologue_pressed() -> void:
	get_tree().change_scene_to_file("res://prologue_cutscene.tscn")

func _on_config_pressed() -> void:
	settings_modal.open_menu()

func _on_settings_closed() -> void:
	# Resume normal home menu focus
	pass

func _on_specs_pressed() -> void:
	specs_panel.visible = not specs_panel.visible

func _on_quit_pressed() -> void:
	get_tree().quit()
