# Project Vanguard: Feature List & Unreal Engine 5 Porting Guide

A comprehensive architectural inventory of all systems implemented in Project Vanguard, accompanied by a step-by-step technical conversion guide for porting to Unreal Engine 5 (UE 5.4+).

---

## Part 1: Comprehensive Feature List

### 1. Flight Dynamics & Physics
* **6-DOF Aerodynamic Flight Model**:
  * Cruise throttle with smooth acceleration (`180 m/s` top cruise) and braking/reverse.
  * Afterburner boost accelerating to `290 m/s`.
  * Multi-axis rotational steering (Pitch, Roll, Yaw) with inertia-damped angular velocity.
  * Aerodynamic stall & lift simulation: dynamic lift ratio dependent on forward velocity vs stall speed (`45 m/s`), with uncompensated gravity acting when stalled.
* **Dual Control Inputs (Mouse + Keyboard + Gamepad Readiness)**:
  * **Turn (Yaw)**: Left / Right Arrow keys (and A / E alternates), plus horizontal Mouse X steering.
  * **Roll (Aileron)**: Q / D keys (or A / D on QWERTY).
  * **Throttle (Speed)**: Z / S keys (or W / S on QWERTY).
  * **Pitch (Elevator)**: Up / Down Arrow keys, plus vertical Mouse Y steering (with optional flight-stick inversion).
* **Fully Customizable Input Remapping**:
  * In-game click-to-rebind modal in the Settings menu.
  * Native Godot `InputMap` integration.
  * Instant presets for **Belgian AZERTY** and **QWERTY**.
  * Persistent storage in `user://settings.cfg`.

### 2. Tactical Military Sci-Fi HUD
* **Top Compass Horizon Ribbon (`0°..360°`)**:
  * Scrolling heading tape with cardinal markers (`N`, `E`, `S`, `W`) and degree ticks.
  * Hostile bogeys plotted in Tactical Crimson Red (`#FF1744`) with down-chevrons.
  * Mission objectives plotted in Tactical Gold (`#FFD700`) with diamond markers.
* **Toggleable Circular Radar Disc (`R` key)**:
  * Top-down polar projection with 100m, 200m, and 300m range rings.
  * Azimuth and elevation tracking for all targets within 350m radius.
* **Target Tracking & Missile Lock-On System**:
  * 45° forward seeker acquisition cone.
  * Screen-space projection around targets in camera frustum.
  * Timed lock-on ring transitioning to solid lock reticle upon missile lock acquisition.
  * Off-screen edge tracking chevrons with range readouts when bogeys break visual contact.
* **Nitro / Afterburner Capacitor**:
  * 100-unit energy pool draining during afterburner boost.
  * Recharges automatically during cruise flight.
  * 3.0s emergency overheat lockout penalty with flashing warning alerts if depleted.
* **Unified Shield & Hull Pool**:
  * 100 HP multi-phase regenerative shield halo (15 HP/s recharge after 4s no-damage cooldown).
  * 100 HP structural composite hull.
  * Real-time damage testing hook (`H` key).
* **Ordnance Bay**:
  * 4x Vanguard Strike Missiles rack with armed/expended status.
  * 20mm rotary autocannon ammo counter.

### 3. Presentation, Menus & Hangar
* **Home Menu & Eerie White Hangar Construct**:
  * 3D cleanroom showroom with reflective glossy white floor and soft directional lighting.
  * Dark carbon docking pad with glowing cyan accents.
  * Player fighter rotating on a turntable (`0.12 rad/s`) with subtle hydraulic hover breathing.
  * Active repair FX: moving cyan diagnostic laser scan ring and nanite weld spark particles.
  * Left-aligned tactical sidebar with transparent 404th Vanguard Strike Wing insignia.
  * Interactive technical specifications modal with top-down CAD blueprint.
* **Tactical In-Flight Pause Menu**:
  * Simulation suspension via `ESC` key.
  * Quick save and load buttons with animated confirmation toasts (`// SORTIE SAVED // SECURE SYNC COMPLETE`).
  * Return to Hangar, restart sortie, and avionics configuration.

### 4. Persistence & Versioning
* **Save Game System**:
  * Human-readable, indented JSON saved to `user://saves/vanguard_savegame.json` (`%APPDATA%\Godot\app_userdata\Project Vanguard\saves\`).
  * Full serialization of 3D coordinates, orientation, velocity, vitals, ordnance, and enemy drone state.
  * Home Menu detection enabling **`[ CONTINUE SORTIE ]`** with timestamp and hull readouts.
* **Semantic Versioning**:
  * Tracked centrally via root `VERSION` file, `project.godot`, and `CHANGELOG.md`.

### 5. Multiplayer, Split-Screen & Networking Suite
* **Campaign Drop-In Split-Screen Co-Op**:
  * Single-player sorties start in full screen by default across all 8 campaign missions.
  * Player 2 drops in dynamically upon verified secondary control keypress (action `P2_ACTIONS`, gamepad `device >= 1`, or secondary keyboard cluster `IJKL`, `Enter`, NumPad).
  * Dual `SubViewport`s created on the fly sharing the active campaign `World3D`.
  * Player 2 spawns in wingman formation with distinct Solar Amber / Gold wingman livery.
  * Threat AI (drones and bosses) dynamically acquire and engage whichever active player is closest.
  * 5-second wingman field respawn loop upon airframe destruction; sortie fails only if both flight elements are lost.
* **Local Split-Screen PvP Dogfight Arena**:
  * First-to-5 dogfight arena (`split_screen_arena.tscn`) in the canyon proving grounds.
  * On-the-fly layout toggle via `F2` (Horizontal Top/Bottom $\leftrightarrow$ Vertical Left/Right).
  * Dual independent cameras and tactical HUD overlays without cross-viewport state bleeding.
  * Mutual radar acquisition and missile lock-on against opponent.
* **LAN Peer-to-Peer / Network Dogfight Arena**:
  * ENet multiplayer architecture on UDP port 7779.
  * Background UDP discovery beacon broadcast on UDP port 7778 for zero-configuration local lobby discovery.
  * Client snapshot interpolation (20Hz lerp smoothing position, rotation, and velocities).
  * Synchronized RPC cannon bursts, missile tracking, and damage events.
* **PvP Matchmaking & Lobby Hub (`pvp_menu.tscn`)**:
  * Instant access from the Home Menu.
  * Host LAN Server, Auto-Discover LAN Games, Direct IP Connect, and Local Split-Screen Arena buttons.

---

## Part 2: Unreal Engine 5 Porting Blueprint

```mermaid
flowchart TD
    subgraph Godot [Godot 4 System]
        G_Flight[spaceship_controller.gd]
        G_Telem[combat_telemetry.gd]
        G_HUD[hud.gd (Vector Canvas)]
        G_Input[InputMap + config_manager.gd]
        G_Save[save_manager.gd (JSON)]
        G_Assets[Spaceship_Sculpted_V_Hull.glb]
    end

    subgraph UE5 [Unreal Engine 5 Equivalent]
        UE_Flight[AVanguardFighterPawn + UVanguardFlightComponent]
        UE_Telem[UCombatTelemetryComponent (ActorComponent)]
        UE_HUD[Common UI / UMG + Slate Vector Materials]
        UE_Input[Enhanced Input (IMC_Vanguard + Input Actions)]
        UE_Save[UVanguardSaveGame (USaveGame / JsonObject)]
        UE_Assets[Nanite StaticMesh + UCX_ Collision + ORM PBR]
    end

    G_Flight --> UE_Flight
    G_Telem --> UE_Telem
    G_HUD --> UE_HUD
    G_Input --> UE_Input
    G_Save --> UE_Save
    G_Assets --> UE_Assets
```

---

### 1. Pawn & Flight Mechanics (`AVanguardFighterPawn`)
* **Base Class**: Derive from `APawn` rather than `ACharacter` (avoids humanoid walking physics overhead).
* **Movement Component**: Create a custom `UVanguardFlightMovementComponent` (subclass of `UPawnMovementComponent` or `UMovementComponent`):
  ```cpp
  // Calculate forward aerodynamic velocity
  FVector ForwardDir = GetActorForwardVector();
  FVector ForwardVel = ForwardDir * CurrentSpeed;

  // Stall & Lift simulation
  float LiftRatio = FMath::Clamp(CurrentSpeed / StallSpeed, 0.0f, 1.0f);
  float UncompensatedGravity = (1.0f - LiftRatio) * GravityZ;
  DownwardVelocity = FMath::Clamp(DownwardVelocity + UncompensatedGravity * DeltaTime, 0.0f, MaxFallSpeed);

  FVector FinalVelocity = ForwardVel - FVector(0.0f, 0.0f, DownwardVelocity);
  MoveUpdatedComponent(FinalVelocity * DeltaTime, GetActorRotation(), true);
  ```
* **Rotational Torques**:
  ```cpp
  FRotator DeltaRot(PitchInput * PitchRate * DeltaTime,
                    YawInput * YawRate * DeltaTime,
                    RollInput * RollRate * DeltaTime);
  AddActorLocalRotation(DeltaRot);
  ```
* **Camera System**:
  * `USpringArmComponent` (Length: 1400cm, Lag: enabled with speed `8.0`).
  * `UCameraComponent` attached to spring arm with Field of View `75.0`.

---

### 2. Enhanced Input Subsystem (UE 5.1+)
Unreal's **Enhanced Input** maps directly to our Godot actions:

#### A. Input Actions (`UInputAction`)
* `IA_Throttle` (`Axis1D`): Continuous speed forward / brake.
* `IA_Yaw` (`Axis1D`): Turn left (-1) / right (+1).
* `IA_Roll` (`Axis1D`): Bank left (+1) / right (-1).
* `IA_Pitch` (`Axis1D`): Nose up (+1) / nose down (-1).
* `IA_Look` (`Axis2D`): Mouse / Right Stick input.
* `IA_Boost` (`Digital`): Afterburner boost.
* `IA_FireMissile` (`Digital`): Launch missile.
* `IA_ToggleRadar` (`Digital`): Radar toggle.
* `IA_Pause` (`Digital`): Escape / Start button.

#### B. Input Mapping Contexts (`UInputMappingContext`)
* Create two mapping contexts: `IMC_AZERTY` and `IMC_QWERTY`.
* **AZERTY Context**:
  * `IA_Throttle`: `Z` (1.0), `S` (-1.0)
  * `IA_Yaw`: `Left Arrow` (-1.0), `Right Arrow` (1.0), `A` (-1.0), `E` (1.0), Gamepad `LeftThumbstick X`
  * `IA_Roll`: `Q` (1.0), `D` (-1.0), Gamepad `Left/Right Bumper`
  * `IA_Pitch`: `Down Arrow` (1.0), `Up Arrow` (-1.0), Gamepad `LeftThumbstick Y`
  * `IA_Look`: Mouse XY (with `Negate` modifier for Y when inverted)
* **Runtime Layout Switching**:
  ```cpp
  UEnhancedInputLocalPlayerSubsystem* Subsystem = ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(PlayerController->GetLocalPlayer());
  Subsystem->RemoveMappingContext(IMC_QWERTY);
  Subsystem->AddMappingContext(IMC_AZERTY, 0);
  ```

---

### 3. Combat Telemetry (`UCombatTelemetryComponent`)
* Subclass of `UActorComponent`.
* Properties:
  * `Shield` (`float`, Recharging via timer delegate).
  * `Hull` (`float`).
  * `Nitro` (`float`, Overheat cooldown FSM).
  * `MissilesRemaining` (`int32`).
* **Target Detection & Screen Projection**:
  * Query actors implementing `ITacticalTargetInterface` or with Gameplay Tag `Tag.Target.Hostile`.
  * Calculate bearing and screen space:
    ```cpp
    FVector2D ScreenPosition;
    PlayerController->ProjectWorldLocationToScreen(TargetActor->GetActorLocation(), ScreenPosition, true);
    ```

---

### 4. Tactical HUD (Common UI / UMG)
* **Vector Shaders / Materials**:
  * Create a Dynamic Material Instance for the Compass Ribbon:
    `Material Parameter: HeadingOffset = Normalize(ActorYaw / 360.0f)`.
  * Use the SVG vector assets already created in user space:
    * [`assets/ui/reticle_bracket.svg`](file:///c:/Users/Boris/Documents/antigravity/lucid-davinci/assets/ui/reticle_bracket.svg)
    * [`assets/ui/ship_paperdoll.svg`](file:///c:/Users/Boris/Documents/antigravity/lucid-davinci/assets/ui/ship_paperdoll.svg)
    * [`godot_project/ui/vanguard_squadron_patch.svg`](file:///c:/Users/Boris/Documents/antigravity/lucid-davinci/godot_project/ui/vanguard_squadron_patch.svg)
* **Post-Process & Glitch**:
  * Screen-space Retainer Box with slight scanline and chromatic aberration post-process.

---

### 5. Save Game System (`UVanguardSaveGame`)
* Subclass of `USaveGame`.
* Fields match the JSON schema:
  ```cpp
  UCLASS()
  class UVanguardSaveGame : public USaveGame
  {
      GENERATED_BODY()
  public:
      UPROPERTY(VisibleAnywhere) FString SaveDisplayDate;
      UPROPERTY(VisibleAnywhere) FVector ShipPosition;
      UPROPERTY(VisibleAnywhere) FRotator ShipRotation;
      UPROPERTY(VisibleAnywhere) float CurrentSpeed;
      UPROPERTY(VisibleAnywhere) float Shield;
      UPROPERTY(VisibleAnywhere) float Hull;
      UPROPERTY(VisibleAnywhere) int32 MissilesRemaining;
  };
  ```
* Saving & Loading:
  ```cpp
  UGameplayStatics::SaveGameToSlot(SaveObj, TEXT("vanguard_savegame"), 0);
  UVanguardSaveGame* LoadedObj = Cast<UVanguardSaveGame>(UGameplayStatics::LoadGameFromSlot(TEXT("vanguard_savegame"), 0));
  ```

---

### 6. Multiplayer & Split-Screen Architecture in UE5
* **Split-Screen Local Multiplayer**:
  * Utilize `UGameplayStatics::CreatePlayer(GetWorld(), 1, true)` dynamically on secondary input.
  * Adjust `UGameViewportClient::SetForceDisableSplitscreen()` and configure viewport orientation via `UGameViewportClient::SplitscreenInfo` (`ESplitScreenType::TwoPlayer_Horizontal` vs `ESplitScreenType::TwoPlayer_Vertical`).
  * Each `APlayerController` binds to its own `UVanguardHUDWidget` with separate camera viewports and independent audio listeners.
* **Network Replication & LAN Matchmaking**:
  * Set `bReplicates = true` and `SetReplicateMovement(true)` on `AVanguardFighterPawn`.
  * Weapon fire triggers reliable Server RPCs (`Server_FireGun()`, `Server_LaunchMissile()`).
  * Continuous position/orientation synchronization handles smooth visual interpolation with `CharacterMovementComponent` or custom replication smoothing.
  * LAN session discovery utilizes `OnlineSubsystem` with `bIsLANMatch = true` for broadcast beacons and server pinging.

---

### 7. Asset & Pipeline Readiness in User Space
All prerequisites for a frictionless UE5 import are already prepared in this workspace:
* **Game-Ready FBX**: [`Exports/Spaceship_Sculpted_V_Hull_game_ready.fbx`](file:///c:/Users/Boris/Documents/antigravity/lucid-davinci/Exports/Spaceship_Sculpted_V_Hull_game_ready.fbx) contains clean Smart UVs and convex `UCX_` collision hulls recognized natively by Unreal Engine.
* **PBR Textures**: Packed ORM (Ambient Occlusion, Roughness, Metallic) and DirectX Normal maps generated via [`tools/texture_processor.py`](file:///c:/Users/Boris/Documents/antigravity/lucid-davinci/tools/texture_processor.py).
* **Automation Client**: [`tools/ue5_client.py`](file:///c:/Users/Boris/Documents/antigravity/lucid-davinci/tools/ue5_client.py) ready for remote execution socket imports.
