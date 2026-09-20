extends Control

## MissionSelector: Tactical Sortie Briefing and Mission Selection Modal.
## Displays the 4-mission campaign progression, dossiers, tactical objectives,
## faction badges, and deployment controls.

signal mission_scrambled(mission_id: String)
signal selector_closed()

@onready var mission_list_container: VBoxContainer = find_child("MissionListContainer", true, false)
@onready var scramble_btn: Button = find_child("ScrambleBtn", true, false)
@onready var close_btn: Button = find_child("CloseBtn", true, false)

# Dossier UI Elements
@onready var classification_label: Label = find_child("ClassificationLabel", true, false)
@onready var mission_title_label: Label = find_child("MissionTitleLabel", true, false)
@onready var theater_label: Label = find_child("TheaterLabel", true, false)
@onready var weather_label: Label = find_child("WeatherLabel", true, false)
@onready var narrative_label: Label = find_child("NarrativeLabel", true, false)
@onready var objectives_list_container: VBoxContainer = find_child("ObjectivesListContainer", true, false)
@onready var flight_specs_label: Label = find_child("FlightSpecsLabel", true, false)
@onready var threat_label: Label = find_child("ThreatLabel", true, false)
@onready var status_badge_label: Label = find_child("StatusBadgeLabel", true, false)

@onready var recon_card_rect: TextureRect = find_child("ReconCardRect", true, false)

# Faction crests
@onready var crest_sol: TextureRect = find_child("CrestSol", true, false)
@onready var crest_combine: TextureRect = find_child("CrestCombine", true, false)

var selected_mission_id: String = "M01"
var mission_buttons: Dictionary = {} # id -> Button

# Rich Briefing Dossiers matching Lore Documents
const DOSSIERS = {
	"M01": {
		"codename": "OPERATION CLOUDBURST",
		"classification": "// CLASSIFIED: TOP SECRET // DIRECTORATE AIR DEFENSE COMMAND //",
		"theater": "Sub-Cloud Interception Sector 07 (Ascension Outpost Apex-Zero)",
		"weather": "0740 HRS // Heavy Overcast, Cloud Ceiling 2,800m, Moderate Turbulence",
		"narrative": "At dawn, sensor arrays at high-altitude launch base Apex-Zero detect unauthorized telemetry signatures piercing the dense storm front. The Helion Combine has dispatched autonomous scout drones to probe radar coverage of the equatorial launch corridors. Flight lead Vanguard 1 is scrambled into the clouds to sanitize the sector.",
		"flight_specs": "• Stall Speed: 25.0 m/s | Low-Altitude Cloud Interception\n• Radar Lock-On Envelope: 350m Polar Disc\n• Armament: 4x VPSM-01 Missiles, 20mm Rotary Cannon (1,200 Rnds)",
		"threat_assessment": "• 4x Helion Autonomous Recon Drones (TD-X Marauder)\n• Threat Level: MODERATE // High Evasion Capability"
	},
	"M02": {
		"codename": "OPERATION IRON CANYON",
		"classification": "// CLASSIFIED: SECRET // TACTICAL STRIKE WING //",
		"theater": "The Red Sinks (Canyon Rift Complex, Sector 12)",
		"weather": "1720 HRS // Golden Dusk, Clear Skies, Deep Canyon Shadows",
		"narrative": "Reconnaissance drones from Mission 01 deployed ground-based jamming repeaters along the floor of the Red Sinks canyon, blinding early-warning radars. Vanguard 1 must perform a high-speed canyon run, hugging the terrain beneath 120 meters while destroying three modular transmitter relays without triggering high-altitude SAM grids.",
		"flight_specs": "• Stall Speed: 25.0 m/s | Terrain Masking Required (<120m)\n• Altitude Limit: Exceeding 180m triggers SAM missile battery\n• Recommended Weaponry: 20mm Rotary Autocannon for relay destruction",
		"threat_assessment": "• 3x Helion Modular Jamming Relays (Ground Targets)\n• 4x Canyon Patrol Drones\n• Threat Level: HIGH // Spatial Hazard & SAM Radar Lock"
	},
	"M03": {
		"codename": "OPERATION APEX LIFTOFF",
		"classification": "// CLASSIFIED: PRIORITY ONE // ESCORT COMMAND //",
		"theater": "Equatorial Ascension Catapult Corridor",
		"weather": "0530 HRS // Dawn Horizon, Low Ground Fog, Sky Transitioning to Indigo",
		"narrative": "The heavy orbital transport Olympus-4 is spooling up along the 15-kilometer magnetic catapult rail for an emergency launch. The Helion Combine launches a saturation strike to destroy the transport before it can reach escape velocity. Vanguard 1 and wingman Viper 2 are scrambled as close-in combat air patrol.",
		"flight_specs": "• Stall Speed: 25.0 m/s | High-Speed Intercept\n• Allied Wingman: Lt. Vance Miller (Callsign: Viper 2 in F-82 Viper HD)\n• Propulsion: Utilize Nitro Afterburner (SHIFT) for rapid 2km quadrant transit",
		"threat_assessment": "• 3 Saturation Waves: Skirmishers, Dive Bombers, Heavy Interceptors\n• Protected Target: Olympus-4 Heavy Transport (Must survive)\n• Threat Level: SEVERE // Multiple Vector Saturation"
	},
	"M04": {
		"codename": "OPERATION STRATOSPHERE ZERO",
		"classification": "// CLASSIFIED: EYES ONLY // APEX ACE INTERCEPTION //",
		"theater": "The Karman Boundary (Altitude: 42,000m - 55,000m Mesosphere)",
		"weather": "1200 HRS // Space Zenith (Black Starfield Above, Curving Planet Below)",
		"narrative": "Telemetry traces reveal the Helion swarm's control nexus: a high-apogee command fighter nicknamed the 'Combine Ghost' cruising in the mesosphere. Vanguard 1 executes a maximum-thrust zoom climb into the upper stratosphere to eliminate the enemy flight commander in single combat and shatter the drone network.",
		"flight_specs": "• Stall Speed: 45.0 m/s (-85% Wing Lift in Thin Air / Vacuum)\n• Flight Physics: Post-stall energy vectoring & zoom-and-dive maneuvers\n• Environmental Hazard: Near-zero aerodynamic authority",
		"threat_assessment": "• Adversary Ace: Helion Strike Commander ('Combine Ghost' in Crimson Viper)\n• 4x Elite Guard Escort Drones (Diamond Formation)\n• Threat Level: CRITICAL // Apex Air Superiority Dogfight"
	}
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_node_references()
	hide()
	
	if scramble_btn:
		scramble_btn.pressed.connect(_on_scramble_pressed)
	if close_btn:
		close_btn.pressed.connect(close_selector)
	
	var mm = get_node_or_null("/root/MissionManager")
	if mm:
		mm.campaign_updated.connect(refresh_mission_list)

func _ensure_node_references() -> void:
	if not mission_list_container:
		mission_list_container = find_child("MissionListContainer", true, false)
	if not scramble_btn:
		scramble_btn = find_child("ScrambleBtn", true, false)
	if not close_btn:
		close_btn = find_child("CloseBtn", true, false)
	if not classification_label:
		classification_label = find_child("ClassificationLabel", true, false)
	if not mission_title_label:
		mission_title_label = find_child("MissionTitleLabel", true, false)
	if not theater_label:
		theater_label = find_child("TheaterLabel", true, false)
	if not weather_label:
		weather_label = find_child("WeatherLabel", true, false)
	if not narrative_label:
		narrative_label = find_child("NarrativeLabel", true, false)
	if not objectives_list_container:
		objectives_list_container = find_child("ObjectivesListContainer", true, false)
	if not flight_specs_label:
		flight_specs_label = find_child("FlightSpecsLabel", true, false)
	if not threat_label:
		threat_label = find_child("ThreatLabel", true, false)
	if not status_badge_label:
		status_badge_label = find_child("StatusBadgeLabel", true, false)
	if not crest_sol:
		crest_sol = find_child("CrestSol", true, false)
	if not crest_combine:
		crest_combine = find_child("CrestCombine", true, false)
	if not recon_card_rect:
		recon_card_rect = find_child("ReconCardRect", true, false)

func open_selector() -> void:
	_ensure_node_references()
	var mm = get_node_or_null("/root/MissionManager")
	if mm:
		selected_mission_id = mm.current_mission_id
	refresh_mission_list()
	select_mission(selected_mission_id)
	show()

func close_selector() -> void:
	hide()
	selector_closed.emit()

func refresh_mission_list() -> void:
	var mm = get_node_or_null("/root/MissionManager")
	if not mm:
		return
	
	var all_missions = mm.get_all_missions()
	
	# Clear existing dynamic items if present
	for child in mission_list_container.get_children():
		mission_list_container.remove_child(child)
		child.queue_free()
	mission_buttons.clear()
	
	for i in range(all_missions.size()):
		var m = all_missions[i]
		var id = m.get("id", "")
		var codename = m.get("codename", "")
		var theater = m.get("theater", "")
		var is_unlocked = mm.is_mission_unlocked(id)
		var is_completed = id in mm.completed_missions
		
		var btn = Button.new()
		btn.name = "MissionBtn_" + id
		btn.custom_minimum_size = Vector2(0, 70)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var num_str = "0" + str(i + 1) if (i + 1) < 10 else str(i + 1)
		var status_str = "[ READY ]" if is_unlocked else "[ LOCKED ]"
		if is_completed:
			var stats = mm.completed_missions[id]
			var time_str = str(int(stats.get("elapsed_time", 0))) + "s"
			status_str = "★ CLEARED (" + time_str + ")"
		
		btn.text = "  [%s]  %s\n        %s  |  %s" % [num_str, codename, status_str, theater]
		
		# Button style
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.03, 0.08, 0.14, 0.85)
		style_normal.border_width_left = 3
		style_normal.border_color = Color(0.0, 0.85, 1.0, 0.9) if is_unlocked else Color(0.8, 0.2, 0.2, 0.5)
		style_normal.corner_radius_top_left = 4
		style_normal.corner_radius_bottom_left = 4
		style_normal.content_margin_left = 12.0
		style_normal.content_margin_top = 8.0
		style_normal.content_margin_bottom = 8.0
		
		var style_hover = style_normal.duplicate()
		style_hover.bg_color = Color(0.06, 0.16, 0.26, 0.95)
		style_hover.border_color = Color(1.0, 0.84, 0.0, 1.0)
		
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_font_size_override("font_size", 12)
		
		if not is_unlocked:
			btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 0.7))
		elif is_completed:
			btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3, 1.0))
		else:
			btn.add_theme_color_override("font_color", Color(0.0, 0.92, 1.0, 1.0))
		
		btn.pressed.connect(func(): select_mission(id))
		mission_list_container.add_child(btn)
		mission_buttons[id] = btn

func select_mission(mission_id: String) -> void:
	selected_mission_id = mission_id
	var mm = get_node_or_null("/root/MissionManager")
	if not mm:
		return
	
	var m_manifest = mm.get_mission(mission_id)
	var is_unlocked = mm.is_mission_unlocked(mission_id)
	var is_completed = mission_id in mm.completed_missions
	
	var dossier = DOSSIERS.get(mission_id, {})
	
	# Update Highlight on Selected Button
	for id in mission_buttons.keys():
		var b = mission_buttons[id]
		var sb = b.get_theme_stylebox("normal") as StyleBoxFlat
		if sb:
			if id == selected_mission_id:
				sb.border_width_left = 6
				sb.border_color = Color(1.0, 0.84, 0.0, 1.0)
			else:
				sb.border_width_left = 3
				sb.border_color = Color(0.0, 0.85, 1.0, 0.9) if mm.is_mission_unlocked(id) else Color(0.8, 0.2, 0.2, 0.5)
	
	# Update Dossier Headers
	if classification_label:
		classification_label.text = dossier.get("classification", "// TOP SECRET //")
	if mission_title_label:
		mission_title_label.text = "[%s] %s" % [mission_id, dossier.get("codename", m_manifest.get("codename", ""))]
	if theater_label:
		theater_label.text = "THEATER: %s" % dossier.get("theater", m_manifest.get("theater", ""))
	if weather_label:
		weather_label.text = "CONDITIONS: %s" % dossier.get("weather", "")
	if narrative_label:
		narrative_label.text = dossier.get("narrative", "")
	if flight_specs_label:
		flight_specs_label.text = dossier.get("flight_specs", "")
	if threat_label:
		threat_label.text = dossier.get("threat_assessment", "")
	
	# Update Tactical Reconnaissance Card
	if recon_card_rect:
		var card_path = "res://ui/mission_card_" + mission_id.to_lower() + ".png"
		if ResourceLoader.exists(card_path):
			recon_card_rect.texture = load(card_path)
			recon_card_rect.visible = true
		else:
			recon_card_rect.visible = false
	
	# Status Badge
	if status_badge_label:
		if not is_unlocked:
			status_badge_label.text = "STATUS: [ ACCESS RESTRICTED - PREREQUISITES NOT MET ]"
			status_badge_label.set("theme_override_colors/font_color", Color(1.0, 0.25, 0.25, 1.0))
		elif is_completed:
			var stats = mm.completed_missions[mission_id]
			var t = int(stats.get("elapsed_time", 0))
			var acc = int(stats.get("hit_rate", 1.0) * 100)
			status_badge_label.text = "STATUS: [ SORTIE CLEARED ★★★ ]  |  BEST RECORD: %ds  |  ACCURACY: %d%%" % [t, acc]
			status_badge_label.set("theme_override_colors/font_color", Color(1.0, 0.85, 0.2, 1.0))
		else:
			status_badge_label.text = "STATUS: [ READY FOR HOT SCRAMBLE ]"
			status_badge_label.set("theme_override_colors/font_color", Color(0.1, 1.0, 0.5, 1.0))
	
	# Objectives Checklist
	if objectives_list_container:
		for child in objectives_list_container.get_children():
			objectives_list_container.remove_child(child)
			child.queue_free()
		
		var raw_objs = m_manifest.get("objectives", [])
		for obj in raw_objs:
			var lbl = Label.new()
			var req_tag = "[PRIMARY]" if obj.get("mandatory", true) else "[SECONDARY]"
			lbl.text = "• %s %s" % [req_tag, obj.get("text", "")]
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.92) if obj.get("mandatory", true) else Color(1.0, 0.85, 0.4, 0.9))
			objectives_list_container.add_child(lbl)
	
	# Scramble Button State
	if scramble_btn:
		scramble_btn.disabled = not is_unlocked
		if is_unlocked:
			scramble_btn.text = "  ⚡ SCRAMBLE SORTIE [%s]  " % mission_id
			scramble_btn.tooltip_text = "Deploy immediately to " + dossier.get("codename", "")
		else:
			scramble_btn.text = "  🔒 SORTIE LOCKED  "
			scramble_btn.tooltip_text = "Complete preceding operations to unlock this sortie."

func _on_scramble_pressed() -> void:
	var mm = get_node_or_null("/root/MissionManager")
	if not mm or not mm.is_mission_unlocked(selected_mission_id):
		return
	
	mm.current_mission_id = selected_mission_id
	var sm = get_node_or_null("/root/SaveManager")
	if sm:
		sm.should_load_on_start = false
	
	mission_scrambled.emit(selected_mission_id)
	get_tree().change_scene_to_file("res://main.tscn")
