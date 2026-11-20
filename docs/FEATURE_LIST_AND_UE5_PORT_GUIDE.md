# Feature List and UE5 Port Notes

Part 1 lists what the Godot game currently does, with links to the detailed
docs. Part 2 sketches how each system would map onto Unreal Engine 5 (5.4+).
There is no UE5 port yet. Only the asset pipeline and `tools/ue5_client.py`
target it today.

---

## Part 1: Features

| Area | What's there | Details |
| :--- | :--- | :--- |
| Flight | 6-DOF flight, speed-dependent lift, stalls, G-load and drag, chase camera | [CONTROLS_AND_PHYSICS.md](CONTROLS_AND_PHYSICS.md) |
| Input | Keyboard (AZERTY/QWERTY detection), mouse, gamepad, phone controller, rebinding | [CONTROLS_AND_PHYSICS.md](CONTROLS_AND_PHYSICS.md) |
| HUD and combat | Compass, radar, missile lock, afterburner heat, shields and hull, gun aim assist, homing missiles | [HUD_AND_COMBAT_SYSTEM.md](HUD_AND_COMBAT_SYSTEM.md), [WEAPONS_AND_SOCKETS.md](WEAPONS_AND_SOCKETS.md) |
| Campaign | 8 missions, 9 cutscenes plus a prologue, debrief and scoring, 3 difficulty settings | [docs/lore/](lore/README.md), [ASSET_GENERATION_AND_MISSION_SPECIFICATION.md](ASSET_GENERATION_AND_MISSION_SPECIFICATION.md) |
| Agility mode | 8 time trials with gates, buoys and a ghost replay | `agility_*.gd`, `agility_courses/` |
| Multiplayer | Campaign co-op, split-screen 1v1, LAN, internet P2P lobbies | [MULTIPLAYER_AND_COOP_SYSTEM.md](MULTIPLAYER_AND_COOP_SYSTEM.md) |
| Saves and accounts | Local JSON saves, optional accounts, cloud sync, leaderboards | [SAVE_SYSTEM_AND_PROFILES.md](SAVE_SYSTEM_AND_PROFILES.md) |
| Progression | Stars currency, badges, login streak, reward wheel, armory | `reward_manager.gd`, `/api/pilot/reward` |
| Menus | 3D hangar home menu, pause menu, settings, in-game updater (checks GitHub releases) | `home_menu.gd`, `updater.gd` |

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
The Godot `InputMap` actions map onto Enhanced Input like this:

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
  * `IA_Yaw`: `Left Arrow` (-1.0), `Right Arrow` (1.0), Gamepad `Left/Right Shoulder`, `RightThumbstick X`
  * `IA_Roll`: `Q` (1.0), `D` (-1.0), Gamepad `LeftThumbstick X`
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
  * Reuse the existing SVGs:
    * [`assets/ui/reticle_bracket.svg`](../assets/ui/reticle_bracket.svg)
    * [`assets/ui/ship_paperdoll.svg`](../assets/ui/ship_paperdoll.svg)
    * [`godot_project/ui/vanguard_squadron_patch.svg`](../godot_project/ui/vanguard_squadron_patch.svg)
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

### 7. Assets
What already exists for a UE5 import:
* **FBX:** the Blender pipeline writes `Exports/Spaceship_Sculpted_V_Hull_game_ready.fbx` (Smart UVs plus `UCX_` hulls). `Exports/` is git-ignored, so run the pipeline to produce it. UE-ready staging copies are in `assets/staging/ue5/`.
* **PBR textures:** packed ORM (Ambient Occlusion, Roughness, Metallic) and DirectX Normal maps generated via [`tools/texture_processor.py`](../tools/texture_processor.py).
* **Automation:** [`tools/ue5_client.py`](../tools/ue5_client.py) drives a running editor through Python remote execution.
