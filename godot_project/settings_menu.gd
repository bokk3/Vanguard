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

@onready var apply_btn: Button = %ApplyBtn
@onready var close_btn: Button = %CloseBtn

var rebind_target_action: String = ""
var key_buttons_map: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Populate window options
	window_option.clear()
	window_option.add_item("Windowed", 0)
	window_option.add_item("Exclusive Fullscreen", 1)
	window_option.add_item("Borderless Window", 2)
	
	# Connect slider value labels
	sens_slider.value_changed.connect(func(v): sens_val_label.text = "%.1fx" % v)
	master_slider.value_changed.connect(func(v): master_val_label.text = "%d%%" % int(v * 100))
	sfx_slider.value_changed.connect(func(v): sfx_val_label.text = "%d%%" % int(v * 100))
	
	# Preset buttons
	preset_azerty_btn.pressed.connect(_on_preset_azerty)
	preset_qwerty_btn.pressed.connect(_on_preset_qwerty)
	
	# Action buttons
	apply_btn.pressed.connect(_on_apply_pressed)
	close_btn.pressed.connect(_on_close_pressed)
	
	if rebind_overlay:
		rebind_overlay.hide()
	
	_build_keybindings_ui()
	refresh_from_config()

func _build_keybindings_ui() -> void:
	var cfg = get_node_or_null("/root/ConfigManager")
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
	var cfg = get_node_or_null("/root/ConfigManager")
	if not cfg:
		return
	
	sens_slider.value = cfg.mouse_sensitivity
	sens_val_label.text = "%.1fx" % cfg.mouse_sensitivity
	invert_check.button_pressed = cfg.invert_pitch
	gravity_check.button_pressed = cfg.enable_gravity
	
	radar_check.button_pressed = cfg.radar_circular_default
	window_option.select(cfg.window_mode)
	
	master_slider.value = cfg.master_volume
	master_val_label.text = "%d%%" % int(cfg.master_volume * 100)
	sfx_slider.value = cfg.sfx_volume
	sfx_val_label.text = "%d%%" % int(cfg.sfx_volume * 100)
	
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
	var cfg = get_node_or_null("/root/ConfigManager")
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
		
		var keycode = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		
		# Cancel if Escape pressed
		if event.keycode == KEY_ESCAPE:
			_cancel_rebind()
			return
		
		var cfg = get_node_or_null("/root/ConfigManager")
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
	var cfg = get_node_or_null("/root/ConfigManager")
	if cfg:
		cfg.reset_keybindings_preset(true)
		refresh_from_config()

func _on_preset_qwerty() -> void:
	var cfg = get_node_or_null("/root/ConfigManager")
	if cfg:
		cfg.reset_keybindings_preset(false)
		refresh_from_config()

func _on_apply_pressed() -> void:
	var cfg = get_node_or_null("/root/ConfigManager")
	if cfg:
		cfg.mouse_sensitivity = sens_slider.value
		cfg.invert_pitch = invert_check.button_pressed
		cfg.enable_gravity = gravity_check.button_pressed
		
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
