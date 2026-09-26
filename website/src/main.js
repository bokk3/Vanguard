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

    // Find direct binary download asset if attached
    let directDownloadUrl = releaseUrl;
    let assetSizeText = '';
    if (data.assets && data.assets.length > 0) {
      const winAsset = data.assets.find(a => 
        a.name.toLowerCase().includes('win') || 
        a.name.toLowerCase().endsWith('.zip') || 
        a.name.toLowerCase().endsWith('.exe')
      ) || data.assets[0];

      if (winAsset) {
        directDownloadUrl = winAsset.browser_download_url;
        const sizeMb = (winAsset.size / (1024 * 1024)).toFixed(1);
        assetSizeText = ` (${sizeMb} MB)`;
      }
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
    if (heroBtnText) heroBtnText.textContent = `Download ${tagName} (Win64)${assetSizeText}`;

    const downloadSectionBtn = document.getElementById('download-section-btn');
    const downloadSectionText = document.getElementById('download-section-text');
    if (downloadSectionBtn) downloadSectionBtn.href = directDownloadUrl;
    if (downloadSectionText) downloadSectionText.textContent = `Download ${tagName} (Win64)${assetSizeText}`;

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

  function openPilotModal() {
    audio.beep(880, 0.05);
    if (pilotModal) pilotModal.classList.remove('hidden');
    // If logged in, jump straight to dossier
    if (localStorage.getItem('vanguard_pilot_token')) {
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

  function updateAuthUI() {
    const rawProfile = localStorage.getItem('vanguard_pilot_profile');
    if (rawProfile && pilotPortalLabel) {
      try {
        const pilot = JSON.parse(rawProfile);
        pilotPortalLabel.textContent = pilot.callsign;
        if (mobilePilotLabel) mobilePilotLabel.textContent = `${pilot.rank} ${pilot.callsign}`;
        if (pilotPortalIcon) pilotPortalIcon.textContent = '⚡';
        if (heroRegisterBtn) {
          heroRegisterBtn.innerHTML = `<span class="text-xl">⚡</span><span>PILOT DOSSIER // ${pilot.callsign}</span>`;
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
    } catch {}
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

          localStorage.setItem('vanguard_pilot_profile', JSON.stringify(pilot));
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

  updateAuthUI();
  syncStatsFromCloud(false);
  syncGitHubRelease();
  fetchNetworkStats();
  sendWebHeartbeat();
  setInterval(fetchNetworkStats, 20000);
  setInterval(sendWebHeartbeat, 30000);
});
