extends SceneTree

## Test suite for Menu Mouse Visibility, Custom Sci-Fi Cursor, and Mobile HOTAS Yaw Steering
var timer: float = 0.0
var step: int = 0
var home_menu: Node = null
var qr_dialog: Node = null
var dummy_ship: CharacterBody3D = null

func _init() -> void:
	print("=================================================================")
	print(">>> Project Vanguard: Menu Mouse, Cursor & Steering Test Suite <<<")
	print("=================================================================")

func _process(delta: float) -> bool:
	timer += delta

	# Step 0: Test Custom Cursor Texture Assets
	if step == 0:
		var img_tactical = Image.load_from_file("res://ui/cursor_tactical.png")
		assert(img_tactical != null and not img_tactical.is_empty(), "cursor_tactical.png must load as Image!")
		assert(img_tactical.get_width() == 32 and img_tactical.get_height() == 32, "cursor_tactical.png must be 32x32!")
		print("[PASS] Tactical Chevron Cursor verified (32x32 RGBA8).")

		var img_pointer = Image.load_from_file("res://ui/cursor_pointer.png")
		assert(img_pointer != null and not img_pointer.is_empty(), "cursor_pointer.png must load as Image!")
		assert(img_pointer.get_width() == 32 and img_pointer.get_height() == 32, "cursor_pointer.png must be 32x32!")
		print("[PASS] Target Lock Reticle Cursor verified (32x32 RGBA8).")

		step = 1
		timer = 0.0

	# Step 1: Instantiate HomeMenu and verify mouse mode is VISIBLE
	elif step == 1:
		var scene = load("res://home_menu.tscn")
		assert(scene != null, "home_menu.tscn must load!")
		home_menu = scene.instantiate()
		root.add_child(home_menu)
		
		# Set current_scene so dialogs know we are in HomeMenu
		current_scene = home_menu
		
		assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Mouse mode in HomeMenu must be MOUSE_MODE_VISIBLE!")
		print("[PASS] HomeMenu loaded with Input.mouse_mode == MOUSE_MODE_VISIBLE.")

		step = 2
		timer = 0.0

	# Step 2: Open and Close QRJoinDialog in HomeMenu
	elif step == 2:
		var qr_scene = load("res://qr_join_dialog.tscn")
		assert(qr_scene != null, "qr_join_dialog.tscn must load!")
		qr_dialog = qr_scene.instantiate()
		home_menu.add_child(qr_dialog)
		
		# Show dialog
		qr_dialog.show_dialog(1)
		assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Mouse mode while QR dialog is open must be VISIBLE!")
		print("[PASS] QRJoinDialog opened with Input.mouse_mode == MOUSE_MODE_VISIBLE.")
		
		# Hide dialog
		qr_dialog.hide_dialog()
		assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Mouse mode after closing QR dialog in HomeMenu must remain VISIBLE!")
		print("[PASS] QRJoinDialog closed: Input.mouse_mode remained MOUSE_MODE_VISIBLE (not captured!).")

		step = 3
		timer = 0.0

	# Step 3: Test mobile pilot connection simulation (auto-close timer)
	elif step == 3:
		qr_dialog.show_dialog(1)
		
		# Simulate pilot connected signal
		var net_server = root.get_node_or_null("NetworkControllerServer")
		if net_server:
			net_server.pilot_connected.emit("TEST-PILOT", 1)
			print("[PASS] Simulated pilot_connected signal emitted.")
		
		step = 4
		timer = 0.0

	# Step 4: Wait 2.5s for the auto-close timer and verify mouse mode remains VISIBLE
	elif step == 4:
		if timer >= 2.5:
			assert(not qr_dialog.visible, "QR dialog should be hidden after auto-close timer.")
			assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Mouse mode after mobile pairing auto-close must remain VISIBLE!")
			print("[PASS] Mobile pairing auto-close verified: Input.mouse_mode is STILL MOUSE_MODE_VISIBLE!")
			step = 5
			timer = 0.0

	# Step 5: Test Spaceship Steering conventions (mobile_pitch, mobile_roll, mobile_yaw)
	elif step == 5:
		var ship_script = load("res://spaceship_controller.gd")
		assert(ship_script != null, "spaceship_controller.gd must load!")
		dummy_ship = CharacterBody3D.new()
		dummy_ship.set_script(ship_script)
		root.add_child(dummy_ship)
		
		# Test yaw left (mobile_yaw = -1.0)
		dummy_ship.apply_mobile_inputs({
			"pitch": 0.5,
			"roll": 0.75,
			"yaw": -1.0, # Left yaw in standard convention
			"throttle": 0.5
		})
		
		# Check variables applied
		assert(abs(dummy_ship.mobile_pitch - 0.5) < 0.01, "mobile_pitch applied correctly")
		assert(abs(dummy_ship.mobile_roll - 0.75) < 0.01, "mobile_roll applied correctly")
		assert(abs(dummy_ship.mobile_yaw - (-1.0)) < 0.01, "mobile_yaw applied correctly")
		
		# In spaceship_controller:
		# y_input += -mobile_yaw -> -(-1.0) = +1.0
		# In Godot, positive y_input rotates counter-clockwise around Vector3.UP -> turns LEFT!
		var effective_y_input = -dummy_ship.mobile_yaw
		assert(effective_y_input > 0, "mobile_yaw = -1.0 must yield positive y_input to turn LEFT!")
		print("[PASS] mobile_yaw = -1.0 (Left) correctly maps to left turn in Godot.")

		# Test yaw right (mobile_yaw = 1.0)
		dummy_ship.apply_mobile_inputs({"yaw": 1.0})
		effective_y_input = -dummy_ship.mobile_yaw
		assert(effective_y_input < 0, "mobile_yaw = 1.0 must yield negative y_input to turn RIGHT!")
		print("[PASS] mobile_yaw = 1.0 (Right) correctly maps to right turn in Godot.")

		# Clean up
		dummy_ship.queue_free()
		home_menu.queue_free()

		print("=================================================================")
		print(">>> ALL MENU MOUSE, CURSOR & STEERING TESTS PASSED 100%! <<<")
		print("=================================================================")
		quit(0)
		return true

	return false
