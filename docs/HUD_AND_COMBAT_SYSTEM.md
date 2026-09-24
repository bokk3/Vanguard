# Vanguard Tactical HUD & Combat Telemetry System

A military sci-fi Heads-Up Display (HUD) and decoupled combat telemetry architecture built for high-speed spaceflight and dogfighting. Implemented natively in Godot 4.x and architected for seamless porting to Unreal Engine 5 (UMG / Slate / Niagara).

---

## 1. Architectural Overview

The combat HUD is built around strict separation between **telemetry simulation** (flight logic, locking FSM, capacitor math) and **visual presentation** (vector canvas rendering, SVG widgets).

```mermaid
flowchart TD
    subgraph Simulation [Data & Telemetry Layer]
        CT[CombatTelemetry Node]
        SC[Spaceship Flight Controller]
        SC -->|Requests Boost / Fires Weapons| CT
        Targets[Entities in radar_targets & enemies] -.->|World Positions| CT
    end

    subgraph Presentation [Presentation Layer]
        HUD[HUD TacticalOverlay (Control)]
        CT -->|Shield, Hull, Nitro, Lock State| HUD
        Camera3D[Camera3D] -->|unproject_position| HUD
        HUD -->|Compass Ribbon| DrawTape[Top Compass Tape]
        HUD -->|Polar Projection| DrawRadar[Circular Radar Disc]
        HUD -->|Screen Projection| DrawBrackets[Dynamic Target Lock Box]
        HUD -->|Vitals & Ordnance| DrawPanels[Shield, Hull, Nitro & Ammo]
    end
```

---

## 2. In-Game Controls & Keybindings

The controller dynamically auto-detects keyboard layout (`AZERTY` on Belgian/French systems, `QWERTY` elsewhere) at startup and supports runtime switching:

| Function | AZERTY Binding | QWERTY Binding | Additional Controls |
| :--- | :--- | :--- | :--- |
| **Throttle Forward** | `Z` | `W` | Physical Scancode `KEY_W` |
| **Brake / Reverse** | `S` | `S` | Smooth deceleration |
| **Roll Left / Right** | `Q` / `D` | `A` / `D` | Aileron banking |
| **Yaw Rudder** | `A` / `E` | `Q` / `E` | Horizontal yaw turning |
| **Pitch Nose** | Mouse Y / `Up` / `Down` | Mouse Y / `Up` / `Down` | Inverted or direct flight stick |
| **Nitro Afterburner** | `L-SHIFT` (Hold) | `L-SHIFT` (Hold) | Drains Nitro Capacitor |
| **Fire Missile** | `SPACE` or `ENTER` | `SPACE` or `ENTER` | Requires Missile Lock |
| **Toggle Radar Style** | `R` | `R` | Toggles Circular Radar Disc |
| **Damage Test Hit** | `H` | `H` | Simulates -25 HP hit on Shields/Hull |
| **Toggle AZERTY/QWERTY**| `F1` | `F1` | Instant layout switch |
| **Release / Capture Mouse**| `ESC` | `ESC` | Unlocks cursor |

---

## 3. Core HUD Components

### 3.1 Top Compass Horizon Ribbon
* **Visual Anchor:** Positioned at top-center of the screen.
* **Heading Tape:** Ticks every 15°, labeled with cardinal headings (`N`, `E`, `S`, `W`) and numerical degrees (`000°` - `359°`).
* **Target Beacons:**
  * **Hostiles / Enemies:** Marked in Tactical Crimson Red (`#FF1744`) with downward indicator chevrons.
  * **Objectives / Beacons:** Marked in Mission Gold (`#FFD700`) with diamond markers.
* **Bearing Angle:** Dynamically mapped relative to the player's forward nose vector.

### 3.2 Toggleable Circular Radar Disc
* **Activation:** Toggled on/off at any time using the `R` key.
* **Projection:** Polar top-down radar projection centered on the player craft.
* **Range Rings:** Concentric rings representing 100m, 200m, and 300m range boundaries.
* **Relative Elevation Blips:** Displays azimuth and distance to all targets within 350m radius.

### 3.3 Dynamic Screen-Space Target Lock-On System
* **Acquisition Cone:** Evaluates all active hostile entities within a 45° forward view cone.
* **Screen Projection:** Translates 3D world coordinates to 2D screen coordinates using `Camera3D.unproject_position()`.
* **Lock State Machine:**
  1. **Acquiring (0% - 99%):** Segmented cyan bracket with circular loading reticle that fills over 1.4 seconds.
  2. **Solid Lock (100%):** Brackets contract into high-contrast crimson/gold locked box with diamond lead reticle.
  3. **Off-Screen Tracking:** If the target maneuvers off-screen, directional chevrons lock to the viewport edge pointing toward the target with distance indicators.

### 3.4 Nitro & Afterburner Capacitor
* **Capacity:** 100 units max.
* **Drain Rate:** 24 units/sec (~4.2 seconds of continuous afterburner thrust).
* **Recharge Rate:** 18 units/sec (~5.5 seconds recovery time).
* **Overheat Penalty:** If capacitor hits 0%, an emergency overheat lockout locks afterburner for 3.0 seconds accompanied by a flashing red visual alarm.

### 3.5 Unified Shield & Hull Vitals Panel
* **Shield Halo:** 100 HP max, regenerates automatically at 15 HP/sec after 4 seconds of taking no damage.
* **Hull Core:** 100 HP max structural integrity. Absorbs kinetic damage when shields deplete.
* **Testing Key:** Press `H` to inflict simulated 25 HP damage and observe shield depletion, flash response, and regenerative recharge.

### 3.6 Ordnance Bay
* **Vanguard Strike Missiles:** 4x ready rack. Displays missile status (armed, locked, fired).
* **20mm Rotary Cannon:** Real-time ammunition counter.

---

## 4. Cross-Engine Porting Guide (Unreal Engine 5)

This HUD was designed to port 1:1 into Unreal Engine 5:

| Godot 4 System | Unreal Engine 5 Equivalent |
| :--- | :--- |
| `godot_project/combat_telemetry.gd` | `UCombatTelemetryComponent` (`UActorComponent`) |
| `godot_project/hud.gd` | `UVanguardHUDWidget` (`UUserWidget` or Common UI) |
| Vector `_draw()` primitives | UMG Retainer Box with Slate Vector Brushes or Dynamic Material Instances |
| `assets/ui/reticle_bracket.svg` | SVG imported as Vector Texture or Slate SVG Brush |
| `assets/ui/ship_paperdoll.svg` | UMG Paperdoll Image widget with dynamic material scalar parameters for shield/hull |
| `camera.unproject_position()` | `APlayerController::ProjectWorldLocationToScreen()` |
| Radar group query | `UAIPerceptionComponent` or `GetOverlappingActors` with gameplay tags |

---

## 5. Multi-Player & Split-Screen HUD Telemetry

### Dual-Viewport Avionics Binding
To support split-screen dogfights and campaign drop-in co-op without telemetry cross-talk, the HUD system uses dynamic instance binding:
```gdscript
hud_instance.bind_to_ship(ship_node, camera_node, player_id)
```
- **Independent Viewport Rendering:** Each player's HUD is embedded inside their respective `SubViewport/HUD` `CanvasLayer`, ensuring reticle unprojection calculations (`unproject_position`) use that player's viewport camera and aspect ratio.
- **Player Identification & Color Theming:**
  - **Player 1 (Flight Lead):** Cyan/Sky Blue tactical instrumentation (`#00E5FF`).
  - **Player 2 Co-Op Wingman:** Solar Amber/Gold avionics (`#FFB300`) with wingman formation telemetry.
  - **Player 2 PvP Aggressor:** Crimson/Amber dogfight avionics (`#FF3D00`) with direct lock-on against Player 1.

### Multi-Target Radar Symbology
The 350m tactical radar identifies all contacts in 3D battlespace:
- **Crimson Diamond (`#FF2638`):** Hostile combat drones, strike craft, and PvP opponents in group `"enemies"`.
- **Amber Cross (`#FFB300`):** Friendly wingman (Player 2) in group `"player"` / `"radar_targets"`.
- **Emerald Chevron (`#00E676`):** Friendly mission targets (e.g. Olympus-4 transport, SOC Dauntless).
- **Gold Ring (`#FFD700`):** Tactical navigation beacons and canyon pylon gates.

### Damage Pipeline & Combat Feedback
Incoming hostile rounds and collisions process through an integrated multi-sensory feedback pipeline:
1. **Shield Absorption:** Shields deplete first (`telemetry.current_shield`).
2. **Hull Bleed:** Damage beyond available shields damages the structural hull (`telemetry.current_hull`).
3. **Cockpit Trauma:** Screen trauma shaking scales up to `1.0` and decays smoothly.
4. **Haptic Rumble:** Direct gamepad rumble pulse (`cfg.play_rumble(weak, strong, duration, device_id)`).
5. **HUD Alarm:** Flashes red warning banner: `// WARNING: HIT -X HP //`.

### Co-Op Field Respawn System
In campaign co-op sorties, catastrophic destruction of a single aircraft does not trigger mission failure. A 5-second emergency airframe repair countdown begins on the downed player's HUD. Upon completion, the wingman respawns in formation alongside the surviving flight lead with full shields, repaired hull, and replenished ordnance. Only the loss of both flight elements fails the sortie (`SORTIE_WIPED`).

---

## 6. Verification & Testing

* **Split-Screen & Co-Op Headless Test:**
  ```powershell
  godot_console --headless --path godot_project -s test_campaign_coop.gd
  godot_console --headless --path godot_project -s test_split_screen.gd
  ```
* **Full PvP & Networking Suite:**
  ```powershell
  godot_console --headless --path godot_project -s test_pvp_system.gd
  ```
* **Interactive Playtest:**
  Double-click `Launch_Godot_Vanguard.bat` on the Windows Desktop.
