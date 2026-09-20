# 📻 Pilot Briefing, Avionics & Brevity Protocol

Standard operating procedure for the 404th Vanguard Strike Wing. Matches the diegetic HUD and combat telemetry systems in-game.

---

## 1. Tactical Brevity Codes

| Code Term | Context & Meaning |
| :--- | :--- |
| **"Fox Three"** | Launch of an active radar-guided **Vanguard Precision Strike Missile** (VPSM-01). |
| **"Guns, Guns, Guns"** | Firing of the internal 20mm rotary autocannon. |
| **"Magnum"** | Anti-radiation or anti-structure missile launch against heavy enemy sensor relays. |
| **"Blind"** | Pilot has lost visual contact with wingman or target in cloud/jamming layer. |
| **"Tally"** | Pilot has visual acquisition of hostile target. |
| **"Spike"** | Enemy active radar has achieved missile lock on the player's craft. |
| **"Mud"** | Ground/surface-based tracking radar detected. |
| **"Winchester"** | Out of all primary ordnance (missiles expended; cannon only). |
| **"Bingo Nitro"** | Afterburner capacitor drained to emergency reserve threshold. |

---

## 2. Cockpit EVA (Electronic Virtual Assistant) Voice Lines

The onboard flight computer utilizes an authoritative, calm synthetic voice (often designated **"Aegis-7"**):

* **Stall Warning:** *"Airspeed decaying. Stall impending. Pitch down."*
* **Target Acquisition:** *"Target acquired. Lock confirmed on station two."*
* **Missile Fired:** *"Fox Three away."*
* **Capacitor Overheat:** *"Warning: Nitro capacitor depleted. Thermal lockout active: three seconds."*
* **Shield Failure:** *"Shield collapse. Armor breach detected. Structural integrity compromised."*
* **Combat Reset:** *"Threat neutralized. Scanning horizon ribbon."*

---

## 3. AWACS ("Apex Command") Radio Dialogue Samples

* **Sortie Initiation:**
  > *"Vanguard 1, Apex Command. You are cleared for catapult launch. Threat grid shows multiple bogeys ascending through the cloud deck. Intercept and sanitize the corridor. Good hunting."*

* **Target Saturation:**
  > *"Caution, Vanguard Flight. Helion drone swarm has breached sector Charlie. Target disc shows twelve hostiles closing at Mach 2. Watch your six."*

* **Mission Complete:**
  > *"All hostile signatures off the scope. Outstanding shooting, Vanguard 1. Form up and RTB for re-arm."*

---

## 4. Local Vocal Generation Pipeline (Zero Cloud Cost)

All mission dialogue, AWACS comms, and cockpit AI voice lines are generated via local automation using [`tools/generate_vocals.py`](file:///c:/Users/Boris/Documents/antigravity/lucid-davinci/tools/generate_vocals.py).

### Voice Cast Manifest
| Character | Role | Voice Profile | Technical Parameters |
| :--- | :--- | :--- | :--- |
| **The Chronicler** | Intro Cutscene & Campaign Narrator | `en-US-BrianNeural` | Pitch `-3Hz`, Rate `-4%` (Deep, gravelly blockbuster cinematic trailer tone) |
| **Apex Command** | AWACS Tactical Controller (Male) | `en-US-ChristopherNeural` | Pitch `-2Hz`, Rate `+2%` (Deep, commanding military radar officer) |
| **Aegis-7** | Cockpit Flight Computer (Female) | `en-GB-SoniaNeural` | Pitch `+0Hz`, Rate `+2%` (Crisp, calm, unflinching synthetic AI) |
| **Lt. Vance Miller (Viper 2)** | Allied Fighter Wingman (Male) | `en-US-GuyNeural` | Pitch `+0Hz`, Rate `+4%` (Agile, tactical fighter pilot timbre) |

### Executing Vocal Generation
```powershell
# Generates all mission voice files directly into godot_project/audio/comms/
python tools/generate_vocals.py
```

Generated `.mp3` transmission files are automatically recognized and imported by Godot 4:
* `godot_project/audio/comms/m01_apex_scramble.mp3`
* `godot_project/audio/comms/m01_aegis_launch.mp3`
* `godot_project/audio/comms/m01_aegis_contact.mp3`
* `godot_project/audio/comms/m01_apex_weapons_free.mp3`
* `godot_project/audio/comms/m01_aegis_lock_confirmed.mp3`
* `godot_project/audio/comms/m01_apex_mission_complete.mp3`

