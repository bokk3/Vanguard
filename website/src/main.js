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

  // Sound toggle button
  const soundToggle = document.getElementById('sound-toggle');
  if (soundToggle) {
    soundToggle.addEventListener('click', () => {
      audio.muted = !audio.muted;
      soundToggle.textContent = audio.muted ? '[ AUDIO: MUTED ]' : '[ AUDIO: TACTICAL ]';
      soundToggle.classList.toggle('text-vanguard-textMuted', audio.muted);
      soundToggle.classList.toggle('text-vanguard-cyan', !audio.muted);
    });
  }

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

  syncGitHubRelease();
});
