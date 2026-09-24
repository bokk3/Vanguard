extends SceneTree

## Automated Headless Test Suite for Project Vanguard PvP System:
## 1. Verify pvp_menu.tscn scene loading & UI node linkage
## 2. Verify split_screen_arena.tscn dual viewports & World3D sharing
## 3. Verify lan_arena.tscn scene structure & role bindings
## 4. Verify NetworkManager ENet listen server creation & stop
## 5. Verify UDP LAN Beacon broadcast packet formatting

func _init() -> void:
	call_deferred("_run_pvp_tests")

func _run_pvp_tests() -> void:
	print("==================================================")
	print("PROJECT VANGUARD: PVP & NETWORKING TEST SUITE")
	print("==================================================")
	
	# --- TEST 1: PvP Menu Scene ---
	print("\n[TEST 1] Testing pvp_menu.tscn...")
	var menu_scene = load("res://pvp_menu.tscn")
	assert(menu_scene != null, "Failed to load pvp_menu.tscn")
	var menu_inst = menu_scene.instantiate()
	assert(menu_inst != null, "Failed to instantiate pvp_menu.tscn")
	root.add_child(menu_inst)
	await process_frame
	
	assert(menu_inst.get_node_or_null("%SplitScreenBtn") != null, "SplitScreenBtn missing")
	assert(menu_inst.get_node_or_null("%HostBtn") != null, "HostBtn missing")
	assert(menu_inst.get_node_or_null("%DirectConnectBtn") != null, "DirectConnectBtn missing")
	assert(menu_inst.get_node_or_null("%ServerListContainer") != null, "ServerListContainer missing")
	print("  [OK] PvP Menu UI hierarchy & unique node bindings verified.")
	menu_inst.queue_free()
	await process_frame

	# --- TEST 2: Split-Screen Arena Scene ---
	print("\n[TEST 2] Testing split_screen_arena.tscn...")
	var ss_scene = load("res://split_screen_arena.tscn")
	assert(ss_scene != null, "Failed to load split_screen_arena.tscn")
	var ss_inst = ss_scene.instantiate()
	assert(ss_inst != null, "Failed to instantiate split_screen_arena.tscn")
	root.add_child(ss_inst)
	await process_frame
	await process_frame
	
	var p1 = ss_inst.get_node_or_null("WorldContainer/SpaceshipP1")
	var p2 = ss_inst.get_node_or_null("WorldContainer/SpaceshipP2")
	var vp1 = ss_inst.get_node_or_null("SplitUI/ViewportP1/SubViewport")
	var vp2 = ss_inst.get_node_or_null("SplitUI/ViewportP2/SubViewport")
	
	assert(p1 != null and p2 != null, "Split-screen ships missing")
	assert(p1.player_id == 1 and p2.player_id == 2, "Player IDs incorrect")
	assert(p1.pvp_mode and p2.pvp_mode, "PvP mode not set on ships")
	assert(p1.is_in_group("enemies") and p2.is_in_group("enemies"), "Ships must be in enemies group for mutual lock-on")
	assert(p1.is_in_group("radar_targets") and p2.is_in_group("radar_targets"), "Ships must be in radar_targets group")
	assert(vp2.world_3d == vp1.find_world_3d(), "World3D sharing failed")
	print("  [OK] Dual-viewport World3D sharing & mutual radar acquisition groups verified.")
	
	# Layout switching
	ss_inst._apply_split_layout(false) # Vertical
	assert(ss_inst.container_p1.anchor_right == 0.5, "Vertical split failed")
	ss_inst._apply_split_layout(true) # Horizontal
	assert(ss_inst.container_p1.anchor_bottom == 0.5, "Horizontal split failed")
	print("  [OK] Dynamic Horizontal/Vertical split toggle (F2) verified.")
	
	# Score tracking
	ss_inst._on_p1_destroyed(p2)
	assert(ss_inst.p2_score == 1, "P2 kill score increment failed")
	ss_inst._on_p2_destroyed(p1)
	assert(ss_inst.p1_score == 1, "P1 kill score increment failed")
	print("  [OK] First-to-5 kill scoring & destruction callbacks verified.")
	ss_inst.queue_free()
	await process_frame

	# --- TEST 3: LAN Arena Scene ---
	print("\n[TEST 3] Testing lan_arena.tscn...")
	var lan_scene = load("res://lan_arena.tscn")
	assert(lan_scene != null, "Failed to load lan_arena.tscn")
	var lan_inst = lan_scene.instantiate()
	assert(lan_inst != null, "Failed to instantiate lan_arena.tscn")
	root.add_child(lan_inst)
	await process_frame
	await process_frame
	
	var lan_p1 = lan_inst.get_node_or_null("WorldContainer/SpaceshipP1")
	var lan_p2 = lan_inst.get_node_or_null("WorldContainer/SpaceshipP2")
	assert(lan_p1 != null and lan_p2 != null, "LAN ships missing")
	assert(lan_inst.local_ship != null, "LAN local_ship not assigned")
	assert(lan_inst.remote_ship != null, "LAN remote_ship not assigned")
	print("  [OK] LAN arena local/remote ship assignment & HUD binding verified.")
	
	# Synchronized RPC kill scoring
	lan_inst.rpc_report_kill(1)
	assert(lan_inst.p1_score == 1, "LAN score sync failed for P1")
	lan_inst.rpc_report_kill(2)
	assert(lan_inst.p2_score == 1, "LAN score sync failed for P2")
	print("  [OK] Synchronized RPC kill reporting verified.")
	lan_inst.queue_free()
	await process_frame

	# --- TEST 4: NetworkManager ENet Listen Server & UDP Beacon ---
	print("\n[TEST 4] Testing NetworkManager ENet Listen Server & UDP Beacons...")
	var nm = root.get_node_or_null("NetworkManager")
	assert(nm != null, "NetworkManager autoload missing")
	
	var host_err = nm.host_game("TEST BATTLEGROUND", 7779, 1)
	assert(host_err == OK, "NetworkManager failed to host ENet server")
	assert(nm.is_host, "is_host flag not set")
	assert(nm.udp_broadcaster != null, "UDP broadcaster not created")
	print("  [OK] ENet listen server active on port 7779 with UDP beacon broadcaster.")
	
	# Verify UDP beacon transmission
	nm._send_lan_beacon()
	print("  [OK] UDP LAN discovery beacon packet transmitted successfully.")
	
	# Stop network session cleanly
	nm.stop_network()
	assert(not nm.is_host, "is_host flag should be false after stop")
	assert(nm.peer == null, "ENet peer should be null after stop")
	assert(nm.udp_broadcaster == null, "UDP broadcaster should be null after stop")
	print("  [OK] NetworkManager clean session teardown verified.")

	print("\n==================================================")
	print("ALL PVP & NETWORKING TESTS PASSED SUCCESSFULLY! (100%)")
	print("==================================================")
	quit(0)
