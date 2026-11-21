# HUD and Combat Telemetry

The HUD and the combat state behind it (shields, hull, afterburner heat,
missile lock). Game logic lives in
[`combat_telemetry.gd`](../godot_project/combat_telemetry.gd), and drawing in
[`hud.gd`](../godot_project/hud.gd). Section 4 maps each piece to Unreal
Engine 5.

---

## 1. Architectural Overview

`CombatTelemetry` holds the state and does the maths: lock state machine, capacitor and damage. The HUD only reads that state and draws it with `_draw()`.

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

## 2. Controls

Key and gamepad bindings are listed in
[CONTROLS_AND_PHYSICS.md](CONTROLS_AND_PHYSICS.md). The HUD-specific keys are
**R** (show or hide the radar) and **H** (debug: apply a 25 HP hit to yourself).

---

## 3. Core HUD Components

### 3.1 Top Compass Horizon Ribbon
* Sits at the top centre of the screen.
* **Heading Tape:** Ticks every 15°, labeled with cardinal headings (`N`, `E`, `S`, `W`) and numerical degrees (`000°` - `359°`).
* **Target Beacons:**
  * **Hostiles / Enemies:** Marked in Tactical Crimson Red (`#FF1744`) with downward indicator chevrons.
  * **Objectives / Beacons:** Marked in Mission Gold (`#FFD700`) with diamond markers.
* Bearings are relative to the ship's nose.

### 3.2 Toggleable Circular Radar Disc
* Toggled with `R`.
* Top-down polar view centred on the player, with the seeker cone drawn on it.
* Range is `max_radar_range_m` (3000 m by default). The rings are at one
  third, two thirds and full range.

### 3.3 Dynamic Screen-Space Target Lock-On System
* Considers hostiles inside a 35° half-angle cone ahead of the nose (`seeker_cone_deg`).
* Positions are projected to the screen with `Camera3D.unproject_position()`.
* Lock states:
  1. **Acquiring:** a cyan bracket with a progress ring that fills over 1.2 s (`lock_duration`).
  2. **Locked:** the bracket tightens into a red/gold box with a lead diamond.
  3. **Off-screen:** a chevron on the screen edge points at the target and shows its distance.

### 3.4 Nitro & Afterburner Capacitor
* **Capacity:** 100 units max.
* **Drain Rate:** 24 units/sec (~4.2 seconds of continuous afterburner thrust).
* **Recharge Rate:** 18 units/sec (~5.5 seconds recovery time).
* **Overheat:** emptying the capacitor locks the afterburner for 3.0 seconds and flashes a red warning.

### 3.5 Unified Shield & Hull Vitals Panel
* **Shield:** 100 HP. Regenerates at 15 HP/s after 4 seconds without taking damage.
* **Hull:** 100 HP. Takes damage once the shield is empty.
* **Debug:** `H` applies a 25 HP hit.

### 3.6 Ordnance Bay
* **Vanguard Strike Missiles:** 4x ready rack. Displays missile status (armed, locked, fired).
* **20mm Rotary Cannon:** Real-time ammunition counter.

---

## 4. Cross-Engine Porting Guide (Unreal Engine 5)

Suggested Unreal Engine 5 equivalents:

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
Each HUD instance is bound to one ship, so split-screen players don't read each other's state:
```gdscript
hud_instance.bind_to_ship(ship_node, camera_node, player_id)
```
- Each player's HUD sits in their own `SubViewport/HUD` `CanvasLayer`, so `unproject_position` uses that player's camera and aspect ratio.
- Colours per player:
  - **Player 1 (Flight Lead):** Cyan/Sky Blue tactical instrumentation (`#00E5FF`).
  - **Player 2 Co-Op Wingman:** Solar Amber/Gold avionics (`#FFB300`) with wingman formation telemetry.
  - **Player 2 PvP Aggressor:** Crimson/Amber dogfight avionics (`#FF3D00`) with direct lock-on against Player 1.

### Multi-Target Radar Symbology
Radar contact symbols:
- **Crimson Diamond (`#FF2638`):** Hostile combat drones, strike craft, and PvP opponents in group `"enemies"`.
- **Amber Cross (`#FFB300`):** Friendly wingman (Player 2) in group `"player"` / `"radar_targets"`.
- **Emerald Chevron (`#00E676`):** Friendly mission targets (e.g. Olympus-4 transport, SOC Dauntless).
- **Gold Ring (`#FFD700`):** Tactical navigation beacons and canyon pylon gates.

### Damage Pipeline & Combat Feedback
When the player is hit (by enemy fire or a collision):
1. **Shield Absorption:** Shields deplete first (`telemetry.current_shield`).
2. **Hull Bleed:** Damage beyond available shields damages the structural hull (`telemetry.current_hull`).
3. **Cockpit Trauma:** Screen trauma shaking scales up to `1.0` and decays smoothly.
4. **Haptic Rumble:** Direct gamepad rumble pulse (`cfg.play_rumble(weak, strong, duration, device_id)`).
5. **HUD Alarm:** Flashes red warning banner: `// WARNING: HIT -X HP //`.

### Co-Op Field Respawn System
In campaign co-op, losing one ship doesn't fail the mission. The downed player sees a 5-second countdown, then respawns next to the surviving player with full shields, hull and missiles. The sortie fails (`SORTIE_WIPED`) only if both ships are down at once.

---

## 6. Verification & Testing

* **Split-Screen & Co-Op Headless Test:**
  ```powershell
  godot --headless --path godot_project -s test_campaign_coop.gd
  godot --headless --path godot_project -s test_split_screen.gd
  ```
* **Full PvP & Networking Suite:**
  ```powershell
  godot --headless --path godot_project -s test_pvp_system.gd
  ```
