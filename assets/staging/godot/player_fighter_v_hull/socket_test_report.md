# Project Vanguard: F-77 Player Fighter Pilot Verification Report

> [!IMPORTANT]
> **Staging Quarantine Verification**: All artifacts, meshes, and materials for this pilot are strictly isolated inside `assets/staging/godot/player_fighter_v_hull/`. Zero files were modified or written to `godot_project/` or active production directories.

## 1. Executive Summary
- **Asset Identifier**: `player_fighter_v_hull` (F-77 V-Hull Interceptor)
- **Baseline Model**: `godot_project/Spaceship_Sculpted_V_Hull.glb`
- **Quarantined Staged Model**: `assets/staging/godot/player_fighter_v_hull/player_fighter_v_hull.glb`
- **Review Objective**: Verify 1:1 node tree parity, millimeter socket precision, segmented multi-hull scrape collision physics, and visual fidelity.
- **Overall Status**: **PASSED (100% Contract Compliance)**

## 2. Millimeter Socket Alignment & Contract Audit
Active GDScript (`spaceship_controller.gd`, `hud.gd`, `combat_telemetry.gd`) requires exact socket naming and positions.

| Socket Name | Active In-Engine (X, Y, Z) | Staged Pilot (X, Y, Z) | Delta (mm) | Contract Status |
| :--- | :---: | :---: | :---: | :---: |
| `SOCKET_Chase_Camera` | `(0.00, 3.20, 9.50)` | `(0.00, 3.20, 9.50)` | `0.00 mm` | **PASS** |
| `SOCKET_Cockpit_Camera` | `(0.00, 0.72, -1.85)` | `(0.00, 0.72, -1.85)` | `0.00 mm` | **PASS** |
| `SOCKET_Headlight_L` | `(-1.15, 0.28, -4.55)` | `(-1.15, 0.28, -4.55)` | `0.00 mm` | **PASS** |
| `SOCKET_Headlight_R` | `(1.15, 0.28, -4.55)` | `(1.15, 0.28, -4.55)` | `0.00 mm` | **PASS** |
| `SOCKET_Thruster_L` | `(-0.95, -0.05, 4.75)` | `(-0.95, -0.05, 4.75)` | `0.00 mm` | **PASS** |
| `SOCKET_Thruster_R` | `(0.95, -0.05, 4.75)` | `(0.95, -0.05, 4.75)` | `0.00 mm` | **PASS** |
| `SOCKET_Ventral_Sensor` | `(0.00, -0.72, -2.75)` | `(0.00, -0.72, -2.75)` | `0.00 mm` | **PASS** |
| `SOCKET_Weapon_Hardpoint_01` | `(-3.60, -0.25, 1.80)` | `(-3.60, -0.25, 1.80)` | `0.00 mm` | **PASS** |
| `SOCKET_Weapon_Hardpoint_02` | `(-2.60, -0.25, 1.80)` | `(-2.60, -0.25, 1.80)` | `0.00 mm` | **PASS** |
| `SOCKET_Weapon_Hardpoint_03` | `(2.60, -0.25, 1.80)` | `(2.60, -0.25, 1.80)` | `0.00 mm` | **PASS** |
| `SOCKET_Weapon_Hardpoint_04` | `(3.60, -0.25, 1.80)` | `(3.60, -0.25, 1.80)` | `0.00 mm` | **PASS** |

### Runtime Alias Sockets (Requested by CEObot)
| Alias Socket Name | Staged Coordinate (X, Y, Z) | Target Functionality | Status |
| :--- | :---: | :--- | :---: |
| `SOCKET_Cockpit_View` | `(0.00, 0.72, -1.85)` | 1st Person Cockpit View HUD Camera | **PASS** |
| `SOCKET_Engine_L` | `(-0.95, -0.05, 4.75)` | Port Main Engine Afterburner Particle Emitter | **PASS** |
| `SOCKET_Engine_R` | `(0.95, -0.05, 4.75)` | Starboard Main Engine Afterburner Particle Emitter | **PASS** |
| `SOCKET_Muzzle_L` | `(-0.85, -0.15, -2.60)` | Port Forward Plasma Cannon Projectile Spawn | **PASS** |
| `SOCKET_Muzzle_R` | `(0.85, -0.15, -2.60)` | Starboard Forward Plasma Cannon Projectile Spawn | **PASS** |

## 3. Discrete Visual Props & Material Assignments
| Prop Node Name | Parent | Material Slot | Status |
| :--- | :--- | :--- | :---: |
| `Prop_Headlight_L` | `Spaceship_Sculpted_V_Hull` | `MI_Headlights` | **PASS** |
| `Prop_Headlight_R` | `Spaceship_Sculpted_V_Hull` | `MI_Headlights` | **PASS** |
| `Prop_Thruster_Core_L` | `Spaceship_Sculpted_V_Hull` | `MI_Thrusters` | **PASS** |
| `Prop_Thruster_Core_R` | `Spaceship_Sculpted_V_Hull` | `MI_Thrusters` | **PASS** |

## 4. Multi-Hull Scrape Collision Physics (Commit `0b15f98`)
The single primitive bounding box has been replaced with 4 dedicated convex collision hulls engineered specifically for the canyon wall glancing scrape and spark mechanics:

| Collision Hull (Godot / UE5) | Verts / Faces | Aerodynamic Purpose | Scrape Mechanic |
| :--- | :---: | :--- | :--- |
| `Fuselage-convcol` / `UCX_Fuselage` | 14 / 24 | Centerline lifting body & canopy spine | Deflects head-on strikes into glancing angles |
| `Wing_L-convcol` / `UCX_Wing_L` | 8 / 12 | Port delta wing leading edge | 35° chamfered normal triggers `_trigger_glancing_scrape()` |
| `Wing_R-convcol` / `UCX_Wing_R` | 8 / 12 | Starboard delta wing leading edge | 35° chamfered normal triggers `_trigger_glancing_scrape()` |
| `Ventral_Keel-convcol` / `UCX_Ventral_Keel` | 9 / 14 | Upward-sloping ventral skid runner | Deflects ground-skimming impacts upward away from terrain |

## 5. Visual Diff Sheet
Visual review rendering generated at: `assets/staging/godot/player_fighter_v_hull/visual_diff_sheet.png`.

> [!TIP]
> **Sign-Off Recommendation**: The staged asset satisfies all pilot requirements with zero millimeter drift and 100% node tree parity. Ready for CEObot review and promotion approval.