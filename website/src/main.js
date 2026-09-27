import './style.css';
import { missions } from './missions.js';

// Procedural Tactical UI Audio Synthesizer (Zero asset dependency)
class TacticalAudio {
  constructor() {
    this.ctx = null;
    this.muted = false;
  }

  init() {
    if (!this.ctx && typeof AudioContext !== 'undefined') {
      this.ctx = new (window.AudioContext || window.webkitAudioContext)();
    }
  }

  beep(freq = 880, duration = 0.04, type = 'sine') {
    if (this.muted) return;
    this.init();
    if (!this.ctx) return;
    if (this.ctx.state === 'suspended') this.ctx.resume();

    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = type;
    osc.frequency.setValueAtTime(freq, this.ctx.currentTime);

    gain.gain.setValueAtTime(0.08, this.ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + duration);

    osc.connect(gain);
    gain.connect(this.ctx.destination);

    osc.start();
    osc.stop(this.ctx.currentTime + duration);
  }

  ping() {
    this.beep(1200, 0.08, 'triangle');
  }

  lock() {
    this.beep(1760, 0.12, 'square');
  }
}

const audio = new TacticalAudio();

// Attach tactical sound to all interactive elements with .tactical-click
document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('button, a, .interactive-btn').forEach(el => {
    el.addEventListener('click', () => {
      audio.beep(1100, 0.03);
    });
  });

  // SFX sound toggle button
  const soundToggle = document.getElementById('sound-toggle');
  if (soundToggle) {
    soundToggle.addEventListener('click', () => {
      audio.muted = !audio.muted;
      soundToggle.textContent = audio.muted ? '[ SFX: MUTED ]' : '[ SFX: TACTICAL ]';
      soundToggle.classList.toggle('text-vanguard-textMuted', audio.muted);
      soundToggle.classList.toggle('text-vanguard-cyan', !audio.muted);
    });
  }

  // --- Tactical Menu Soundtrack Engine (Auto-play with gesture fallback) ---
  const bgm = new Audio('/audio/menu_soundscape.mp3');
  bgm.loop = true;
  bgm.volume = 0.35;
  let bgmPlaying = false;
  let bgmUserMuted = false;

  const bgmToggle = document.getElementById('bgm-toggle');
  const bgmLabel = document.getElementById('bgm-label');
  const bgmIcon = document.getElementById('bgm-icon');
  const bgmBars = document.getElementById('bgm-bars');

  function updateBgmUI() {
    if (!bgmToggle) return;
    if (bgmPlaying && !bgm.paused) {
      if (bgmLabel) bgmLabel.textContent = '[ BGM: PLAYING ]';
      if (bgmIcon) bgmIcon.textContent = '🎵';
      if (bgmBars) bgmBars.classList.remove('opacity-25', 'grayscale');
      bgmToggle.classList.remove('text-vanguard-textMuted');
      bgmToggle.classList.add('text-vanguard-cyan');
    } else {
      if (bgmLabel) bgmLabel.textContent = '[ BGM: MUTED ]';
      if (bgmIcon) bgmIcon.textContent = '🔇';
      if (bgmBars) bgmBars.classList.add('opacity-25', 'grayscale');
      bgmToggle.classList.remove('text-vanguard-cyan');
      bgmToggle.classList.add('text-vanguard-textMuted');
    }
  }

  function startBgm() {
    if (bgmUserMuted) return;
    const playPromise = bgm.play();
    if (playPromise !== undefined) {
      playPromise
        .then(() => {
          bgmPlaying = true;
          updateBgmUI();
        })
        .catch(() => {
          // Autoplay policy prevented immediate playback; wait for first user interaction
          bgmPlaying = false;
          updateBgmUI();
          const unlockAudio = () => {
            if (!bgmUserMuted && bgm.paused) {
              bgm.play()
                .then(() => {
                  bgmPlaying = true;
                  updateBgmUI();
                })
                .catch(() => {});
            }
            ['click', 'keydown', 'touchstart', 'scroll'].forEach(evt => {
              window.removeEventListener(evt, unlockAudio);
            });
          };
          ['click', 'keydown', 'touchstart', 'scroll'].forEach(evt => {
            window.addEventListener(evt, unlockAudio, { passive: true, once: true });
          });
        });
    }
  }

  if (bgmToggle) {
    bgmToggle.addEventListener('click', () => {
      audio.ping();
      if (bgm.paused) {
        bgmUserMuted = false;
        bgm.play().then(() => {
          bgmPlaying = true;
          updateBgmUI();
        });
      } else {
        bgmUserMuted = true;
        bgm.pause();
        bgmPlaying = false;
        updateBgmUI();
      }
    });
  }

  startBgm();

  // --- Campaign Mission Dossier System ---
  let selectedMissionIndex = 0;
  const missionTabsContainer = document.getElementById('mission-tabs');
  const missionCardImg = document.getElementById('mission-card-img');
  const missionIdBadge = document.getElementById('mission-id-badge');
  const missionCodename = document.getElementById('mission-codename');
  const missionTitle = document.getElementById('mission-title');
  const missionAct = document.getElementById('mission-act');
  const missionTheater = document.getElementById('mission-theater');
  const missionThreat = document.getElementById('mission-threat');
  const missionBriefing = document.getElementById('mission-briefing');
  const missionObjectives = document.getElementById('mission-objectives');
  const missionSky = document.getElementById('mission-sky');
  const missionReward = document.getElementById('mission-reward');

  function renderMissionTabs() {
    if (!missionTabsContainer) return;
    missionTabsContainer.innerHTML = '';

    missions.forEach((m, idx) => {
      const btn = document.createElement('button');
      btn.className = `w-full text-left p-3 border transition-all duration-200 flex items-center justify-between font-mono text-sm ${
        idx === selectedMissionIndex
          ? 'bg-vanguard-cyan/15 border-vanguard-cyan text-vanguard-cyan shadow-cyan-glow'
          : 'bg-vanguard-panel/60 border-vanguard-border text-slate-400 hover:border-vanguard-cyan/40 hover:text-slate-200'
      }`;
      btn.innerHTML = `
        <div class="flex items-center space-x-3">
          <span class="font-bold tracking-wider">${m.id}</span>
          <span class="font-display font-semibold uppercase text-xs sm:text-sm tracking-wide text-slate-100">${m.codename}</span>
        </div>
        <span class="text-xs px-2 py-0.5 rounded bg-black/40 text-vanguard-cyanDim border border-vanguard-border">${m.act.split(':')[0]}</span>
      `;
      btn.addEventListener('click', () => {
        selectedMissionIndex = idx;
        renderMissionTabs();
        updateMissionView();
        audio.ping();
      });
      missionTabsContainer.appendChild(btn);
    });
  }

  function updateMissionView() {
    const m = missions[selectedMissionIndex];
    if (!m) return;

    if (missionCardImg) missionCardImg.src = m.reconCard;
    if (missionIdBadge) missionIdBadge.textContent = `// OPERATION ${m.id} //`;
    if (missionCodename) missionCodename.textContent = m.codename;
    if (missionTitle) missionTitle.textContent = m.title;
    if (missionAct) missionAct.textContent = m.act;
    if (missionTheater) missionTheater.textContent = m.theater;
    if (missionThreat) missionThreat.textContent = m.threatLevel;
    if (missionBriefing) missionBriefing.textContent = m.briefing;
    if (missionSky) missionSky.textContent = m.skyPreset;
    if (missionReward) missionReward.textContent = m.reward;

    if (missionObjectives) {
      missionObjectives.innerHTML = m.objectives
        .map(
          obj => `
          <li class="flex items-start space-x-2 text-sm text-slate-300">
            <span class="text-vanguard-cyan select-none">▶</span>
            <span>${obj}</span>
          </li>
        `
        )
        .join('');
    }
  }

  renderMissionTabs();
  updateMissionView();

  // --- Keyboard Layout Switcher (AZERTY vs QWERTY) ---
  const btnAzerty = document.getElementById('btn-azerty');
  const btnQwerty = document.getElementById('btn-qwerty');
  const keyThrottle = document.getElementById('key-throttle');
  const keyRollL = document.getElementById('key-roll-l');
  const keyRollR = document.getElementById('key-roll-r');
  const keyYawL = document.getElementById('key-yaw-l');
  const keyYawR = document.getElementById('key-yaw-r');
  const layoutIndicator = document.getElementById('layout-indicator');

  if (btnAzerty && btnQwerty) {
    btnAzerty.addEventListener('click', () => {
      setLayout('AZERTY');
      audio.ping();
    });
    btnQwerty.addEventListener('click', () => {
      setLayout('QWERTY');
      audio.ping();
    });
  }

  function setLayout(layout) {
    if (layout === 'AZERTY') {
      btnAzerty.classList.add('bg-vanguard-cyan', 'text-black');
      btnAzerty.classList.remove('bg-vanguard-panel', 'text-vanguard-cyan');
      btnQwerty.classList.remove('bg-vanguard-cyan', 'text-black');
      btnQwerty.classList.add('bg-vanguard-panel', 'text-slate-300');

      if (keyThrottle) keyThrottle.textContent = 'Z / S';
      if (keyRollL) keyRollL.textContent = 'Q';
      if (keyRollR) keyRollR.textContent = 'D';
      if (keyYawL) keyYawL.textContent = 'A';
      if (keyYawR) keyYawR.textContent = 'E';
      if (layoutIndicator) layoutIndicator.textContent = 'AUTODETECT: BE / FR AZERTY';
    } else {
      btnQwerty.classList.add('bg-vanguard-cyan', 'text-black');
      btnQwerty.classList.remove('bg-vanguard-panel', 'text-vanguard-cyan');
      btnAzerty.classList.remove('bg-vanguard-cyan', 'text-black');
      btnAzerty.classList.add('bg-vanguard-panel', 'text-slate-300');

      if (keyThrottle) keyThrottle.textContent = 'W / S';
      if (keyRollL) keyRollL.textContent = 'A';
      if (keyRollR) keyRollR.textContent = 'D';
      if (keyYawL) keyYawL.textContent = 'Q';
      if (keyYawR) keyYawR.textContent = 'E';
      if (layoutIndicator) layoutIndicator.textContent = 'AUTODETECT: STANDARD QWERTY';
    }
  }

  // --- Split Screen Layout Simulator (F2 Toggle) ---
  const btnToggleSplit = document.getElementById('btn-toggle-split');
  const splitSimContainer = document.getElementById('split-sim-container');
  const splitP1 = document.getElementById('split-p1');
  const splitP2 = document.getElementById('split-p2');
  const splitLabel = document.getElementById('split-layout-label');
  let isHorizontalSplit = true;

  if (btnToggleSplit && splitSimContainer && splitP1 && splitP2) {
    btnToggleSplit.addEventListener('click', () => {
      isHorizontalSplit = !isHorizontalSplit;
      audio.lock();
      if (isHorizontalSplit) {
        splitSimContainer.className = 'grid grid-rows-2 h-72 border border-vanguard-border rounded-lg overflow-hidden bg-black/80';
        splitP1.className = 'relative border-b border-vanguard-border/80 flex items-center justify-center p-4 bg-gradient-to-b from-vanguard-cyan/10 to-transparent';
        splitP2.className = 'relative flex items-center justify-center p-4 bg-gradient-to-t from-vanguard-amber/10 to-transparent';
        if (splitLabel) splitLabel.textContent = 'LAYOUT: HORIZONTAL (TOP / BOTTOM)';
      } else {
        splitSimContainer.className = 'grid grid-cols-2 h-72 border border-vanguard-border rounded-lg overflow-hidden bg-black/80';
        splitP1.className = 'relative border-r border-vanguard-border/80 flex items-center justify-center p-4 bg-gradient-to-r from-vanguard-cyan/10 to-transparent';
        splitP2.className = 'relative flex items-center justify-center p-4 bg-gradient-to-l from-vanguard-amber/10 to-transparent';
        if (splitLabel) splitLabel.textContent = 'LAYOUT: VERTICAL (LEFT / RIGHT)';
      }
    });
  }

  // --- Live Combat Telemetry Ticker (Atmospheric simulation) ---
  const tickerSpeed = document.getElementById('ticker-speed');
  const tickerAlt = document.getElementById('ticker-alt');
  const tickerLift = document.getElementById('ticker-lift');
  let simulatedSpeed = 62.4;
  let simulatedAlt = 3450.0;

  setInterval(() => {
    simulatedSpeed = Math.max(48.0, Math.min(125.0, simulatedSpeed + (Math.random() - 0.48) * 1.5));
    simulatedAlt = simulatedAlt + (Math.random() - 0.5) * 6.0;
    const liftRatio = Math.min(1.0, simulatedSpeed / 25.0);

    if (tickerSpeed) tickerSpeed.textContent = `${simulatedSpeed.toFixed(1)} m/s (${Math.round(simulatedSpeed * 3.6)} km/h)`;
    if (tickerAlt) tickerAlt.textContent = `${Math.round(simulatedAlt)} m`;
    if (tickerLift) tickerLift.textContent = `${(liftRatio * 100).toFixed(0)}% (OPTIMAL)`;
  }, 350);

  // --- Mobile Drawer Toggle ---
  const mobileMenuBtn = document.getElementById('mobile-menu-btn');
  const mobileNav = document.getElementById('mobile-nav');
  if (mobileMenuBtn && mobileNav) {
    mobileMenuBtn.addEventListener('click', () => {
      mobileNav.classList.toggle('hidden');
      audio.ping();
    });
    mobileNav.querySelectorAll('a').forEach(link => {
      link.addEventListener('click', () => {
        mobileNav.classList.add('hidden');
      });
    });
  }

  // --- Live GitHub Release & Tag Sync Engine ---
  async function syncGitHubRelease() {
    const defaultVersion = typeof __APP_VERSION__ !== 'undefined' ? `v${__APP_VERSION__}` : 'v0.8.0';
    const repo = 'bokk3/Vanguard';
    const CACHE_KEY = 'vanguard_github_release_cache';
    const CACHE_TIME_KEY = 'vanguard_github_release_cache_time';
    const CACHE_TTL = 10 * 60 * 1000; // 10 minutes cache

    // Check cached response first
    try {
      const cachedData = sessionStorage.getItem(CACHE_KEY);
      const cachedTime = sessionStorage.getItem(CACHE_TIME_KEY);
      if (cachedData && cachedTime && (Date.now() - parseInt(cachedTime, 10) < CACHE_TTL)) {
        applyReleaseData(JSON.parse(cachedData));
        return;
      }
    } catch (e) {}

    try {
      // 1. Try fetching latest release
      let res = await fetch(`https://api.github.com/repos/${repo}/releases/latest`, {
        headers: { 'Accept': 'application/vnd.github.v3+json' }
      });

      let data = null;
      if (res.ok) {
        data = await res.json();
      } else {
        // 2. Fallback to tags endpoint if no official release object published yet
        const tagsRes = await fetch(`https://api.github.com/repos/${repo}/tags?per_page=1`);
        if (tagsRes.ok) {
          const tags = await tagsRes.json();
          if (tags && tags.length > 0) {
            data = {
              tag_name: tags[0].name,
              html_url: `https://github.com/${repo}/releases/tag/${tags[0].name}`,
              published_at: null,
              assets: []
            };
          }
        }
      }

      if (data && data.tag_name) {
        try {
          sessionStorage.setItem(CACHE_KEY, JSON.stringify(data));
          sessionStorage.setItem(CACHE_TIME_KEY, Date.now().toString());
        } catch (e) {}
        applyReleaseData(data);
      }
    } catch (err) {
      console.warn('[Vanguard Portal] GitHub release sync fallback to build version:', defaultVersion, err);
    }
  }

  function applyReleaseData(data) {
    const tagName = data.tag_name || 'v0.8.0';
    const releaseUrl = data.html_url || 'https://github.com/bokk3/Vanguard/releases';

    // Detect user platform
    const ua = (navigator.userAgent || '').toLowerCase();
    const uaPlatform = (navigator.platform || '').toLowerCase();
    let detectedOS = 'windows'; // default
    if (ua.includes('mac') || uaPlatform.includes('mac')) {
      detectedOS = 'macos';
    } else if (ua.includes('linux') || uaPlatform.includes('linux')) {
      detectedOS = 'linux';
    }

    const platformLabels = {
      windows: 'Win64',
      linux: 'Linux x86_64',
      macos: 'macOS'
    };
    const platformAssetKeys = {
      windows: 'windows',
      linux: 'linux',
      macos: 'macos'
    };

    // Find the platform-matching binary asset from the release
    let directDownloadUrl = releaseUrl;
    let assetSizeText = '';
    let platformLabel = platformLabels[detectedOS];

    if (data.assets && data.assets.length > 0) {
      const key = platformAssetKeys[detectedOS];
      const matchedAsset = data.assets.find(a =>
        a.name.toLowerCase().includes(key)
      );

      if (matchedAsset) {
        directDownloadUrl = matchedAsset.browser_download_url;
        const sizeMb = (matchedAsset.size / (1024 * 1024)).toFixed(1);
        assetSizeText = ` (${sizeMb} MB)`;
      }
      // If no platform match found, link to the release page (not a wrong-platform asset)
    }

    // Update DOM elements
    const topBadge = document.getElementById('top-version-badge');
    if (topBadge) topBadge.textContent = `${tagName.toUpperCase()}`;

    const heroTag = document.getElementById('hero-tag-name');
    if (heroTag) heroTag.textContent = tagName;

    const notesLink = document.getElementById('release-notes-link');
    if (notesLink) notesLink.href = releaseUrl;

    const heroBtn = document.getElementById('hero-download-btn');
    const heroBtnText = document.getElementById('hero-download-text');
    if (heroBtn) heroBtn.href = directDownloadUrl;
    if (heroBtnText) heroBtnText.textContent = `Download ${tagName} (${platformLabel})${assetSizeText}`;

    const downloadSectionBtn = document.getElementById('download-section-btn');
    const downloadSectionText = document.getElementById('download-section-text');
    if (downloadSectionBtn) downloadSectionBtn.href = directDownloadUrl;
    if (downloadSectionText) downloadSectionText.textContent = `Download ${tagName} (${platformLabel})${assetSizeText}`;

    // Announcement status formatting
    const releaseStatusText = document.getElementById('release-status-text');
    if (releaseStatusText) {
      let dateStr = '';
      if (data.published_at) {
        const d = new Date(data.published_at);
        dateStr = ` // ${d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }).toUpperCase()}`;
      }
      releaseStatusText.innerHTML = `DISPATCH: <strong class="text-white">${tagName}</strong>${dateStr} // LIVE ON GITHUB`;
    }
  }

  // ==========================================================================
  // PILOT PORTAL (Registration, Authentication & Live Dossier)
  // ==========================================================================
  const pilotModal = document.getElementById('pilotModal');
  const pilotPortalBtn = document.getElementById('pilot-portal-btn');
  const heroRegisterBtn = document.getElementById('hero-register-btn');
  const mobilePilotBtn = document.getElementById('mobile-pilot-portal-btn');
  const closePilotModalBtn = document.getElementById('close-pilot-modal-btn');

  const tabRegisterBtn = document.getElementById('tab-register-btn');
  const tabLoginBtn = document.getElementById('tab-login-btn');
  const tabDossierBtn = document.getElementById('tab-dossier-btn');

  const viewRegister = document.getElementById('view-register');
  const viewLogin = document.getElementById('view-login');
  const viewDossier = document.getElementById('view-dossier');

  const registerForm = document.getElementById('register-form');
  const regFeedback = document.getElementById('reg-feedback');
  const loginForm = document.getElementById('login-form');
  const loginFeedback = document.getElementById('login-feedback');

  const pilotPortalLabel = document.getElementById('pilot-portal-label');
  const mobilePilotLabel = document.getElementById('mobile-pilot-label');
  const pilotPortalIcon = document.getElementById('pilot-portal-icon');

  function openPilotModal(preferredTab = null) {
    audio.beep(880, 0.05);
    if (pilotModal) pilotModal.classList.remove('hidden');
    if (preferredTab) {
      switchTab(preferredTab);
    } else if (localStorage.getItem('vanguard_pilot_token')) {
      switchTab('dossier');
    }
  }

  function closePilotModal() {
    if (pilotModal) pilotModal.classList.add('hidden');
  }

  if (pilotPortalBtn) pilotPortalBtn.addEventListener('click', openPilotModal);
  if (heroRegisterBtn) heroRegisterBtn.addEventListener('click', openPilotModal);
  if (mobilePilotBtn) mobilePilotBtn.addEventListener('click', openPilotModal);
  if (closePilotModalBtn) closePilotModalBtn.addEventListener('click', closePilotModal);

  if (pilotModal) {
    pilotModal.addEventListener('click', (e) => {
      if (e.target === pilotModal) closePilotModal();
    });
  }

  function switchTab(tab) {
    audio.beep(1200, 0.03);
    [tabRegisterBtn, tabLoginBtn, tabDossierBtn].forEach(b => {
      if (b) {
        b.classList.remove('border-vanguard-cyan', 'text-vanguard-cyan', 'bg-vanguard-cyan/5', 'border-vanguard-amber', 'text-vanguard-amber');
        b.classList.add('border-transparent', 'text-slate-400');
      }
    });

    [viewRegister, viewLogin, viewDossier].forEach(v => {
      if (v) v.classList.add('hidden');
    });

    if (tab === 'register' && tabRegisterBtn && viewRegister) {
      tabRegisterBtn.classList.add('border-vanguard-cyan', 'text-vanguard-cyan', 'bg-vanguard-cyan/5');
      tabRegisterBtn.classList.remove('border-transparent', 'text-slate-400');
      viewRegister.classList.remove('hidden');
    } else if (tab === 'login' && tabLoginBtn && viewLogin) {
      tabLoginBtn.classList.add('border-vanguard-cyan', 'text-vanguard-cyan', 'bg-vanguard-cyan/5');
      tabLoginBtn.classList.remove('border-transparent', 'text-slate-400');
      viewLogin.classList.remove('hidden');
    } else if (tab === 'dossier' && tabDossierBtn && viewDossier) {
      tabDossierBtn.classList.add('border-vanguard-amber', 'text-vanguard-amber', 'bg-vanguard-amber/5');
      tabDossierBtn.classList.remove('border-transparent', 'text-slate-400');
      viewDossier.classList.remove('hidden');
      renderDossier();
    }
  }

  if (tabRegisterBtn) tabRegisterBtn.addEventListener('click', () => switchTab('register'));
  if (tabLoginBtn) tabLoginBtn.addEventListener('click', () => switchTab('login'));
  if (tabDossierBtn) tabDossierBtn.addEventListener('click', () => switchTab('dossier'));

  const BADGES_CATALOG = [
    { id: "FIRST_SORTIE", icon: "🎖️", name: "First Sortie", desc: "Complete initial flight qualification or combat sortie.", condition: "Awarded upon flight commissioning." },
    { id: "ACE_INTERCEPTOR", icon: "⚡", name: "Ace Interceptor", desc: "Confirm 25 or more hostile targets destroyed in combat.", condition: "Destroy 25 enemies." },
    { id: "WAR_GOD_OF_SOL", icon: "👑", name: "War God of Sol", desc: "Legendary combat standing: 100 confirmed career kills.", condition: "Confirm 100 kills." },
    { id: "GHOST_PROTOCOL", icon: "🛡️", name: "Ghost Protocol", desc: "Flawless sortie execution: Survive an engagement taking zero hull damage.", condition: "Flawless mission outcome." },
    { id: "CAMPAIGN_HERO", icon: "🌌", name: "Campaign Hero", desc: "Unlock and conquer Chapter / Mission 05: Silent Orbit.", condition: "Complete Mission 05." },
    { id: "FLEET_DEDICATION", icon: "📅", name: "Fleet Dedication", desc: "Demonstrate relentless discipline: Maintain a 7-day login streak.", condition: "Reach Day 7 streak." },
    { id: "LUCKY_STRIKE", icon: "🎯", name: "Lucky Strike", desc: "Hit the Grand Prize Jackpot (1,000★) on the Daily Tactical Wheel.", condition: "Wheel Jackpot hit." },
    { id: "PVP_GLADIATOR", icon: "⚔️", name: "PVP Gladiator", desc: "Score victory against a rival pilot in local or online dogfight arena.", condition: "Win a PvP match." },
    { id: "ARSENAL_OVERLORD", icon: "🛠️", name: "Arsenal Overlord", desc: "Upgrade any weapon or kinetic defense system to Tier III.", condition: "Upgrade system to Tier 3." },
    { id: "SOLAR_FASHION", icon: "🎨", name: "Solar Fashion", desc: "Acquire and equip a custom aerospace livery from the Hangar.", condition: "Equip custom livery." },
  ];

  const SKINS_CATALOG = {
    "CLASSIC_CYAN": { id: "CLASSIC_CYAN", name: "Interceptor Classic", cost: 0, color: "#00e5ff", desc: "Standard Vanguard titanium-composite hull with cyan avionics." },
    "SOLAR_FLARE": { id: "SOLAR_FLARE", name: "Solar Flare", cost: 250, color: "#ffd700", desc: "Radiant high-albedo gold plating reflecting intense coronal bursts." },
    "VOID_STEALTH": { id: "VOID_STEALTH", name: "Void Stealth", cost: 500, color: "#a855f7", desc: "Radar-absorbent matte carbon black finish with violet impulse glow." },
    "CRIMSON_FURY": { id: "CRIMSON_FURY", name: "Crimson Fury", cost: 750, color: "#ef4444", desc: "Aggressive blood-red aerofoil livery with scorched titanium trim." },
    "CYBER_NEON": { id: "CYBER_NEON", name: "Cyberpunk Neon", cost: 1000, color: "#ec4899", desc: "Overclocked holographic dual-tone synthwave neon coating." },
  };

  const UPGRADES_CATALOG = {
    "PULSE_CANNON": { name: "Pulse Laser Cannons", icon: "⚡", tiers: ["Tier I (Base)", "Tier II (+20% Dmg)", "Tier III (Plasma Punch)"], costs: [100, 250, 600] },
    "HYDRA_MISSILES": { name: "Hydra Missile Pods", icon: "🚀", tiers: ["Tier I (4 Racks)", "Tier II (-25% Lock)", "Tier III (-35% Reload)"], costs: [150, 300, 700] },
    "DEFLECTOR_SHIELD": { name: "Deflector Kinetic Shields", icon: "🛡️", tiers: ["Tier I (100 HP)", "Tier II (+35% Recharge)", "Tier III (50% Divert)"], costs: [120, 280, 650] },
    "AFTERBURNER_TURBO": { name: "Afterburner Turbo Capacitor", icon: "🔥", tiers: ["Tier I (120 m/s)", "Tier II (+25 Nitro)", "Tier III (-30% Drain)"], costs: [100, 220, 500] },
  };

  const STREAK_AMOUNTS = [50, 75, 100, 150, 200, 300, 500];

  function updateAuthUI() {
    const rawProfile = localStorage.getItem('vanguard_pilot_profile');
    const token = localStorage.getItem('vanguard_pilot_token');
    const headerStarsPill = document.getElementById('header-stars-pill');
    const headerStarsVal = document.getElementById('header-stars-val');
    const mobileStarsPill = document.getElementById('mobile-stars-pill');
    const mobileStarsVal = document.getElementById('mobile-stars-val');

    let starsCount = 0;

    if (rawProfile && pilotPortalLabel) {
      try {
        const pilot = JSON.parse(rawProfile);
        starsCount = pilot.rewards?.stars || 0;
        pilotPortalLabel.textContent = pilot.callsign;
        if (mobilePilotLabel) mobilePilotLabel.textContent = `${pilot.rank} ${pilot.callsign}`;
        if (pilotPortalIcon) pilotPortalIcon.textContent = '⚡';
        if (heroRegisterBtn) {
          heroRegisterBtn.innerHTML = `<span class="text-xl">⚡</span><span>PILOT DOSSIER // ${pilot.callsign} [${starsCount}★]</span>`;
        }
        if (tabDossierBtn) tabDossierBtn.classList.remove('hidden');
      } catch {}
    } else if (pilotPortalLabel) {
      pilotPortalLabel.textContent = 'COMMISSION CALLSIGN';
      if (mobilePilotLabel) mobilePilotLabel.textContent = 'COMMISSION CALLSIGN';
      if (pilotPortalIcon) pilotPortalIcon.textContent = '🎖️';
      if (heroRegisterBtn) {
        heroRegisterBtn.innerHTML = `<span class="text-2xl">🎖️</span><span id="hero-register-text">COMMISSION CALLSIGN (FREE)</span>`;
      }
      if (tabDossierBtn) tabDossierBtn.classList.add('hidden');
    }

    if (headerStarsPill) {
      if (token) {
        headerStarsPill.classList.remove('hidden');
        headerStarsPill.classList.add('flex');
        if (headerStarsVal) headerStarsVal.textContent = starsCount.toLocaleString();
      } else {
        headerStarsPill.classList.add('hidden');
        headerStarsPill.classList.remove('flex');
      }
    }
    if (mobileStarsPill) {
      if (token) {
        mobileStarsPill.classList.remove('hidden');
        mobileStarsPill.classList.add('flex');
        if (mobileStarsVal) mobileStarsVal.textContent = `${starsCount.toLocaleString()} ★`;
      } else {
        mobileStarsPill.classList.add('hidden');
        mobileStarsPill.classList.remove('flex');
      }
    }

    renderPilotStats();
  }

  function renderDossier() {
    const rawProfile = localStorage.getItem('vanguard_pilot_profile');
    if (!rawProfile) return;
    try {
      const pilot = JSON.parse(rawProfile);
      const callEl = document.getElementById('dossier-callsign');
      const rankEl = document.getElementById('dossier-rank-squadron');
      if (callEl) callEl.textContent = pilot.callsign;
      if (rankEl) rankEl.textContent = `${pilot.rank} // ${pilot.squadron}`;
      const stats = pilot.stats || {};
      const rewards = pilot.rewards || {
        stars: 0,
        streak: 1,
        badges: ["FIRST_SORTIE"],
        unlocked_skins: ["CLASSIC_CYAN"],
        active_skin: "CLASSIC_CYAN",
        upgrades: { PULSE_CANNON: 1, HYDRA_MISSILES: 1, DEFLECTOR_SHIELD: 1, AFTERBURNER_TURBO: 1 }
      };

      const sortiesEl = document.getElementById('dossier-sorties');
      const killsEl = document.getElementById('dossier-kills');
      const campEl = document.getElementById('dossier-campaign');
      if (sortiesEl) sortiesEl.textContent = stats.total_sorties || 0;
      if (killsEl) killsEl.textContent = stats.total_kills || stats.dogfight_kills || 0;
      if (campEl) campEl.textContent = stats.highest_mission_unlocked || 'M01';

      const won = stats.battles_won || 0;
      const lost = stats.battles_lost || 0;
      const total = won + lost;
      const recordEl = document.getElementById('dossier-record');
      const winRateEl = document.getElementById('dossier-win-rate');
      const controlsEl = document.getElementById('dossier-controls');

      if (recordEl) recordEl.textContent = `${won}W - ${lost}L`;
      if (winRateEl) winRateEl.textContent = total > 0 ? `${((won / total) * 100).toFixed(1)}%` : '0.0%';
      if (controlsEl) controlsEl.textContent = stats.preferred_controls || 'AZERTY';

      // Stars Currency update
      const starsValEl = document.getElementById('dossier-stars-val');
      if (starsValEl) starsValEl.textContent = (rewards.stars || 0).toLocaleString();

      // Verification status handling
      const verifiedBadge = document.getElementById('dossier-verified-badge');
      const unverifiedBox = document.getElementById('dossier-unverified-box');
      const unverifiedEmail = document.getElementById('dossier-unverified-email');

      const isVerified = pilot.email_verified === 1 || pilot.email_verified === true;
      if (verifiedBadge) {
        if (isVerified) {
          verifiedBadge.className = 'inline-block px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-400 border border-emerald-500/40 text-[10px] font-bold';
          verifiedBadge.textContent = '⚡ VERIFIED';
        } else {
          verifiedBadge.className = 'inline-block px-2 py-0.5 rounded bg-amber-500/20 text-amber-400 border border-amber-500/40 text-[10px] font-bold';
          verifiedBadge.textContent = '⚠️ UNVERIFIED';
        }
      }

      if (unverifiedBox) {
        if (isVerified) {
          unverifiedBox.classList.add('hidden');
        } else {
          unverifiedBox.classList.remove('hidden');
          if (unverifiedEmail) unverifiedEmail.textContent = pilot.email || '';
        }
      }

      // Render Rewards Systems
      renderStreakPips(rewards);
      renderBadges(rewards, stats);
      renderArmory(rewards);

    } catch (err) {
      console.warn('[Dossier Error]', err);
    }
  }

  function renderStreakPips(rewards) {
    const container = document.getElementById('streak-pips-container');
    const countText = document.getElementById('streak-count-text');
    const claimBtn = document.getElementById('btn-claim-streak');
    const claimLabel = document.getElementById('streak-claim-label');
    const wheelBtn = document.getElementById('btn-open-wheel');
    const wheelLabel = document.getElementById('wheel-btn-label');

    const streak = Math.max(1, Math.min(rewards.streak || 1, 7));
    if (countText) countText.textContent = `Day ${streak} / 7`;

    const today = new Date().toISOString().split('T')[0];
    const canClaim = rewards.last_login_date !== today;
    const canSpin = rewards.last_wheel_date !== today;

    if (claimBtn && claimLabel) {
      if (canClaim) {
        claimBtn.disabled = false;
        claimBtn.classList.remove('opacity-50', 'cursor-not-allowed');
        claimLabel.textContent = `CLAIM +${STREAK_AMOUNTS[streak - 1]}★`;
      } else {
        claimBtn.disabled = true;
        claimBtn.classList.add('opacity-50', 'cursor-not-allowed');
        claimLabel.textContent = `✓ CLAIMED TODAY`;
      }
    }

    if (wheelBtn && wheelLabel) {
      if (canSpin) {
        wheelLabel.textContent = 'REWARD WHEEL (1 FREE)';
        wheelBtn.classList.add('animate-pulse');
      } else {
        wheelLabel.textContent = 'REWARD WHEEL';
        wheelBtn.classList.remove('animate-pulse');
      }
    }

    if (container) {
      container.innerHTML = Array.from({ length: 7 }, (_, i) => {
        const dayNum = i + 1;
        const isDone = dayNum < streak || (dayNum === streak && !canClaim);
        const isCurrent = dayNum === streak && canClaim;
        const rewardText = `+${STREAK_AMOUNTS[i]}★`;

        let borderClass = 'border-vanguard-border/50 bg-black/40 text-slate-500';
        if (isDone) {
          borderClass = 'border-emerald-500/80 bg-emerald-950/40 text-emerald-400 shadow-[0_0_8px_rgba(52,211,153,0.3)]';
        } else if (isCurrent) {
          borderClass = 'border-vanguard-gold bg-amber-950/50 text-vanguard-gold animate-pulse shadow-[0_0_10px_rgba(255,215,0,0.4)]';
        }

        return `
          <div class="p-1.5 rounded-lg border text-center font-mono ${borderClass}">
            <div class="text-[9px] uppercase font-bold">D${dayNum}</div>
            <div class="text-[10px] font-bold mt-0.5">${dayNum === 7 ? '🎖️ 500★' : rewardText}</div>
          </div>
        `;
      }).join('');
    }
  }

  function renderBadges(rewards, stats) {
    const container = document.getElementById('badges-grid-container');
    const countBadge = document.getElementById('badges-unlocked-badge');
    if (!container) return;

    const unlockedSet = new Set(rewards.badges || []);
    unlockedSet.add("FIRST_SORTIE");
    if ((stats.total_kills || 0) >= 25) unlockedSet.add("ACE_INTERCEPTOR");
    if ((stats.total_kills || 0) >= 100) unlockedSet.add("WAR_GOD_OF_SOL");
    if (['M05', 'M06', 'M07', 'M08'].includes(stats.highest_mission_unlocked)) unlockedSet.add("CAMPAIGN_HERO");
    if ((stats.battles_won || 0) >= 1) unlockedSet.add("PVP_GLADIATOR");
    if ((rewards.streak || 0) >= 7) unlockedSet.add("FLEET_DEDICATION");

    const totalUnlocked = BADGES_CATALOG.filter(b => unlockedSet.has(b.id)).length;
    if (countBadge) countBadge.textContent = `${totalUnlocked}/${BADGES_CATALOG.length}`;

    container.innerHTML = BADGES_CATALOG.map(b => {
      const isUnlocked = unlockedSet.has(b.id);
      return `
        <div class="p-3 rounded-xl border ${isUnlocked ? 'border-vanguard-cyan/60 bg-gradient-to-r from-vanguard-deep to-black/80 shadow-[0_0_15px_rgba(0,229,255,0.15)]' : 'border-vanguard-border/40 bg-black/40 opacity-60'} flex items-start gap-3 transition-all hover:scale-[1.01]">
          <div class="w-10 h-10 rounded-lg flex items-center justify-center text-xl shrink-0 ${isUnlocked ? 'bg-vanguard-cyan/20 border border-vanguard-cyan/50 shadow-cyan-glow' : 'bg-slate-800/50 border border-slate-700/50 grayscale'}">
            ${b.icon}
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center justify-between">
              <h5 class="text-xs font-bold font-display ${isUnlocked ? 'text-white' : 'text-slate-400'} truncate">${b.name}</h5>
              <span class="text-[9px] font-mono px-1.5 py-0.5 rounded font-bold ${isUnlocked ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/40' : 'bg-slate-800 text-slate-500'}">
                ${isUnlocked ? 'UNLOCKED' : 'LOCKED'}
              </span>
            </div>
            <p class="text-[11px] text-slate-300 font-sans mt-0.5 line-clamp-2">${b.desc}</p>
            <div class="text-[9px] font-mono text-vanguard-cyan/80 mt-1 uppercase">// REQUIREMENT: ${b.condition}</div>
          </div>
        </div>
      `;
    }).join('');
  }

  function renderArmory(rewards) {
    const skinsContainer = document.getElementById('skins-grid-container');
    const upgradesContainer = document.getElementById('upgrades-list-container');
    const stars = rewards.stars || 0;
    const unlockedSkins = rewards.unlocked_skins || ['CLASSIC_CYAN'];
    const activeSkin = rewards.active_skin || 'CLASSIC_CYAN';
    const upgrades = rewards.upgrades || { PULSE_CANNON: 1, HYDRA_MISSILES: 1, DEFLECTOR_SHIELD: 1, AFTERBURNER_TURBO: 1 };

    if (skinsContainer) {
      skinsContainer.innerHTML = Object.values(SKINS_CATALOG).map(skin => {
        const isOwned = unlockedSkins.includes(skin.id);
        const isEquipped = activeSkin === skin.id;

        let btnMarkup = '';
        if (isEquipped) {
          btnMarkup = `<span class="px-3 py-1 rounded bg-emerald-500/20 text-emerald-400 border border-emerald-500/40 text-[10px] font-bold font-mono">✓ EQUIPPED</span>`;
        } else if (isOwned) {
          btnMarkup = `<button data-action="equip_skin" data-id="${skin.id}" class="armory-action-btn px-3 py-1 rounded bg-vanguard-cyan text-black hover:bg-white text-[10px] font-bold uppercase tracking-wider font-display transition-all cursor-pointer">EQUIP</button>`;
        } else {
          const canAfford = stars >= skin.cost;
          btnMarkup = `<button data-action="buy_skin" data-id="${skin.id}" class="armory-action-btn px-3 py-1 rounded ${canAfford ? 'bg-vanguard-gold text-black hover:bg-white' : 'bg-slate-800 text-slate-500 cursor-not-allowed'} text-[10px] font-bold uppercase tracking-wider font-display transition-all cursor-pointer">UNLOCK (${skin.cost}★)</button>`;
        }

        return `
          <div class="p-3 rounded-xl border border-vanguard-border/60 bg-black/60 flex items-center justify-between gap-2.5">
            <div class="flex items-center gap-2.5 min-w-0">
              <div class="w-8 h-8 rounded-lg shrink-0 border flex items-center justify-center font-bold text-xs" style="background-color: ${skin.color}22; color: ${skin.color}; border-color: ${skin.color}66;">
                ✈
              </div>
              <div class="min-w-0">
                <div class="text-xs font-bold text-white truncate font-display">${skin.name}</div>
                <div class="text-[10px] text-slate-400 truncate">${skin.desc}</div>
              </div>
            </div>
            <div class="shrink-0">${btnMarkup}</div>
          </div>
        `;
      }).join('');
    }

    if (upgradesContainer) {
      upgradesContainer.innerHTML = Object.entries(UPGRADES_CATALOG).map(([key, up]) => {
        const curTier = upgrades[key] || 1;
        const isMax = curTier >= 3;
        const nextCost = !isMax ? up.costs[curTier - 1] : 0;
        const canAfford = !isMax && stars >= nextCost;

        let btnMarkup = '';
        if (isMax) {
          btnMarkup = `<span class="px-3 py-1 rounded bg-vanguard-gold/20 text-vanguard-gold border border-vanguard-gold/40 text-[10px] font-bold font-mono">MAX TIER III</span>`;
        } else {
          btnMarkup = `<button data-action="buy_upgrade" data-id="${key}" class="armory-action-btn px-3 py-1 rounded ${canAfford ? 'bg-vanguard-gold text-black hover:bg-white shadow-[0_0_10px_rgba(255,215,0,0.3)]' : 'bg-slate-800 text-slate-500 cursor-not-allowed'} text-[10px] font-bold uppercase tracking-wider font-display transition-all cursor-pointer">UPGRADE (${nextCost}★)</button>`;
        }

        return `
          <div class="p-3 rounded-xl border border-vanguard-border/60 bg-black/60 flex items-center justify-between gap-3">
            <div class="flex items-center gap-2.5">
              <span class="text-xl">${up.icon}</span>
              <div>
                <div class="text-xs font-bold text-white font-display">${up.name}</div>
                <div class="text-[10px] text-vanguard-cyan font-mono mt-0.5">${up.tiers[curTier - 1]}</div>
              </div>
            </div>
            <div class="flex items-center gap-3">
              <div class="flex gap-1">
                ${[1, 2, 3].map(t => `<span class="w-2.5 h-2.5 rounded-full ${t <= curTier ? 'bg-vanguard-gold shadow-[0_0_6px_#ffd700]' : 'bg-slate-800 border border-slate-700'}"></span>`).join('')}
              </div>
              <div>${btnMarkup}</div>
            </div>
          </div>
        `;
      }).join('');
    }

    // Attach click listeners to armory buttons
    document.querySelectorAll('.armory-action-btn').forEach(btn => {
      btn.onclick = async () => {
        const action = btn.dataset.action;
        const id = btn.dataset.id;
        const token = localStorage.getItem('vanguard_pilot_token');
        if (!token) {
          alert("Please authenticate your pilot credentials first.");
          return;
        }

        btn.disabled = true;
        btn.textContent = 'TRANSMITTING...';
        audio.beep(1200, 0.05);

        try {
          const bodyPayload = { action };
          if (action === 'buy_skin' || action === 'equip_skin') bodyPayload.skin_id = id;
          if (action === 'buy_upgrade') bodyPayload.upgrade_id = id;

          const res = await fetch('/api/pilot/reward', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${token}`
            },
            body: JSON.stringify(bodyPayload)
          });

          const data = await res.json();
          if (res.ok && data.success) {
            audio.lock();
            const rawProfile = localStorage.getItem('vanguard_pilot_profile');
            let p = rawProfile ? JSON.parse(rawProfile) : {};
            p.rewards = data.rewards;
            localStorage.setItem('vanguard_pilot_profile', JSON.stringify(p));
            updateAuthUI();
            renderDossier();
          } else {
            alert(data.error || 'Armory transaction failed.');
            renderDossier();
          }
        } catch {
          alert('Network communication failed.');
          renderDossier();
        }
      };
    });
  }

  // Dossier Subtab Switcher
  const subtabRecordBtn = document.getElementById('subtab-record-btn');
  const subtabBadgesBtn = document.getElementById('subtab-badges-btn');
  const subtabArmoryBtn = document.getElementById('subtab-armory-btn');

  const dossierViewRecord = document.getElementById('dossier-view-record');
  const dossierViewBadges = document.getElementById('dossier-view-badges');
  const dossierViewArmory = document.getElementById('dossier-view-armory');

  function switchDossierSubtab(tab) {
    audio.beep(1100, 0.03);
    [subtabRecordBtn, subtabBadgesBtn, subtabArmoryBtn].forEach(b => {
      if (b) {
        b.classList.remove('border-vanguard-cyan', 'text-vanguard-cyan', 'font-bold');
        b.classList.add('border-transparent', 'text-slate-400');
      }
    });

    [dossierViewRecord, dossierViewBadges, dossierViewArmory].forEach(v => {
      if (v) v.classList.add('hidden');
    });

    if (tab === 'record' && subtabRecordBtn && dossierViewRecord) {
      subtabRecordBtn.classList.add('border-vanguard-cyan', 'text-vanguard-cyan', 'font-bold');
      subtabRecordBtn.classList.remove('border-transparent', 'text-slate-400');
      dossierViewRecord.classList.remove('hidden');
    } else if (tab === 'badges' && subtabBadgesBtn && dossierViewBadges) {
      subtabBadgesBtn.classList.add('border-vanguard-cyan', 'text-vanguard-cyan', 'font-bold');
      subtabBadgesBtn.classList.remove('border-transparent', 'text-slate-400');
      dossierViewBadges.classList.remove('hidden');
    } else if (tab === 'armory' && subtabArmoryBtn && dossierViewArmory) {
      subtabArmoryBtn.classList.add('border-vanguard-cyan', 'text-vanguard-cyan', 'font-bold');
      subtabArmoryBtn.classList.remove('border-transparent', 'text-slate-400');
      dossierViewArmory.classList.remove('hidden');
    }
  }

  if (subtabRecordBtn) subtabRecordBtn.addEventListener('click', () => switchDossierSubtab('record'));
  if (subtabBadgesBtn) subtabBadgesBtn.addEventListener('click', () => switchDossierSubtab('badges'));
  if (subtabArmoryBtn) subtabArmoryBtn.addEventListener('click', () => switchDossierSubtab('armory'));

  // Claim Daily Streak Bonus Handler
  const btnClaimStreak = document.getElementById('btn-claim-streak');
  if (btnClaimStreak) {
    btnClaimStreak.addEventListener('click', async () => {
      const token = localStorage.getItem('vanguard_pilot_token');
      if (!token) return;

      btnClaimStreak.disabled = true;
      btnClaimStreak.innerHTML = `<span>⏳</span><span>CLAIMING...</span>`;
      audio.ping();

      try {
        const res = await fetch('/api/pilot/reward', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`
          },
          body: JSON.stringify({ action: 'claim_streak' })
        });
        const data = await res.json();
        if (res.ok && data.success) {
          audio.lock();
          const rawProfile = localStorage.getItem('vanguard_pilot_profile');
          let p = rawProfile ? JSON.parse(rawProfile) : {};
          p.rewards = data.rewards;
          localStorage.setItem('vanguard_pilot_profile', JSON.stringify(p));
          updateAuthUI();
          renderDossier();
        } else {
          alert(data.error || 'Failed to claim daily bonus.');
          renderDossier();
        }
      } catch {
        alert('Network connection error.');
        renderDossier();
      }
    });
  }

  // --- Tactical Daily Reward Wheel Controller ---
  const wheelModal = document.getElementById('wheel-modal');
  const btnOpenWheel = document.getElementById('btn-open-wheel');
  const closeWheelModalBtn = document.getElementById('close-wheel-modal-btn');
  const btnSpinWheelAction = document.getElementById('btn-spin-wheel-action');
  const wheelCanvas = document.getElementById('wheel-canvas');
  const wheelFeedback = document.getElementById('wheel-feedback');

  const WHEEL_SEGMENTS = [
    { label: "50 ★", color: "#0f172a", textColor: "#38bdf8" },
    { label: "100 ★", color: "#1e293b", textColor: "#ffd700" },
    { label: "250 ★", color: "#0f233a", textColor: "#00e5ff" },
    { label: "500 ★", color: "#2e1065", textColor: "#c084fc" },
    { label: "JACKPOT 1K★", color: "#78350f", textColor: "#fde047" },
    { label: "LIVERY", color: "#14532d", textColor: "#4ade80" },
    { label: "CANNON +1", color: "#1e1b4b", textColor: "#818cf8" },
    { label: "SHIELD +1", color: "#450a0a", textColor: "#f87171" }
  ];

  let currentWheelAngle = 0;
  let isWheelSpinning = false;

  function drawWheel(angle = 0) {
    if (!wheelCanvas) return;
    const ctx = wheelCanvas.getContext('2d');
    const width = wheelCanvas.width;
    const height = wheelCanvas.height;
    const cx = width / 2;
    const cy = height / 2;
    const radius = cx - 4;
    const numSlices = WHEEL_SEGMENTS.length;
    const sliceAngle = (2 * Math.PI) / numSlices;

    ctx.clearRect(0, 0, width, height);

    for (let i = 0; i < numSlices; i++) {
      const startA = angle + i * sliceAngle;
      const endA = startA + sliceAngle;
      const seg = WHEEL_SEGMENTS[i];

      // Slice background
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.arc(cx, cy, radius, startA, endA);
      ctx.closePath();
      ctx.fillStyle = seg.color;
      ctx.fill();

      // Border outline
      ctx.strokeStyle = "rgba(0, 229, 255, 0.4)";
      ctx.lineWidth = 1.5;
      ctx.stroke();

      // Text label
      ctx.save();
      ctx.translate(cx, cy);
      ctx.rotate(startA + sliceAngle / 2);
      ctx.textAlign = "right";
      ctx.fillStyle = seg.textColor;
      ctx.font = "bold 11px monospace";
      ctx.fillText(seg.label, radius - 16, 4);
      ctx.restore();
    }
  }

  if (wheelCanvas) drawWheel(0);

  function openWheelModal() {
    audio.beep(880, 0.05);
    if (wheelModal) wheelModal.classList.remove('hidden');
    if (wheelFeedback) wheelFeedback.textContent = '';
    const rawProfile = localStorage.getItem('vanguard_pilot_profile');
    try {
      const p = JSON.parse(rawProfile || '{}');
      const today = new Date().toISOString().split('T')[0];
      const canSpin = p.rewards?.last_wheel_date !== today;
      if (btnSpinWheelAction) {
        btnSpinWheelAction.disabled = !canSpin;
        btnSpinWheelAction.textContent = canSpin ? '🎡 SPIN TACTICAL WHEEL' : '✓ SPUN TODAY // RESETS AT 00:00 UTC';
        btnSpinWheelAction.classList.toggle('opacity-50', !canSpin);
        btnSpinWheelAction.classList.toggle('cursor-not-allowed', !canSpin);
      }
    } catch {}
    drawWheel(currentWheelAngle);
  }

  function closeWheelModal() {
    if (!isWheelSpinning && wheelModal) {
      wheelModal.classList.add('hidden');
    }
  }

  if (btnOpenWheel) btnOpenWheel.addEventListener('click', openWheelModal);
  if (closeWheelModalBtn) closeWheelModalBtn.addEventListener('click', closeWheelModal);
  if (wheelModal) {
    wheelModal.addEventListener('click', (e) => {
      if (e.target === wheelModal) closeWheelModal();
    });
  }

  if (btnSpinWheelAction) {
    btnSpinWheelAction.addEventListener('click', async () => {
      if (isWheelSpinning) return;
      const token = localStorage.getItem('vanguard_pilot_token');
      if (!token) {
        alert("Please authenticate pilot credentials first.");
        return;
      }

      isWheelSpinning = true;
      btnSpinWheelAction.disabled = true;
      btnSpinWheelAction.textContent = 'CALCULATING ORBITAL TRAJECTORY...';
      audio.ping();

      try {
        const res = await fetch('/api/pilot/reward', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`
          },
          body: JSON.stringify({ action: 'spin_wheel' })
        });

        const data = await res.json();
        if (!res.ok || !data.success) {
          alert(data.error || 'Daily spin already claimed or unavailable.');
          isWheelSpinning = false;
          openWheelModal();
          return;
        }

        const prizeIdx = data.prize_index ?? 0;
        const numSlices = WHEEL_SEGMENTS.length;
        const sliceAngle = (2 * Math.PI) / numSlices;

        // Pointer is at the top (-PI/2). To align slice prizeIdx with top pointer:
        // sliceCenterAngle = angle + prizeIdx * sliceAngle + sliceAngle/2
        // targetAngle = -PI/2 - (prizeIdx * sliceAngle + sliceAngle/2)
        const targetOffset = -Math.PI / 2 - (prizeIdx * sliceAngle + sliceAngle / 2);
        const fullSpins = (5 + Math.floor(Math.random() * 3)) * (2 * Math.PI);
        const finalTargetAngle = fullSpins + targetOffset;

        const startAngle = currentWheelAngle % (2 * Math.PI);
        const totalDelta = finalTargetAngle - startAngle;
        const durationMs = 4200;
        const startTime = performance.now();

        let lastTickQuarter = -1;

        function animateWheel(now) {
          const elapsed = now - startTime;
          const progress = Math.min(1.0, elapsed / durationMs);
          // Ease out cubic
          const easeOut = 1 - Math.pow(1 - progress, 3);
          const currentA = startAngle + totalDelta * easeOut;
          currentWheelAngle = currentA;
          drawWheel(currentA);

          // Audio ticking
          const tickStep = Math.floor(currentA / (sliceAngle / 2));
          if (tickStep !== lastTickQuarter) {
            lastTickQuarter = tickStep;
            audio.beep(1600, 0.015);
          }

          if (progress < 1.0) {
            requestAnimationFrame(animateWheel);
          } else {
            isWheelSpinning = false;
            audio.lock();
            const rawProfile = localStorage.getItem('vanguard_pilot_profile');
            let p = rawProfile ? JSON.parse(rawProfile) : {};
            p.rewards = data.rewards;
            localStorage.setItem('vanguard_pilot_profile', JSON.stringify(p));

            if (wheelFeedback) {
              wheelFeedback.innerHTML = `<span class="text-vanguard-gold text-sm animate-bounce">⚡ WON: ${data.prize?.label || 'REWARD GRANTED'}!</span>`;
            }
            btnSpinWheelAction.textContent = '✓ SPUN TODAY // DISPATCH COMPLETE';
            btnSpinWheelAction.classList.add('opacity-50', 'cursor-not-allowed');

            updateAuthUI();
            renderDossier();
          }
        }

        requestAnimationFrame(animateWheel);

      } catch (err) {
        console.error(err);
        alert('Network communication failed.');
        isWheelSpinning = false;
        openWheelModal();
      }
    });
  }

  // --- Live Combat Stats & Battle History Engine ---
  function renderPilotStats() {
    let pilot = null;
    try {
      const raw = localStorage.getItem('vanguard_pilot_profile');
      if (raw) pilot = JSON.parse(raw);
    } catch {}

    const callsign = pilot?.callsign || localStorage.getItem('vanguard_callsign') || 'VANGUARD-LEAD';
    const rank = pilot?.rank || 'FLIGHT LIEUTENANT';
    const squadron = pilot?.squadron || '404th Vanguard Strike Wing';
    const stats = pilot?.stats || {};
    const token = localStorage.getItem('vanguard_pilot_token');

    // Header & identity
    const pCallEl = document.getElementById('stats-pilot-callsign');
    const pRankEl = document.getElementById('stats-pilot-rank-squadron');
    const cloudStatusEl = document.getElementById('stats-cloud-status');
    const cloudDotEl = document.getElementById('stats-cloud-dot');
    const cloudBadgeEl = document.getElementById('stats-cloud-badge');
    const authBtnLabel = document.getElementById('stats-auth-btn-label');

    if (pCallEl) pCallEl.textContent = callsign;
    if (pRankEl) pRankEl.textContent = `${rank} // ${squadron}`;

    if (token) {
      if (cloudStatusEl) cloudStatusEl.textContent = 'CLOUD SYNCED (D1)';
      if (cloudDotEl) cloudDotEl.className = 'w-2 h-2 rounded-full bg-vanguard-emerald animate-pulse';
      if (cloudBadgeEl) {
        cloudBadgeEl.className = 'px-3 py-1.5 rounded bg-black/60 border border-vanguard-emerald/40 text-vanguard-emerald text-xs font-mono font-bold flex items-center gap-1.5';
      }
      if (authBtnLabel) authBtnLabel.textContent = 'PILOT PROFILE';
    } else {
      if (cloudStatusEl) cloudStatusEl.textContent = 'LOCAL TELEMETRY';
      if (cloudDotEl) cloudDotEl.className = 'w-2 h-2 rounded-full bg-vanguard-cyan animate-pulse';
      if (cloudBadgeEl) {
        cloudBadgeEl.className = 'px-3 py-1.5 rounded bg-black/60 border border-vanguard-cyan/30 text-vanguard-cyan text-xs font-mono font-bold flex items-center gap-1.5';
      }
      if (authBtnLabel) authBtnLabel.textContent = 'COMMISSION / LOGIN';
    }

    // 8 Core Metrics
    const sorties = stats.total_sorties || 0;
    const wins = stats.battles_won || 0;
    const losses = stats.battles_lost || 0;
    const totalBattles = wins + losses;
    const winRate = totalBattles > 0 ? ((wins / totalBattles) * 100).toFixed(1) + '%' : '0.0%';
    const kills = stats.dogfight_kills || stats.total_kills || 0;
    const flightSec = stats.total_flight_time_sec || 0;
    const fHours = Math.floor(flightSec / 3600);
    const fMins = Math.floor((flightSec % 3600) / 60);
    const fSecs = Math.floor(flightSec % 60);
    const flightTimeStr = fHours > 0 ? `${fHours}h ${fMins.toString().padStart(2, '0')}m` : `${fMins}m ${fSecs.toString().padStart(2, '0')}s`;
    const controls = stats.preferred_controls || 'AZERTY';
    const mission = stats.highest_mission_unlocked || 'M01';

    const elSorties = document.getElementById('stats-total-sorties');
    const elWins = document.getElementById('stats-battles-won');
    const elLosses = document.getElementById('stats-battles-lost');
    const elWinRate = document.getElementById('stats-win-rate');
    const elKills = document.getElementById('stats-total-kills');
    const elFlight = document.getElementById('stats-flight-time');
    const elControls = document.getElementById('stats-preferred-controls');
    const elMission = document.getElementById('stats-highest-mission');

    if (elSorties) elSorties.textContent = sorties;
    if (elWins) elWins.textContent = wins;
    if (elLosses) elLosses.textContent = losses;
    if (elWinRate) elWinRate.textContent = winRate;
    if (elKills) elKills.textContent = kills;
    if (elFlight) elFlight.textContent = flightTimeStr;
    if (elControls) elControls.textContent = controls;
    if (elMission) elMission.textContent = mission;

    // Recent combat table
    const historyTbody = document.getElementById('stats-history-tbody');
    if (historyTbody) {
      const history = Array.isArray(stats.battle_history) ? stats.battle_history : [];
      if (history.length === 0) {
        historyTbody.innerHTML = `
          <tr>
            <td colspan="6" class="py-6 text-center text-slate-500 font-mono text-xs">
              NO COMBAT SORTIES LOGGED YET. DEPLOY INTO COMBAT OR PAIR PHONE TO RECORD FLIGHT TELEMETRY.
            </td>
          </tr>
        `;
      } else {
        const recent = history.slice(-10).reverse();
        historyTbody.innerHTML = recent
          .map(entry => {
            const timeStr = entry.timestamp ? entry.timestamp.replace('T', ' ').substring(0, 16) : 'RECENT';
            const theater = entry.theater || 'SOL ORBITAL // SORTIE';
            const isWin = entry.outcome === 'VICTORY';
            const outcomeBadge = isWin
              ? `<span class="px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-400 border border-emerald-500/40 text-[10px] font-bold">VICTORY</span>`
              : `<span class="px-2 py-0.5 rounded bg-red-500/20 text-red-400 border border-red-500/40 text-[10px] font-bold">DEFEAT</span>`;
            const k = entry.kills || 0;
            const dur = entry.duration_sec || 0;
            const dM = Math.floor(dur / 60);
            const dS = Math.round(dur % 60);
            const durText = `${dM}m ${dS.toString().padStart(2, '0')}s`;
            const ctrl = entry.controls || 'AZERTY';

            return `
              <tr class="hover:bg-white/5 transition-colors">
                <td class="py-2.5 px-4 text-slate-400 text-[11px] whitespace-nowrap">${timeStr}</td>
                <td class="py-2.5 px-4 font-bold text-white uppercase text-[11px]">${theater}</td>
                <td class="py-2.5 px-4">${outcomeBadge}</td>
                <td class="py-2.5 px-4 text-vanguard-cyan font-bold text-[11px]">${k} KILLS</td>
                <td class="py-2.5 px-4 text-slate-300 text-[11px]">${durText}</td>
                <td class="py-2.5 px-4 text-vanguard-amber font-mono font-bold text-[11px]">${ctrl}</td>
              </tr>
            `;
          })
          .join('');
      }
    }
  }

  // Synchronize stats from Cloudflare D1
  async function syncStatsFromCloud(showFeedback = false) {
    const token = localStorage.getItem('vanguard_pilot_token');
    const syncBtn = document.getElementById('btn-sync-stats');
    if (!token) {
      if (showFeedback) openPilotModal();
      return;
    }

    if (syncBtn) {
      syncBtn.disabled = true;
      syncBtn.innerHTML = `<span>⏳</span><span>SYNCING...</span>`;
    }

    try {
      const res = await fetch('/api/pilot/sync', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        if (data.success) {
          let rawProfile = localStorage.getItem('vanguard_pilot_profile');
          let pilot = rawProfile ? JSON.parse(rawProfile) : { callsign: data.pilot.callsign, rank: data.pilot.rank };
          const cloudStats = data.save_data?.stats || {};
          const record = data.record || {};

          pilot.stats = {
            total_sorties: Math.max(pilot.stats?.total_sorties || 0, record.total_sorties || cloudStats.total_sorties || 0),
            total_kills: Math.max(pilot.stats?.total_kills || 0, record.total_kills || cloudStats.total_kills || 0),
            total_flight_time_sec: Math.max(pilot.stats?.total_flight_time_sec || 0, record.total_flight_time_sec || cloudStats.total_flight_time_sec || 0),
            highest_mission_unlocked: cloudStats.highest_mission_unlocked || record.highest_mission_unlocked || pilot.stats?.highest_mission_unlocked || 'M01',
            battles_won: Math.max(pilot.stats?.battles_won || 0, cloudStats.battles_won || 0),
            battles_lost: Math.max(pilot.stats?.battles_lost || 0, cloudStats.battles_lost || 0),
            dogfight_kills: Math.max(pilot.stats?.dogfight_kills || 0, cloudStats.dogfight_kills || 0),
            preferred_controls: cloudStats.preferred_controls || pilot.stats?.preferred_controls || 'AZERTY',
            battle_history: (cloudStats.battle_history && cloudStats.battle_history.length > 0)
              ? cloudStats.battle_history
              : (pilot.stats?.battle_history || [])
          };

          const incomingRewards = data.rewards || data.save_data?.rewards || {};
          const incomingStars = Math.max(
            Number(data.stars) || 0,
            Number(data.record?.stars) || 0,
            Number(incomingRewards.stars) || 0,
            Number(pilot.rewards?.stars) || 0
          );

          if (!pilot.rewards) {
            pilot.rewards = {
              stars: incomingStars,
              streak: 1,
              badges: ["FIRST_SORTIE"],
              unlocked_skins: ["CLASSIC_CYAN"],
              active_skin: "CLASSIC_CYAN",
              upgrades: { PULSE_CANNON: 1, HYDRA_MISSILES: 1, DEFLECTOR_SHIELD: 1, AFTERBURNER_TURBO: 1 }
            };
          }

          pilot.rewards.stars = incomingStars;
          if (incomingRewards.streak) {
            pilot.rewards.streak = Math.max(pilot.rewards.streak || 1, incomingRewards.streak);
          }
          if (incomingRewards.last_login_date) {
            pilot.rewards.last_login_date = incomingRewards.last_login_date;
          }
          if (incomingRewards.last_wheel_date) {
            pilot.rewards.last_wheel_date = incomingRewards.last_wheel_date;
          }
          if (Array.isArray(incomingRewards.badges)) {
            const bSet = new Set([...(pilot.rewards.badges || []), ...incomingRewards.badges]);
            pilot.rewards.badges = Array.from(bSet);
          }
          if (Array.isArray(incomingRewards.unlocked_skins)) {
            const sSet = new Set([...(pilot.rewards.unlocked_skins || []), ...incomingRewards.unlocked_skins]);
            pilot.rewards.unlocked_skins = Array.from(sSet);
          }
          if (incomingRewards.active_skin) {
            pilot.rewards.active_skin = incomingRewards.active_skin;
          }
          if (incomingRewards.upgrades && typeof incomingRewards.upgrades === 'object') {
            pilot.rewards.upgrades = pilot.rewards.upgrades || {};
            for (const [k, v] of Object.entries(incomingRewards.upgrades)) {
              pilot.rewards.upgrades[k] = Math.max(pilot.rewards.upgrades[k] || 1, Number(v) || 1);
            }
          }

          localStorage.setItem('vanguard_pilot_profile', JSON.stringify(pilot));
          updateAuthUI();
          renderPilotStats();
          renderDossier();
          if (showFeedback) audio.lock();
        }
      }
    } catch (err) {
      console.warn('[Vanguard Portal] Cloud stats sync error:', err);
    } finally {
      if (syncBtn) {
        syncBtn.disabled = false;
        syncBtn.innerHTML = `<span>🔄</span><span>SYNC STATS</span>`;
      }
    }
  }

  // Connect stats buttons
  const btnSyncStats = document.getElementById('btn-sync-stats');
  if (btnSyncStats) {
    btnSyncStats.addEventListener('click', () => {
      audio.ping();
      syncStatsFromCloud(true);
    });
  }

  const btnPortalFromStats = document.getElementById('btn-portal-from-stats');
  if (btnPortalFromStats) {
    btnPortalFromStats.addEventListener('click', () => {
      openPilotModal();
    });
  }

  const dossierStatsLink = document.getElementById('dossier-stats-link');
  if (dossierStatsLink) {
    dossierStatsLink.addEventListener('click', () => {
      closePilotModal();
    });
  }

  // Handle Pilot Registration
  if (registerForm) {
    registerForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      if (regFeedback) regFeedback.classList.add('hidden');
      const submitBtn = document.getElementById('btn-submit-reg');
      if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.textContent = 'COMMISSIONING...';
      }

      const payload = {
        callsign: document.getElementById('reg-callsign').value.trim(),
        email: document.getElementById('reg-email').value.trim(),
        password: document.getElementById('reg-password').value,
        rank: document.getElementById('reg-rank').value,
        squadron: document.getElementById('reg-squadron').value,
      };

      try {
        const res = await fetch('/api/auth/register', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        const data = await res.json();

        if (res.ok && data.success) {
          audio.lock();
          localStorage.setItem('vanguard_pilot_token', data.token);
          localStorage.setItem('vanguard_pilot_profile', JSON.stringify(data.pilot));
          localStorage.setItem('vanguard_callsign', data.pilot.callsign);
          updateAuthUI();
          syncStatsFromCloud(false);
          switchTab('dossier');
        } else {
          audio.beep(300, 0.15, 'sawtooth');
          if (regFeedback) {
            regFeedback.className = 'p-3 rounded text-xs border border-red-500/50 bg-red-950/40 text-red-400 font-bold block';
            regFeedback.textContent = data.error || 'Registration failed. Check inputs.';
          }
        }
      } catch (err) {
        if (regFeedback) {
          regFeedback.className = 'p-3 rounded text-xs border border-red-500/50 bg-red-950/40 text-red-400 font-bold block';
          regFeedback.textContent = 'Failed to connect to Vanguard edge network.';
        }
      } finally {
        if (submitBtn) {
          submitBtn.disabled = false;
          submitBtn.innerHTML = '<span>🎖️</span><span>COMMISSION CALLSIGN // ENLIST NOW</span>';
        }
      }
    });
  }

  // Handle Pilot Login
  if (loginForm) {
    loginForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      if (loginFeedback) loginFeedback.classList.add('hidden');
      const submitBtn = document.getElementById('btn-submit-login');
      if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.textContent = 'AUTHENTICATING...';
      }

      const payload = {
        callsign_or_email: document.getElementById('login-identifier').value.trim(),
        password: document.getElementById('login-password').value,
      };

      try {
        const res = await fetch('/api/auth/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        const data = await res.json();

        if (res.ok && data.success) {
          audio.ping();
          localStorage.setItem('vanguard_pilot_token', data.token);
          localStorage.setItem('vanguard_pilot_profile', JSON.stringify(data.pilot));
          localStorage.setItem('vanguard_callsign', data.pilot.callsign);
          updateAuthUI();
          syncStatsFromCloud(false);
          switchTab('dossier');
        } else {
          audio.beep(300, 0.15, 'sawtooth');
          if (loginFeedback) {
            loginFeedback.className = 'p-3 rounded text-xs border border-red-500/50 bg-red-950/40 text-red-400 font-bold block';
            loginFeedback.textContent = data.error || 'Authentication rejected.';
          }
        }
      } catch (err) {
        if (loginFeedback) {
          loginFeedback.className = 'p-3 rounded text-xs border border-red-500/50 bg-red-950/40 text-red-400 font-bold block';
          loginFeedback.textContent = 'Connection error. Check network link.';
        }
      } finally {
        if (submitBtn) {
          submitBtn.disabled = false;
          submitBtn.innerHTML = '<span>🔐</span><span>AUTHENTICATE PILOT</span>';
        }
      }
    });
  }

  // Handle Station Pair Authorization
  const btnApproveStation = document.getElementById('btn-approve-station');
  const inputStationCode = document.getElementById('input-station-code');
  const stationFeedback = document.getElementById('station-link-feedback');

  if (btnApproveStation) {
    btnApproveStation.addEventListener('click', async () => {
      const code = inputStationCode.value.trim().toUpperCase();
      const token = localStorage.getItem('vanguard_pilot_token');
      if (!code) return;
      if (!token) {
        if (stationFeedback) {
          stationFeedback.className = 'text-[10px] font-bold text-red-400 block pt-1';
          stationFeedback.textContent = 'You must be logged in to authorize a game station.';
        }
        return;
      }

      btnApproveStation.disabled = true;
      btnApproveStation.textContent = 'PAIRING...';

      try {
        const res = await fetch('/api/auth/link?action=approve', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ' + token,
          },
          body: JSON.stringify({ link_code: code }),
        });
        const data = await res.json();

        if (res.ok && data.success) {
          audio.lock();
          if (stationFeedback) {
            stationFeedback.className = 'text-[10px] font-bold text-emerald-400 block pt-1';
            stationFeedback.textContent = `// STATION AUTHORIZED // Welcome aboard! //`;
          }
          inputStationCode.value = '';
        } else {
          if (stationFeedback) {
            stationFeedback.className = 'text-[10px] font-bold text-red-400 block pt-1';
            stationFeedback.textContent = data.error || 'Invalid or expired station code.';
          }
        }
      } catch {
        if (stationFeedback) {
          stationFeedback.className = 'text-[10px] font-bold text-red-400 block pt-1';
          stationFeedback.textContent = 'Station authorization failed. Check network.';
        }
      } finally {
        btnApproveStation.disabled = false;
        btnApproveStation.textContent = 'Authorize';
      }
    });
  }

  // Handle In-Dossier Verification & Resend
  const btnDossierSubmitVerify = document.getElementById('btn-dossier-submit-verify');
  const inputDossierVerifyCode = document.getElementById('input-dossier-verify-code');
  const dossierVerifyFeedback = document.getElementById('dossier-verify-feedback');
  const btnDossierResendVerify = document.getElementById('btn-dossier-resend-verify');

  if (btnDossierSubmitVerify) {
    btnDossierSubmitVerify.addEventListener('click', async () => {
      const code = inputDossierVerifyCode ? inputDossierVerifyCode.value.trim() : '';
      if (!code) return;
      btnDossierSubmitVerify.disabled = true;
      btnDossierSubmitVerify.textContent = '...';

      try {
        const rawProfile = localStorage.getItem('vanguard_pilot_profile');
        const pilot = rawProfile ? JSON.parse(rawProfile) : {};
        const res = await fetch('/api/auth/verify', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ code, email: pilot.email })
        });
        const data = await res.json();
        if (res.ok && data.success) {
          audio.lock();
          if (dossierVerifyFeedback) {
            dossierVerifyFeedback.className = 'text-[10px] font-bold text-emerald-400 block pt-1';
            dossierVerifyFeedback.textContent = '// CLEARANCE CONFIRMED // Email verified.';
          }
          pilot.email_verified = 1;
          localStorage.setItem('vanguard_pilot_profile', JSON.stringify(pilot));
          renderDossier();
        } else {
          if (dossierVerifyFeedback) {
            dossierVerifyFeedback.className = 'text-[10px] font-bold text-red-400 block pt-1';
            dossierVerifyFeedback.textContent = data.error || 'Invalid or expired code.';
          }
        }
      } catch {
        if (dossierVerifyFeedback) {
          dossierVerifyFeedback.className = 'text-[10px] font-bold text-red-400 block pt-1';
          dossierVerifyFeedback.textContent = 'Network error verifying code.';
        }
      } finally {
        btnDossierSubmitVerify.disabled = false;
        btnDossierSubmitVerify.textContent = 'Confirm';
      }
    });
  }

  if (btnDossierResendVerify) {
    btnDossierResendVerify.addEventListener('click', async () => {
      const rawProfile = localStorage.getItem('vanguard_pilot_profile');
      const pilot = rawProfile ? JSON.parse(rawProfile) : {};
      if (!pilot.email) return;

      btnDossierResendVerify.disabled = true;
      btnDossierResendVerify.textContent = 'Sending...';

      try {
        const token = localStorage.getItem('vanguard_pilot_token');
        const headers = { 'Content-Type': 'application/json' };
        if (token) headers['Authorization'] = 'Bearer ' + token;

        const res = await fetch('/api/auth/resend-verification', {
          method: 'POST',
          headers,
          body: JSON.stringify({ email: pilot.email })
        });
        const data = await res.json();
        if (res.ok && data.success) {
          audio.ping();
          if (dossierVerifyFeedback) {
            dossierVerifyFeedback.className = 'text-[10px] font-bold text-amber-300 block pt-1';
            dossierVerifyFeedback.textContent = `// ${data.message || 'CLEARANCE CODE DISPATCHED // Check inbox.'}`;
          }
          let secondsLeft = 60;
          const timer = setInterval(() => {
            secondsLeft--;
            if (secondsLeft <= 0) {
              clearInterval(timer);
              btnDossierResendVerify.disabled = false;
              btnDossierResendVerify.textContent = 'Resend';
            } else {
              btnDossierResendVerify.textContent = `${secondsLeft}s`;
            }
          }, 1000);
        } else {
          btnDossierResendVerify.disabled = false;
          btnDossierResendVerify.textContent = 'Resend';
          if (dossierVerifyFeedback) {
            dossierVerifyFeedback.className = 'text-[10px] font-bold text-red-400 block pt-1';
            dossierVerifyFeedback.textContent = data.error || 'Resend rate limited.';
          }
        }
      } catch {
        btnDossierResendVerify.disabled = false;
        btnDossierResendVerify.textContent = 'Resend';
      }
    });
  }

  // Handle Logout
  const btnLogout = document.getElementById('btn-logout');
  if (btnLogout) {
    btnLogout.addEventListener('click', () => {
      localStorage.removeItem('vanguard_pilot_token');
      localStorage.removeItem('vanguard_pilot_profile');
      audio.beep(600, 0.08);
      updateAuthUI();
      switchTab('login');
    });
  }

  // ============================================================================
  // Live Fleet Radar & Operational Presence Engine
  // ============================================================================
  const webSessionId = "web-" + Math.random().toString(36).substring(2, 10);

  async function fetchNetworkStats() {
    try {
      const res = await fetch('/api/network/stats');
      if (!res.ok) return;
      const data = await res.json();
      if (!data.success) return;

      const onlineCount = data.online_pilots || 1;
      const lobbyCount = data.active_lobbies || 0;
      const rosterCount = (data.registered_pilots || 1420).toLocaleString();

      // Top Ticker Elements
      const tickerOnline = document.getElementById('ticker-online-pilots');
      const tickerLobbies = document.getElementById('ticker-active-lobbies');
      const tickerRoster = document.getElementById('ticker-registered-pilots');
      if (tickerOnline) tickerOnline.textContent = onlineCount;
      if (tickerLobbies) tickerLobbies.textContent = lobbyCount;
      if (tickerRoster) tickerRoster.textContent = rosterCount;

      // Hero Radar Elements
      const heroOnline = document.getElementById('hero-online-pilots');
      const heroLobbies = document.getElementById('hero-active-lobbies');
      const heroRoster = document.getElementById('hero-registered-pilots');
      if (heroOnline) heroOnline.textContent = onlineCount;
      if (heroLobbies) heroLobbies.textContent = lobbyCount;
      if (heroRoster) heroRoster.textContent = rosterCount;
    } catch {
      // Offline fallback
    }
  }

  async function sendWebHeartbeat() {
    try {
      let callsign = 'WEB-PILOT';
      let pilotId = null;
      try {
        const profile = JSON.parse(localStorage.getItem('vanguard_pilot_profile') || '{}');
        if (profile.callsign) callsign = profile.callsign;
        if (profile.id) pilotId = profile.id;
      } catch {
        // Fallback default
      }

      await fetch('/api/network/heartbeat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          session_id: webSessionId,
          callsign: callsign,
          pilot_id: pilotId,
          session_type: 'PILOT',
          metadata: { client: 'website_portal' }
        })
      });
    } catch {
      // Non-blocking
    }
  }

  // Gracefully leave network session on page unload
  window.addEventListener('beforeunload', () => {
    try {
      if (navigator.sendBeacon) {
        navigator.sendBeacon('/api/network/leave', JSON.stringify({ session_id: webSessionId }));
      }
    } catch {
      // Ignored
    }
  });

  // ============================================================================
  // Global Fleet Leaderboard & Mission Speedrun Engine
  // ============================================================================
  let currentLeaderboardCategory = 'global';
  let leaderboardData = [];
  let leaderboardSearchFilter = '';

  const lbThead = document.getElementById('leaderboard-thead');
  const lbTbody = document.getElementById('leaderboard-tbody');
  const lbSearch = document.getElementById('leaderboard-search');
  const lbRefreshBtn = document.getElementById('leaderboard-refresh-btn');
  const lbPersonalBanner = document.getElementById('leaderboard-personal-banner');
  const lbTabBtns = document.querySelectorAll('.leaderboard-tab-btn');

  function initLeaderboard() {
    if (!lbTbody) return;

    if (lbTabBtns) {
      lbTabBtns.forEach(btn => {
        btn.addEventListener('click', () => {
          const cat = btn.getAttribute('data-cat') || 'global';
          if (cat === currentLeaderboardCategory) return;
          currentLeaderboardCategory = cat;

          lbTabBtns.forEach(b => {
            const isActive = b.getAttribute('data-cat') === currentLeaderboardCategory;
            b.classList.toggle('active', isActive);
            b.classList.toggle('border-vanguard-gold', isActive);
            b.classList.toggle('bg-vanguard-gold/15', isActive);
            b.classList.toggle('text-vanguard-gold', isActive);
            b.classList.toggle('border-vanguard-border/60', !isActive);
            b.classList.toggle('bg-vanguard-panel/60', !isActive);
            b.classList.toggle('text-slate-400', !isActive);
          });

          fetchLeaderboard(currentLeaderboardCategory);
        });
      });
    }

    if (lbSearch) {
      lbSearch.addEventListener('input', (e) => {
        leaderboardSearchFilter = (e.target.value || '').trim().toLowerCase();
        renderLeaderboard();
      });
    }

    if (lbRefreshBtn) {
      lbRefreshBtn.addEventListener('click', () => {
        const icon = document.getElementById('leaderboard-refresh-icon');
        if (icon) icon.classList.add('animate-spin');
        fetchLeaderboard(currentLeaderboardCategory).finally(() => {
          if (icon) setTimeout(() => icon.classList.remove('animate-spin'), 600);
        });
      });
    }

    fetchLeaderboard(currentLeaderboardCategory);
  }

  async function fetchLeaderboard(category) {
    if (!lbTbody) return;
    lbTbody.innerHTML = `
      <tr>
        <td colspan="7" class="py-12 text-center text-slate-400 font-mono text-xs animate-pulse">
          <span class="inline-block mr-2">⚡</span> QUERYING CLOUDFLARE D1 FLEET ARCHIVES [CAT: ${category.toUpperCase()}]...
        </td>
      </tr>
    `;

    const headers = {};
    const token = localStorage.getItem('vanguard_pilot_token');
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    let url = `/api/leaderboard?type=global&limit=50`;
    if (category !== 'global') {
      url = `/api/leaderboard?mission=${encodeURIComponent(category)}&limit=50`;
    }

    try {
      const res = await fetch(url, { headers });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      if (!data.success) throw new Error(data.error || 'Failed to fetch leaderboard');

      leaderboardData = data.leaderboard || data.entries || [];
      updatePersonalBanner(data.your_rank);
      renderLeaderboard();
    } catch {
      // Fallback offline mock data for local dev or offline demo
      leaderboardData = getOfflineLeaderboardData(category);
      updatePersonalBanner(null);
      renderLeaderboard();
    }
  }

  function updatePersonalBanner(yourRankObj) {
    if (!lbPersonalBanner) return;
    let pilot = null;
    try {
      pilot = JSON.parse(localStorage.getItem('vanguard_pilot_profile') || '{}');
    } catch {}

    if (!pilot || !pilot.callsign) {
      lbPersonalBanner.classList.add('hidden');
      return;
    }

    lbPersonalBanner.classList.remove('hidden');
    const callEl = document.getElementById('personal-callsign-display');
    const badgeEl = document.getElementById('personal-rank-badge');
    const squadEl = document.getElementById('personal-squadron-display');
    const scoreEl = document.getElementById('personal-score-display');
    const killsEl = document.getElementById('personal-kills-display');
    const sortiesEl = document.getElementById('personal-sorties-display');

    if (callEl) callEl.textContent = `${pilot.rank || 'PILOT'} ${pilot.callsign}`;
    if (squadEl) squadEl.textContent = pilot.squadron || '404th Vanguard Strike Wing';

    if (yourRankObj && yourRankObj.rank) {
      if (badgeEl) badgeEl.textContent = `RANK #${yourRankObj.rank}`;
      if (scoreEl) scoreEl.textContent = (yourRankObj.score || yourRankObj.total_score || 0).toLocaleString();
      if (killsEl) killsEl.textContent = (yourRankObj.total_kills || yourRankObj.kills || 0).toLocaleString();
      if (sortiesEl) sortiesEl.textContent = (yourRankObj.total_sorties || yourRankObj.sorties || 0).toLocaleString();
    } else {
      // Match from leaderboardData if present
      const matched = leaderboardData.find(e => e.callsign && e.callsign.toUpperCase() === pilot.callsign.toUpperCase());
      if (matched) {
        if (badgeEl) badgeEl.textContent = `RANK #${matched.rank || '1'}`;
        if (scoreEl) scoreEl.textContent = (matched.score || matched.total_score || 0).toLocaleString();
        if (killsEl) killsEl.textContent = (matched.total_kills || matched.kills || 0).toLocaleString();
        if (sortiesEl) sortiesEl.textContent = (matched.total_sorties || matched.sorties || 0).toLocaleString();
      } else {
        if (badgeEl) badgeEl.textContent = 'UNRANKED IN THIS CAT';
        if (scoreEl) scoreEl.textContent = '--';
        if (killsEl) killsEl.textContent = (pilot.stats?.total_kills || 0).toLocaleString();
        if (sortiesEl) sortiesEl.textContent = (pilot.stats?.total_sorties || 0).toLocaleString();
      }
    }
  }

  function renderLeaderboard() {
    if (!lbThead || !lbTbody) return;

    let activePilotCallsign = '';
    try {
      const pilot = JSON.parse(localStorage.getItem('vanguard_pilot_profile') || '{}');
      if (pilot.callsign) activePilotCallsign = pilot.callsign.toUpperCase();
    } catch {}

    const isGlobal = (currentLeaderboardCategory === 'global');

    // Render Table Header
    if (isGlobal) {
      lbThead.innerHTML = `
        <tr>
          <th class="py-3 px-4 w-16">RANK</th>
          <th class="py-3 px-4">PILOT</th>
          <th class="py-3 px-4">CALLSIGN</th>
          <th class="py-3 px-4">SQUADRON</th>
          <th class="py-3 px-4 text-center">SORTIES</th>
          <th class="py-3 px-4 text-center">KILLS</th>
          <th class="py-3 px-4 text-right">FLEET SCORE</th>
        </tr>
      `;
    } else {
      lbThead.innerHTML = `
        <tr>
          <th class="py-3 px-4 w-16">RANK</th>
          <th class="py-3 px-4">PILOT</th>
          <th class="py-3 px-4">SQUADRON</th>
          <th class="py-3 px-4 text-right">SCORE</th>
          <th class="py-3 px-4 text-center">COMPLETION TIME</th>
          <th class="py-3 px-4 text-center">DIFFICULTY</th>
          <th class="py-3 px-4 text-right">TIMESTAMP</th>
        </tr>
      `;
    }

    // Filter items
    let filtered = leaderboardData;
    if (leaderboardSearchFilter) {
      filtered = filtered.filter(item => {
        const callsign = (item.callsign || '').toLowerCase();
        const pilot = (item.pilot || item.pilot_name || '').toLowerCase();
        const sq = (item.squadron || '').toLowerCase();
        return callsign.includes(leaderboardSearchFilter) || pilot.includes(leaderboardSearchFilter) || sq.includes(leaderboardSearchFilter);
      });
    }

    if (filtered.length === 0) {
      lbTbody.innerHTML = `
        <tr>
          <td colspan="7" class="py-12 text-center text-slate-500 font-mono text-xs">
            NO RECORDS FOUND FOR THIS FILTER OR CATEGORY.
          </td>
        </tr>
      `;
      return;
    }

    lbTbody.innerHTML = filtered.map((entry, idx) => {
      const rankNum = entry.rank || (idx + 1);
      let rankBadge = `#${rankNum}`;
      if (rankNum === 1) rankBadge = '🥇 #1';
      else if (rankNum === 2) rankBadge = '🥈 #2';
      else if (rankNum === 3) rankBadge = '🥉 #3';

      const isCurrentPilot = activePilotCallsign && entry.callsign && (entry.callsign.toUpperCase() === activePilotCallsign);
      const rowClass = isCurrentPilot ? 'bg-vanguard-gold/10 font-bold border-l-2 border-vanguard-gold' : 'hover:bg-white/[0.02] transition-colors';

      if (isGlobal) {
        const score = (entry.score || entry.total_score || 0).toLocaleString();
        const kills = (entry.total_kills || entry.kills || 0).toLocaleString();
        const sorties = (entry.total_sorties || entry.sorties || 0).toLocaleString();
        const callsignMarkup = isCurrentPilot ? `${entry.callsign} <span class="text-[10px] text-vanguard-gold font-bold ml-1">(YOU)</span>` : (entry.callsign || 'PILOT');

        return `
          <tr class="${rowClass}">
            <td class="py-3 px-4 font-bold ${rankNum <= 3 ? 'text-vanguard-gold' : 'text-slate-400'}">${rankBadge}</td>
            <td class="py-3 px-4 text-slate-200">${entry.pilot || entry.rank_title || 'LIEUTENANT'}</td>
            <td class="py-3 px-4 text-vanguard-cyan font-bold">${callsignMarkup}</td>
            <td class="py-3 px-4 text-slate-400 text-[11px]">${entry.squadron || '404th Vanguard Wing'}</td>
            <td class="py-3 px-4 text-center text-amber-300">${sorties}</td>
            <td class="py-3 px-4 text-center text-emerald-300">${kills}</td>
            <td class="py-3 px-4 text-right text-vanguard-cyan font-bold">${score}</td>
          </tr>
        `;
      } else {
        const score = (entry.score || entry.mission_score || 0).toLocaleString();
        const durationSec = entry.time_seconds || entry.duration_seconds || 0;
        const mins = Math.floor(durationSec / 60);
        const secs = (durationSec % 60).toFixed(1);
        const timeFormatted = durationSec > 0 ? `${mins}m ${secs < 10 ? '0' : ''}${secs}s` : '--';
        const callsignMarkup = isCurrentPilot ? `${entry.callsign} <span class="text-[10px] text-vanguard-gold font-bold ml-1">(YOU)</span>` : (entry.callsign || 'PILOT');
        const diff = entry.difficulty || 'REGULAR';
        const dateStr = entry.date ? new Date(entry.date).toLocaleDateString() : 'RECENT';

        return `
          <tr class="${rowClass}">
            <td class="py-3 px-4 font-bold ${rankNum <= 3 ? 'text-vanguard-gold' : 'text-slate-400'}">${rankBadge}</td>
            <td class="py-3 px-4 text-vanguard-cyan font-bold">${callsignMarkup}</td>
            <td class="py-3 px-4 text-slate-400 text-[11px]">${entry.squadron || '404th Vanguard Wing'}</td>
            <td class="py-3 px-4 text-right text-vanguard-cyan font-bold">${score}</td>
            <td class="py-3 px-4 text-center text-amber-300">${timeFormatted}</td>
            <td class="py-3 px-4 text-center"><span class="px-1.5 py-0.5 rounded text-[10px] bg-slate-800 text-slate-300 border border-slate-700">${diff}</span></td>
            <td class="py-3 px-4 text-right text-slate-500 text-[11px]">${dateStr}</td>
          </tr>
        `;
      }
    }).join('');
  }

  function getOfflineLeaderboardData(category) {
    if (category === 'global') {
      return [
        { rank: 1, callsign: 'MAVERICK', pilot: 'WING COMMANDER', squadron: '404th Vanguard Strike Wing', total_sorties: 42, total_kills: 128, score: 98450 },
        { rank: 2, callsign: 'VIPER-01', pilot: 'MAJOR', squadron: '81st Orbital Defense Group', total_sorties: 36, total_kills: 104, score: 81200 },
        { rank: 3, callsign: 'GHOST_RIDER', pilot: 'CAPTAIN', squadron: 'Solar Recon Detachment', total_sorties: 29, total_kills: 88, score: 69500 },
        { rank: 4, callsign: 'PHANTOM', pilot: 'CAPTAIN', squadron: '11th Interceptor Wing', total_sorties: 24, total_kills: 71, score: 55400 },
        { rank: 5, callsign: 'RAZOR', pilot: 'LIEUTENANT', squadron: '404th Vanguard Strike Wing', total_sorties: 18, total_kills: 52, score: 41900 },
        { rank: 6, callsign: 'ARCHANGEL', pilot: 'LIEUTENANT', squadron: 'Ares Strike Group', total_sorties: 14, total_kills: 39, score: 32600 }
      ];
    } else {
      return [
        { rank: 1, callsign: 'MAVERICK', squadron: '404th Vanguard Strike Wing', score: 28400, time_seconds: 142.5, difficulty: 'VETERAN', date: '2026-09-25' },
        { rank: 2, callsign: 'VIPER-01', squadron: '81st Orbital Defense Group', score: 26150, time_seconds: 158.2, difficulty: 'REGULAR', date: '2026-09-24' },
        { rank: 3, callsign: 'GHOST_RIDER', squadron: 'Solar Recon Detachment', score: 24800, time_seconds: 165.0, difficulty: 'REGULAR', date: '2026-09-26' },
        { rank: 4, callsign: 'RAZOR', squadron: '404th Vanguard Strike Wing', score: 21900, time_seconds: 184.8, difficulty: 'RECRUIT', date: '2026-09-27' }
      ];
    }
  }

  updateAuthUI();
  syncStatsFromCloud(false);
  syncGitHubRelease();
  fetchNetworkStats();
  sendWebHeartbeat();
  initLeaderboard();
  setInterval(fetchNetworkStats, 20000);
  setInterval(sendWebHeartbeat, 30000);

  // Tactical Deep Link & Verification Auto-Login Resolver
  const urlParams = new URLSearchParams(window.location.search);
  const actionParam = urlParams.get('action');
  const authtokenParam = urlParams.get('authtoken');

  if (authtokenParam) {
    localStorage.setItem('vanguard_pilot_token', authtokenParam);
    const callsignParam = urlParams.get('callsign');
    const rankParam = urlParams.get('rank');
    const emailParam = urlParams.get('email');
    try {
      const existing = JSON.parse(localStorage.getItem('vanguard_pilot_profile') || '{}');
      if (callsignParam) existing.callsign = callsignParam;
      if (rankParam) existing.rank = rankParam;
      if (emailParam) existing.email = emailParam;
      existing.email_verified = 1;
      localStorage.setItem('vanguard_pilot_profile', JSON.stringify(existing));
    } catch {}
    updateAuthUI();
    syncStatsFromCloud(false);
  }

  const isMobile = /Android|iPhone|iPad|iPod|webOS|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent) || window.innerWidth < 768;
  const isLoggedIn = !!localStorage.getItem('vanguard_pilot_token');

  if (actionParam === 'login') {
    openPilotModal('login');
  } else if (actionParam === 'dossier') {
    openPilotModal('dossier');
  } else if (actionParam === 'register') {
    openPilotModal('register');
  } else if (urlParams.has('verified') || urlParams.has('verify') || urlParams.get('from') === 'email') {
    if (!isLoggedIn) {
      openPilotModal('login');
    }
  }
});
