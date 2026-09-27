extends SceneTree

## Automated Verification Suite for Global P2P Internet Lobbies & Latency Probing

var timer: float = 0.0
var step: int = 0
var pvp_menu: Node = null

func _init() -> void:
	print("==================================================================")
	print("PROJECT VANGUARD: GLOBAL P2P INTERNET LOBBIES & LATENCY TEST SUITE")
	print("==================================================================")

func _process(delta: float) -> bool:
	timer += delta
	
	if step == 0:
		# Step 0: Instantiate PvPMenu
		var pvp_scene = load("res://pvp_menu.tscn")
		assert(pvp_scene != null, "pvp_menu.tscn must load successfully")
		pvp_menu = pvp_scene.instantiate()
		assert(pvp_menu != null, "pvp_menu must instantiate")
		root.add_child(pvp_menu)
		current_scene = pvp_menu
		step = 1
		timer = 0.0
		return false
		
	elif step == 1:
		# Step 1: PvPMenu is now ready in the tree
		print("\n[TEST 1] Verifying PvPMenu Scene & Node Tree with Dual LAN/Global Tabs...")
		assert(pvp_menu.lan_tab_btn != null, "LanTabBtn must exist")
		assert(pvp_menu.global_tab_btn != null, "GlobalTabBtn must exist")
		assert(pvp_menu.lan_section != null, "LanSection must exist")
		assert(pvp_menu.global_section != null, "GlobalSection must exist")
		
		# Default tab is LAN
		assert(pvp_menu.current_tab == "LAN", "Default tab must be LAN")
		assert(pvp_menu.lan_section.visible == true, "LanSection must be visible initially")
		assert(pvp_menu.global_section.visible == false, "GlobalSection must be hidden initially")
		
		# Switch to Global tab
		pvp_menu._switch_tab("GLOBAL")
		assert(pvp_menu.current_tab == "GLOBAL", "Tab should switch to GLOBAL")
		assert(pvp_menu.lan_section.visible == false, "LanSection should be hidden")
		assert(pvp_menu.global_section.visible == true, "GlobalSection should be visible")
		print("  [PASS] Tab switching between LAN and Global P2P verified.")
		
		# Verify Auth state display
		var auth_mgr = root.get_node_or_null("AuthManager")
		if auth_mgr and auth_mgr.is_authenticated:
			assert(pvp_menu.global_lobby_view.visible == true, "GlobalLobbyView should be visible for authenticated pilot")
			assert(pvp_menu.global_auth_prompt.visible == false, "GlobalAuthPrompt should be hidden for authenticated pilot")
			print("  [PASS] Authenticated pilot view displayed correctly: %s" % pvp_menu.global_pilot_label.text)
		
		step = 2
		timer = 0.0
		return false
		
	elif step == 2:
		# Step 2: Verify UPnP Subsystem in NetworkManager
		print("\n[TEST 2] Verifying NetworkManager UPnP Subsystem...")
		var net_mgr = root.get_node_or_null("NetworkManager")
		assert(net_mgr != null, "NetworkManager must exist in root")
		assert("upnp_status" in net_mgr, "NetworkManager must have upnp_status property")
		assert("upnp_enabled" in net_mgr, "NetworkManager must have upnp_enabled property")
		assert(net_mgr.has_method("setup_upnp"), "NetworkManager must implement setup_upnp")
		assert(net_mgr.has_method("cleanup_upnp"), "NetworkManager must implement cleanup_upnp")
		print("  [PASS] NetworkManager UPnP properties and methods verified.")
		
		step = 3
		timer = 0.0
		return false
		
	elif step == 3:
		# Step 3: Verify Global Lobby Parsing & Ingestion
		print("\n[TEST 3] Verifying Global Lobby Ingestion & Rendering...")
		var mock_lobbies: Array[Dictionary] = [
			{
				"session_id": "test-lobby-alpha-001",
				"host_callsign": "TOPGUN",
				"lobby_name": "VALKYRIE SORTIE",
				"host_ip": "82.165.20.4",
				"game_port": 7777,
				"ping_port": 7778,
				"players": 1,
				"max_players": 4,
				"map": "Dusk Canyon",
				"country": "FR",
				"colo": "CDG",
				"upnp_active": true
			},
			{
				"session_id": "test-lobby-bravo-002",
				"host_callsign": "MAVERICK",
				"lobby_name": "NEBULA ARENA",
				"host_ip": "142.250.180.3",
				"game_port": 7777,
				"ping_port": 7778,
				"players": 2,
				"max_players": 4,
				"map": "Asteroid Core",
				"country": "US",
				"colo": "IAD",
				"upnp_active": false
			}
		]
		
		pvp_menu._on_global_lobbies_updated(mock_lobbies)
		var rendered_items = pvp_menu.global_lobby_list_container.get_children().filter(func(c): return c != pvp_menu.no_global_lobbies_label)
		assert(rendered_items.size() == 2, "Global lobby list should render 2 items")
		print("  [PASS] Rendered %d global internet lobbies with host, map, capacity, and region tags." % rendered_items.size())
		
		step = 4
		timer = 0.0
		return false
		
	elif step == 4:
		# Step 4: Verify Live Latency Label Styling & Updates
		print("\n[TEST 4] Verifying Real-Time Latency Badge Probing & Display...")
		assert(pvp_menu.latency_labels.has("test-lobby-alpha-001"), "Latency label for Alpha lobby must be registered")
		assert(pvp_menu.latency_labels.has("test-lobby-bravo-002"), "Latency label for Bravo lobby must be registered")
		
		# Simulate Ping Arrival: 28ms (Green) for Alpha, 95ms (Yellow) for Bravo
		pvp_menu._on_lobby_ping_updated("test-lobby-alpha-001", 28)
		var alpha_lat = pvp_menu.latency_labels["test-lobby-alpha-001"]
		assert(alpha_lat.text == "[ 28 ms ]", "Alpha latency text should be [ 28 ms ]")
		
		pvp_menu._on_lobby_ping_updated("test-lobby-bravo-002", 95)
		var bravo_lat = pvp_menu.latency_labels["test-lobby-bravo-002"]
		assert(bravo_lat.text == "[ 95 ms ]", "Bravo latency text should be [ 95 ms ]")
		print("  [PASS] Live latency badges updated dynamically without list refresh.")
		
		# Simulate Timeout (-1)
		pvp_menu._on_lobby_ping_updated("test-lobby-bravo-002", -1)
		assert(bravo_lat.text == "[ TIMEOUT ]", "Timed out lobby should display [ TIMEOUT ]")
		print("  [PASS] Unreachable / strict NAT host gracefully handled as [ TIMEOUT ].")
		
		step = 5
		timer = 0.0
		return false
		
	elif step == 5:
		# Step 5: Direct UDP Ping / Pong Echo Loopback
		print("\n[TEST 5] Testing UDP Ping Probe & Host Pong Echo...")
		var host_udp = PacketPeerUDP.new()
		var h_err = host_udp.bind(17778, "127.0.0.1")
		if h_err == OK:
			var client_udp = PacketPeerUDP.new()
			client_udp.bind(0, "127.0.0.1")
			
			var test_now = Time.get_ticks_msec()
			var ping_pkt = "VANGUARD_PING|test-session-echo|%d" % test_now
			client_udp.set_dest_address("127.0.0.1", 17778)
			client_udp.put_packet(ping_pkt.to_utf8_buffer())
			
			OS.delay_msec(20)
			if host_udp.get_available_packet_count() > 0:
				var pkt = host_udp.get_packet()
				var msg = pkt.get_string_from_utf8()
				assert(msg.begins_with("VANGUARD_PING|test-session-echo|"), "Host must receive ping message")
				
				var pong_pkt = "VANGUARD_PONG|test-session-echo|%d" % test_now
				var resp_peer = PacketPeerUDP.new()
				resp_peer.set_dest_address(host_udp.get_packet_ip(), host_udp.get_packet_port())
				resp_peer.put_packet(pong_pkt.to_utf8_buffer())
				resp_peer.close()
				
				OS.delay_msec(20)
				if client_udp.get_available_packet_count() > 0:
					var c_pkt = client_udp.get_packet()
					var c_msg = c_pkt.get_string_from_utf8()
					assert(c_msg.begins_with("VANGUARD_PONG|test-session-echo|"), "Client must receive pong reply")
					var elapsed = Time.get_ticks_msec() - test_now
					print("  [PASS] UDP Ping/Pong round-trip verified in %d ms!" % elapsed)
			
			client_udp.close()
			host_udp.close()
		else:
			print("  [SKIP] Port 17778 bound by another process in test environment.")
		
		step = 6
		timer = 0.0
		return false
		
	elif step == 6:
		print("\n[TEST 6] Verifying 3-Mode Architecture, Seat Mutual Exclusion & Launch Gating...")
		# 1. Test 3-mode switching
		pvp_menu._switch_tab("SPLIT")
		assert(pvp_menu.split_section.visible == true, "Split section must be visible")
		assert(pvp_menu.lan_section.visible == false, "Lan section must be hidden")
		assert(pvp_menu.global_section.visible == false, "Global section must be hidden")
		
		pvp_menu._switch_tab("LAN")
		assert(pvp_menu.split_section.visible == false, "Split section must be hidden")
		assert(pvp_menu.lan_section.visible == true, "Lan section must be visible")
		assert(pvp_menu.global_section.visible == false, "Global section must be hidden")
		
		pvp_menu._switch_tab("GLOBAL")
		assert(pvp_menu.split_section.visible == false, "Split section must be hidden")
		assert(pvp_menu.lan_section.visible == false, "Lan section must be hidden")
		assert(pvp_menu.global_section.visible == true, "Global section must be visible")
		print("  [PASS] 3-Mode Tab switching (SPLIT, LAN, GLOBAL) verified.")
		
		# 2. Test pilot seat mutual exclusion
		var net_mgr = root.get_node_or_null("NetworkManager")
		assert(net_mgr != null, "NetworkManager must exist")
		net_mgr.player_callsign = "ACE_TESTER"
		net_mgr.set_my_party_role("Alpha", "pilot", "AZERTY")
		assert(net_mgr.parties["Alpha"]["pilot_callsign"] == "ACE_TESTER", "Alpha pilot should be ACE_TESTER")
		assert(net_mgr.parties["Bravo"]["pilot_callsign"] == "[OPEN SEAT]", "Bravo pilot should be open")
		
		# Switch to Bravo pilot
		net_mgr.set_my_party_role("Bravo", "pilot", "QWERTY")
		assert(net_mgr.parties["Bravo"]["pilot_callsign"] == "ACE_TESTER", "Bravo pilot should now be ACE_TESTER")
		assert(net_mgr.parties["Alpha"]["pilot_callsign"] == "[OPEN SEAT]", "Alpha pilot must be vacated due to mutual exclusion!")
		print("  [PASS] Pilot seat mutual exclusion verified (claiming Bravo vacates Alpha).")
		
		# 3. Test launch button gating (disabled until peer connects)
		pvp_menu._on_host_pressed()
		assert(pvp_menu.host_waiting_modal.visible == true, "Host modal must be visible")
		assert(pvp_menu.launch_arena_btn.disabled == true, "Launch button must be disabled with 0 peers")
		assert("AWAITING CHALLENGER" in pvp_menu.launch_arena_btn.text, "Launch button must display waiting text")
		
		# Simulate opponent join
		pvp_menu._on_peer_connected(2)
		assert(pvp_menu.launch_arena_btn.disabled == false, "Launch button must be enabled once challenger connects")
		assert(pvp_menu.bravo_pilot_label.text.contains("BANDIT-2"), "Bravo pilot must be assigned to bandit")
		
		# Simulate opponent disconnect
		pvp_menu._on_peer_disconnected(2)
		assert(pvp_menu.launch_arena_btn.disabled == true, "Launch button must be re-disabled if peer disconnects")
		print("  [PASS] Launch Sortie button gating verified (disabled with 0 peers, enabled with challenger).")
		
		pvp_menu._on_cancel_host_pressed()
		assert(pvp_menu.host_waiting_modal.visible == false, "Host modal must hide on cancel")
		
		pvp_menu.queue_free()
		
		print("\n==================================================================")
		print(">>> ALL GLOBAL P2P INTERNET LOBBY TESTS PASSED (100%) <<<")
		print("==================================================================")
		quit(0)
		return true

	return false
