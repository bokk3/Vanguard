extends CanvasLayer

var ship: CharacterBody3D
var label: Label

func _ready() -> void:
	ship = get_node_or_null("../Spaceship")
	
	label = Label.new()
	label.name = "HUDLabel"
	label.position = Vector2(25, 25)
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)

func _process(_delta: float) -> void:
	if not ship or not label:
		return
	
	var speed_kmh = round(ship.current_speed * 3.6)
	var alt_m = round(ship.global_position.y)
	var boosting = Input.is_key_pressed(KEY_SHIFT)
	var boost_str = " [AFTERBURNER]" if boosting else ""
	
	var stall_warn = ""
	if ship.enable_gravity and ship.current_speed < ship.stall_speed:
		stall_warn = "\n>>> WARNING: STALL - INSUFFICIENT LIFT (FALLING) <<<"

	var layout_str = "AZERTY (Belgian/French)" if ship.is_azerty else "QWERTY (Standard)"
	var throttle_keys = "Z / S" if ship.is_azerty else "W / S"
	var roll_keys = "Q / D" if ship.is_azerty else "A / D"
	var yaw_keys = "A / E" if ship.is_azerty else "Q / E"

	label.text = """=== PROJECT VANGUARD HUD ===
SPEED: %d km/h%s
ALTITUDE: %d m
GRAVITY: %s
LAYOUT: %s  [Press F1 to switch]

CONTROLS:
  %s : Throttle Accelerate / Airbrake
  SHIFT : Afterburner Boost
  %s : Bank & Roll
  %s : Yaw Rudder
  MOUSE : Pitch Up/Down & Yaw Steering
  ESC   : Toggle Mouse Capture%s""" % [
		speed_kmh,
		boost_str,
		alt_m,
		"9.81 m/s² (Active)" if ship.enable_gravity else "Zero-G (Disabled)",
		layout_str,
		throttle_keys,
		roll_keys,
		yaw_keys,
		stall_warn
	]
