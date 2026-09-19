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
	var boost_str = " [AFTERBURNER ENGAGED]" if boosting else ""
	
	var stall_warn = ""
	if ship.enable_gravity and ship.current_speed < ship.stall_speed:
		stall_warn = "\n>>> WARNING: STALL - INSUFFICIENT LIFT (FALLING) <<<"

	label.text = """=== PROJECT VANGUARD HUD ===
SPEED: %d km/h%s
ALTITUDE: %d m
GRAVITY: %s
CONTROLS:
  W / S : Throttle Acceleration / Airbrake
  SHIFT : Afterburner Boost
  A / D : Bank & Roll
  Q / E : Yaw Rudder
  MOUSE : Pitch Up/Down & Yaw Steering
  ESC   : Toggle Mouse Capture%s""" % [
		speed_kmh,
		boost_str,
		alt_m,
		"9.81 m/s² (Active)" if ship.enable_gravity else "Zero-G (Disabled)",
		stall_warn
	]
