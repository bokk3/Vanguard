# Changelog

All notable changes to **Project Vanguard** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.1] - 2026-09-27

### Added
- **Global Fleet Leaderboard System (Web & In-Game Client)**:
  - Full-stack Cloudflare D1 serverless edge integration (`/api/leaderboard`) aggregating pilot flight records and sortie debriefs into ranked leaderboards.
  - **Composite Fleet Combat Score**: Ranks pilots using verified telemetry: $\text{Total Score} = \sum \text{Mission Scores} + (\text{Total Kills} \times 500) + (\text{Sorties Completed} \times 100)$, allowing both campaign aces and PvP dogfighters to climb the ranks.
  - **Sortie High Scores & Speedruns**: Individual leaderboards for missions (`M01` through `M08`) tracking completion times down to milliseconds, precision scores, and tactical difficulty (`RECRUIT`, `REGULAR`, `VETERAN`, `ACE`).
  - **In-Game Leaderboard Modal (`leaderboard_dialog.tscn`)**: Direct in-game access via the Intel submenu with live category switching, podium medals (🥇, 🥈, 🥉), authenticated pilot highlight with `(YOU)`, and offline fallback caching.
  - **Web Portal Leaderboard Section (`#leaderboard`)**: Interactive responsive table with live callsign search, category tabs, and personal standing banner linked to the commissioned pilot dossier.
- **Categorized Client Submenu Navigation Architecture**:
  - Completely redesigned `home_menu.tscn` to eliminate vertical button clutter, grouping actions into clean operational submenus:
    - `[ 🚀 01 ] SORTIE OPERATIONS`: Resume Sortie, Mission Selector, Prologue Cutscene.
    - `[ ⚔️ 02 ] MULTIPLAYER ARENA`: Dogfight Arena (Split-Screen / LAN / Global P2P), Mobile HOTAS pairing.
    - `[ 🏆 03 ] FLEET INTEL & RECORDS`: Global Fleet Leaderboard, Combat Stats, Fighter Specs blueprint.
    - `[ ⚙️ 04 ] AVIONICS & CONFIG`: Avionics Configuration (Audio, Video, Controls), Keyboard Layout toggle (AZERTY / QWERTY).
    - `[ 🚪 05 ] ABORT / QUIT`: Clean shutdown.
  - Added dedicated `[ ◀ RETURN TO MAIN OPS ]` navigation buttons in each submenu.
  - Full `ESC` key and gamepad back button hierarchy: collapses open modals and submenus before quitting.
- **Multiplayer Mode Disambiguation & Seat Selection**:
  - Redesigned `pvp_menu.tscn` to cleanly partition multiplayer modes into 3 clear operational theaters: Local Split-Screen (single device), Local LAN Subnet (multiple devices on subnet), and Public Internet P2P Lobbies.
  - Enforced mutual exclusion on pilot seat assignments (claiming Pilot Bravo automatically vacates Pilot Alpha).
  - Gated match launch on peer presence, preventing accidental solo launches in multiplayer sessions.

---

## [0.9.0] - 2026-09-27

### Added
- **Global Internet P2P Lobby Directory & Matchmaking**:
  - Worldwide multiplayer matchmaking directory allowing authenticated pilots to publish combat lobbies to the global fleet radar.
  - 100% direct peer-to-peer gameplay: flight physics, transforms, bullets, and missiles travel directly between host and client over UDP/ENet on port 7777 with zero latency inflation and 0 bytes routed through Cloudflare.
  - Dedicated Cloudflare edge API endpoint `GET /api/network/lobbies` with 4-second caching to serve global lobbies with minimal resource consumption.
  - Automatic public WAN IP and edge geolocation discovery via `cf-connecting-ip` and `request.cf` headers.
- **Asynchronous UPnP Router Auto-Port-Mapping**:
  - Built-in `UPNP` background thread automatically discovers the player's home router gateway and maps UDP ports 7777 (Game) and 7778 (Ping) with zero manual router setup.
  - Real-time router status badge (`UPNP: ACTIVE (PORT 7777 UDP)`, `NO GATEWAY`, or `PORT MAP REJECTED`) displayed in the UI and waiting modal.
  - Graceful cleanup on session end or game exit.
- **Real-Time Return Latency (Ping) Probing**:
  - Direct 12-byte UDP ping probes (`VANGUARD_PING`) sent from client to host on port 7778.
  - Host's UDP socket immediately echoes back `VANGUARD_PONG`, allowing the client to measure exact millisecond round-trip time.
  - Color-coded real-time latency badges in the lobby directory: Emerald Green (< 60 ms), Yellow (60-120 ms), Amber (> 120 ms), or `[ TIMEOUT ]` for strict NAT/CGNAT.
- **Redesigned Dual-Mode Tactical PvP Portal**:
  - Mode tab switcher: `[ 📡 LOCAL LAN SUBNET ]` $\longleftrightarrow$ `[ 🌐 GLOBAL FLEET RADAR (P2P) ]`.
  - Integrated pilot credential verification gate with direct access to cloud authentication and registration dialog.
  - Robust IP endpoint parsing supporting standard IPv4 (`192.168.1.1:7777`), bare IPs, and bracketed IPv6 addresses (`[2001:db8::1]:7777`).

---

## [0.8.6] - 2026-09-27

### Added
- **Machine Gun Lead Aim Assist & Proximity Fuse**:
  - Dynamic trajectory magnetization (`gun_aim_assist_cone_deg: 16.0°`, `gun_aim_assist_max_dist: 900.0m`) with target lead intercept calculation taking into account target velocity and bullet velocity (650 m/s).
  - Kinetic proxy fuse proximity sweep (`radius = 0.85m`) in `bullet.gd`, eliminating high-speed tunneling through thin 3D meshes.
- **Dynamic Combat Drone AI & Lead Gunfire**:
  - `target_drone.gd` and `boss_combine_ghost.gd` now dynamically calculate first-order lead targeting against moving player ships instead of firing at stale positions.
  - Tightened drone dispersion cone and introduced rapid double-tap burst salvos for authentic aerial threat.

### Fixed
- **Mobile HOTAS Gyroscope Pitch Inversion & Tare**:
  - Fixed 2D screen gravity matrix in `website/src/controller.js` (`sx = gx*cos + gy*sin`, `sy = -gx*sin + gy*cos`), resolving pitch polarity inversion in landscape orientation where pulling back pitched downward.
  - Added instantaneous mid-flight zero calibration (`performTareZero`) that zeroes active hold angles in 0ms without waiting for async sensor events.
- **Mobile HOTAS Sortie-to-Sortie Scene Persistence**:
  - Automatic `Spaceship` registration on `_ready()` and clean unregistration on `_exit_tree()` with `NetworkControllerServer`.
  - Added fallback routing to active player flight elements in single-player sorties, preventing controller disconnections across mission transitions.

---

## [0.8.5] - 2026-09-27

### Added
- **Custom Vanguard Text Logo Boot Splash**:
  - Replaced the default Godot engine boot splash with the crisp `res://ui/project_vanguard_title.png` logo.
  - Deep space navy background (`Color(0.015, 0.025, 0.045, 1)`) matching Vanguard UI palette with 1.0s minimum presentation time.

### Changed
- **Menu & Authentication Streamlining**:
  - Redesigned `login_dialog.tscn`: larger panel, clearer status readouts, prominent primary "PLAY" action, and "QUICK PLAY (GUEST)" / "CLOUD LOGIN" toggles.
  - Removed intrusive post-login mode selector dialog popup; pilots transition directly to the Hangar operations hub.
  - Renamed dogfight button to "MULTIPLAYER / SPLIT-SCREEN" with explicit menu-driven launch.
- **Website Enhancements**:
  - Platform-aware download buttons automatically detecting Windows, Linux, or macOS.

---

## [0.8.2] - 2026-09-26

### Added
- **Fleet Operations Presence & Global Network Counters**:
  - Cloudflare Edge Serverless Presence Engine (`/api/network/stats`, `/api/network/heartbeat`, `/api/network/leave`) tracking registered pilots, online pilots, and active PvP lobbies.
  - Added `active_sessions` table in Cloudflare D1 with automatic TTL sweeping for ephemeral active presence.
  - **Website Live Fleet Radar**:
    - Sticky top telemetry ticker displays live `ONLINE`, `LOBBIES`, and `ROSTER` counts.
    - Hero section features a dedicated live **Fleet Radar Operations Bar** with emerald pulse glow.
    - Automatic web visitor presence heartbeat with graceful `navigator.sendBeacon` disconnection on unload.
  - **Client In-Game Fleet Telemetry**:
    - `home_menu.tscn`: Sidebar **Fleet Radar Box** displaying active pilots in sortie, open combat lobbies, and total commissioned roster.
    - `mode_selector_dialog.tscn`: Live fleet radar indicator informing pilots of active lobbies before selecting Solo vs Online.
    - `pvp_menu.tscn`: Live battlespace radar counters integrated directly into the PvP dogfight hub.
- **Avionics & Cockpit Polish**:
  - High-G blackout / redout radial vignette gradient replacing hard rectangular borders with smooth, hardware-accelerated falloff.
  - Tactical HUD G-LOC caution readout with load meter (`// G-LOC CAUTION // LOAD: +6.2 G //`).
  - Pilot dossier and credentials management directly accessible from Hangar home menu.

## [0.8.0] - 2026-09-24

### Added
- **Campaign Dynamic Drop-In Split-Screen Co-Op**:
  - Single-player sorties begin in standard full-screen across all 8 campaign missions.
  - Player 2 joins dynamically in real time upon verified secondary control keypress (action `P2_ACTIONS`, gamepad `device >= 1`, or secondary keyboard cluster `IJKL`, `Enter`, NumPad).
  - Runtime `CoopSplitLayer` builds dual `SubViewport`s sharing the active campaign `World3D`, rendering all mission entities without physics or rendering desync.
  - Wingman Vanguard-2 spawns in formation alongside Player 1 (`Vector3(22, 0, -6)` offset) with distinct Solar Amber / Gold wingman livery and matching thruster glow.
  - Dynamic split layout toggle via <kbd>F2</kbd> (Horizontal Top/Bottom $\leftrightarrow$ Vertical Left/Right).
  - Hostile combat drones and bosses dynamically calculate proximity across all active flight elements in group `"player"` and engage the closest target.
  - 5-second wingman field respawn loop: destruction of a single aircraft initiates an emergency repair sequence near the surviving wingman; sortie terminates with `SORTIE_WIPED` only if both flight elements are lost.
- **Local Split-Screen PvP Dogfight Arena**:
  - Dedicated 1v1 canyon dogfight arena (`split_screen_arena.tscn`) with first-to-5 confirmed kills victory condition.
  - Dual independent cameras and tactical HUD overlays (`TacticalOverlay`) bound to each respective fighter without viewport state bleeding.
  - Mutual radar tracking and missile lock-on against opponent.
  - Kill banners and score tracking.
- **LAN Peer-to-Peer / Network Dogfight Arena**:
  - High-performance ENet multiplayer architecture on UDP port 7779 with host listen server authority.
  - Autonomous zero-configuration UDP discovery beacons on port 7778 for local server discovery.
  - Snapshot synchronization and 20Hz linear interpolation smoothing remote craft movement.
  - Synchronized RPC machine gun bursts, missile tracking, and damage events.
- **PvP Matchmaking & Lobby Hub (`pvp_menu.tscn`)**:
  - Dedicated PvP hub accessible from the Home Menu for hosting LAN servers, scanning local games, connecting directly via IP, or launching local split-screen arenas.
- **Comprehensive Multiplayer Documentation**:
  - Dedicated architecture and engineering manual: `docs/MULTIPLAYER_AND_COOP_SYSTEM.md`.
  - Updated `docs/CONTROLS_AND_PHYSICS.md`, `docs/HUD_AND_COMBAT_SYSTEM.md`, `docs/FEATURE_LIST_AND_UE5_PORT_GUIDE.md`, and `README.md`.

## [0.7.4] - 2026-09-21

### Added
- **Hostile Drone Weapons Fire & Combat Dynamics**:
  - Enemy drones fire deliberate, sporadic crimson rounds (`Color(1.0, 0.2, 0.1)`) with dynamic omni-light illumination.
  - Inaccuracy spread calibrated so shots realistically whiz past the cockpit ($0.14\text{ rad}$ on Cadet, $0.08\text{ rad}$ on Veteran, $0.035\text{ rad}$ on Ace).
  - Progressive damage escalation across sorties ($3.0\text{ HP}$ in M01 up to $12.5\text{ HP}$ in M08) scaled by difficulty ($0.5\times$, $1.0\times$, $1.5\times$).
  - Full player damage pipeline: shields absorb incoming fire first before hull bleed, accompanied by camera trauma shudder, controller rumble haptics, scrape SFX, and HUD tactical alerts.
  - Spatialized 3D cannon audio on the `Weapons` bus.
- **Cinematic Sortie Launch & Logo Fly-Through**:
  - Smooth camera animation swooping through the Vanguard 3D logo into hyperspace cutscene.
  - Seamless loop integration for menu music (`menu_soundscape.mp3`) with dynamic fade-out upon sortie departure.
  - Mandatory prologue cutscene presentation when deploying M01.
- **Settings Data & Storage Management**:
  - Dedicated "Data & Storage" tab in the Settings interface.
  - Factory reset functionality reverting controls, sensitivity, audio volumes, and display presets.
  - Save purge utility clearing `user://saves/` and resetting campaign progress.
- **Collision Physics & Flight Mechanics**:
  - Catastrophic high-speed terrain/obstacle impacts vs glancing deflection scrapes.
  - Tuned boss dogfight flight envelope and wingman maneuverability.

## [0.7.0] - 2026-09-20

### Added
- **Live Guided Missile Launch System**:
  - Standalone projectile scene (`res://missile.tscn` & `missile.gd`) leveraging `Vanguard_Strike_Missile.fbx`.
  - Realistic rocket kinematics: initial launch ejection impulse + forward acceleration to $210\text{ m/s}$ ($756\text{ km/h}$).
  - Particle exhaust FX: high-temperature orange/white flame core + persistent expanding smoke contrail trailing in world space + dynamic exhaust light.
  - Proportional navigation homing guidance smoothly steering towards the target acquired by `CombatTelemetry`.
  - Impact detonation triggering `res://explosion_fx.tscn` and applying $50.0$ explosive damage.
  - Procedural rocket motor launch audio synthesis via `AudioStreamWAV`.
- **Under-Wing Weapon Hardpoints & Rack Visuals**:
  - Decoupled floating static missiles from the base airframe in `Spaceship_Sculpted_V_Hull.glb` via Blender headless.
  - Added 4 dedicated aerodynamic pylon hardpoints mounted flush under the wings:
    - Station 01 (Left Outer): `(-3.20, -0.22, 1.20)`
    - Station 02 (Left Inner): `(-2.20, -0.26, 0.40)`
    - Station 03 (Right Inner): `(2.20, -0.26, 0.40)`
    - Station 04 (Right Outer): `(3.20, -0.22, 1.20)`
  - Alternating launch sequence (1 $\rightarrow$ 4 $\rightarrow$ 2 $\rightarrow$ 3) maintaining aerodynamic weight balance.
  - Real-time hardpoint rack visibility synchronization: firing a missile physically detaches and hides it from the wing rack.
  - Integrated underwing hardpoint display into the Home Menu showroom turntable fighter.
- **Cinematic 3D Explosion FX** (`res://explosion_fx.tscn` & `explosion_fx.gd`):
  - High-intensity flash `OmniLight3D`, expanding shockwave torus ring, 45-shard debris particle blast, and synthetic low-frequency explosion rumble audio.
- **Target Drone Hit Reactions & Destruction/Respawn Loop**:
  - Equipped `target_drone.gd` with an `Area3D` collision hitbox.
  - Visual hit reaction: white-hot emissive flash upon taking damage.
  - Health progression ($100 \rightarrow 50 \rightarrow 0\text{ HP}$).
  - On destruction ($0\text{ HP}$): triggers cinematic explosion, disables collision/radar tracking, and respawns after $4.0\text{ seconds}$ at a new patrol orbit.
- **Tactical HUD Target Health & Hitmarker Feedback**:
  - Segmented tactical health bar displayed above target tracking brackets with dynamic color-coding.
  - Tactical crosshair hitmarker `X` flash upon confirmed hit.
  - On-screen combat event notifications (`// MISSILE AWAY //`, `// DIRECT HIT: -50 HP //`, `// TARGET DESTROYED //`).
- **Missile Cooldown Auto-Reload & Beacon Resupply**:
  - Automatic progressive ordnance restock cycle ($6.5\text{s}$ cooldown per missile) restocking empty wing racks sequentially.
  - Interactive HUD ordnance bay charging bar displaying real-time reload percentage (`ARMING 65%`).
  - Proximity-based full ordnance refill: flying within $75\text{m}$ of `NavBeaconAlpha` triggers an instant $4/4$ resupply with tactical HUD audio/visual confirmation (`// NAV BEACON RESUPPLY // ALL ORDNANCE RESTOCKED //`).
  - Wing hardpoint models physically reappear in sequence as missiles restock.

---

## [0.6.0] - 2026-09-20

### Added
- **Interactive In-Game Key Remapping**:
  - Dedicated **Controls & Keybindings** tab in `settings_menu.tscn`.
  - Dynamic remapping table for all 10 avionics and combat flight actions (`throttle_up`, `throttle_down`, `yaw_left`, `yaw_right`, `roll_left`, `roll_right`, `pitch_up`, `pitch_down`, `boost`, `fire_missile`, `toggle_radar`).
  - Interactive modal key-capture prompt (`[ PRESS ANY KEY... / ESC TO CANCEL ]`) with physical/hardware scancode resolution.
  - Quick-preset buttons: `[ PRESET: AZERTY (BELGIAN) ]` and `[ PRESET: QWERTY (STANDARD) ]`.
- **UE5 Porting Guide & Feature Inventory** (`docs/FEATURE_LIST_AND_UE5_PORT_GUIDE.md`):
  - Comprehensive feature matrix contrasting Godot 4.x implementations with Unreal Engine 5.4/5.5 equivalents.
  - Technical porting blueprint detailing Pawn & Movement Component architecture, Enhanced Input System (`UInputMappingContext`, `UInputAction`), Slate/UMG material radar shaders, `USaveGame` binary/JSON persistence, and DCC asset pipelines.

### Changed
- **Flight Control Overhaul**:
  - `Left / Right Arrow` keys now command turn / yaw (reorienting ship heading horizontally).
  - `Q / D` keys dedicated to banking / roll (with AZERTY/QWERTY aware defaults).
  - `Z / S` keys manage throttle forward / reverse brake.
  - `Up / Down Arrow` keys handle pitch elevation / dive.
  - **Preserved Mouse Steering**: Mouse X/Y retains full analog yaw and pitch agility with user-configurable sensitivity and pitch inversion.
  - Refactored `spaceship_controller.gd` to purely consume Godot `InputMap` actions (`Input.get_axis()`, `Input.is_action_pressed()`), paving the way for upcoming Gamepad / HOTAS flight stick controllers.

---

## [0.5.0] - 2026-09-20

### Added
- **Persistent Save Game System**:
  - Central `SaveManager` autoload managing human-readable JSON saves in `user://saves/vanguard_savegame.json`.
  - Full serialization of player flight position, rotation, velocity, shields, hull, nitro capacitor, and missile ordnance.
  - World state serialization for enemy drones and objective beacons.
- **Home Menu Save & Continue Integration**:
  - `[ 01 ] CONTINUE SORTIE` button with automatic save detection.
  - Active sortie profile metadata displayed on the sidebar (timestamp, hull integrity, ordnance status).
- **Pause Menu Save & Load**:
  - `[ 02 ] SAVE SORTIE` with tactical animated confirmation toast (`// SORTIE SAVED // SECURE SYNC COMPLETE`).
  - `[ 03 ] LOAD LAST SAVE` with instant in-flight state restoration.
- **Formalized Version Tracking**:
  - Root `VERSION` file and `config/version="0.5.0"` in `project.godot`.
  - Dynamic in-game version resolution via `ProjectSettings`.

---

## [0.4.0] - 2026-09-20

### Added
- **Home Menu & Eerie White Hangar Construct**:
  - 3D minimalist showroom hangar with reflective glossy floor, cleanroom lighting, and turntable platform.
  - Active repair FX: moving holographic cyan laser scan ring and nanite weld spark particles.
  - Left-aligned military sci-fi sidebar with tactical insignia, stats, and sound-ready buttons.
- **Tactical In-Game Pause Menu**:
  - Flight suspension via `ESC` key releasing mouse capture and presenting tactical override options.
  - Integrated 404th Vanguard Strike Wing transparent badge and button iconography.
- **Centralized Configuration System (`ConfigManager`)**:
  - Persistent preferences stored in `user://settings.cfg`.
  - Controls calibration: AZERTY/QWERTY toggle, mouse sensitivity slider, pitch inversion, gravity compensation.
  - Audio and display settings management.

---

## [0.3.0] - 2026-09-20

### Added
- **Tactical Military Sci-Fi HUD & Combat Telemetry**:
  - Top compass horizon ribbon (`0°..360°`) plotting red hostiles and gold mission objectives.
  - Toggleable circular radar disc (`R` key) with 100m, 200m, and 300m range rings.
  - Target tracking and missile lock-on FSM with forward-cone acquisition and off-screen edge chevrons.
  - Nitro / afterburner capacitor with 3.0s overheat lockout penalty.
  - Unified shield & hull health pools with test damage simulation (`H` key).
  - Adaptive Belgian AZERTY keyboard auto-detection on Windows (`F1` toggle).

---

## [0.2.0] - 2026-09-19

### Added
- **Asset Factory & Automation Suite**:
  - Headless Blender pipeline with automated Smart UVs, convex collision hull (`UCX_`) generation, and UE5 coordinates.
  - PBR texture processor with normal map generator and ORM (Ambient Occlusion, Roughness, Metallic) packer.
  - Unreal Engine 5 remote execution client and procedural modular level generator.

---

## [0.1.0] - 2026-09-18

### Added
- **Initial Project Architecture**:
  - High-poly sculpted V-hull fighter concept and game-ready FBX export.
  - Antigravity ↔ Fusion 360 & Blender live network bridge servers.
  - Git repository structure with Git LFS tracking for 3D and texture binaries.
