# Project Vanguard Web Portal 🚀🌐

Official web application, pilot operations center, and mobile flight companion for **Project Vanguard**, hosted globally on **Cloudflare Pages**.

* **Live Production Portal**: [`https://project-vanguard.pages.dev`](https://project-vanguard.pages.dev)
* **Status**: Combat Ready (v0.8.0)
* **Architecture**: Vite 6 + Tailwind CSS + Cloudflare Pages Functions + Cloudflare D1 (Serverless SQLite)

---

## 🌟 Core Modules

### 1. Tactical Flight Operations Portal (`/`)
* **Mission Recon Dossier**: Interactive orbital recon cards, theater briefings, and combat directives for all 8 campaign missions.
* **Release Synchronization**: Auto-syncs latest release tags, changelogs, and binary downloads directly from GitHub (`bokk3/Vanguard`) with client-side caching.
* **HUD Audio Synthesizer**: Zero-dependency Web Audio API procedural sound effects (radar lock blips, weapon charge, comms clicks).
* **Save File Dossier Inspector**: Client-side drag-and-drop tool that parses `vanguard_savegame.json` using the browser's `FileReader` API (100% free, 0 server compute).

### 2. "Scan-to-Fly" Mobile Web Controller (`/controller`)
* **Zero-Download Phone HOTAS**: Any smartphone camera scanning an in-game QR code instantly launches the controller.
* **Touch & Gyroscope Flight**: Dual virtual thumbstick, continuous throttle slider, and optional `DeviceOrientationEvent` gyroscope tilt steering.
* **Tactile Haptic Feedback**: Vibrates phone hardware (`navigator.vibrate`) upon photon laser discharge and missile lock-on.
* **Direct LAN WebSocket Bridge**: Connects directly to the host PC (`ws://<local_ip>:8080`) for sub-5ms control latency.

### 3. Sovereign Pilot Cloud Backend (`/functions/api/`)
* **$0 Infrastructure Cost**: Leverages Cloudflare Pages Functions and Cloudflare D1 (edge SQLite) with 5,000,000 reads/day and 100,000 writes/day free.
* **Pilot Authentication**: PBKDF2 password hashing, secure token generation, and device QR link authorization.
* **Verified Leaderboards**: Global mission rankings with client-side cryptographic HMAC validation.

---

## 🚀 Local Development

```bash
# 1. Navigate to website directory
cd website

# 2. Install dependencies
npm install

# 3. Start local development server with Vite HMR
npm run dev

# 4. Compile static production build
npm run build

# 5. Preview production build locally
npm run preview
```

---

## ☁️ Cloudflare Pages & D1 Deployment

### Cloudflare Pages Git Integration
1. Cloudflare Pages is connected to `bokk3/Vanguard` on branch `main`.
2. Every push automatically triggers a build (`npm run build`, output: `dist`).
3. Pages Functions inside `functions/` are automatically packaged into edge Workers.

### Managing D1 Database via Wrangler
```bash
# Authenticate Wrangler with Cloudflare
npx wrangler login

# Create D1 database for Project Vanguard
npx wrangler d1 create vanguard-db

# Execute schema migration on production D1
npx wrangler d1 execute vanguard-db --file=./schema.sql
```

---

## 📁 Repository Structure

```text
website/
├── functions/                    # Cloudflare Pages Serverless API Functions
│   └── api/                      # Edge REST endpoints
│       ├── auth/                 # /api/auth (register, login, link)
│       ├── pilot/                # /api/pilot (profile, savegame sync)
│       └── leaderboard/          # /api/leaderboard (top sorties)
├── public/                       # Static public assets
│   ├── _headers                  # Security headers & cache control
│   └── images/                   # High-res blueprints & mission recon cards
├── src/                          # Frontend source code
│   ├── main.js                   # Landing page logic & GitHub API sync
│   ├── missions.js               # Structured campaign mission metadata
│   ├── controller.js             # Mobile HOTAS touch/gyro controller engine
│   └── style.css                 # Tailwind CSS directives & HUD theme
├── index.html                    # Tactical operations landing page
├── controller.html               # Mobile HOTAS cockpit web companion
├── schema.sql                    # Cloudflare D1 database schema
├── wrangler.toml                 # Cloudflare Wrangler configuration
└── vite.config.js                # Vite 6 bundler configuration
```
