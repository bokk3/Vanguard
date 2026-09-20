extends Node3D

## HomeMenu: Main Menu controller for Project Vanguard.
## Handles eerie white hangar presentation, turntable ship, repair FX, and left-aligned menu.

@onready var ship_pivot: Node3D = $HangarScene/ShipTurntable
@onready var scan_ring: Node3D = $HangarScene/ShipTurntable/ScanRing
@onready var repair_sparks: CPUParticles3D = $HangarScene/ShipTurntable/RepairSparks
@onready var scan_light: OmniLight3D = $HangarScene/ShipTurntable/ScanRing/ScanLight

@onready var deploy_btn: Button = %DeployBtn
@onready var config_btn: Button = %ConfigBtn
@onready var specs_btn: Button = %SpecsBtn
@onready var quit_btn: Button = %QuitBtn

@onready var specs_panel: PanelContainer = %SpecsPanel
@onready var close_specs_btn: Button = %CloseSpecsBtn
@onready var settings_modal: Control = %SettingsMenu

@onready var repair_progress_bar: ProgressBar = %RepairProgressBar
@onready var repair_status_label: Label = %RepairStatusLabel

var anim_time: float = 0.0
var repair_percent: float = 84.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Connect buttons
	deploy_btn.pressed.connect(_on_deploy_pressed)
	config_btn.pressed.connect(_on_config_pressed)
	specs_btn.pressed.connect(_on_specs_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	close_specs_btn.pressed.connect(func(): specs_panel.hide())
	
	settings_modal.closed.connect(_on_settings_closed)
	specs_panel.hide()
	settings_modal.hide()

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

func _on_deploy_pressed() -> void:
	# Launch into flight mission
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
