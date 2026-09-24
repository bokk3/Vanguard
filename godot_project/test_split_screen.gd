extends SceneTree

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("Testing split_screen_arena.tscn instantiation...")
	var scene = load("res://split_screen_arena.tscn")
	if not scene:
		print("FAIL: Could not load split_screen_arena.tscn")
		quit(1)
		return
	
	var inst = scene.instantiate()
	if not inst:
		print("FAIL: Could not instantiate split_screen_arena.tscn")
		quit(1)
		return
	
	root.add_child(inst)
	print("  [OK] Scene instantiated and added to root.")
	
	await process_frame
	await process_frame
	
	# Verify ships
	var p1 = inst.get_node_or_null("WorldContainer/SpaceshipP1")
	var p2 = inst.get_node_or_null("WorldContainer/SpaceshipP2")
	assert(p1 != null, "SpaceshipP1 missing")
	assert(p2 != null, "SpaceshipP2 missing")
	assert(p1.player_id == 1, "P1 player_id wrong")
	assert(p2.player_id == 2, "P2 player_id wrong")
	assert(p1.is_split_screen, "P1 is_split_screen not set")
	assert(p2.is_split_screen, "P2 is_split_screen not set")
	print("  [OK] Player 1 and Player 2 configured correctly.")
	
	# Verify viewports sharing
	var vp1 = inst.get_node_or_null("SplitUI/ViewportP1/SubViewport")
	var vp2 = inst.get_node_or_null("SplitUI/ViewportP2/SubViewport")
	assert(vp1 != null and vp2 != null, "Viewports missing")
	assert(vp2.world_3d == vp1.find_world_3d(), "World3D not shared")
	print("  [OK] Dual SubViewports sharing World3D verified.")
	
	# Test layout toggle
	inst._apply_split_layout(false)
	assert(inst.container_p1.anchor_right == 0.5, "Vertical split layout container 1 failed")
	assert(inst.container_p2.anchor_left == 0.5, "Vertical split layout container 2 failed")
	inst._apply_split_layout(true)
	assert(inst.container_p1.anchor_bottom == 0.5, "Horizontal split layout container 1 failed")
	assert(inst.container_p2.anchor_top == 0.5, "Horizontal split layout container 2 failed")
	print("  [OK] Dynamic Horizontal/Vertical layout switching verified.")
	
	# Test destruction and scoring
	inst._on_p1_destroyed(p2)
	assert(inst.p2_score == 1, "P2 score should be 1")
	inst._on_p2_destroyed(p1)
	assert(inst.p1_score == 1, "P1 score should be 1")
	print("  [OK] Kill scoring logic verified.")
	
	print("ALL SPLIT-SCREEN TESTS PASSED!")
	quit(0)
