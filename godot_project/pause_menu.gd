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

@onready var mission_name_label: Label = find_child("MissionNameLabel", true, false)
@onready var theater_label: Label = find_child("TheaterLabel", true, false)
@onready var objectives_list: VBoxContainer = find_child("ObjectivesList", true, false)

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
	_refresh_objectives()
	if save_toast:
		save_toast.hide()
	show()

func _refresh_objectives() -> void:
	var mm = get_node_or_null("/root/MissionManager")
	if not mm:
		return
	
	if not mission_name_label:
		mission_name_label = find_child("MissionNameLabel", true, false)
	if not theater_label:
		theater_label = find_child("TheaterLabel", true, false)
	if not objectives_list:
		objectives_list = find_child("ObjectivesList", true, false)
	
	var m = mm.get_mission(mm.current_mission_id)
	if mission_name_label:
		mission_name_label.text = "CURRENT SORTIE: [%s] %s" % [mm.current_mission_id, m.get("codename", "UNKNOWN")]
	if theater_label:
		theater_label.text = "THEATER: %s" % m.get("theater", "Sector 07")
	
	if objectives_list:
		for child in objectives_list.get_children():
			objectives_list.remove_child(child)
			child.queue_free()
		
		for obj in mm.active_objectives:
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			
			var icon_lbl = Label.new()
			var status = obj.get("status", "IN_PROGRESS")
			var icon = "[ ]"
			var col = Color(0.0, 0.85, 1.0)
			if status == "COMPLETED":
				icon = "[X]"
				col = Color(0.1, 1.0, 0.4)
			elif status == "FAILED":
				icon = "[!]"
				col = Color(1.0, 0.25, 0.25)
			
			icon_lbl.text = icon
			icon_lbl.add_theme_font_size_override("font_size", 11)
			icon_lbl.add_theme_color_override("font_color", col)
			row.add_child(icon_lbl)
			
			var desc_lbl = Label.new()
			var cur_v = obj.get("current_val", 0)
			var tgt_v = obj.get("target_val", 1)
			var prog_str = " (%d/%d)" % [cur_v, tgt_v] if tgt_v > 1 else ""
			desc_lbl.text = "%s%s" % [obj.get("text", ""), prog_str]
			desc_lbl.add_theme_font_size_override("font_size", 11)
			desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.95) if status != "FAILED" else Color(1.0, 0.4, 0.4))
			desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(desc_lbl)
			
			objectives_list.add_child(row)

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
