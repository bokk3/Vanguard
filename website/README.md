# Project Vanguard Website

Official public landing page and tactical portal for **Project Vanguard**, engineered for fast static hosting on **Cloudflare Pages**.

---

## 🚀 Quick Start (Local Development)

```bash
# 1. Navigate to website directory
cd website

# 2. Install dependencies
npm install

# 3. Start local development server with HMR
npm run dev

# 4. Compile static production build
npm run build

# 5. Preview production build locally
npm run preview
```

---

## ☁️ Cloudflare Pages Deployment Guide

### Option 1: Git Integration (Recommended)
1. Go to **Cloudflare Dashboard** &rarr; **Workers & Pages** &rarr; **Create application** &rarr; **Pages** &rarr; **Connect to Git**.
2. Select the `bokk3/Vanguard` repository.
3. Configure the build settings:
   - **Framework preset**: `Vite` (or None)
   - **Build command**: `npm run build`
   - **Build output directory**: `dist`
   - **Root directory**: `website`
4. Click **Save and Deploy**. Cloudflare Pages will automatically rebuild on every `git push`.

### Option 2: Direct Upload via Wrangler CLI
```bash
# Install Wrangler globally or use npx
npx wrangler pages deploy dist --project-name=vanguard
```

---

## 📁 Architecture

- **`index.html`**: Tactical sci-fi landing page with HUD scanline effects, live atmospheric telemetry ticker, fighter blueprint specs, and responsive controls.
- **`src/missions.js`**: Structured dossier containing tactical recon cards, objectives, and parameters for all 8 campaign missions.
- **`src/main.js`**: Interactive mission switcher, AZERTY/QWERTY layout toggler, F2 split-screen simulator, and zero-dependency procedural Web Audio sound effects.
- **`src/style.css`**: Tailwind directives and tactical HUD glow/border styling.
- **`public/images/`**: High-resolution 3D renders, squadron patches, and mission reconnaissance cards.
- **`public/_headers`**: Cloudflare Pages security headers (X-Frame-Options, MIME types, cache control).
