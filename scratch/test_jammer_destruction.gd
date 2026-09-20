extends SceneTree

func _init() -> void:
	print("--- TESTING JAMMING RELAY DESTRUCTION ---")
	
	var mm_script = load("res://mission_manager.gd")
	var mm = Node.new()
	mm.set_script(mm_script)
	root.add_child(mm)
	
	var dummy_root = Node3D.new()
	dummy_root.name = "LevelRoot"
	root.add_child(dummy_root)
	
	mm.current_mission_id = "M02"
	mm.initialize_level(dummy_root)
	
	var relay1 = dummy_root.find_child("JammingRelay_01", true, false)
	assert(relay1 != null, "JammingRelay_01 not found!")
	
	print("Found JammingRelay_01, applying lethal damage...")
	relay1.take_damage(200.0)
	
	print("Targets destroyed count: ", mm.targets_destroyed)
	assert(mm.targets_destroyed == 1, "Expected 1 target destroyed!")
	
	for obj in mm.active_objectives:
		if obj["id"] == "obj_relays":
			print("obj_relays status: ", obj["status"], " current_val: ", obj["current_val"], "/", obj["target_val"])
			assert(obj["current_val"] == 1, "Expected current_val to be 1")
	
	print("--- JAMMING RELAY DESTRUCTION TEST PASSED CLEANLY ---")
	quit(0)
