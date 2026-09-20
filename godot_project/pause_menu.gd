extends Control

## PauseMenu: In-flight tactical pause overlay for Project Vanguard.
## Freezes game simulation, captures/releases mouse, and links to Settings, Restart, or Hangar.

@onready var resume_btn: Button = %ResumeBtn
@onready var restart_btn: Button = %RestartBtn
@onready var config_btn: Button = %ConfigBtn
@onready var hangar_btn: Button = %HangarBtn
@onready var quit_btn: Button = %QuitBtn

@onready var settings_modal: Control = %SettingsMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	
	resume_btn.pressed.connect(resume_flight)
	restart_btn.pressed.connect(restart_sortie)
	config_btn.pressed.connect(open_config)
	hangar_btn.pressed.connect(return_to_hangar)
	quit_btn.pressed.connect(quit_game)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# If settings modal is open, close it first
		if settings_modal and settings_modal.visible:
			settings_modal.hide()
			return
		
		# Toggle pause state
		if visible:
			resume_flight()
		else:
			pause_flight()

func pause_flight() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()

func resume_flight() -> void:
	if settings_modal:
		settings_modal.hide()
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func restart_sortie() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func open_config() -> void:
	if settings_modal:
		settings_modal.open_menu()

func return_to_hangar() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://home_menu.tscn")

func quit_game() -> void:
	get_tree().quit()
