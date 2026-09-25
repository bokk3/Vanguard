# 🎨 Vanguard Web & Media Asset Gallery

High-resolution promotional key art, studio branding assets, and UI concept renders for the official **Project Vanguard** website, press kit, and marketing campaigns.

---

## 📁 Gallery Manifest

| Asset Name | Resolution / Format | Primary Use | Description |
| :--- | :--- | :--- | :--- |
| **[`vanguard_hero_fighter.jpg`](vanguard_hero_fighter.jpg)** | `1920x1080` (16:9) / JPEG | Website Hero Banner / Key Art | The F-77 Sculpted V-Hull Interceptor banking hard through atmospheric storm clouds with glowing cyan plasma afterburners and armed Vanguard Strike Missiles. |
| **[`vanguard_squadron_patch.png`](vanguard_squadron_patch.png)** | `1024x1024` (1:1) / Transparent PNG | Web Navigation, Overlays, Merchandise | Official embroidered tactical insignia of the **404th Vanguard Strike Wing** with **transparent alpha background** (carbon texture removed with anti-aliased edge). |
| **[`vanguard_squadron_patch_cropped.png`](vanguard_squadron_patch_cropped.png)** | `760x760` (1:1) / Transparent PNG | Favicons, In-Game Menu Sidebar, Badges | Tight-cropped circular insignia with zero excess border padding. Integrated into the Godot `HomeMenu` sidebar header and project README. |
| **[`vanguard_squadron_patch.svg`](vanguard_squadron_patch.svg)** | Scalable / Vector + SVG | Web Headers, Responsive UI | SVG container embedding the embroidered patch with circular vector clip path and dynamic glow filter. |
| **[`vanguard_vector_emblem.svg`](vanguard_vector_emblem.svg)** | Pure Procedural Vector SVG | Scalable Logos, Header Badges | 100% vector graphic with sharp geometric diamond chevrons, interceptor silhouette, star accents, and curved typography. |
| **[`project_vanguard_title_cropped.png`](project_vanguard_title_cropped.png)** | `1383x351` Transparent PNG | Official Game Title Wordmark | Chiseled titanium & tactical cyan aerospace typography with flanking intake brackets, stencil subtext, and hazard gold accents. |
| **[`project_vanguard_title.png`](project_vanguard_title.png)** | `2400x640` Transparent PNG | Full Wide Website & Press Kit Banner | Full-width title banner with speed streak lines and wide tactical spacing. |
| **[`vanguard_title_logo.png`](vanguard_title_logo.png)** | `800x220` Transparent PNG | Compact UI Header | Stylized compact logo with tactical cyan chevron backdrop. |
| **[`fighter_blueprint_topdown.png`](fighter_blueprint_topdown.png)** | `1024x1024` Transparent PNG | Menu Specs Panel, Hangar Telemetry | Top-down technical HUD schematic of the F-77 Interceptor with 4x pylon weapon stations, 20mm cannon, radar radome, and dimension callouts. |
| **[`menu_icon_deploy.png`](menu_icon_deploy.png)** | `128x128` Transparent PNG | UI Button `[ 01 ] DEPLOY SORTIE` | Ascending interceptor inside tactical diamond brackets with glowing cyan thrusters. |
| **[`menu_icon_config.png`](menu_icon_config.png)** | `128x128` Transparent PNG | UI Button `[ 02 ] AVIONICS CONFIG` | Tactical radar reticle with telemetry diagnostic equalization sliders. |
| **[`menu_icon_specs.png`](menu_icon_specs.png)** | `128x128` Transparent PNG | UI Button `[ 03 ] FIGHTER SPECS` | Isometric CAD wireframe blueprint glyph with center target reticle. |
| **[`menu_icon_quit.png`](menu_icon_quit.png)** | `128x128` Transparent PNG | UI Button `[ 04 ] ABORT / QUIT` | Emergency pilot ejection / tactical abort hazard glyph with amber warning borders. |
| **[`faction_sol_crest.png`](faction_sol_crest.png)** | `512x512` Transparent PNG | Sol Directorate Lore & Campaign UI | Sovereign planetary authority emblem with cobalt/gold orbital ring and ascending vector chevron. |
| **[`faction_combine_crest.png`](faction_combine_crest.png)** | `512x512` Transparent PNG | Helion Combine Adversary & Threat HUD | Predatory hexagonal crimson insignia representing the rogue extraction syndicate and autonomous drone grids. |
| **[`vanguard_cockpit_hud.jpg`](vanguard_cockpit_hud.jpg)** | `1920x1080` (16:9) / JPEG | Gameplay Features Section / Banner | First-person cockpit perspective through the faceted canopy showing holographic HUD tracking, top compass ribbon, radar sweeps, and target lock-on during high-altitude combat. |

---

## 🌐 Website Integration Guidelines

### 1. Hero Landing Page Section
```html
<header class="hero-section" style="background-image: url('docs/lore/images/vanguard_hero_fighter.jpg');">
  <div class="hero-content">
    <img src="docs/lore/images/vanguard_squadron_patch.jpg" alt="404th Vanguard Strike Wing" class="squadron-patch" />
    <h1 class="glitch-title">PROJECT VANGUARD</h1>
    <p class="tagline">Precision in the Void. Firepower in the Envelope.</p>
    <a href="#play" class="btn-cta">Scramble Interceptor</a>
  </div>
</header>
```

### 2. Feature Section (Cockpit & Combat Telemetry)
* Feature image: [`vanguard_cockpit_hud.jpg`](vanguard_cockpit_hud.jpg)
* Accompanying copy:
  > *"True 6-DOF Aerodynamic Combat. Master the stall envelope, track hostiles through your 350m polar radar, and lock on with Vanguard Precision Strike Missiles."*

### 3. Palette & Hex Codes for Web CSS
* **Titanium Void (Background):** `#0B0E14`
* **Tactical Cyan (HUD & Accents):** `#00E5FF`
* **Vanguard Cobalt (Directorate Blue):** `#0D47A1`
* **Afterburner Amber (Stall / Warning):** `#FFB300`
* **Hostile Crimson (Lock Reticle):** `#FF1744`
