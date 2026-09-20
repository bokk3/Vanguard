# 🔊 Project Vanguard: Diegetic Sound Design & SFX Suite

The sound design in **Project Vanguard** is built on the philosophy of **Hard-Surface Aerospace Diegesis**: every cockpit bleep, aerodynamic rush, and combat alarm represents authentic military electronic synthesis and aerodynamic physics rather than generic stock audio.

All SFX are synthesized procedurally via [`tools/build_sfx_library.py`](file:///c:/Users/Boris/Documents/antigravity/lucid-davinci/tools/build_sfx_library.py) as 16-bit 44.1kHz PCM `.wav` files with zero cloud costs.

---

## 🎧 Master SFX Catalog

### 1. Cockpit Avionics & HUD Telemetry
Real fighter jets (F-22, F-35, Rafale) use pure electronic frequency modulation for cockpit audio to ensure instant pilot recognition amidst high-G combat.

| Sound Effect | File Name | Synthesis Method & Frequency | In-Game Trigger |
| :--- | :--- | :--- | :--- |
| **Target Acquiring** | [`sfx_hud_target_locking.wav`](audio/sfx/sfx_hud_target_locking.wav) | 880 Hz pure sine chirp, 80ms duration with sharp exponential decay. | Played intermittently while target lock brackets contract (0%–99%). |
| **Solid Target Lock** | [`sfx_hud_target_locked.wav`](audio/sfx/sfx_hud_target_locked.wav) | Dual-tone 1320 Hz + 1760 Hz harmonic with 16 Hz rapid tremolo warble. | Fired upon achieving 100% missile lock. |
| **Missile Spike (RWR)** | [`sfx_hud_missile_incoming_spike.wav`](audio/sfx/sfx_hud_missile_incoming_spike.wav) | Alternating 1400 Hz / 1900 Hz square wave at 12 Hz with soft-clipping grit. | Triggered when an enemy craft locks onto player. High urgency. |
| **Stall Warning Klaxon** | [`sfx_hud_stall_warning.wav`](audio/sfx/sfx_hud_stall_warning.wav) | 240 Hz sawtooth wave pulsed at 4 Hz repetition rate. | Fires when airspeed decays below $25\text{ m/s}$. |
| **Capacitor Depleted** | [`sfx_hud_capacitor_empty.wav`](audio/sfx/sfx_hud_capacitor_empty.wav) | Descending FM sweep from 900 Hz down to 180 Hz over 300ms. | Triggered when Nitro capacitor hits 0% (thermal lockout). |

---

### 2. Aerodynamics, High-G Maneuvers & Flybys
Simulates the physical roar of air over composite wings and Doppler-shifted supersonic passes.

| Sound Effect | File Name | Synthesis Method | In-Game Trigger |
| :--- | :--- | :--- | :--- |
| **High-G Whoosh** | [`sfx_flight_high_g_whoosh.wav`](audio/sfx/sfx_flight_high_g_whoosh.wav) | Bandpass filtered pink noise with dynamic volume swell and 120Hz–200Hz sweep. | Swells during aggressive pitch pulls and high-speed banking turns. |
| **Enemy Doppler Flyby** | [`sfx_flyby_enemy_doppler.wav`](audio/sfx/sfx_flyby_enemy_doppler.wav) | Relativistic radial Doppler shift equation ($f_{obs} = \frac{f_0}{1 + v/c}$) with jet turbine whine. | Plays when an enemy drone or fighter screams past camera within 50m. |
| **Near-Miss Bullet Whiz**| [`sfx_near_miss_bullet_whiz.wav`](audio/sfx/sfx_near_miss_bullet_whiz.wav) | Microsecond supersonic shockwave snap followed by rapid 3200Hz $\rightarrow$ 700Hz whiz. | Plays when enemy projectiles pass within meters of the cockpit. |

---

### 3. Weapons, Ballistics & Impacts
Grounded kinetic impacts and rocket motors.

| Sound Effect | File Name | Synthesis Method | In-Game Trigger |
| :--- | :--- | :--- | :--- |
| **20mm Cannon Burst** | [`sfx_weapon_cannon_burst.wav`](audio/sfx/sfx_weapon_cannon_burst.wav) | 3-round 85Hz low-frequency punch + explosive noise crack + 1650Hz metallic ring. | Triggered when firing the internal rotary cannon (1200 RPM report). |
| **Missile Launch** | [`sfx_weapon_missile_launch.wav`](audio/sfx/sfx_weapon_missile_launch.wav) | 60Hz pneumatic ejector thud + 140Hz/320Hz resonant rocket plume ignition roar. | Plays when releasing a Vanguard Strike Missile from wing pylons. |
| **Shield Deflection Hit** | [`sfx_impact_shield_hit.wav`](audio/sfx/sfx_impact_shield_hit.wav) | 2400Hz $\rightarrow$ 600Hz FM plasma chirp with 80Hz phase modulation. | Triggered when taking damage with shields active. |

---

### 4. UI & Tactile Cockpit Controls
Subtle, high-frequency haptic sounds for menu navigation and switch flipping.

| Sound Effect | File Name | Description |
| :--- | :--- | :--- |
| **UI Button Hover** | [`sfx_ui_button_hover.wav`](audio/sfx/sfx_ui_button_hover.wav) | 1800 Hz micro-second tick with rapid decay for crisp menu navigation. |
| **UI Button Click** | [`sfx_ui_button_click.wav`](audio/sfx/sfx_ui_button_click.wav) | Dual 1200 Hz / 2400 Hz confirmation click for selecting sorties or toggling settings. |
| **Debrief Tally Tick** | [`sfx_debrief_tally_tick.wav`](audio/sfx/sfx_debrief_tally_tick.wav) | 1650 Hz high-speed mechanical counter chirp for rapid score decryption rollup. |
| **Debrief Rank Slam** | [`sfx_debrief_rank_slam.wav`](audio/sfx/sfx_debrief_rank_slam.wav) | Sub-bass 65 Hz->25 Hz drop layered with 480 Hz metallic hydraulic stamp impact for pilot rank evaluation. |

---

## 🕹️ GDScript Integration Example

```gdscript
# Triggering SFX in Godot 4
func play_sfx(sfx_name: String, bus: String = "SFX") -> void:
    var player = AudioStreamPlayer.new()
    player.bus = bus
    player.stream = load("res://audio/sfx/" + sfx_name)
    add_child(player)
    player.finished.connect(player.queue_free)
    player.play()

# In combat telemetry:
if is_solid_lock:
    play_sfx("sfx_hud_target_locked.wav")
elif is_locking:
    play_sfx("sfx_hud_target_locking.wav")
```
