extends Control

## SettingsMenu: Reusable tactical configuration modal for Project Vanguard.
## Can be opened from both Home Menu and in-flight Pause Menu.

signal closed

@onready var layout_option: OptionButton = %LayoutOption
@onready var sens_slider: HSlider = %SensSlider
@onready var sens_val_label: Label = %SensValLabel
@onready var invert_check: CheckBox = %InvertCheck
@onready var gravity_check: CheckBox = %GravityCheck

@onready var radar_check: CheckBox = %RadarCheck
@onready var window_option: OptionButton = %WindowOption

@onready var master_slider: HSlider = %MasterSlider
@onready var master_val_label: Label = %MasterValLabel
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_val_label: Label = %SfxValLabel

@onready var apply_btn: Button = %ApplyBtn
@onready var close_btn: Button = %CloseBtn

func _ready() -> void:
	# Populate layout options
	layout_option.clear()
	layout_option.add_item("AZERTY (Belgian / French)", 0)
	layout_option.add_item("QWERTY (Standard US/UK)", 1)
	
	# Populate window options
	window_option.clear()
	window_option.add_item("Windowed", 0)
	window_option.add_item("Exclusive Fullscreen", 1)
	window_option.add_item("Borderless Window", 2)
	
	# Connect signals
	apply_btn.pressed.connect(_on_apply_pressed)
	close_btn.pressed.connect(_on_close_pressed)
	sens_slider.value_changed.connect(func(v): sens_val_label.text = "%.1fx" % v)
	master_slider.value_changed.connect(func(v): master_val_label.text = "%d%%" % int(v * 100))
	sfx_slider.value_changed.connect(func(v): sfx_val_label.text = "%d%%" % int(v * 100))
	
	# Load initial UI state
	refresh_from_config()

func refresh_from_config() -> void:
	var cfg = get_node_or_null("/root/ConfigManager")
	if not cfg:
		return
	
	layout_option.select(0 if cfg.is_azerty else 1)
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

func open_menu() -> void:
	refresh_from_config()
	show()

func _on_apply_pressed() -> void:
	var cfg = get_node_or_null("/root/ConfigManager")
	if cfg:
		cfg.is_azerty = (layout_option.selected == 0)
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
