/**
 * Project Vanguard - Mobile Cockpit HOTAS Controller Engine
 * High-performance 30Hz touch & gyroscope telemetry streamer over local WebSocket.
 * Features: Multi-touch analog flight stick, continuous throttle, Web Haptics, and Screen WakeLock.
 */

// ============================================================================
// 1. Controller State
// ============================================================================

const state = {
  // Flight telemetry inputs
  pitch: 0.0,      // -1.0 (Nose Down) to +1.0 (Nose Up)
  roll: 0.0,       // -1.0 (Bank Left) to +1.0 (Bank Right)
  yaw: 0.0,        // -1.0 (Rudder Left) to +1.0 (Rudder Right)
  throttle: 0.5,   // 0.0 (Idle) to 1.0 (Full Thrust)
  boost: false,    // Afterburner nitro boost
  fire_primary: false,
  fire_missile: false,
  target_lock: false,
  power_divert: 'BALANCED', // 'ENGINES', 'SHIELDS', 'WEAPONS', 'BALANCED'

  // Mode & connection settings
  steerMode: 'touch', // 'touch' or 'gyro'
  host: '',
  callsign: 'WINGMAN-2',
  token: '',
  connected: false,
  audioEnabled: true,

  // Gyroscope calibration
  gyroNeutral: { beta: 45, gamma: 0 },
  gyroMaxDeflection: 30, // degrees
};

let ws = null;
let transmitTimer = null;
let wakeLock = null;
let audioCtx = null;

// ============================================================================
// 2. DOM Elements
// ============================================================================

const els = {
  tacticalFlashOverlay: document.getElementById('tacticalFlashOverlay'),
  connectionPill: document.getElementById('connectionPill'),
  connectionDot: document.getElementById('connectionDot'),
  connectionText: document.getElementById('connectionText'),
  headerCallsign: document.getElementById('headerCallsign'),
  toggleSteerModeBtn: document.getElementById('toggleSteerModeBtn'),
  steerModeIcon: document.getElementById('steerModeIcon'),
  steerModeText: document.getElementById('steerModeText'),
  calibrateGyroBtn: document.getElementById('calibrateGyroBtn'),
  toggleAudioBtn: document.getElementById('toggleAudioBtn'),
  openConfigBtn: document.getElementById('openConfigBtn'),
  
  // Vitals
  shieldBar: document.getElementById('shieldBar'),
  shieldText: document.getElementById('shieldText'),
  hullBar: document.getElementById('hullBar'),
  hullText: document.getElementById('hullText'),
  threatBanner: document.getElementById('threatBanner'),
  speedDisplay: document.getElementById('speedDisplay'),
  missilePylons: document.querySelectorAll('.pylon'),

  // Power Management Tri-Divert
  pwrEngBtn: document.getElementById('pwrEngBtn'),
  pwrShdBtn: document.getElementById('pwrShdBtn'),
  pwrWpnBtn: document.getElementById('pwrWpnBtn'),
  pwrBalBtn: document.getElementById('pwrBalBtn'),

  // Throttle
  throttleTrack: document.getElementById('throttleTrack'),
  throttleFill: document.getElementById('throttleFill'),
  throttleHandle: document.getElementById('throttleHandle'),
  throttlePctText: document.getElementById('throttlePctText'),

  // Flight Stick
  stickZone: document.getElementById('stickZone'),
  stickKnob: document.getElementById('stickKnob'),
  gyroHorizon: document.getElementById('gyroHorizon'),
  gyroReticle: document.getElementById('gyroReticle'),
  yawLeftBtn: document.getElementById('yawLeftBtn'),
  yawRightBtn: document.getElementById('yawRightBtn'),

  // Weapons & Systems
  primaryFireBtn: document.getElementById('primaryFireBtn'),
  missileFireBtn: document.getElementById('missileFireBtn'),
  targetLockBtn: document.getElementById('targetLockBtn'),
  nitroBoostBtn: document.getElementById('nitroBoostBtn'),

  // Config Modal
  configModal: document.getElementById('configModal'),
  closeConfigBtn: document.getElementById('closeConfigBtn'),
  inputHost: document.getElementById('inputHost'),
  inputCallsign: document.getElementById('inputCallsign'),
  inputToken: document.getElementById('inputToken'),
  connectStationBtn: document.getElementById('connectStationBtn'),
};

// ============================================================================
// 3. Audio & Haptics Engine
// ============================================================================

function initAudio() {
  if (!audioCtx) {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (AudioContext) {
      audioCtx = new AudioContext();
    }
  }
}

function playSynthTone(freq, duration = 0.05, type = 'sine') {
  if (!state.audioEnabled || !audioCtx) return;
  try {
    if (audioCtx.state === 'suspended') audioCtx.resume();
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, audioCtx.currentTime);
    gain.gain.setValueAtTime(0.08, audioCtx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + duration);
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    osc.start();
    osc.stop(audioCtx.currentTime + duration);
  } catch {}
}

let flashTimeout = null;
function triggerScreenFlash(ringClass, duration = 180) {
  if (!els.tacticalFlashOverlay) return;
  if (flashTimeout) clearTimeout(flashTimeout);
  els.tacticalFlashOverlay.className = `pointer-events-none fixed inset-0 z-40 transition-opacity duration-75 opacity-100 ring-inset ring-8 ${ringClass}`;
  flashTimeout = setTimeout(() => {
    els.tacticalFlashOverlay.className = 'pointer-events-none fixed inset-0 z-40 transition-opacity duration-150 opacity-0';
  }, duration);
}

function playRadioSquelch(isOpening = true) {
  if (!state.audioEnabled || !audioCtx) return;
  try {
    if (audioCtx.state === 'suspended') audioCtx.resume();
    const now = audioCtx.currentTime;
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = 'triangle';
    if (isOpening) {
      osc.frequency.setValueAtTime(1400, now);
      osc.frequency.exponentialRampToValueAtTime(750, now + 0.04);
    } else {
      osc.frequency.setValueAtTime(800, now);
      osc.frequency.exponentialRampToValueAtTime(1550, now + 0.04);
    }
    gain.gain.setValueAtTime(0.06, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.05);
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    osc.start(now);
    osc.stop(now + 0.05);
  } catch {}
}

let lastSpeechTime = 0;
let lastSpeechText = '';

function speakBetty(text, priority = false) {
  if (!state.audioEnabled || !('speechSynthesis' in window)) return;
  const now = Date.now();
  if (!priority && (now - lastSpeechTime < 2200 || (lastSpeechText === text && now - lastSpeechTime < 6000))) {
    return;
  }
  lastSpeechTime = now;
  lastSpeechText = text;

  try {
    playRadioSquelch(true);
    if (priority) {
      window.speechSynthesis.cancel();
    }
    const utter = new SpeechSynthesisUtterance(text);
    utter.rate = 1.15;
    utter.pitch = 1.12;
    utter.volume = 0.95;
    
    const voices = window.speechSynthesis.getVoices();
    const enVoice = voices.find(v => v.lang.startsWith('en') && (v.name.includes('Natural') || v.name.includes('Female') || v.name.includes('Zira') || v.name.includes('Samantha')));
    if (enVoice) utter.voice = enVoice;

    utter.onend = () => {
      playRadioSquelch(false);
    };
    window.speechSynthesis.speak(utter);
  } catch {}
}

let cannonRecoilInterval = null;
function startCannonRecoil() {
  if (cannonRecoilInterval) return;
  haptic([18, 22]);
  cannonRecoilInterval = setInterval(() => {
    if (state.fire_primary) {
      haptic([18, 22]);
      playSynthTone(520, 0.035, 'sawtooth');
    } else {
      stopCannonRecoil();
    }
  }, 50);
}

function stopCannonRecoil() {
  if (cannonRecoilInterval) {
    clearInterval(cannonRecoilInterval);
    cannonRecoilInterval = null;
  }
}

function haptic(pattern = 15) {
  if (navigator.vibrate) {
    try {
      navigator.vibrate(pattern);
    } catch {}
  }
}

// ============================================================================
// 4. Screen WakeLock (Keep display awake during sortie)
// ============================================================================

async function requestWakeLock() {
  if ('wakeLock' in navigator) {
    try {
      wakeLock = await navigator.wakeLock.request('screen');
      wakeLock.addEventListener('release', () => {
        wakeLock = null;
      });
    } catch {}
  }
}

// ============================================================================
// 5. WebSocket Client & Network Loop
// ============================================================================

function updateConnectionUI(status, label) {
  if (status === 'connected') {
    els.connectionPill.className = 'flex items-center gap-1.5 px-2 py-0.5 rounded border border-emerald-500/50 bg-emerald-950/40 text-emerald-400 font-bold tracking-wider';
    els.connectionDot.className = 'w-2 h-2 rounded-full bg-emerald-400 shadow-[0_0_6px_#00e676]';
    els.connectionText.textContent = label || 'ONLINE';
    els.threatBanner.textContent = `// FLIGHT LINK ACTIVE // PILOT: ${state.callsign} //`;
    els.threatBanner.className = 'text-vanguard-cyan font-bold tracking-widest truncate';
  } else if (status === 'connecting') {
    els.connectionPill.className = 'flex items-center gap-1.5 px-2 py-0.5 rounded border border-amber-500/50 bg-amber-950/40 text-amber-400 font-bold tracking-wider';
    els.connectionDot.className = 'w-2 h-2 rounded-full bg-amber-400 animate-ping';
    els.connectionText.textContent = 'CONNECTING...';
    els.threatBanner.textContent = `// ACQUIRING STATION LINK: ${state.host} //`;
    els.threatBanner.className = 'text-amber-400 font-bold tracking-widest truncate';
  } else {
    els.connectionPill.className = 'flex items-center gap-1.5 px-2 py-0.5 rounded border border-red-500/50 bg-red-950/40 text-red-400 font-bold tracking-wider';
    els.connectionDot.className = 'w-2 h-2 rounded-full bg-red-500 animate-pulse';
    els.connectionText.textContent = 'OFFLINE';
    els.threatBanner.textContent = '// DISCONNECTED // TAP ⚙️ TO CONFIGURE HOST //';
    els.threatBanner.className = 'text-red-400 font-bold tracking-widest truncate';
  }
}

function connectWebSocket() {
  if (!state.host) {
    updateConnectionUI('disconnected');
    openConfig();
    return;
  }

  if (ws) {
    ws.close();
  }

  updateConnectionUI('connecting');
  const wsUrl = `ws://${state.host}`;

  try {
    ws = new WebSocket(wsUrl);

    ws.onopen = () => {
      state.connected = true;
      updateConnectionUI('connected', 'LINKED // 2ms');
      haptic([30, 20, 30]);
      playSynthTone(880, 0.1);

      // Send Handshake packet
      ws.send(JSON.stringify({
        type: 'handshake',
        callsign: state.callsign,
        token: state.token,
        client: 'vanguard_mobile_hotas_v1',
      }));

      requestWakeLock();
    };

    ws.onmessage = (event) => {
      try {
        const telem = JSON.parse(event.data);
        handleIncomingTelemetry(telem);
      } catch {}
    };

    ws.onclose = () => {
      state.connected = false;
      updateConnectionUI('disconnected');
    };

    ws.onerror = () => {
      state.connected = false;
      updateConnectionUI('disconnected');
    };
  } catch (e) {
    state.connected = false;
    updateConnectionUI('disconnected');
  }
}

function handleIncomingTelemetry(telem) {
  // 1. Shields
  if (telem.shield !== undefined) {
    const s = Math.round(telem.shield);
    els.shieldBar.style.width = `${Math.max(0, Math.min(100, s))}%`;
    els.shieldText.textContent = `${s}`;
  }

  // 2. Hull
  if (telem.hull !== undefined) {
    const h = Math.round(telem.hull);
    els.hullBar.style.width = `${Math.max(0, Math.min(100, h))}%`;
    els.hullText.textContent = `${h}`;
    if (h < 25) {
      els.hullBar.className = 'h-full bg-crimson shadow-crimson-glow animate-pulse';
    } else {
      els.hullBar.className = 'h-full bg-emerald-400 shadow-[0_0_8px_#00e676]';
    }
  }

  // 3. Airspeed
  if (telem.speed !== undefined) {
    els.speedDisplay.textContent = `${Math.round(telem.speed)} M/S`;
  }

  // 4. Missiles
  if (telem.missiles !== undefined) {
    const mCount = Math.max(0, Math.min(4, telem.missiles));
    els.missilePylons.forEach((pylon, idx) => {
      if (idx < mCount) {
        pylon.className = 'pylon px-1 rounded bg-vanguard-amber/20 border border-vanguard-amber/60 text-vanguard-amber';
      } else {
        pylon.className = 'pylon px-1 rounded bg-slate-900 border border-slate-700 text-slate-600 line-through';
      }
    });
  }

  // 5. Threat Alarms & Haptics
  if (telem.under_fire) {
    els.threatBanner.textContent = '// ALERT: UNDER FIRE // EVASIVE MANEUVER //';
    els.threatBanner.className = 'text-vanguard-crimson font-black tracking-widest animate-pulse truncate';
    haptic([40, 20, 40]);
  } else if (telem.target_locked) {
    els.threatBanner.textContent = '// TACTICAL: MISSILE LOCK ACQUIRED //';
    els.threatBanner.className = 'text-vanguard-amber font-black tracking-widest truncate';
  }

  // 6. High-Priority Combat Telemetry Events
  if (Array.isArray(telem.events) && telem.events.length > 0) {
    for (const ev of telem.events) {
      if (ev === 'HIT_CONFIRMED') {
        playSynthTone(1450, 0.04, 'sine');
        haptic(30);
        triggerScreenFlash('ring-vanguard-cyan', 130);
        els.threatBanner.textContent = '// DIRECT HIT CONFIRMED // TARGET INTEGRITY DAMAGED //';
        els.threatBanner.className = 'text-vanguard-cyan font-black tracking-widest truncate';
      } else if (ev === 'KILL_CONFIRMED') {
        playSynthTone(580, 0.16, 'triangle');
        haptic([80, 40, 80, 40, 160]);
        triggerScreenFlash('ring-vanguard-gold', 450);
        speakBetty('Splash one, bandit down!', true);
        els.threatBanner.textContent = '★ TARGET DESTROYED ★ CONFIRMED KILL ★';
        els.threatBanner.className = 'text-vanguard-gold font-black tracking-widest animate-bounce truncate';
      } else if (ev === 'SHIELD_BROKEN') {
        playSynthTone(180, 0.35, 'sawtooth');
        haptic([100, 50, 150, 50, 250]);
        triggerScreenFlash('ring-vanguard-crimson', 350);
        speakBetty('Warning: Shields down!', true);
        els.threatBanner.textContent = '⚠ SHIELDS COLLAPSED ⚠ STRUCTURAL DAMAGE IMMINENT ⚠';
        els.threatBanner.className = 'text-vanguard-crimson font-black tracking-widest animate-pulse truncate';
      } else if (ev === 'TARGET_LOCKED') {
        playSynthTone(1200, 0.12, 'square');
        haptic([40, 25, 40]);
        triggerScreenFlash('ring-vanguard-amber', 180);
        speakBetty('Target locked.');
        els.threatBanner.textContent = '⌖ MISSILE LOCK CONFIRMED ⌖ FOX TWO READY ⌖';
        els.threatBanner.className = 'text-vanguard-amber font-black tracking-widest truncate';
      }
    }
  }

  // 7. Sync Server Power Mode if reported
  if (telem.power_mode && telem.power_mode !== state.power_divert) {
    if (typeof updatePowerUI === 'function') {
      updatePowerUI(telem.power_mode);
    }
  }
}

function startTransmitLoop() {
  if (transmitTimer) clearInterval(transmitTimer);

  // 30Hz high-frequency transmit loop (every ~33ms)
  transmitTimer = setInterval(() => {
    if (!ws || ws.readyState !== WebSocket.OPEN) return;

    const packet = {
      t: Date.now(),
      pitch: Number(state.pitch.toFixed(3)),
      roll: Number(state.roll.toFixed(3)),
      yaw: Number(state.yaw.toFixed(3)),
      throttle: Number(state.throttle.toFixed(3)),
      boost: state.boost,
      fire_primary: state.fire_primary,
      fire_missile: state.fire_missile,
      target_lock: state.target_lock,
      power_divert: state.power_divert,
    };

    ws.send(JSON.stringify(packet));

    // Reset single-pulse action flags
    state.fire_missile = false;
    state.target_lock = false;
  }, 33);
}

// ============================================================================
// 6. Flight Controls: Virtual Analog Thumbstick
// ============================================================================

let stickActive = false;
let stickCenter = { x: 0, y: 0 };
let stickMaxRadius = 60;

function setupFlightStick() {
  const zone = els.stickZone;
  const knob = els.stickKnob;

  function updateStickMetrics() {
    const rect = zone.getBoundingClientRect();
    stickCenter = {
      x: rect.left + rect.width / 2,
      y: rect.top + rect.height / 2,
    };
    stickMaxRadius = Math.min(rect.width, rect.height) * 0.35;
  }

  window.addEventListener('resize', updateStickMetrics);
  updateStickMetrics();

  function onTouchStart(e) {
    if (state.steerMode !== 'touch') return;
    initAudio();
    stickActive = true;
    updateStickMetrics();
    onTouchMove(e);
  }

  function onTouchMove(e) {
    if (!stickActive || state.steerMode !== 'touch') return;
    e.preventDefault();

    const touch = e.touches[0];
    const dx = touch.clientX - stickCenter.x;
    const dy = touch.clientY - stickCenter.y;
    const distance = Math.hypot(dx, dy);

    let clampedX = dx;
    let clampedY = dy;

    if (distance > stickMaxRadius) {
      const angle = Math.atan2(dy, dx);
      clampedX = Math.cos(angle) * stickMaxRadius;
      clampedY = Math.sin(angle) * stickMaxRadius;
    }

    // Set normalized inputs [-1.0, 1.0]
    state.roll = clampedX / stickMaxRadius;
    // Pulling stick back (downwards touch) pitches UP (+1.0)
    state.pitch = -(clampedY / stickMaxRadius);

    // Update UI knob position
    knob.style.transform = `translate(calc(-50% + ${clampedX}px), calc(-50% + ${clampedY}px))`;
  }

  function onTouchEnd() {
    if (!stickActive) return;
    stickActive = false;
    state.pitch = 0.0;
    state.roll = 0.0;
    knob.style.transform = 'translate(-50%, -50%)';
  }

  zone.addEventListener('touchstart', onTouchStart, { passive: false });
  zone.addEventListener('touchmove', onTouchMove, { passive: false });
  zone.addEventListener('touchend', onTouchEnd);
  zone.addEventListener('touchcancel', onTouchEnd);
}

// ============================================================================
// 7. Flight Controls: Continuous Vertical Throttle
// ============================================================================

function setupThrottle() {
  const track = els.throttleTrack;
  let throttleDragging = false;

  function updateThrottleFromY(clientY) {
    const rect = track.getBoundingClientRect();
    const relativeY = clientY - rect.top;
    // Invert because bottom is 0% and top is 100%
    const ratio = 1.0 - (relativeY / rect.height);
    const clamped = Math.max(0.0, Math.min(1.0, ratio));

    state.throttle = clamped;
    // Boost threshold at >90% throttle
    state.boost = clamped > 0.90;

    const pct = Math.round(clamped * 100);
    els.throttleFill.style.height = `${pct}%`;
    els.throttleHandle.style.bottom = `${pct}%`;
    els.throttlePctText.textContent = `${pct}%`;

    if (state.boost) {
      els.throttlePctText.textContent = 'BOOST!';
      els.throttlePctText.className = 'text-[10px] font-black text-vanguard-amber animate-pulse mt-0.5';
    } else {
      els.throttlePctText.className = 'text-[10px] font-extrabold text-vanguard-cyan mt-0.5';
    }
  }

  track.addEventListener('touchstart', (e) => {
    initAudio();
    throttleDragging = true;
    updateThrottleFromY(e.touches[0].clientY);
    haptic(10);
  }, { passive: true });

  track.addEventListener('touchmove', (e) => {
    if (!throttleDragging) return;
    e.preventDefault();
    updateThrottleFromY(e.touches[0].clientY);
  }, { passive: false });

  window.addEventListener('touchend', () => {
    throttleDragging = false;
  });
}

// ============================================================================
// 8. Flight Controls: Gyroscope / Motion Steering
// ============================================================================

function setupGyroscope() {
  function handleOrientation(e) {
    if (state.steerMode !== 'gyro') return;

    const beta = e.beta || 0;   // Pitch: [-180, 180]
    const gamma = e.gamma || 0; // Roll: [-90, 90]

    // Calculate delta relative to calibrated neutral angle
    const deltaBeta = beta - state.gyroNeutral.beta;
    const deltaGamma = gamma - state.gyroNeutral.gamma;

    // Pitch: tilting device forward (deltaBeta > 0) pitches down (-1.0)
    const normPitch = Math.max(-1.0, Math.min(1.0, -deltaBeta / state.gyroMaxDeflection));
    // Roll: tilting device right (deltaGamma > 0) rolls right (+1.0)
    const normRoll = Math.max(-1.0, Math.min(1.0, deltaGamma / state.gyroMaxDeflection));

    // Deadzone filter (3 degrees)
    state.pitch = Math.abs(normPitch) < 0.08 ? 0.0 : normPitch;
    state.roll = Math.abs(normRoll) < 0.08 ? 0.0 : normRoll;

    // Visual horizon reticle rotation
    els.gyroReticle.style.transform = `rotate(${-state.roll * 35}deg) translateY(${-state.pitch * 20}px)`;
  }

  window.addEventListener('deviceorientation', handleOrientation);

  els.calibrateGyroBtn.addEventListener('click', () => {
    haptic(25);
    // Center at current device orientation
    window.addEventListener('deviceorientation', function onCalibrate(e) {
      state.gyroNeutral.beta = e.beta || 45;
      state.gyroNeutral.gamma = e.gamma || 0;
      window.removeEventListener('deviceorientation', onCalibrate);
      playSynthTone(700, 0.1);
    }, { once: true });
  });

  els.toggleSteerModeBtn.addEventListener('click', async () => {
    initAudio();
    haptic(20);

    if (state.steerMode === 'touch') {
      // Request permission on iOS 13+ devices
      if (typeof DeviceOrientationEvent !== 'undefined' && typeof DeviceOrientationEvent.requestPermission === 'function') {
        try {
          const perm = await DeviceOrientationEvent.requestPermission();
          if (perm !== 'granted') {
            alert('Motion sensor permission denied.');
            return;
          }
        } catch (err) {
          alert('Failed to request motion sensor permission.');
          return;
        }
      }

      state.steerMode = 'gyro';
      els.steerModeIcon.textContent = '🧭';
      els.steerModeText.textContent = 'GYRO STEER';
      els.stickKnob.classList.add('hidden');
      els.gyroHorizon.classList.remove('hidden');
      els.calibrateGyroBtn.classList.remove('hidden');
    } else {
      state.steerMode = 'touch';
      els.steerModeIcon.textContent = '🕹️';
      els.steerModeText.textContent = 'TOUCH STICK';
      els.stickKnob.classList.remove('hidden');
      els.gyroHorizon.classList.add('hidden');
      els.calibrateGyroBtn.classList.add('hidden');
      state.pitch = 0.0;
      state.roll = 0.0;
    }
  });
}

// ============================================================================
// 9. Combat Buttons & Systems Triggers
// ============================================================================

function setupCombatTriggers() {
  // Primary Photon Cannon (Hold to fire + Rotary Autocannon Recoil)
  function onFirePrimaryStart(e) {
    if (e.cancelable) e.preventDefault();
    initAudio();
    state.fire_primary = true;
    startCannonRecoil();
    playSynthTone(480, 0.05, 'sawtooth');
  }

  function onFirePrimaryEnd() {
    state.fire_primary = false;
    stopCannonRecoil();
  }

  els.primaryFireBtn.addEventListener('touchstart', onFirePrimaryStart, { passive: false });
  els.primaryFireBtn.addEventListener('touchend', onFirePrimaryEnd);
  els.primaryFireBtn.addEventListener('touchcancel', onFirePrimaryEnd);
  els.primaryFireBtn.addEventListener('mousedown', onFirePrimaryStart);
  els.primaryFireBtn.addEventListener('mouseup', onFirePrimaryEnd);
  els.primaryFireBtn.addEventListener('mouseleave', onFirePrimaryEnd);

  // Secondary Strike Missile
  function onFireMissile(e) {
    if (e.cancelable) e.preventDefault();
    initAudio();
    state.fire_missile = true;
    haptic([100, 35, 60]);
    playSynthTone(180, 0.22, 'triangle');
    triggerScreenFlash('ring-vanguard-amber', 250);
    speakBetty('Fox Two away!');
  }

  els.missileFireBtn.addEventListener('touchstart', onFireMissile, { passive: false });
  els.missileFireBtn.addEventListener('mousedown', onFireMissile);

  // Target Lock Button
  els.targetLockBtn.addEventListener('click', () => {
    initAudio();
    state.target_lock = true;
    haptic(35);
    playSynthTone(1200, 0.08, 'sine');
    triggerScreenFlash('ring-vanguard-amber', 120);
  });

  // Nitro Boost Button
  function onBoostStart(e) {
    if (e.cancelable) e.preventDefault();
    state.boost = true;
    haptic(25);
    playSynthTone(300, 0.1, 'sawtooth');
    triggerScreenFlash('ring-vanguard-cyan', 180);
  }

  function onBoostEnd() {
    if (state.throttle <= 0.90) {
      state.boost = false;
    }
  }

  els.nitroBoostBtn.addEventListener('touchstart', onBoostStart, { passive: false });
  els.nitroBoostBtn.addEventListener('mousedown', onBoostStart);
  els.nitroBoostBtn.addEventListener('touchend', onBoostEnd);
  els.nitroBoostBtn.addEventListener('mouseup', onBoostEnd);

  // Yaw Pedals
  els.yawLeftBtn.addEventListener('touchstart', (e) => {
    e.preventDefault();
    state.yaw = -1.0;
    haptic(10);
  }, { passive: false });

  els.yawLeftBtn.addEventListener('touchend', () => {
    state.yaw = 0.0;
  });

  els.yawRightBtn.addEventListener('touchstart', (e) => {
    e.preventDefault();
    state.yaw = 1.0;
    haptic(10);
  }, { passive: false });

  els.yawRightBtn.addEventListener('touchend', () => {
    state.yaw = 0.0;
  });

  // Audio Toggle
  els.toggleAudioBtn.addEventListener('click', () => {
    state.audioEnabled = !state.audioEnabled;
    els.toggleAudioBtn.textContent = state.audioEnabled ? '🔊' : '🔇';
    haptic(10);
  });
}

// ============================================================================
// 9b. Power Management Tri-Divert
// ============================================================================

let updatePowerUI = null;

function setupPowerDivert() {
  const modes = [
    { id: 'pwrEngBtn', mode: 'ENGINES', callout: 'Power diverted to engines.', ring: 'ring-vanguard-cyan', activeClass: 'border-2 border-vanguard-cyan bg-vanguard-cyan/30 text-white shadow-[0_0_15px_#00e5ff]' },
    { id: 'pwrShdBtn', mode: 'SHIELDS', callout: 'Power diverted to shields.', ring: 'ring-emerald-400', activeClass: 'border-2 border-emerald-400 bg-emerald-500/30 text-white shadow-[0_0_15px_#00e676]' },
    { id: 'pwrWpnBtn', mode: 'WEAPONS', callout: 'Power diverted to weapons.', ring: 'ring-vanguard-crimson', activeClass: 'border-2 border-vanguard-crimson bg-vanguard-crimson/30 text-white shadow-[0_0_15px_#ff2a4d]' },
    { id: 'pwrBalBtn', mode: 'BALANCED', callout: 'Power balanced.', ring: 'ring-slate-300', activeClass: 'border-2 border-white/80 bg-white/20 text-white shadow-sm' },
  ];

  updatePowerUI = function(selectedMode) {
    state.power_divert = selectedMode;
    const defaultClasses = {
      pwrEngBtn: 'py-1 px-1 rounded border border-vanguard-cyan/40 bg-vanguard-cyan/10 text-vanguard-cyan text-[10px] font-bold tracking-wider flex items-center justify-center gap-1 active:scale-95 transition-all',
      pwrShdBtn: 'py-1 px-1 rounded border border-emerald-500/40 bg-emerald-500/10 text-emerald-400 text-[10px] font-bold tracking-wider flex items-center justify-center gap-1 active:scale-95 transition-all',
      pwrWpnBtn: 'py-1 px-1 rounded border border-vanguard-crimson/40 bg-vanguard-crimson/10 text-vanguard-crimson text-[10px] font-bold tracking-wider flex items-center justify-center gap-1 active:scale-95 transition-all',
      pwrBalBtn: 'py-1 px-1 rounded border border-slate-700 bg-slate-900/60 text-slate-400 text-[10px] font-bold tracking-wider flex items-center justify-center gap-1 active:scale-95 transition-all',
    };

    modes.forEach(m => {
      const btn = els[m.id];
      if (!btn) return;
      if (m.mode === selectedMode) {
        btn.className = `py-1 px-1 rounded ${m.activeClass} text-[10px] font-black tracking-wider flex items-center justify-center gap-1 active:scale-95 transition-all`;
      } else {
        btn.className = defaultClasses[m.id];
      }
    });
  };

  modes.forEach(m => {
    const btn = els[m.id];
    if (btn) {
      btn.addEventListener('click', () => {
        initAudio();
        haptic(25);
        playSynthTone(m.mode === 'ENGINES' ? 950 : m.mode === 'SHIELDS' ? 620 : m.mode === 'WEAPONS' ? 1250 : 750, 0.08);
        triggerScreenFlash(m.ring, 220);
        speakBetty(m.callout);
        updatePowerUI(m.mode);
      });
    }
  });

  updatePowerUI('BALANCED');
}

// ============================================================================
// 10. Configuration Modal & URL Param Autoload
// ============================================================================

function openConfig() {
  els.inputHost.value = state.host;
  els.inputCallsign.value = state.callsign;
  els.inputToken.value = state.token;
  els.configModal.classList.remove('hidden');
}

function closeConfig() {
  els.configModal.classList.add('hidden');
}

function setupConfig() {
  els.openConfigBtn.addEventListener('click', openConfig);
  els.closeConfigBtn.addEventListener('click', closeConfig);

  els.connectStationBtn.addEventListener('click', () => {
    initAudio();
    haptic(20);
    state.host = els.inputHost.value.trim();
    state.callsign = (els.inputCallsign.value.trim() || 'WINGMAN-2').toUpperCase();
    state.token = els.inputToken.value.trim();

    localStorage.setItem('vanguard_last_host', state.host);
    localStorage.setItem('vanguard_callsign', state.callsign);
    els.headerCallsign.textContent = `CALLSIGN: ${state.callsign}`;

    closeConfig();
    connectWebSocket();
  });
}

// ============================================================================
// 11. App Initialization
// ============================================================================

function init() {
  // Read URL query parameters from QR code scan
  const params = new URLSearchParams(window.location.search);
  const paramHost = params.get('host');
  const paramCallsign = params.get('callsign') || params.get('pilot');
  const paramToken = params.get('token') || params.get('room');

  state.host = paramHost || localStorage.getItem('vanguard_last_host') || '';
  state.callsign = (paramCallsign || localStorage.getItem('vanguard_callsign') || 'WINGMAN-2').toUpperCase();
  state.token = paramToken || '';

  els.headerCallsign.textContent = `CALLSIGN: ${state.callsign}`;

  setupFlightStick();
  setupThrottle();
  setupGyroscope();
  setupCombatTriggers();
  setupPowerDivert();
  setupConfig();
  startTransmitLoop();

  // If host parameter exists from QR scan, auto-connect immediately!
  if (state.host) {
    connectWebSocket();
  } else {
    updateConnectionUI('disconnected');
    openConfig();
  }

  // Prevent double-tap zoom on iOS Safari
  document.addEventListener('dblclick', (e) => e.preventDefault(), { passive: false });
}

window.addEventListener('DOMContentLoaded', init);
