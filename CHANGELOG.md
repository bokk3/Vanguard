# Changelog

Notable changes to Project Vanguard. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Security
- `AUTH_SECRET` is no longer in `wrangler.toml` or in code. The value that
  was committed is public, so anyone could forge login tokens. It must now
  be set as a Pages secret of at least 32 characters, and the old value is
  refused. If it's missing, auth endpoints return a server error instead of
  falling back to a default. Rotating it logs everyone out once.
- The phone controller server now requires the session room code in the
  handshake before it accepts any input. Previously any device on the LAN
  could connect and fly a player's ship. Room codes are now 6 characters
  from a cryptographic RNG, and wrong or missing codes close the connection
  (4001 / 4002).
- `/api/diag` is off unless a `DIAG_TOKEN` secret is set and sent as a Bearer
  token. It used to be public, showed the start of the Brevo API key, and
  would send a test email to any address.
- Lobby sessions belong to the IP that created them. Session IDs are listed
  publicly, so anyone could previously re-point or delete another player's
  lobby. The heartbeat now takes the pilot ID from the login token instead of
  trusting the request body, and limits the length of names and metadata.
- The game and website create session IDs from a cryptographic RNG.
- Login returns 429 after 10 failed attempts on one account or 30 from one
  IP within 15 minutes. Five wrong email verification codes lock code entry
  for 30 minutes. Failures are counted in a new `auth_throttle` D1 table,
  created on first use.
- Device link codes are `ACE-` plus 6 characters from a cryptographic RNG
  (previously 3 characters from `Math.random`), and only the IP that requested
  a code can collect the login token once it is approved.
- The phone controller page put the `host` and `http` URL parameters into
  `innerHTML`, so a crafted link could run script on the site and read the
  saved login token. It now accepts only a private IPv4 host and numeric
  ports, and builds the LAN link with DOM methods.
- Registration ignores a client-supplied `rank` and only accepts a plain
  squadron name, and the website escapes leaderboard fields. A squadron like
  `<img onerror=...>` previously ran script for everyone viewing the
  leaderboard.
- `POST /api/leaderboard` requires login and validates the mission ID,
  accuracy and ghost key. Guests could post any callsign.
- The email verification link logs the pilot in only on first use, and the
  login token is passed in the URL fragment instead of the query string, so
  it isn't sent to the server or kept in logs. The home page no longer
  accepts `?authtoken=`.
- Removed `rpc_take_damage_net`. Nothing called it, but any connected peer
  could use it to deal any amount of damage.
- The in-game updater refuses zip entries that point outside the staging
  folder (`../`, absolute paths), checks the download's size and, when GitHub
  provides one, its SHA-256 digest, clears earlier extractions first, and
  aborts if a file can't be written. Covered by `test_updater_safety.gd`.
- On macOS the updater copied the new `.app` into the running app's
  `Contents/MacOS` folder, so updates never replaced the app. It now installs
  next to the existing bundle. Not tested on a Mac.
- The website sends a Content-Security-Policy that only allows its own
  scripts.

### Fixed
- `verify.html` wasn't in the Vite build, so on the live site verification
  links opened the home page. It's built now, and the redirects go to `/verify`.
- Cloud sync added the game's cumulative flight time to the stored total on
  every sync, so it grew far past the real value. It now keeps the larger of
  the two, and the highest unlocked mission can't go backwards.
- The registered pilot count no longer adds a made-up 1,420 to the real number.

### Changed
- Website dev dependencies updated within their ranges (Vite 6.4.6) to clear
  `npm audit` advisories for the dev server. The website CI build now also
  checks that `verify.html` and the standalone controller are produced.
- Renamed the Blender and Fusion 360 bridges to `vanguard_bridge` and
  `VanguardBridge`. The Blender panel is now under the "Vanguard" sidebar tab,
  and its operators are `vanguard.*`.
- Tool and model scripts now find files relative to the repo instead of a
  hard-coded `C:\Users\...` path. `VANGUARD_ROOT` and `BLENDER_EXE` override
  the defaults.
- The bridge clients set `__file__` on scripts sent with `--file`, so
  repo-relative paths still work when the code runs inside Fusion or Blender.
- `project.godot`, the macOS export preset and `wrangler.toml` now report 0.9.7,
  matching `VERSION`.
- Rewrote the README and changelog, and changed doc links from `file:///`
  absolute paths to relative ones.

### Removed
- `docs/TEAM_SYNC_HUB.md`, `scratch/`, and the unrelated `tools/verify_backup.py`
  and `tools/fix_rdp.*` scripts.
- Duplicate copies of `dogfight_cinematic_hq.mp4` and the menu soundtrack from
  the repo root (still in `website/public/videos/` and `godot_project/audio/music/`).

## [0.9.7] - 2026-10-12

### Added
- The phone controller is easier to find: there are links in the website
  navbar, hero and mobile drawer, a banner and category button in the home
  menu, and a button in the pause menu. F3 works in the home and pause menus.

## [0.9.6] - 2026-10-08

### Added
- In-engine dogfight cinematic (`cinematic_dogfight.tscn`), rendered at
  1080p60 with Godot's Movie Maker mode and used as the website hero video.
- Four new achievement badges, agility-course CAD models and HUD cards.

### Changed
- Flight model: G-load tracking, induced drag above about 3 G, energy trade on
  climbs and dives, and a stall that reduces control authority, drops the nose
  and sounds a stall horn.
- The Olympus-4 transport is now generated by the CAD pipeline.
- Physics loop and autoload lookup optimizations. Fixed several leaks and
  export warnings.
- The website hero video uses a lighter encode and GPU compositing.

### Fixed
- M03 no longer blows the player up at launch on contact with Olympus-4. The
  escort now flies in echelon.
- Agility timer freezes on crash. The pause menu works in agility mode again.
- Guest and cloud logins are shown differently, and a failed sync now raises
  an error prompt.
- Logo, HUD card and dialog sizing on small windows. The pilot overview card no
  longer covers the hangar ship.

## [0.9.5] - 2026-10-02

### Added
- Agility mode: 8 trials with gates, target buoys, scoring and a ghost replay
  of your best run.
- Pilot stats panel and visual achievement badges.

### Changed
- Visual overhaul of the game client and website: darker hangar, amber accent
  colour, new settings menu styling.
- Reworked the reward wheel and armory screens.

## [0.9.4] - 2026-09-27

### Added
- In-game rewards dialog with wheel spin, login streak claim, armory and badges.
- The squadron badge is now the executable, window and website icon.

### Changed
- Simplified the website hero and navigation.

### Fixed
- Stars balance and rewards now sync correctly in both directions.

## [0.9.3] - 2026-09-27

### Added
- Stars currency, badges, daily login streak, reward wheel and hangar armory.

## [0.9.2] - 2026-09-27

### Added
- Email verification through Brevo's transactional API. Players can verify by
  clicking a signed link (valid 24 h) or by entering a 6-digit code in the game
  or on the website. Unverified accounts can still play.
- D1 migration that adds the verification columns if they are missing.
- 90-second cooldown on `/api/auth/resend-verification`.
- Verified/unverified badge on the website pilot page, and a `verify.html`
  landing page.
- `/api/diag` endpoint for checking the email configuration.

### Fixed
- Verification emails: sender address, subject and headers for Gmail
  deliverability, and links that Brevo's click tracking no longer rewrites.

## [0.9.1] - 2026-09-27

### Added
- Leaderboards (`/api/leaderboard`) in the game and on the website: an overall
  score (mission scores + 500 per kill + 100 per sortie) and per-mission best
  times and scores.
- Home menu regrouped into submenus (sorties, multiplayer, records, settings,
  quit), with Esc / gamepad Back closing them in order.

### Changed
- The multiplayer menu now separates split-screen, LAN and internet play, and
  will not start a match until a second player is present.

## [0.9.0] - 2026-09-27

### Added
- Internet lobbies: logged-in players can publish a lobby to
  `GET /api/network/lobbies`. Gameplay traffic goes directly between players
  over ENet on UDP 7777, not through Cloudflare.
- UPnP port mapping for UDP 7777 (game) and 7778 (ping), with its status shown
  in the UI.
- Lobby list ping measured with UDP probes on port 7778.
- IPv4 and bracketed IPv6 addresses accepted for direct connect.

## [0.8.6] - 2026-09-27

### Added
- Gun aim assist (16° cone, 900 m) with lead calculation, and a proximity
  check on bullets so they don't pass through thin meshes.
- Drones and the boss now lead their shots and fire in short bursts.

### Fixed
- Phone controller gyro pitch was inverted in landscape. Added instant
  re-centring.
- The phone controller stays connected across mission changes.

## [0.8.5] - 2026-09-27

### Changed
- Custom boot splash with the Vanguard logo.
- Larger login dialog with guest and cloud login options. Removed the
  mode-selector popup after login.
- Website download buttons detect Windows, Linux or macOS.

## [0.8.2] - 2026-09-26

### Added
- Presence API (`/api/network/stats`, `heartbeat`, `leave`) with an
  `active_sessions` D1 table, and online, lobby and registered-player counters
  on the website and in the game menus.
- Radial vignette at high G and a G-LOC warning on the HUD.

## [0.8.0] - 2026-09-24

### Added
- Drop-in split-screen co-op in all campaign missions. Player 2 joins by
  pressing any of their controls. F2 switches horizontal and vertical split.
  A downed player respawns near their wingman after 5 s, and the sortie fails
  only if both are down.
- Local 1v1 split-screen arena, first to 5 kills.
- LAN multiplayer over ENet with UDP discovery beacons and interpolated
  snapshots.
- Multiplayer menu for hosting, scanning, direct connect and split-screen.
- `docs/MULTIPLAYER_AND_COOP_SYSTEM.md`.

## [0.7.4] - 2026-09-21

### Added
- Enemy drones shoot back. Their spread and damage scale with difficulty and
  mission. Shields absorb hits before hull.
- Logo fly-through when launching a sortie, and the prologue cutscene before M01.
- Settings → Data & Storage: reset settings and delete saves.
- Hard terrain impacts destroy the ship, glancing ones scrape.

## [0.7.0] - 2026-09-20

### Added
- Homing missiles with launch impulse, exhaust and smoke trail, proportional
  navigation and 50 damage on impact.
- Four wing pylons that fire in a balanced order and visibly empty and refill.
- Explosion effect, drone hit flashes, health bars, hit markers and combat
  messages.
- Missile reload (6.5 s per missile) and a full refill near the nav beacon.

## [0.6.0] - 2026-09-20

### Added
- In-game key remapping with AZERTY and QWERTY presets.
- `docs/FEATURE_LIST_AND_UE5_PORT_GUIDE.md`.

### Changed
- Arrow keys pitch and yaw, A/D (Q/D on AZERTY) roll, W/S (Z/S) throttle.
  Mouse steering is still available.
- `spaceship_controller.gd` reads only from the `InputMap`.

## [0.5.0] - 2026-09-20

### Added
- JSON save system (`user://saves/vanguard_savegame.json`) with Continue in the
  home menu and Save/Load in the pause menu.
- `VERSION` file and `config/version` in `project.godot`.

## [0.4.0] - 2026-09-20

### Added
- Home menu with a 3D hangar and turntable ship.
- Pause menu (Esc).
- `ConfigManager` with settings saved to `user://settings.cfg`.

## [0.3.0] - 2026-09-20

### Added
- HUD: compass ribbon, radar (R), target lock, afterburner heat, shields and hull.
- AZERTY detection with F1 to switch.

## [0.2.0] - 2026-09-19

### Added
- Headless Blender pipeline (UVs, `UCX_` collision, UE5 axes), PBR texture
  processing, UE5 remote-execution client and a level generator.

## [0.1.0] - 2026-09-18

### Added
- First fighter model and FBX export.
- Fusion 360 and Blender bridge servers.
- Git LFS for meshes and textures.
