extends Control

## SettingsMenu: Reusable tactical configuration modal for Project Vanguard.
## Provides full key remapping, presets, flight sensitivity, audio, and display settings.

signal closed

@onready var tab_container: TabContainer = %TabContainer

# Controls & Avionics
@onready var sens_slider: HSlider = %SensSlider
@onready var sens_val_label: Label = %SensValLabel
@onready var invert_check: CheckBox = %InvertCheck
@onready var gravity_check: CheckBox = %GravityCheck
@onready var difficulty_option: OptionButton = %DifficultyOption

# Keybindings UI
@onready var keybinds_list: VBoxContainer = %KeybindsList
@onready var preset_azerty_btn: Button = %PresetAzertyBtn
@onready var preset_qwerty_btn: Button = %PresetQwertyBtn

# Rebind Modal Overlay
@onready var rebind_overlay: ColorRect = %RebindOverlay
@onready var rebind_prompt: Label = %RebindPrompt

# Display & Audio
@onready var radar_check: CheckBox = %RadarCheck
@onready var window_option: OptionButton = %WindowOption
@onready var master_slider: HSlider = %MasterSlider
@onready var master_val_label: Label = %MasterValLabel
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_val_label: Label = %SfxValLabel

# Gamepad & Controller
@onready var pad_status_label: Label = %PadStatusLabel
@onready var rumble_check: CheckBox = %RumbleCheck
@onready var pad_layout_list: VBoxContainer = %PadLayoutList

# Data & Storage
@onready var reset_config_btn: Button = %ResetConfigBtn
@onready var config_status_label: Label = %ConfigStatusLabel
@onready var clear_saves_btn: Button = %ClearSavesBtn
@onready var save_status_label: Label = %SaveStatusLabel

@onready var apply_btn: Button = %ApplyBtn
@onready var close_btn: Button = %CloseBtn

var rebind_target_action: String = ""
var key_buttons_map: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Listen for controller connect / disconnect events
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
	
	# Populate difficulty options
	if difficulty_option:
		difficulty_option.clear()
		difficulty_option.add_item("Cadet (EASY)", 0)
		difficulty_option.add_item("Veteran (NORMAL)", 1)
		difficulty_option.add_item("Top Gun (ACE)", 2)
	
	# Populate window options
	window_option.clear()
	window_option.add_item("Windowed", 0)
	window_option.add_item("Exclusive Fullscreen", 1)
	window_option.add_item("Borderless Window", 2)
	
	# Connect slider value labels
	if not sens_slider.value_changed.is_connected(_on_sens_changed):
		sens_slider.value_changed.connect(_on_sens_changed)
	if not master_slider.value_changed.is_connected(_on_master_changed):
		master_slider.value_changed.connect(_on_master_changed)
	if not sfx_slider.value_changed.is_connected(_on_sfx_changed):
		sfx_slider.value_changed.connect(_on_sfx_changed)
	
	# Preset buttons
	if not preset_azerty_btn.pressed.is_connected(_on_preset_azerty):
		preset_azerty_btn.pressed.connect(_on_preset_azerty)
	if not preset_qwerty_btn.pressed.is_connected(_on_preset_qwerty):
		preset_qwerty_btn.pressed.connect(_on_preset_qwerty)
	
	# Action buttons
	if not apply_btn.pressed.is_connected(_on_apply_pressed):
		apply_btn.pressed.connect(_on_apply_pressed)
	if not close_btn.pressed.is_connected(_on_close_pressed):
		close_btn.pressed.connect(_on_close_pressed)
	
	if reset_config_btn and not reset_config_btn.pressed.is_connected(_on_reset_config_pressed):
		reset_config_btn.pressed.connect(_on_reset_config_pressed)
	if clear_saves_btn and not clear_saves_btn.pressed.is_connected(_on_clear_saves_pressed):
		clear_saves_btn.pressed.connect(_on_clear_saves_pressed)
	
	if rebind_overlay:
		rebind_overlay.hide()
	
	_build_keybindings_ui()
	_build_gamepad_ui()
	refresh_from_config()

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	var cfg = _get_config_manager()
	if pad_status_label and cfg and cfg.has_method("get_connected_controller_name"):
		pad_status_label.text = cfg.get_connected_controller_name()

func _on_sens_changed(v: float) -> void:
	if sens_val_label:
		sens_val_label.text = "%.1fx" % v

func _on_master_changed(v: float) -> void:
	if master_val_label:
		master_val_label.text = "%d%%" % int(v * 100)

func _on_sfx_changed(v: float) -> void:
	if sfx_val_label:
		sfx_val_label.text = "%d%%" % int(v * 100)

func _build_keybindings_ui() -> void:
	var cfg = _get_config_manager()
	if not cfg or not keybinds_list:
		return
	
	# Clear existing dynamic children
	for child in keybinds_list.get_children():
		child.queue_free()
	key_buttons_map.clear()
	
	for action in cfg.ACTIONS:
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 32)
		
		var label = Label.new()
		label.text = cfg.ACTION_LABELS.get(action, action)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.set("theme_override_colors/font_color", Color(0.85, 0.95, 1.0, 0.95))
		label.set("theme_override_font_sizes/font_size", 12)
		row.add_child(label)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(130, 28)
		btn.text = "[ %s ]" % cfg.get_key_string_for_action(action)
		btn.set("theme_override_font_sizes/font_size", 11)
		
		var captured_action = action
		btn.pressed.connect(func(): _start_rebind(captured_action))
		row.add_child(btn)
		
		key_buttons_map[action] = btn
		keybinds_list.add_child(row)

func refresh_from_config() -> void:
	var cfg = _get_config_manager()
	if not cfg:
		return
	
	sens_slider.value = cfg.mouse_sensitivity
	sens_val_label.text = "%.1fx" % cfg.mouse_sensitivity
	invert_check.button_pressed = cfg.invert_pitch
	gravity_check.button_pressed = cfg.enable_gravity
	
	if difficulty_option:
		match cfg.difficulty.to_upper():
			"EASY":
				difficulty_option.select(0)
			"ACE":
				difficulty_option.select(2)
			_:
				difficulty_option.select(1)
	
	radar_check.button_pressed = cfg.radar_circular_default
	window_option.select(cfg.window_mode)
	
	master_slider.value = cfg.master_volume
	master_val_label.text = "%d%%" % int(cfg.master_volume * 100)
	sfx_slider.value = cfg.sfx_volume
	sfx_val_label.text = "%d%%" % int(cfg.sfx_volume * 100)
	
	if pad_status_label and cfg.has_method("get_connected_controller_name"):
		pad_status_label.text = cfg.get_connected_controller_name()
	if rumble_check and "enable_rumble" in cfg:
		rumble_check.button_pressed = cfg.enable_rumble
	
	# Refresh key button labels
	for action in key_buttons_map.keys():
		var btn = key_buttons_map[action]
		if is_instance_valid(btn):
			btn.text = "[ %s ]" % cfg.get_key_string_for_action(action)

func open_menu() -> void:
	refresh_from_config()
	if tab_container:
		tab_container.current_tab = 0
	show()

func _start_rebind(action: String) -> void:
	var cfg = _get_config_manager()
	if not cfg:
		return
	
	rebind_target_action = action
	var action_label = cfg.ACTION_LABELS.get(action, action)
	if rebind_prompt:
		rebind_prompt.text = "REBINDING: %s\n\nPRESS ANY KEY ON YOUR KEYBOARD...\n(PRESS ESCAPE TO CANCEL)" % action_label.to_upper()
	if rebind_overlay:
		rebind_overlay.show()

func _input(event: InputEvent) -> void:
	if rebind_target_action == "" or not rebind_overlay.visible:
		return
	
	if event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
		
		var keycode = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
		
		# Cancel if Escape pressed
		if event.keycode == KEY_ESCAPE:
			_cancel_rebind()
			return
		
		var cfg = _get_config_manager()
		if cfg:
			cfg.rebind_action(rebind_target_action, keycode)
		
		if key_buttons_map.has(rebind_target_action):
			var btn = key_buttons_map[rebind_target_action]
			if is_instance_valid(btn) and cfg:
				btn.text = "[ %s ]" % cfg.get_key_string_for_action(rebind_target_action)
		
		_finish_rebind()

func _cancel_rebind() -> void:
	rebind_target_action = ""
	if rebind_overlay:
		rebind_overlay.hide()

func _finish_rebind() -> void:
	rebind_target_action = ""
	if rebind_overlay:
		rebind_overlay.hide()

func _on_preset_azerty() -> void:
	var cfg = _get_config_manager()
	if cfg:
		cfg.reset_keybindings_preset(true)
		refresh_from_config()

func _on_preset_qwerty() -> void:
	var cfg = _get_config_manager()
	if cfg:
		cfg.reset_keybindings_preset(false)
		refresh_from_config()

func _on_apply_pressed() -> void:
	var cfg = _get_config_manager()
	if cfg:
		cfg.mouse_sensitivity = sens_slider.value
		cfg.invert_pitch = invert_check.button_pressed
		cfg.enable_gravity = gravity_check.button_pressed
		
		if difficulty_option:
			match difficulty_option.selected:
				0:
					cfg.difficulty = "EASY"
				2:
					cfg.difficulty = "ACE"
				_:
					cfg.difficulty = "NORMAL"
		
		if rumble_check and "enable_rumble" in cfg:
			cfg.enable_rumble = rumble_check.button_pressed
		
		cfg.radar_circular_default = radar_check.button_pressed
		cfg.window_mode = window_option.selected
		
		cfg.master_volume = master_slider.value
		cfg.sfx_volume = sfx_slider.value
		cfg.save_settings()
	
	hide()
	closed.emit()

func _on_close_pressed() -> void:
	hide()
	closed.emit()

func _on_reset_config_pressed() -> void:
	var cfg = _get_config_manager()
	if cfg and cfg.has_method("reset_to_factory_defaults"):
		cfg.reset_to_factory_defaults()
		refresh_from_config()
		if config_status_label:
			config_status_label.text = "CONFIG RESTORED TO FACTORY DEFAULTS // OK"
			config_status_label.modulate.a = 1.0
			var t = create_tween()
			t.tween_property(config_status_label, "modulate:a", 0.0, 3.5).set_delay(1.5)

func _on_clear_saves_pressed() -> void:
	var sm = _get_save_manager()
	if sm and sm.has_method("delete_all_saves"):
		sm.delete_all_saves()
	var mm = _get_mission_manager()
	if mm and mm.has_method("reset_campaign_progress"):
		mm.reset_campaign_progress()
	
	# If HomeMenu is active, refresh its save state so Resume Sortie button hides
	var cur_scene = get_tree().current_scene if (is_inside_tree() and get_tree()) else null
	if cur_scene and cur_scene.has_method("_check_save_game_state"):
		cur_scene._check_save_game_state()
	
	if save_status_label:
		save_status_label.text = "ALL SAVES PURGED // CAMPAIGN RESET TO M01"
		save_status_label.modulate.a = 1.0
		var t = create_tween()
		t.tween_property(save_status_label, "modulate:a", 0.0, 3.5).set_delay(1.5)

func _build_gamepad_ui() -> void:
	var cfg = _get_config_manager()
	if not cfg or not pad_layout_list:
		return
	
	for child in pad_layout_list.get_children():
		child.queue_free()
	
	# Header row
	var header = HBoxContainer.new()
	var h_act = Label.new()
	h_act.text = "FLIGHT ACTION"
	h_act.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_act.set("theme_override_colors/font_color", Color(0, 0.92, 1, 1))
	h_act.set("theme_override_font_sizes/font_size", 11)
	header.add_child(h_act)
	
	var h_xb = Label.new()
	h_xb.custom_minimum_size = Vector2(170, 0)
	h_xb.text = "XBOX / PC LAYOUT"
	h_xb.set("theme_override_colors/font_color", Color(0.2, 1.0, 0.4, 1))
	h_xb.set("theme_override_font_sizes/font_size", 11)
	header.add_child(h_xb)
	
	var h_ps = Label.new()
	h_ps.custom_minimum_size = Vector2(170, 0)
	h_ps.text = "PS5 / DUALSENSE"
	h_ps.set("theme_override_colors/font_color", Color(0.3, 0.7, 1.0, 1))
	h_ps.set("theme_override_font_sizes/font_size", 11)
	header.add_child(h_ps)
	pad_layout_list.add_child(header)
	
	var sep = HSeparator.new()
	pad_layout_list.add_child(sep)
	
	if "JOYPAD_CONTROLS_TABLE" in cfg:
		for item in cfg.JOYPAD_CONTROLS_TABLE:
			var row = HBoxContainer.new()
			row.custom_minimum_size = Vector2(0, 24)
			
			var l_act = Label.new()
			l_act.text = item["action"]
			l_act.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l_act.set("theme_override_font_sizes/font_size", 11)
			l_act.set("theme_override_colors/font_color", Color(0.9, 0.95, 1.0, 0.95))
			row.add_child(l_act)
			
			var l_xb = Label.new()
			l_xb.custom_minimum_size = Vector2(170, 0)
			l_xb.text = item["xbox"]
			l_xb.set("theme_override_font_sizes/font_size", 11)
			l_xb.set("theme_override_colors/font_color", Color(0.8, 1.0, 0.85, 0.9))
			row.add_child(l_xb)
			
			var l_ps = Label.new()
			l_ps.custom_minimum_size = Vector2(170, 0)
			l_ps.text = item["ps"]
			l_ps.set("theme_override_font_sizes/font_size", 11)
			l_ps.set("theme_override_colors/font_color", Color(0.8, 0.9, 1.0, 0.9))
			row.add_child(l_ps)
			
			pad_layout_list.add_child(row)

func _get_config_manager() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		var c = get_tree().root.get_node_or_null("ConfigManager")
		if c: return c
	if get_parent():
		var c = get_parent().get_node_or_null("ConfigManager")
		if c: return c
	var main_loop = Engine.get_main_loop() as SceneTree
	if main_loop and main_loop.root:
		var c = main_loop.root.get_node_or_null("ConfigManager")
		if c: return c
	return null

func _get_save_manager() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		var s = get_tree().root.get_node_or_null("SaveManager")
		if s: return s
	if get_parent():
		var s = get_parent().get_node_or_null("SaveManager")
		if s: return s
	var main_loop = Engine.get_main_loop() as SceneTree
	if main_loop and main_loop.root:
		var s = main_loop.root.get_node_or_null("SaveManager")
		if s: return s
	return null

func _get_mission_manager() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		var m = get_tree().root.get_node_or_null("MissionManager")
		if m: return m
	if get_parent():
		var m = get_parent().get_node_or_null("MissionManager")
		if m: return m
	var main_loop = Engine.get_main_loop() as SceneTree
	if main_loop and main_loop.root:
		var m = main_loop.root.get_node_or_null("MissionManager")
		if m: return m
	return null
