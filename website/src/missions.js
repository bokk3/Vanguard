export const missions = [
  {
    id: "M01",
    codename: "CLOUDBURST",
    title: "Atmospheric Scramble",
    act: "Chapter I: Iron Canopy",
    theater: "Southern Stratospheric Defense Grid // Alt: 8,500m",
    threatLevel: "CADET / TACTICAL",
    reconCard: "/images/mission_card_m01.png",
    briefing: "Hostile Helion Combine reconnaissance UCAV swarms have breached the troposphere perimeter. Scramble from Alert-1 readiness, intercept advance patrol bogeys, and eliminate the target drones before their telemetry relays fire.",
    objectives: [
      "Eliminate 4x Stalker-4 Recon Drones",
      "Perform tactical altitude check above 75m",
      "Secure airspace corridor for extraction"
    ],
    skyPreset: "Cloudburst Dawn // Sun Elevation 32°",
    reward: "Rank S: 10,000 PTS // Unlocks M02 Iron Canyon"
  },
  {
    id: "M02",
    codename: "IRON CANYON",
    title: "Low-Altitude Radar Masking",
    act: "Chapter I: Iron Canopy",
    theater: "Caldera Trench System // Alt: < 120m Masking Ceiling",
    threatLevel: "VETERAN",
    reconCard: "/images/mission_card_m02.png",
    briefing: "Deep canyon strike run beneath enemy long-range surface radar ceilings. Stay low between the red basalt cliffs to avoid surface-to-air missile locks while systematically disabling automated EW jamming relays.",
    objectives: [
      "Fly below 120m canyon radar masking ceiling",
      "Destroy 3x Hardened Jamming Relays",
      "Neutralize canyon flank patrol interceptors"
    ],
    skyPreset: "Ochre Canyon Haze // Basalt Valley",
    reward: "Rank S: 14,500 PTS // Unlocks M03 Apex Liftoff"
  },
  {
    id: "M03",
    codename: "APEX LIFTOFF",
    title: "Ascent Corridor Defense",
    act: "Chapter I: Iron Canopy",
    theater: "Apex Orbital Launch Gantry // Ascending Vector",
    threatLevel: "HARDENED",
    reconCard: "/images/mission_card_m03.png",
    briefing: "The heavy sub-orbital transport 'Olympus-4' is beginning its vertical booster burn. Provide high-energy close air support across 3 aggressive enemy strike craft attack waves to safeguard the transport's climb into orbit.",
    objectives: [
      "Protect Heavy Transport Olympus-4 from destruction",
      "Intercept Wave 1: Razor Skirmisher interceptors",
      "Intercept Wave 2: Strikefly Dive Bombers",
      "Intercept Wave 3: Heavy combined strike package"
    ],
    skyPreset: "High Noon Cobalt // Dynamic Ascent",
    reward: "Rank S: 18,000 PTS // Unlocks M04 Stratosphere Zero"
  },
  {
    id: "M04",
    codename: "STRATOSPHERE ZERO",
    title: "Combine Ghost Prototype Duel",
    act: "Chapter I Finale: Mesosphere",
    theater: "Mesosphere Karman Boundary // Alt: 35,000m",
    threatLevel: "BOSS // CLASSIFIED",
    reconCard: "/images/mission_card_m04.png",
    briefing: "High-altitude duel against the Combine Ghost—an advanced stealth air superiority prototype featuring phased active camouflage, high-maneuverability vectored thrust, and micro-missile salvos. Bring it down.",
    objectives: [
      "Track down Combine Ghost stealth telemetry signatures",
      "Evade phased optical camouflage ambushes",
      "Splash the Combine Ghost air superiority prototype"
    ],
    skyPreset: "Karman Boundary Velvet // Black Sky Dawn",
    reward: "Rank S: 25,000 PTS // Unlocks Chapter II & Orbital Theater"
  },
  {
    id: "M05",
    codename: "SILENT ORBIT",
    title: "Debris Field Mine Sweep",
    act: "Chapter II: Deep Space & Orbital Forge",
    theater: "Low Earth Orbit // Orbital Shrapnel Belt Alpha",
    threatLevel: "VETERAN",
    reconCard: "/images/mission_card_m05.png",
    briefing: "Navigate a derelict orbital junk field and neutralize automated tether mines before they detonate against allied logistics freighters entering high orbital transit.",
    objectives: [
      "Navigate dense moving asteroid & orbital debris belts",
      "Disarm 6x Proximity Tether Mines",
      "Clear the civilian evacuation transit corridor"
    ],
    skyPreset: "Hard Vacuum Stellar // Earth Horizon Glow",
    reward: "Rank S: 16,000 PTS // Unlocks M06 Ghost Reef"
  },
  {
    id: "M06",
    codename: "GHOST REEF",
    title: "Sub-Surface Geothermal Run",
    act: "Chapter II: Deep Space & Orbital Forge",
    theater: "Volcanic Cavern Trench // Sub-Surface Conduit 04",
    threatLevel: "HAZARDOUS",
    reconCard: "/images/mission_card_m06.png",
    briefing: "High-speed tactical trench sprint inside volcanic cavern conduits. Precision bank control is mandatory to avoid rock arches and destroy geothermal generators powering enemy orbital cannon batteries.",
    objectives: [
      "Thread narrow subterranean cavern conduits",
      "Destroy 4x Geothermal Generator Cores",
      "Escape through the thermal exhaust flue before collapse"
    ],
    skyPreset: "Subterranean Magma Glow // Smoke & Ash",
    reward: "Rank S: 20,000 PTS // Unlocks M07 Dauntless Defender"
  },
  {
    id: "M07",
    codename: "DAUNTLESS DEFENDER",
    title: "Fleet Carrier Fleet Escort",
    act: "Chapter II: Deep Space & Orbital Forge",
    theater: "High Orbit Above Jupiter's Moon // SOC Task Force 8",
    threatLevel: "FLEET SCALE",
    reconCard: "/images/mission_card_m07.png",
    briefing: "The fleet carrier SOC Dauntless has sustained engine damage and is under sustained anti-ship torpedo bombardment. Intercept incoming hypersonic fusion torpedoes and clear hostile bombers.",
    objectives: [
      "Protect Fleet Carrier SOC Dauntless from hull failure",
      "Shoot down 8x incoming Fusion Torpedoes in flight",
      "Splash heavy bomber escorts before torpedo lock"
    ],
    skyPreset: "Jovian Gas Giant Corona // Deep Void",
    reward: "Rank S: 24,000 PTS // Unlocks M08 Nexus Crucible"
  },
  {
    id: "M08",
    codename: "NEXUS CRUCIBLE",
    title: "Dreadnought Fortress Breach",
    act: "Chapter II Finale: Ascension Zenith",
    theater: "Orbital Shipyard Fortress // Dreadnought Nemesis-9",
    threatLevel: "CRUCIBLE // ACE",
    reconCard: "/images/mission_card_m08.png",
    briefing: "The decisive fleet engagement. Punch through the flak barrier of the dreadnought Nemesis-9, destroy the heavy CIWS flak batteries, breach the exhaust vent, and deliver the payload into the central antimatter reactor core.",
    objectives: [
      "Disable 4x Dreadnought Flak Defense Turrets",
      "Penetrate ventral magnetic shield barrier",
      "Surgical torpedo strike into the primary Reactor Core",
      "Emergency high-G escape from superstructure blast wave"
    ],
    skyPreset: "Crucible Nova Red // Exploding Citadel",
    reward: "Rank S: 35,000 PTS // Campaign Victory & Ace Mode"
  }
];
