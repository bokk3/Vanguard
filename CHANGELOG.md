# Changelog

All notable changes to **Project Vanguard** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

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
