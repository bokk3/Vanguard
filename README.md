<div align="center">

<img src="docs/lore/images/vanguard_squadron_patch_cropped.png" alt="404th Vanguard Strike Wing patch" width="160" />
<br/>
<img src="docs/lore/images/project_vanguard_title_cropped.png" alt="Project Vanguard" width="580" />

[Releases](https://github.com/bokk3/Vanguard/releases) · [Website](https://project-vanguard.pages.dev) · [Changelog](CHANGELOG.md)

</div>

# Project Vanguard

A sci-fi combat flight game built in Godot 4, plus the CAD-to-engine asset
pipeline used to make its ships.

Current version: **0.9.7** (see [`VERSION`](VERSION)).

## What's in it

- **Campaign:** 8 missions (M01–M08) with cutscenes between them, a debrief
  and score screen, and three difficulty settings (Easy, Normal, Ace).
- **Agility mode:** 8 time trials through gates and target buoys, with a ghost
  of your best run.
- **Multiplayer:** drop-in split-screen co-op in the campaign, a local 1v1
  split-screen arena, LAN matches, and internet P2P lobbies listed through the
  website API (ENet on UDP 7777, with UPnP port mapping where the router allows it).
- **Phone as controller:** the game shows a QR code (F3). Scanning it opens
  `/controller` on the website, which talks to the game over a local WebSocket
  (port 8081) and gives you a touch stick, a throttle and optional gyro steering.
- **Accounts and progression:** optional pilot accounts with cloud save sync,
  leaderboards, a Stars currency, badges and a daily login streak. These run on
  Cloudflare Pages Functions and D1. The game also works offline with a local
  JSON save.

## Repository layout

```text
godot_project/     The game (Godot 4.7). Entry scene: home_menu.tscn
  test_*.gd        Headless test scripts (see "Running tests")
website/           Vite + Tailwind site, phone controller page, and the
                   Cloudflare Pages Functions API (functions/api/), D1 schema
tools/             Python asset tooling: CAD pipeline, Blender/Fusion/UE5
                   bridge clients, audio, texture and image generators
blender_addon/     Blender bridge (HTTP server on 127.0.0.1:9877)
fusion_addin/      Fusion 360 bridge add-in (HTTP server on 127.0.0.1:9876)
scripts/models/    Fusion 360 scripts that generate the ship models
scripts/unreal/    Unreal Engine helper scripts
assets/            Source CAD, meshes, textures, staging exports
data/              Asset and campaign manifests, level data
docs/              Design and technical notes; docs/lore/ holds the setting
archive/           Snapshot of older models kept for reference
```

## Running the game

1. Install [Godot 4.7](https://godotengine.org/download) (CI builds with 4.7.2 stable).
2. Open `godot_project/project.godot` and press Play.

Release builds for Windows, Linux and macOS come from
[`.github/workflows/build.yml`](.github/workflows/build.yml) on every `v*` tag.

### Default controls

Keyboard defaults depend on the layout (F1 switches between them). All keys can
be rebound in Settings.

| Action | QWERTY | AZERTY | Gamepad |
| :--- | :--- | :--- | :--- |
| Pitch | ↑ / ↓ | ↑ / ↓ | Left stick Y |
| Roll | A / D | Q / D | Left stick X |
| Yaw | ← / → | ← / → | LB / RB, right stick X |
| Throttle up / down | W / S | Z / S | RT / LT |
| Afterburner | Shift | Shift | L3 or Y |
| Gun | F or left mouse | F or left mouse | A or R3 |
| Missile | Space, Enter or right mouse | Space, Enter or right mouse | B |
| Radar | R | R | X |

Hotkeys: **F1** switches the keyboard layout, **F2** switches between
horizontal and vertical split during co-op, and **F3** shows the phone
controller QR code.

Player 2 on the same keyboard uses `I/K` pitch, `J/L` roll, `U/O` yaw,
`Y/H` throttle, `N` boost, `Enter` gun and `M` missile, or the matching numpad
keys. The full map is in
[`config_manager.gd`](godot_project/config_manager.gd).

### Running tests

The `test_*.gd` scripts in `godot_project/` are headless `SceneTree` scripts:

```sh
godot --headless --path godot_project -s test_campaign_headless.gd
```

## Website and API

See [`website/README.md`](website/README.md) for local development and
[`website/CLOUDFLARE_WRANGLER_GUIDE.md`](website/CLOUDFLARE_WRANGLER_GUIDE.md)
for deploying to Cloudflare Pages. The D1 schema is in
[`website/schema.sql`](website/schema.sql).

Run `npm run setup-hooks` in `website/` to enable the repo's git hooks. They
build the website before commits that touch `website/` and before every push.

## Asset pipeline

Ships are modeled as parametric CAD in Fusion 360, cleaned up in Blender
(UVs, `SOCKET_` hardpoints, `UCX_` collision), and exported as glTF for Godot
or FBX for Unreal. The bridges let the Python tools in `tools/` run scripts
inside each application:

```sh
python tools/fusion_client.py --ping
python tools/fusion_client.py --file scripts/models/spaceship_v_hull_sculpted.py
python tools/blender_client.py --file tools/mount_weapons_blender.py
```

Scripts resolve paths relative to the repo. Set `VANGUARD_ROOT` if you run them
from somewhere else, and `BLENDER_EXE` if Blender isn't on your `PATH`. Details
are in [`docs/PIPELINE_WORKFLOW.md`](docs/PIPELINE_WORKFLOW.md) and
[`docs/ASSET_GENERATION_AND_MISSION_SPECIFICATION.md`](docs/ASSET_GENERATION_AND_MISSION_SPECIFICATION.md).

## Documentation

| Topic | Document |
| :--- | :--- |
| Flight model and input | [CONTROLS_AND_PHYSICS.md](docs/CONTROLS_AND_PHYSICS.md) |
| HUD, radar, targeting | [HUD_AND_COMBAT_SYSTEM.md](docs/HUD_AND_COMBAT_SYSTEM.md) |
| Weapons and sockets | [WEAPONS_AND_SOCKETS.md](docs/WEAPONS_AND_SOCKETS.md) |
| Multiplayer and co-op | [MULTIPLAYER_AND_COOP_SYSTEM.md](docs/MULTIPLAYER_AND_COOP_SYSTEM.md) |
| Saves, profiles, cloud sync | [SAVE_SYSTEM_AND_PROFILES.md](docs/SAVE_SYSTEM_AND_PROFILES.md) |
| Backend and phone controller | [ZERO_COST_INFRASTRUCTURE_AND_CONTROLLER_SPEC.md](docs/ZERO_COST_INFRASTRUCTURE_AND_CONTROLLER_SPEC.md) |
| Asset pipeline | [PIPELINE_WORKFLOW.md](docs/PIPELINE_WORKFLOW.md) |
| Feature list and UE5 port notes | [FEATURE_LIST_AND_UE5_PORT_GUIDE.md](docs/FEATURE_LIST_AND_UE5_PORT_GUIDE.md) |
| Setting, factions, missions | [docs/lore/](docs/lore/README.md) |
