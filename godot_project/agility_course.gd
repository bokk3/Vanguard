class_name AgilityCourse
extends Node3D

## AgilityCourse: Base scene controller for Agility Mode flight trials.
## Spawns ship, binds HUD, attaches ManeuverDetector, starts chronometer,
## and routes retry/exit requests.

@export var trial_id: String = "T01"

@onready var spaceship: CharacterBody3D = $Spaceship
@onready var ghost_ship: Node3D = $GhostShip
@onready var agility_hud: Control = $HUD/AgilityHUD

var maneuver_detector: ManeuverDetector = null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Attach ManeuverDetector to Spaceship
	if spaceship and not spaceship.has_node("ManeuverDetector"):
		maneuver_detector = ManeuverDetector.new()
		maneuver_detector.name = "ManeuverDetector"
		maneuver_detector.ship = spaceship
		spaceship.add_child(maneuver_detector)
		
	# Wire HUD actions
	if agility_hud:
		if not agility_hud.retry_requested.is_connected(_on_retry_requested):
			agility_hud.retry_requested.connect(_on_retry_requested)
		if not agility_hud.selector_requested.is_connected(_on_exit_requested):
			agility_hud.selector_requested.connect(_on_exit_requested)
			
	# Start Trial in AgilityManager
	var am = get_node_or_null("/root/AgilityManager")
	if am:
		am.start_trial(trial_id, spaceship, agility_hud)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_exit_requested()
		get_viewport().set_input_as_handled()

func _on_retry_requested() -> void:
	get_tree().reload_current_scene()

func _on_exit_requested() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var am = get_node_or_null("/root/AgilityManager")
	if am:
		am.is_trial_active = false
	get_tree().change_scene_to_file("res://home_menu.tscn")
