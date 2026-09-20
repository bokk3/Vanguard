extends SceneTree

func _init() -> void:
	print("--- TESTING GET_AXIS WITH JOYPAD MOTIONS ---")
	
	InputMap.add_action("roll_left")
	var m_l = InputEventJoypadMotion.new()
	m_l.axis = JOY_AXIS_LEFT_X
	m_l.axis_value = -1.0
	InputMap.action_add_event("roll_left", m_l)
	
	InputMap.add_action("roll_right")
	var m_r = InputEventJoypadMotion.new()
	m_r.axis = JOY_AXIS_LEFT_X
	m_r.axis_value = 1.0
	InputMap.action_add_event("roll_right", m_r)
	
	# Emulate stick tilted right 0.75
	var emu = InputEventJoypadMotion.new()
	emu.device = 0
	emu.axis = JOY_AXIS_LEFT_X
	emu.axis_value = 0.75
	Input.parse_input_event(emu)
	Input.flush_buffered_events()
	
	var r_val = Input.get_axis("roll_left", "roll_right")
	print("Analog Stick at +0.75 -> Input.get_axis('roll_left', 'roll_right') = ", r_val)
	
	# Emulate stick tilted left -0.6
	var emu2 = InputEventJoypadMotion.new()
	emu2.device = 0
	emu2.axis = JOY_AXIS_LEFT_X
	emu2.axis_value = -0.6
	Input.parse_input_event(emu2)
	Input.flush_buffered_events()
	
	var l_val = Input.get_axis("roll_left", "roll_right")
	print("Analog Stick at -0.60 -> Input.get_axis('roll_left', 'roll_right') = ", l_val)
	
	quit(0)
