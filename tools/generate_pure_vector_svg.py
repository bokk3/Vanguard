pure_vector_svg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800" width="100%" height="100%">
  <defs>
    <!-- Gradients -->
    <radialGradient id="bgGlow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#1565C0" stop-opacity="0.9" />
      <stop offset="70%" stop-color="#0D47A1" stop-opacity="0.95" />
      <stop offset="100%" stop-color="#082046" stop-opacity="1.0" />
    </radialGradient>

    <linearGradient id="metalRing" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF" />
      <stop offset="50%" stop-color="#90A4AE" />
      <stop offset="100%" stop-color="#ECEFF1" />
    </linearGradient>

    <linearGradient id="cyanPlasma" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#00E5FF" />
      <stop offset="100%" stop-color="#0091EA" stop-opacity="0.2" />
    </linearGradient>

    <linearGradient id="interceptorBody" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#ECEFF1" />
      <stop offset="50%" stop-color="#B0BEC5" />
      <stop offset="100%" stop-color="#78909C" />
    </linearGradient>

    <!-- Drop Shadow Filter -->
    <filter id="vectorDropShadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="10" stdDeviation="12" flood-color="#00E5FF" flood-opacity="0.3" />
    </filter>

    <!-- Curved Text Paths -->
    <path id="topTextPath" d="M 170,400 A 230,230 0 0,1 630,400" fill="none" />
    <path id="bottomTextPath" d="M 640,400 A 240,240 0 0,1 160,400" fill="none" />
  </defs>

  <!-- Outer Glow Group -->
  <g filter="url(#vectorDropShadow)">
    <!-- Outer Stitched / Segmented Border Ring -->
    <circle cx="400" cy="400" r="375" fill="none" stroke="#00E5FF" stroke-width="4" stroke-opacity="0.8" />
    <circle cx="400" cy="400" r="365" fill="none" stroke="#1E88E5" stroke-width="12" />
    <circle cx="400" cy="400" r="355" fill="none" stroke="#ECEFF1" stroke-width="2" stroke-dasharray="6,6" />

    <!-- Main Shield Disc -->
    <circle cx="400" cy="400" r="350" fill="url(#bgGlow)" />
    
    <!-- Concentric Inner Tactical Rings -->
    <circle cx="400" cy="400" r="285" fill="none" stroke="#1565C0" stroke-width="32" stroke-opacity="0.7" />
    <circle cx="400" cy="400" r="268" fill="none" stroke="#00E5FF" stroke-width="2" />
    <circle cx="400" cy="400" r="190" fill="none" stroke="#42A5F5" stroke-width="1.5" stroke-dasharray="8,8" />

    <!-- Central Diamond Chevrons (Multi-Layered CAD Precision) -->
    <!-- Outer Chevron -->
    <polygon points="400,210 540,400 400,560 260,400" fill="none" stroke="#ECEFF1" stroke-width="14" stroke-linejoin="round" />
    <!-- Middle Chevron -->
    <polygon points="400,245 510,400 400,530 290,400" fill="none" stroke="#00E5FF" stroke-width="6" stroke-linejoin="round" />
    <!-- Inner Dark Core -->
    <polygon points="400,270 485,400 400,505 315,400" fill="#0A192F" stroke="#1E88E5" stroke-width="3" />

    <!-- Plasma Thruster Plumes -->
    <path d="M 388,435 L 372,550 L 392,442 Z" fill="url(#cyanPlasma)" opacity="0.9" />
    <path d="M 412,435 L 428,550 L 408,442 Z" fill="url(#cyanPlasma)" opacity="0.9" />
    <line x1="384" y1="435" x2="368" y2="565" stroke="#00E5FF" stroke-width="3" stroke-linecap="round" />
    <line x1="416" y1="435" x2="432" y2="565" stroke="#00E5FF" stroke-width="3" stroke-linecap="round" />

    <!-- Sculpted V-Hull Interceptor Silhouette Climbing 45-deg Angle -->
    <!-- Forward Canards, Delta Wings, Twin Vertical Stabilizers -->
    <g transform="translate(400, 375) rotate(-35)">
      <!-- Wingtip Missiles -->
      <line x1="-125" y1="20" x2="-125" y2="-45" stroke="#ECEFF1" stroke-width="3.5" stroke-linecap="round" />
      <line x1="125" y1="20" x2="125" y2="-45" stroke="#ECEFF1" stroke-width="3.5" stroke-linecap="round" />
      
      <!-- Main Fighter Body -->
      <polygon points="
        0,-140 
        12,-85 24,-45 42,-25 120,28 120,42 85,38 45,55 35,80 
        15,75 10,85 0,82
        -10,85 -15,75 -35,80 -45,55 -85,38 -120,42 -120,28 -42,-25 -24,-45 -12,-85
      " fill="url(#interceptorBody)" stroke="#FFFFFF" stroke-width="2.5" stroke-linejoin="round" />

      <!-- Twin Engine Exhausts -->
      <rect x="-24" y="80" width="16" height="12" rx="2" fill="#263238" stroke="#00E5FF" stroke-width="2" />
      <rect x="8" y="80" width="16" height="12" rx="2" fill="#263238" stroke="#00E5FF" stroke-width="2" />

      <!-- Cockpit Glass (Faceted Cyan) -->
      <polygon points="0,-75 7,-35 0,-15 -7,-35" fill="#00E5FF" stroke="#FFFFFF" stroke-width="1.5" />
      <line x1="0" y1="-75" x2="0" y2="-15" stroke="#FFFFFF" stroke-width="1.2" />

      <!-- Wing Seamlines / Panel Details -->
      <line x1="-18" y1="-10" x2="-80" y2="28" stroke="#546E7A" stroke-width="1.8" />
      <line x1="18" y1="-10" x2="80" y2="28" stroke="#546E7A" stroke-width="1.8" />
    </g>

    <!-- Flanking Tactical 4-Point Navigation Stars -->
    <!-- Left Star -->
    <g transform="translate(185, 400)">
      <polygon points="0,-22 5,-5 22,0 5,5 0,22 -5,5 -22,0 -5,-5" fill="#00E5FF" />
      <circle cx="0" cy="0" r="3" fill="#FFFFFF" />
    </g>
    <!-- Right Star -->
    <g transform="translate(615, 400)">
      <polygon points="0,-22 5,-5 22,0 5,5 0,22 -5,5 -22,0 -5,-5" fill="#00E5FF" />
      <circle cx="0" cy="0" r="3" fill="#FFFFFF" />
    </g>

    <!-- Top Text: 404th VANGUARD -->
    <text font-family="'Segoe UI', 'Montserrat', 'Helvetica Neue', sans-serif" font-weight="900" font-size="38" fill="#FFFFFF" letter-spacing="9">
      <textPath href="#topTextPath" startOffset="50%" text-anchor="middle">404th VANGUARD</textPath>
    </text>

    <!-- Bottom Text: STRIKE WING -->
    <text font-family="'Segoe UI', 'Montserrat', 'Helvetica Neue', sans-serif" font-weight="800" font-size="34" fill="#00E5FF" letter-spacing="12">
      <textPath href="#bottomTextPath" startOffset="50%" text-anchor="middle">STRIKE WING</textPath>
    </text>
  </g>
</svg>
'''

with open(r"docs/lore/images/vanguard_vector_emblem.svg", "w", encoding="utf-8") as f:
    f.write(pure_vector_svg)

print("Saved docs/lore/images/vanguard_vector_emblem.svg")
