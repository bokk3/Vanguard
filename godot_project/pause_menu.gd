extends Control

## PauseMenu: In-flight tactical pause overlay for Project Vanguard.
## Freezes game simulation, captures/releases mouse, and links to Settings, Restart, or Hangar.

@onready var resume_btn: Button = %ResumeBtn
@onready var save_btn: Button = %SaveBtn
@onready var load_btn: Button = %LoadBtn
@onready var restart_btn: Button = %RestartBtn
@onready var config_btn: Button = %ConfigBtn
@onready var hangar_btn: Button = %HangarBtn
@onready var quit_btn: Button = %QuitBtn

@onready var settings_modal: Control = %SettingsMenu
@onready var save_toast: PanelContainer = %SaveToast
@onready var save_toast_label: Label = %SaveToastLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	if save_toast:
		save_toast.hide()
	
	resume_btn.pressed.connect(resume_flight)
	save_btn.pressed.connect(save_sortie)
	load_btn.pressed.connect(load_last_save)
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
	_refresh_save_buttons()
	if save_toast:
		save_toast.hide()
	show()

func _refresh_save_buttons() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if load_btn:
		load_btn.disabled = not (sm and sm.has_save())

func save_sortie() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.save_game():
		_refresh_save_buttons()
		_show_toast("// SORTIE SAVED // SECURE SYNC COMPLETE")
	else:
		_show_toast("[!] FAILED TO SAVE SORTIE", true)

func load_last_save() -> void:
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_save():
		if sm.apply_save_to_current_scene():
			resume_flight()

func _show_toast(msg: String, is_err: bool = false) -> void:
	if not save_toast or not save_toast_label:
		return
	save_toast_label.text = msg
	if is_err:
		save_toast_label.set("theme_override_colors/font_color", Color(1, 0.25, 0.25, 1))
	else:
		save_toast_label.set("theme_override_colors/font_color", Color(0, 1, 0.7, 1))
	save_toast.show()
	
	get_tree().create_timer(2.5, true, false, true).timeout.connect(func():
		if is_instance_valid(save_toast):
			save_toast.hide()
	)

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
