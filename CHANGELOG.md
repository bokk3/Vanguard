# Changelog

All notable changes to **Project Vanguard** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
