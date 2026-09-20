import os
import math
import wave
import struct
import numpy as np

OUTPUT_DIR = r"godot_project/audio/sfx"
DOCS_DIR = r"docs/lore/audio/sfx"
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(DOCS_DIR, exist_ok=True)

SAMPLE_RATE = 44100

def save_wav(filename, samples, sample_rate=SAMPLE_RATE):
    """Saves a 1D numpy array (-1.0 to 1.0) as a 16-bit mono WAV file."""
    # Clip and convert to 16-bit integer
    samples = np.clip(samples, -0.98, 0.98)
    int_samples = (samples * 32767.0).astype(np.int16)
    
    # Save to godot_project and docs/lore
    for out_dir in [OUTPUT_DIR, DOCS_DIR]:
        path = os.path.join(out_dir, filename)
        with wave.open(path, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2) # 16-bit
            wf.setframerate(sample_rate)
            wf.writeframes(int_samples.tobytes())
    print(f"Generated SFX: {filename}")

# -------------------------------------------------------------
# 1. COCKPIT AVIONICS & HUD TELEMETRY
# -------------------------------------------------------------

def gen_hud_target_locking():
    """Intermittent scanning blip tone when acquiring missile lock (880 Hz beep)."""
    duration = 0.08
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    # 880 Hz pure sine with sharp attack and exponential decay
    env = np.exp(-t * 25.0)
    wave_data = np.sin(2 * np.pi * 880.0 * t) * env
    save_wav("sfx_hud_target_locking.wav", wave_data)

def gen_hud_target_locked():
    """Continuous high-pitch solid lock tone with military urgency (1320 Hz + 1760 Hz harmonic)."""
    duration = 0.45
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    # High-pitched solid lock tone with rapid tremolo (16 Hz warble)
    tremolo = 0.85 + 0.15 * np.sin(2 * np.pi * 16.0 * t)
    env = np.ones_like(t)
    # 20ms fade-in and 30ms fade-out
    fade_len = int(SAMPLE_RATE * 0.03)
    env[-fade_len:] = np.linspace(1.0, 0.0, fade_len)
    
    tone = (0.7 * np.sin(2 * np.pi * 1320.0 * t) + 0.3 * np.sin(2 * np.pi * 1760.0 * t)) * env * tremolo
    save_wav("sfx_hud_target_locked.wav", tone)

def gen_hud_missile_incoming_spike():
    """RWR (Radar Warning Receiver) spike: Urgent dual-tone alarm when an enemy locks onto player."""
    duration = 0.6
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    # Alternating 1400Hz and 1900Hz square-ish tone at 12Hz rate
    mod = np.sign(np.sin(2 * np.pi * 12.0 * t))
    freq = np.where(mod > 0, 1400.0, 1900.0)
    phase = np.cumsum(freq) / SAMPLE_RATE
    # Slight soft clipping for cockpit alarm speaker grit
    raw_alarm = np.sin(2 * np.pi * phase)
    grit_alarm = np.tanh(raw_alarm * 2.2) * 0.8
    save_wav("sfx_hud_missile_incoming_spike.wav", grit_alarm)

def gen_hud_stall_warning():
    """Aerodynamic stall warning: Low-frequency urgent horn (240 Hz sawtooth with pulse)."""
    duration = 0.5
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    # 4 Hz repeating bursts
    burst = (np.sin(2 * np.pi * 4.0 * t) > 0.0).astype(float)
    # 240 Hz sawtooth wave
    saw = 2.0 * (t * 240.0 - np.floor(t * 240.0 + 0.5))
    tone = saw * burst * 0.75
    save_wav("sfx_hud_stall_warning.wav", tone)

def gen_hud_capacitor_empty():
    """Capacitor depleted / thermal lockout: Descending electronic sweep."""
    duration = 0.3
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    # Descending frequency from 900 Hz down to 180 Hz
    freq = 900.0 * np.exp(-t * 5.0)
    phase = np.cumsum(freq) / SAMPLE_RATE
    env = np.linspace(1.0, 0.0, len(t))
    tone = np.sin(2 * np.pi * phase) * env * 0.7
    save_wav("sfx_hud_capacitor_empty.wav", tone)

# -------------------------------------------------------------
# 2. AERODYNAMICS, HIGH-G TURNS & FLYBYS
# -------------------------------------------------------------

def gen_flight_high_g_whoosh():
    """High-G turn aerodynamic wind rush: Bandpass pink noise with smooth swell and decay."""
    duration = 1.2
    n_samples = int(SAMPLE_RATE * duration)
    # Pinkish noise via integrated white noise
    white = np.random.randn(n_samples)
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    pink = np.cumsum(white) * 0.02
    # Swell envelope (bell curve peaking around 0.5s)
    t = np.linspace(0, duration, n_samples)
    env = np.sin(np.pi * (t / duration)) ** 2
    # Modulate frequency sweep
    sweep = np.sin(2 * np.pi * (120.0 + 80.0 * env) * t) * 0.3
    whoosh = (pink * env * 0.8) + (sweep * env * 0.2)
    save_wav("sfx_flight_high_g_whoosh.wav", whoosh)

def gen_flyby_enemy_doppler():
    """High-speed enemy craft screaming past the camera with Doppler pitch shift."""
    duration = 1.6
    n_samples = int(SAMPLE_RATE * duration)
    t = np.linspace(-1.0, 1.0, n_samples)
    # Distance to camera: sqrt(d_closest^2 + (v*t)^2)
    d_closest = 0.2
    v = 2.0
    dist = np.sqrt(d_closest**2 + (v * t)**2)
    # Volume: 1 / dist
    vol = (1.0 / dist)
    vol = vol / np.max(vol)
    # Doppler frequency: f_obs = f_src / (1 + (v_rel/c))
    v_radial = (v**2 * t) / dist
    freq_shift = 1.0 / (1.0 + 0.35 * v_radial)
    base_freq = 420.0
    phase = np.cumsum(base_freq * freq_shift) / SAMPLE_RATE
    
    # Engine whine + jet rush
    engine_jet = np.sin(2 * np.pi * phase) + 0.5 * np.sin(4 * np.pi * phase)
    noise = np.random.randn(n_samples) * 0.3
    sound = (engine_jet + noise) * vol * 0.8
    save_wav("sfx_flyby_enemy_doppler.wav", sound)

def gen_near_miss_bullet_whiz():
    """Near-miss projectile: Supersonic sonic snap followed by a rapid Doppler whiz."""
    duration = 0.25
    n_samples = int(SAMPLE_RATE * duration)
    t = np.linspace(0, duration, n_samples)
    
    # Initial sonic snap (sharp impulse click)
    snap = np.zeros(n_samples)
    snap[:8] = [0.0, 0.9, -0.85, 0.7, -0.5, 0.3, -0.15, 0.0]
    
    # Descending whiz frequency (3200 Hz down to 700 Hz over 0.2s)
    freq = 3200.0 * np.exp(-t * 8.0)
    phase = np.cumsum(freq) / SAMPLE_RATE
    env = np.exp(-t * 12.0)
    whiz = np.sin(2 * np.pi * phase) * env * 0.75
    
    sound = snap + whiz
    save_wav("sfx_near_miss_bullet_whiz.wav", sound)

# -------------------------------------------------------------
# 3. WEAPONS & IMPACTS
# -------------------------------------------------------------

def gen_weapon_cannon_burst():
    """20mm Rotary Autocannon burst: Multiple rapid kinetic explosive snaps (3 rounds)."""
    duration = 0.35
    n_samples = int(SAMPLE_RATE * duration)
    sound = np.zeros(n_samples)
    
    # 3 shots spaced at 50ms (1200 RPM)
    shot_times = [0.0, 0.05, 0.10]
    for st in shot_times:
        start_idx = int(st * SAMPLE_RATE)
        shot_len = int(0.12 * SAMPLE_RATE)
        t_shot = np.linspace(0, 0.12, shot_len)
        
        # Low punch (80Hz) + explosive crack + mechanical metallic ring
        punch = np.sin(2 * np.pi * 85.0 * t_shot) * np.exp(-t_shot * 35.0)
        crack = np.random.randn(shot_len) * np.exp(-t_shot * 50.0)
        metal = np.sin(2 * np.pi * 1650.0 * t_shot) * np.exp(-t_shot * 40.0) * 0.3
        
        shot = (punch * 0.6 + crack * 0.5 + metal * 0.2)
        end_idx = min(n_samples, start_idx + shot_len)
        sound[start_idx:end_idx] += shot[:end_idx - start_idx]
        
    save_wav("sfx_weapon_cannon_burst.wav", sound)

def gen_weapon_missile_launch():
    """Missile launch: Pneumatic ejector clunk + solid rocket ignition plume."""
    duration = 0.7
    n_samples = int(SAMPLE_RATE * duration)
    t = np.linspace(0, duration, n_samples)
    
    # Ejector thump (60Hz fast thump)
    thump = np.sin(2 * np.pi * 60.0 * t) * np.exp(-t * 20.0) * 0.8
    
    # Rocket plume ignition at 0.08s
    plume_start = int(0.08 * SAMPLE_RATE)
    plume_len = n_samples - plume_start
    t_plume = np.linspace(0, duration - 0.08, plume_len)
    
    # Roaring noise with resonant combustion frequencies (120Hz & 320Hz)
    noise = np.random.randn(plume_len)
    combust = np.sin(2 * np.pi * 140.0 * t_plume) + 0.4 * np.sin(2 * np.pi * 320.0 * t_plume)
    plume_env = (1.0 - np.exp(-t_plume * 15.0)) * np.exp(-t_plume * 3.0)
    plume = (noise * 0.6 + combust * 0.4) * plume_env * 0.75
    
    sound = thump.copy()
    sound[plume_start:] += plume
    save_wav("sfx_weapon_missile_launch.wav", sound)

def gen_impact_shield_hit():
    """Shield deflection: High-frequency electromagnetic shimmer & plasma pop."""
    duration = 0.28
    n_samples = int(SAMPLE_RATE * duration)
    t = np.linspace(0, duration, n_samples)
    
    # High tech plasma pop: FM chirp from 2400Hz to 600Hz
    freq = 2400.0 * np.exp(-t * 14.0) + 400.0
    phase = np.cumsum(freq) / SAMPLE_RATE
    env = np.exp(-t * 12.0)
    shimmer = np.sin(2 * np.pi * phase + np.sin(2 * np.pi * 80.0 * t) * 2.0) * env * 0.85
    save_wav("sfx_impact_shield_hit.wav", shimmer)

# -------------------------------------------------------------
# 4. UI & MENU INTERACTION SFX
# -------------------------------------------------------------

def gen_ui_button_hover():
    """Tactile UI hover: High-tech subtle tick."""
    duration = 0.02
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    sound = np.sin(2 * np.pi * 1800.0 * t) * np.exp(-t * 200.0) * 0.4
    save_wav("sfx_ui_button_hover.wav", sound)

def gen_ui_button_click():
    """Tactile UI click: Crisp dual-frequency confirmation."""
    duration = 0.05
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    sound = (np.sin(2 * np.pi * 1200.0 * t) + np.sin(2 * np.pi * 2400.0 * t) * 0.5) * np.exp(-t * 80.0) * 0.6
    save_wav("sfx_ui_button_click.wav", sound)

def gen_debrief_tally_tick():
    """Tactile score tally tick: Crisp fast mechanical counter chirp."""
    duration = 0.025
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    sound = np.sin(2 * np.pi * 1650.0 * t) * np.exp(-t * 180.0) * 0.5
    save_wav("sfx_debrief_tally_tick.wav", sound)

def gen_debrief_rank_slam():
    """Cinematic rank stamp slam: Heavy sub-bass boom layered with metallic hydraulic impact."""
    duration = 0.55
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    # Sub-bass pitch drop (65 Hz down to 25 Hz)
    f_drop = 65.0 * np.exp(-t * 4.0) + 25.0
    phase = 2 * np.pi * np.cumsum(f_drop) / SAMPLE_RATE
    bass = np.sin(phase) * np.exp(-t * 5.0) * 0.8
    # Metallic clack impact (480 Hz + noise transient)
    clack = np.sin(2 * np.pi * 480.0 * t) * np.exp(-t * 45.0) * 0.6
    noise = np.random.uniform(-1, 1, len(t)) * np.exp(-t * 70.0) * 0.4
    sound = bass + clack + noise
    save_wav("sfx_debrief_rank_slam.wav", sound)

# -------------------------------------------------------------
# 5. CHAPTER 2 SPACE & CAPITAL FLEET COMBAT SFX
# -------------------------------------------------------------

def gen_torpedo_alarm_loop():
    """Urgent heavy anti-ship torpedo klaxon (Dual sawtooth alert at 380 Hz / 520 Hz)."""
    duration = 0.4
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    tone = (np.sin(2 * np.pi * 380.0 * t) * 0.6 + np.sin(2 * np.pi * 520.0 * t) * 0.4)
    # Warble pulse
    env = 0.5 + 0.5 * np.sin(2 * np.pi * 8.0 * t)
    sound = tone * env * 0.8
    save_wav("sfx_torpedo_alarm_loop.wav", sound)

def gen_asteroid_scrape_impact():
    """Metallic rock scrape & hull friction transient."""
    duration = 0.65
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    noise = np.random.uniform(-1, 1, len(t))
    # Filter noise to simulate grinding rock
    grind = noise * np.exp(-t * 3.5) * (0.6 + 0.4 * np.sin(2 * np.pi * 35.0 * t))
    boom = np.sin(2 * np.pi * 75.0 * t) * np.exp(-t * 6.0) * 0.7
    sound = grind * 0.6 + boom * 0.5
    save_wav("sfx_asteroid_scrape_impact.wav", sound)

def gen_laser_sentry_beam():
    """High-voltage industrial laser beam pulse (Sweep from 2400 Hz down to 600 Hz)."""
    duration = 0.35
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    f = 2400.0 * np.exp(-t * 8.0) + 600.0
    phase = 2 * np.pi * np.cumsum(f) / SAMPLE_RATE
    laser = np.sin(phase) * np.exp(-t * 5.0) * 0.7
    noise = np.random.uniform(-1, 1, len(t)) * np.exp(-t * 12.0) * 0.3
    sound = laser + noise
    save_wav("sfx_laser_sentry_beam.wav", sound)

def gen_capital_ship_core_explosion():
    """Massive capital dreadnought core detonation: Sub-bass rumble and cascading blast waves."""
    duration = 1.4
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    f_sub = 45.0 * np.exp(-t * 1.5) + 18.0
    phase = 2 * np.pi * np.cumsum(f_sub) / SAMPLE_RATE
    sub_bass = np.sin(phase) * np.exp(-t * 2.2) * 0.85
    # Heavy distorted rumble
    noise = np.random.uniform(-1, 1, len(t)) * np.exp(-t * 2.8) * 0.55
    # Secondary echo burst at t=0.4s
    secondary = np.zeros_like(t)
    sec_idx = int(0.4 * SAMPLE_RATE)
    if sec_idx < len(t):
        sec_t = t[sec_idx:] - 0.4
        secondary[sec_idx:] = np.sin(2 * np.pi * 55.0 * sec_t) * np.exp(-sec_t * 4.0) * 0.5
    sound = sub_bass + noise + secondary
    save_wav("sfx_capital_ship_core_explosion.wav", sound)

if __name__ == "__main__":
    print("Synthesizing Project Vanguard Sound Effects Suite...")
    gen_hud_target_locking()
    gen_hud_target_locked()
    gen_hud_missile_incoming_spike()
    gen_hud_stall_warning()
    gen_hud_capacitor_empty()
    gen_flight_high_g_whoosh()
    gen_flyby_enemy_doppler()
    gen_near_miss_bullet_whiz()
    gen_weapon_cannon_burst()
    gen_weapon_missile_launch()
    gen_impact_shield_hit()
    gen_ui_button_hover()
    gen_ui_button_click()
    gen_debrief_tally_tick()
    gen_debrief_rank_slam()
    gen_torpedo_alarm_loop()
    gen_asteroid_scrape_impact()
    gen_laser_sentry_beam()
    gen_capital_ship_core_explosion()
    print("All SFX generated successfully.")
