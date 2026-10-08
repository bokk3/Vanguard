extends Control

## PauseMenu: In-flight tactical pause overlay for Project Vanguard.
## Freezes game simulation, captures/releases mouse, and links to Settings, Restart, or Hangar.

@onready var resume_btn: Button = %ResumeBtn
@onready var save_btn: Button = %SaveBtn
@onready var load_btn: Button = %LoadBtn
@onready var restart_btn: Button = %RestartBtn
@onready var config_btn: Button = %ConfigBtn
@onready var mobile_hotas_btn: Button = get_node_or_null("%MobileHotasPauseBtn")
@onready var hangar_btn: Button = %HangarBtn
@onready var quit_btn: Button = %QuitBtn

@onready var settings_modal: Control = %SettingsMenu
@onready var save_toast: PanelContainer = %SaveToast
@onready var save_toast_label: Label = %SaveToastLabel

@onready var mission_name_label: Label = find_child("MissionNameLabel", true, false)
@onready var theater_label: Label = find_child("TheaterLabel", true, false)
@onready var objectives_list: VBoxContainer = find_child("ObjectivesList", true, false)

var qr_dialog: Control = null

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
	if mobile_hotas_btn:
		mobile_hotas_btn.pressed.connect(_toggle_qr_dialog)
	hangar_btn.pressed.connect(return_to_hangar)
	quit_btn.pressed.connect(quit_game)

	var net_ctrl = get_node_or_null("/root/NetworkControllerServer")
	if net_ctrl:
		if not net_ctrl.pilot_connected.is_connected(_on_pilot_connected):
			net_ctrl.pilot_connected.connect(_on_pilot_connected)
		if not net_ctrl.pilot_disconnected.is_connected(_on_pilot_disconnected):
			net_ctrl.pilot_disconnected.connect(_on_pilot_disconnected)
		_refresh_hotas_btn()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F3 and visible:
			_toggle_qr_dialog()
			if get_viewport(): get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			# If QR dialog is open, close it first
			if qr_dialog and qr_dialog.visible:
				qr_dialog.hide()
				if get_viewport(): get_viewport().set_input_as_handled()
				return
			# If settings modal is open, close it first
			if settings_modal and settings_modal.visible:
				settings_modal.hide()
				return
			
			# If Agility debrief panel is open, let debrief handle clicks/exit
			var ahud = get_node_or_null("../AgilityHUD")
			if ahud and ahud.has_node("%DebriefPanel"):
				var db_panel = ahud.get_node("%DebriefPanel") as Control
				if db_panel and db_panel.visible:
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
	_refresh_hotas_btn()
	if save_toast:
		save_toast.hide()
	show()

func _refresh_objectives() -> void:
	if not mission_name_label:
		mission_name_label = find_child("MissionNameLabel", true, false)
	if not theater_label:
		theater_label = find_child("TheaterLabel", true, false)
	if not objectives_list:
		objectives_list = find_child("ObjectivesList", true, false)

	# 1. Agility Trial Course Handling
	var am = get_node_or_null("/root/AgilityManager")
	if am and (am.is_trial_active or not am.active_trial_id.is_empty()):
		var t_data = am.TRIALS_DEF.get(am.active_trial_id, {})
		if not t_data.is_empty():
			if mission_name_label:
				mission_name_label.text = "AGILITY TRIAL: [%s] %s" % [am.active_trial_id, t_data.get("codename", "PRECISION TRIAL")]
			if theater_label:
				theater_label.text = "CURRICULUM: %s" % t_data.get("subtitle", "TACTICAL APEX FLIGHT")
			
			if objectives_list:
				for child in objectives_list.get_children():
					objectives_list.remove_child(child)
					child.queue_free()
				
				var add_row = func(icon: String, text: String, color: Color):
					var row = HBoxContainer.new()
					row.add_theme_constant_override("separation", 8)
					var il = Label.new()
					il.text = icon
					il.add_theme_font_size_override("font_size", 11)
					il.add_theme_color_override("font_color", color)
					row.add_child(il)
					var tl = Label.new()
					tl.text = text
					tl.add_theme_font_size_override("font_size", 11)
					tl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.95))
					tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					row.add_child(tl)
					objectives_list.add_child(row)
				
				var gates_done = am.current_gate_idx >= am.total_gates_in_trial
				add_row.call("[X]" if gates_done else "[ ]",
					"Navigate all course gates (%d/%d)" % [am.current_gate_idx, am.total_gates_in_trial],
					Color(0.1, 1.0, 0.4) if gates_done else Color(0.0, 0.85, 1.0))
				
				if am.total_targets_in_trial > 0:
					var tgts_done = am.targets_destroyed_count >= am.total_targets_in_trial
					add_row.call("[X]" if tgts_done else "[ ]",
						"Destroy target practice buoys (%d/%d)" % [am.targets_destroyed_count, am.total_targets_in_trial],
						Color(0.1, 1.0, 0.4) if tgts_done else Color(0.0, 0.85, 1.0))
						
				add_row.call("[★]",
					"Benchmark: Gold %.1fs | Silver %.1fs | Bronze %.1fs" % [
						t_data.get("gold_time", 60.0),
						t_data.get("silver_time", 75.0),
						t_data.get("bronze_time", 90.0)
					], Color(1.0, 0.85, 0.2))
			return

	# 2. Campaign Mission Handling
	var mm = get_node_or_null("/root/MissionManager")
	if not mm:
		return
	
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
	var am = get_node_or_null("/root/AgilityManager")
	var is_agility = am and (am.is_trial_active or not am.active_trial_id.is_empty())
	if is_agility:
		if save_btn: save_btn.visible = false
		if load_btn: load_btn.visible = false
	else:
		if save_btn: save_btn.visible = true
		if load_btn:
			load_btn.visible = true
			var sm = get_node_or_null("/root/SaveManager")
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
	if qr_dialog:
		qr_dialog.hide()
	if settings_modal:
		settings_modal.hide()
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func restart_sortie() -> void:
	if qr_dialog:
		qr_dialog.hide()
	var am = get_node_or_null("/root/AgilityManager")
	if am:
		am.is_trial_active = false
	get_tree().paused = false
	get_tree().reload_current_scene()

func open_config() -> void:
	if qr_dialog:
		qr_dialog.hide()
	if settings_modal:
		settings_modal.open_menu()

func _toggle_qr_dialog() -> void:
	if not qr_dialog:
		var scene = load("res://qr_join_dialog.tscn")
		if scene:
			qr_dialog = scene.instantiate()
			add_child(qr_dialog)
			if not qr_dialog.closed.is_connected(_on_qr_dialog_closed):
				qr_dialog.closed.connect(_on_qr_dialog_closed)
	if qr_dialog and qr_dialog.has_method("toggle_dialog"):
		qr_dialog.toggle_dialog(1)

func _on_qr_dialog_closed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_pilot_connected(callsign: String, p_id: int) -> void:
	if mobile_hotas_btn:
		mobile_hotas_btn.text = "  [ 📱 ]  PHONE HOTAS: %s (LINKED)" % callsign
		mobile_hotas_btn.add_theme_color_override("font_color", Color(0.1, 0.95, 0.4))
	_show_toast("// PHONE HOTAS LINKED: %s (P%d) //" % [callsign, p_id])

func _on_pilot_disconnected(_callsign: String, _p_id: int) -> void:
	if mobile_hotas_btn:
		mobile_hotas_btn.text = "  [ 📱 ]  PAIR PHONE HOTAS (F3)"
		mobile_hotas_btn.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0))

func _refresh_hotas_btn() -> void:
	if not mobile_hotas_btn:
		return
	var net_ctrl = get_node_or_null("/root/NetworkControllerServer")
	if net_ctrl and "connected_clients" in net_ctrl and net_ctrl.connected_clients.size() > 0:
		var c = net_ctrl.connected_clients[0]
		mobile_hotas_btn.text = "  [ 📱 ]  PHONE HOTAS: %s (LINKED)" % c.get("callsign", "PILOT")
		mobile_hotas_btn.add_theme_color_override("font_color", Color(0.1, 0.95, 0.4))
	else:
		mobile_hotas_btn.text = "  [ 📱 ]  PAIR PHONE HOTAS (F3)"
		mobile_hotas_btn.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0))

func return_to_hangar() -> void:
	if qr_dialog:
		qr_dialog.hide()
	var am = get_node_or_null("/root/AgilityManager")
	if am:
		am.is_trial_active = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://home_menu.tscn")

func quit_game() -> void:
	get_tree().quit()

