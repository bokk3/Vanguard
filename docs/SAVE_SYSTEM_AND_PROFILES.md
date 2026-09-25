# Vanguard Save Game System, Sovereign Profiles & Zero-Cost Cloud Sync 💾☁️

Comprehensive technical documentation for the Project Vanguard Save Game System, offline state serialization, cryptographic integrity sealing, and zero-cost cloud profile persistence.

---

## 1. Storage Location & Accessibility

The save system stores all sortie and campaign data in human-readable, indented JSON in an isolated `saves/` directory.

| Context | Path | Notes |
| :--- | :--- | :--- |
| **Godot Virtual Path** | `user://saves/vanguard_savegame.json` | Isolated from engine config (`user://settings.cfg`) |
| **Windows OS Resolved Path** | `%APPDATA%\Godot\app_userdata\Project Vanguard\saves\vanguard_savegame.json` | Directly accessible in Windows Explorer for backups & modding |
| **Default Slot Name** | `vanguard_savegame` | Expandable to multi-slot profiles (`slot_1`, `slot_2`) |
| **Web Cloud Backup** | `https://project-vanguard.pages.dev/api/pilot/sync` | Encrypted, zero-cost cloud sync powered by Cloudflare D1 |

---

## 2. JSON Save Schema Breakdown (v0.8.0)

```json
{
  "format_version": 1,
  "game_version": "0.8.0",
  "timestamp": "2026-09-25T13:30:00Z",
  "display_date": "2026-09-25 13:30",
  "profile": {
    "callsign": "VANGUARD-LEAD",
    "squadron": "404th Vanguard Strike Wing",
    "rank": "FLIGHT LIEUTENANT",
    "pilot_id": "vng-usr-8849-ace",
    "auth_token": "cf_edge_jwt_token_sample"
  },
  "sortie": {
    "mission_id": "M01",
    "mission_title": "Operation CLOUDBURST",
    "theater": "Sub-Cloud Interception Sector 07",
    "scene_file": "res://main.tscn"
  },
  "campaign": {
    "unlocked_mission_id": "M02",
    "mission_records": {
      "M01": {
        "completed": true,
        "high_score": 14200,
        "best_time_sec": 184.2,
        "rank": "S"
      }
    }
  },
  "ship": {
    "position": [0.0, 42.5, -80.0],
    "rotation": [0.0, 3.14159, 0.0],
    "current_speed": 140.0,
    "downward_velocity": 0.0
  },
  "telemetry": {
    "current_shield": 85.0,
    "current_hull": 100.0,
    "current_nitro": 92.4,
    "is_overheated": false,
    "overheat_timer": 0.0,
    "missiles_remaining": 3
  },
  "world": {
    "drone_alive": true,
    "drone_state": {
      "angle": 1.45,
      "health": 75.0,
      "global_pos": [-120.0, 75.0, -320.0]
    }
  },
  "security": {
    "hmac_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  }
}
```

---

## 3. Core Architecture & Hybrid Cloud Sync

```mermaid
flowchart TD
    subgraph Storage [Disk Persistence (Offline First)]
        JSON[user://saves/vanguard_savegame.json]
        HMAC[HMAC-SHA256 Integrity Verification]
        JSON <--> HMAC
    end

    subgraph Manager [SaveManager Autoload Singleton]
        SM[save_manager.gd]
        SM <-->|Read / Write Pretty JSON| JSON
    end

    subgraph Cloud [Zero-Cost Cloud Edge - project-vanguard.pages.dev]
        CF[Cloudflare Pages Functions: /api/pilot/sync]
        D1[("Cloudflare D1: SQLite Edge Database\nFree: 5M reads/day, 100k writes/day")]
        CF <--> D1
        SM -.->|Asynchronous HTTPRequest| CF
    end

    subgraph WebPortal [Web Browser Client]
        Web[project-vanguard.pages.dev/pilot]
        Drop[Client-Side Drag & Drop Save Inspector]
        JSON -.->|User inspects local save file| Drop
        Drop --> Web
    end
```

---

## 4. Pilot Identity & Cloud Synchronization

### 4.1 $0 Cloud Architecture (Cloudflare Pages + D1)
Project Vanguard uses a **Sovereign Pilot model**:
* **100% Offline Capability**: Pilots retain complete ownership of their local JSON save file. The game requires zero network connection to launch, save, or play.
* **Optional Cloud Link**: When connected to the internet, pilots can link their callsign to their free account on `project-vanguard.pages.dev`:
  1. Pilot signs up on `project-vanguard.pages.dev` with Callsign & Password.
  2. In-game, pilot clicks **"Link Account"** and enters their credentials (or uses a 6-character link code).
  3. Sortie debrief scores, campaign progression, and medal unlocks automatically sync to Cloudflare D1 via non-blocking background `HTTPRequest`.

### 4.2 Web Dossier Save Inspector ($0 Server Compute)
On the live portal (`https://project-vanguard.pages.dev`), pilots can drag and drop their `vanguard_savegame.json` directly into the browser:
* The web app uses the browser's native `FileReader` API.
* Parses combat stats, weapon accuracy, mission completion trees, and flight hours.
* **100% Client-Side**: Consumes zero cloud compute and zero server bandwidth.

---

## 5. UI Integrations

### Home Menu (`res://home_menu.tscn`)
* Automatically checks `SaveManager.has_save()`.
* When a save exists:
  * Reveals **`[ 01 ] CONTINUE SORTIE`** button (styled with glowing primary cyan border).
  * Prompts **`[ 02 ] NEW SORTIE`** as second option.
  * Sidebar status box dynamically displays:
    `ACTIVE SORTIE: 2026-09-25 13:30`
    `HULL INTEGRITY: 85%`
    `MISSILES ARMED: 3/4`
* When no save exists:
  * Displays **`[ 01 ] DEPLOY SORTIE`** directly.

### Tactical Pause Menu (`res://pause_menu.tscn`)
* Pressing `ESC` during flight opens the tactical pause dialog.
* **`[ 02 ] SAVE SORTIE`**:
  * Calls `SaveManager.save_game()`.
  * Triggers an animated tactical confirmation toast:
    `// SORTIE SAVED // SECURE SYNC COMPLETE` in tactical neon green.
  * Enables the **`[ 03 ] LOAD LAST SAVE`** button immediately.
* **`[ 03 ] LOAD LAST SAVE`**:
  * Calls `SaveManager.apply_save_to_current_scene()`.
  * Instantly restores position, speed, vitals, and ordnance, unpausing the simulation.

---

## 6. Semantic Versioning Strategy

Project Vanguard follows [Semantic Versioning 2.0.0](https://semver.org/):
* **MAJOR**: Incompatible architectural milestones or engine conversions (e.g., Godot -> UE5 port).
* **MINOR**: New gameplay features, UI overhauls, or subsystems (e.g., `v0.8.0` Split-Screen, LAN Dogfights & Cloud Architecture).
* **PATCH**: Bug fixes, control adjustments, or visual polish.

### Version Single Source of Truth
1. Root `VERSION` file: `0.8.0`
2. Project Configuration: `config/version="0.8.0"` in `godot_project/project.godot`
3. Engine Runtime: Retrieved via `ProjectSettings.get_setting("application/config/version")`
4. Changelog: Tracked in `CHANGELOG.md` following [Keep a Changelog](https://keepachangelog.com/).
