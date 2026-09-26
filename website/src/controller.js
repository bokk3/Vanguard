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
  tare_pulse: false,
  power_divert: 'BALANCED', // 'ENGINES', 'SHIELDS', 'WEAPONS', 'BALANCED'

  // Mode & connection settings
  steerMode: 'touch', // 'touch' or 'gyro'
  host: '',
  callsign: 'WINGMAN-2',
  token: '',
  connected: false,
  audioEnabled: true,

  // Gyroscope calibration (screen-orientation-aware)
  gyroNeutral: { screenX: 0.0, screenY: 0.65, calibrated: false },
  gyroMaxDeflection: 0.42, // ~25 degrees of hand deflection in gravity units
};

let yawButtonPressed = false;

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
  tareHorizonBtn: document.getElementById('tareHorizonBtn'),
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

function isPrivateHost(h) {
  if (!h) return false;
  const hostOnly = h.split(':')[0];
  return /^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|127\.|localhost)/.test(hostOnly);
}

function handleMixedContentBlock() {
  if (window.location.protocol === 'https:' && isPrivateHost(state.host)) {
    const ipOnly = state.host.split(':')[0];
    const wsPort = state.host.split(':')[1] || '8081';
    const httpPort = state.httpPort || '8080';
    const lanUrl = `http://${ipOnly}:${httpPort}/?ws=${wsPort}&room=${encodeURIComponent(state.token || '')}&callsign=${encodeURIComponent(state.callsign || '')}&pid=${state.playerId || 1}&role=${encodeURIComponent(state.role || 'pilot')}`;
    els.threatBanner.innerHTML = `<a href="${lanUrl}" style="text-decoration:underline;color:#00e5ff;font-weight:bold;">⚡ CONNECTING LOCAL LAN FLIGHT DECK... TAP HERE IF NOT OPENED</a>`;
    els.threatBanner.className = 'text-vanguard-cyan font-bold tracking-widest truncate cursor-pointer';
    els.threatBanner.onclick = () => { window.location.href = lanUrl; };

    try {
      window.location.replace(lanUrl);
    } catch {}
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
      const roleTag = state.playerId === 1 ? 'COMMAND PILOT' : 'WINGMAN';
      updateConnectionUI('connected', `LINKED // ${roleTag}`);
      haptic([30, 20, 30]);
      playSynthTone(880, 0.1);

      // Send Handshake packet
      ws.send(JSON.stringify({
        type: 'handshake',
        callsign: state.callsign,
        token: state.token,
        role: state.role || 'pilot',
        player_id: state.playerId || 1,
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
      handleMixedContentBlock();
    };
  } catch (e) {
    state.connected = false;
    updateConnectionUI('disconnected');
    handleMixedContentBlock();
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

// ============================================================================
// 5b. Kinesthetic Response Curve (Aerospace Exponential Deadzone)
// ============================================================================

function applyExponentialDeadzone(val, deadzone = 0.04, exponent = 1.6) {
  const absVal = Math.abs(val);
  if (absVal <= deadzone) return 0.0;
  const normalized = (absVal - deadzone) / (1.0 - deadzone);
  return Math.sign(val) * Math.min(1.0, Math.pow(normalized, exponent));
}

// Reusable 16-byte buffer for ultra-low-latency binary control streaming (<5ms latency)
const binaryBuffer = new ArrayBuffer(16);
const floatView = new Float32Array(binaryBuffer);
const int16View = new Int16Array(binaryBuffer);
const uint8View = new Uint8Array(binaryBuffer);
let packetSeq = 0;

function startTransmitLoop() {
  if (transmitTimer) clearInterval(transmitTimer);

  // 30Hz high-frequency binary transmit loop (every ~33ms)
  transmitTimer = setInterval(() => {
    if (!ws || ws.readyState !== WebSocket.OPEN) return;

    // Bytes 0-3: pitch (Float32, Little-Endian)
    floatView[0] = state.pitch;
    // Bytes 4-7: roll (Float32, Little-Endian)
    floatView[1] = state.roll;
    // Bytes 8-11: throttle (Float32, Little-Endian)
    floatView[2] = state.throttle;
    // Bytes 12-13: yaw (Int16, Little-Endian, scaled to [-32767, 32767])
    int16View[6] = Math.max(-32767, Math.min(32767, Math.round(state.yaw * 32767)));

    // Byte 14: Flags bitmask (fire=1, boost=2, missile=4, power=bits 3-4, lock=32, tare=64)
    let flags = 0;
    if (state.fire_primary) flags |= 1;
    if (state.boost) flags |= 2;
    if (state.fire_missile) flags |= 4;

    let powerCode = 0;
    if (state.power_divert === 'ENGINES') powerCode = 1;
    else if (state.power_divert === 'SHIELDS') powerCode = 2;
    else if (state.power_divert === 'WEAPONS') powerCode = 3;
    flags |= (powerCode & 3) << 3;

    if (state.target_lock) flags |= 32;
    if (state.tare_pulse) flags |= 64;
    uint8View[14] = flags;

    // Byte 15: Sequence counter (0-255)
    packetSeq = (packetSeq + 1) & 0xFF;
    uint8View[15] = packetSeq;

    // Raw 16-byte binary send over WebSocket (<5ms latency)
    ws.send(binaryBuffer);

    // Reset single-pulse action flags
    state.fire_missile = false;
    state.target_lock = false;
    state.tare_pulse = false;
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

    // Set normalized inputs [-1.0, 1.0] with aerospace exponential deadzone
    const rawRoll = clampedX / stickMaxRadius;
    const rawPitch = -(clampedY / stickMaxRadius);
    state.roll = applyExponentialDeadzone(rawRoll, 0.04, 1.6);
    state.pitch = applyExponentialDeadzone(rawPitch, 0.04, 1.6);

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
// 8. Flight Controls: Gyroscope / Motion Steering & 1-Tap Tare
// ============================================================================

function getScreenOrientationAngle() {
  if (window.screen && window.screen.orientation && typeof window.screen.orientation.angle === 'number') {
    return window.screen.orientation.angle;
  }
  if (typeof window.orientation === 'number') {
    return window.orientation;
  }
  return window.innerWidth > window.innerHeight ? 90 : 0;
}

function computeScreenGravity(betaDeg, gammaDeg) {
  const rad = Math.PI / 180;
  const b = betaDeg * rad;
  const g = gammaDeg * rad;

  // Physical device gravity components:
  // gx: tilt right along phone short edge
  // gy: tilt up along phone long edge
  const gx = Math.cos(b) * Math.sin(g);
  const gy = -Math.sin(b);

  const angle = getScreenOrientationAngle();
  const aRad = angle * rad;

  // 2D rotation projecting physical device gravity onto the active display screen:
  // screenX: positive when tilted right relative to screen
  // screenY: positive when tilted forward/down relative to screen
  const screenX = gx * Math.cos(aRad) - gy * Math.sin(aRad);
  const screenY = -(gx * Math.sin(aRad) + gy * Math.cos(aRad));

  return { screenX, screenY };
}

function setupGyroscope() {
  function handleOrientation(e) {
    if (state.steerMode !== 'gyro') return;

    const beta = e.beta || 0;
    const gamma = e.gamma || 0;

    const { screenX, screenY } = computeScreenGravity(beta, gamma);

    // Auto-calibrate on first received frame if not yet explicitly tared
    if (!state.gyroNeutral.calibrated) {
      state.gyroNeutral.screenX = screenX;
      state.gyroNeutral.screenY = screenY;
      state.gyroNeutral.calibrated = true;
    }

    // Calculate delta relative to calibrated neutral angle
    const deltaX = screenX - state.gyroNeutral.screenX;
    const deltaY = screenY - state.gyroNeutral.screenY;

    // Aerospace sensitivity deflection limit (~24 degrees of natural hand motion)
    const maxDeflection = state.gyroMaxDeflection || 0.42;

    // Roll: tilting right relative to screen (deltaX > 0) banks right (+1.0)
    const normRoll = Math.max(-1.0, Math.min(1.0, deltaX / maxDeflection));
    // Pitch: tilting top of screen forward (deltaY > 0) pitches down (-1.0), tilting back pitches up (+1.0)
    const normPitch = Math.max(-1.0, Math.min(1.0, -deltaY / maxDeflection));

    // Aerospace exponential deadzone response curve
    state.roll = applyExponentialDeadzone(normRoll, 0.04, 1.5);
    state.pitch = applyExponentialDeadzone(normPitch, 0.04, 1.5);

    // Coordinated rudder / yaw steering: banking left/right smoothly yaws the nose into the turn for fluid space flight
    if (!yawButtonPressed) {
      state.yaw = state.roll * 0.40;
    }

    // Visual horizon reticle rotation & translation
    if (els.gyroReticle) {
      els.gyroReticle.style.transform = `rotate(${-state.roll * 35}deg) translateY(${-state.pitch * 20}px)`;
    }
  }

  window.addEventListener('deviceorientation', handleOrientation);

  // Auto re-zero when screen rotates between horizontal and vertical
  window.addEventListener('orientationchange', () => {
    state.gyroNeutral.calibrated = false;
  });
  if (window.screen && window.screen.orientation) {
    window.screen.orientation.addEventListener('change', () => {
      state.gyroNeutral.calibrated = false;
    });
  }

  // 1-Tap [ 🎯 TARE / ZERO HORIZON ] Calibration (CEObot Mandate)
  function performTareZero() {
    initAudio();
    haptic([30, 20, 50]);
    playSynthTone(880, 0.1, 'sine');
    state.tare_pulse = true;

    // Zero device orientation if sensor available
    if (window.DeviceOrientationEvent) {
      const onTare = function(e) {
        const beta = e.beta || 0;
        const gamma = e.gamma || 0;
        const { screenX, screenY } = computeScreenGravity(beta, gamma);
        state.gyroNeutral.screenX = screenX;
        state.gyroNeutral.screenY = screenY;
        state.gyroNeutral.calibrated = true;
        window.removeEventListener('deviceorientation', onTare);
      };
      window.addEventListener('deviceorientation', onTare, { once: true });
    }

    triggerScreenFlash('ring-vanguard-amber', 250);
    if (els.threatBanner) {
      els.threatBanner.textContent = '🎯 // HORIZON ZEROED & CALIBRATED //';
      els.threatBanner.className = 'text-vanguard-amber font-black tracking-widest truncate animate-pulse';
    }

    if (els.tareHorizonBtn) {
      els.tareHorizonBtn.classList.add('scale-105', 'bg-vanguard-amber', 'text-black');
      setTimeout(() => {
        els.tareHorizonBtn.classList.remove('scale-105', 'bg-vanguard-amber', 'text-black');
      }, 200);
    }
  }

  if (els.tareHorizonBtn) {
    els.tareHorizonBtn.addEventListener('click', performTareZero);
  }
  if (els.calibrateGyroBtn) {
    els.calibrateGyroBtn.addEventListener('click', performTareZero);
  }

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
      state.gyroNeutral.calibrated = false; // Auto-zero on activate
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
      if (!yawButtonPressed) state.yaw = 0.0;
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

  // Yaw Pedals (Rudder Control)
  function onYawLeftStart(e) {
    if (e.cancelable) e.preventDefault();
    yawButtonPressed = true;
    state.yaw = -1.0;
    haptic(10);
  }

  function onYawLeftEnd() {
    yawButtonPressed = false;
    state.yaw = state.steerMode === 'gyro' ? (state.roll * 0.40) : 0.0;
  }

  function onYawRightStart(e) {
    if (e.cancelable) e.preventDefault();
    yawButtonPressed = true;
    state.yaw = 1.0;
    haptic(10);
  }

  function onYawRightEnd() {
    yawButtonPressed = false;
    state.yaw = state.steerMode === 'gyro' ? (state.roll * 0.40) : 0.0;
  }

  els.yawLeftBtn.addEventListener('touchstart', onYawLeftStart, { passive: false });
  els.yawLeftBtn.addEventListener('touchend', onYawLeftEnd);
  els.yawLeftBtn.addEventListener('touchcancel', onYawLeftEnd);
  els.yawLeftBtn.addEventListener('mousedown', onYawLeftStart);
  els.yawLeftBtn.addEventListener('mouseup', onYawLeftEnd);
  els.yawLeftBtn.addEventListener('mouseleave', onYawLeftEnd);

  els.yawRightBtn.addEventListener('touchstart', onYawRightStart, { passive: false });
  els.yawRightBtn.addEventListener('touchend', onYawRightEnd);
  els.yawRightBtn.addEventListener('touchcancel', onYawRightEnd);
  els.yawRightBtn.addEventListener('mousedown', onYawRightStart);
  els.yawRightBtn.addEventListener('mouseup', onYawRightEnd);
  els.yawRightBtn.addEventListener('mouseleave', onYawRightEnd);

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
  const paramWs = params.get('ws') || '8081';
  const paramHttp = params.get('http') || '8080';
  const paramCallsign = params.get('callsign') || params.get('pilot');
  const paramToken = params.get('token') || params.get('room');
  const paramRole = params.get('role') || (params.get('pid') === '2' ? 'wingman' : 'pilot');
  const paramPid = parseInt(params.get('pid') || '1', 10);

  state.httpPort = paramHttp;
  state.role = paramRole;
  state.playerId = paramPid;

  if (paramHost) {
    state.host = paramHost;
  } else if (window.location.hostname && window.location.hostname !== '' && !window.location.hostname.includes('pages.dev')) {
    state.host = `${window.location.hostname}:${paramWs}`;
  } else {
    state.host = localStorage.getItem('vanguard_last_host') || '';
  }

  const defaultCs = state.playerId === 1 ? 'COMMAND-PILOT' : 'WINGMAN-2';
  state.callsign = (paramCallsign || localStorage.getItem('vanguard_callsign') || defaultCs).toUpperCase();
  state.token = paramToken || '';

  const rolePrefix = state.playerId === 1 ? 'HOTAS 1' : 'WING 2';
  els.headerCallsign.textContent = `[${rolePrefix}] CALLSIGN: ${state.callsign}`;

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
    handleMixedContentBlock();
  } else {
    updateConnectionUI('disconnected');
    openConfig();
  }

  // Prevent double-tap zoom on iOS Safari
  document.addEventListener('dblclick', (e) => e.preventDefault(), { passive: false });
}

window.addEventListener('DOMContentLoaded', init);
