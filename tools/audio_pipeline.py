#!/usr/bin/env python3
"""
===============================================================================
PROJECT VANGUARD: AUDIO PIPELINE & DSP SOUND ENGINEERING SUITE
===============================================================================
Lead Audio Director & DSP Sound Engineer: Automated Audio Pipeline
Platform: Godot 4 Space Combat Flight Simulator
License: MIT / Sol Directorate Internal
Cost: $0.00 External Cloud / 100% Local Automated Execution

Subcommands:
    python tools/audio_pipeline.py generate-sfx
        Procedurally synthesizes all 44.1kHz 16-bit PCM WAV assets using
        mathematical acoustic modeling, zero DC-offset correction, peak
        normalization (-1.0 dBFS), and zero-crossing loop seams.
        Generates corresponding Godot 4 .import files.

    python tools/audio_pipeline.py generate-voices [--skip-existing]
        Synthesizes all campaign comms and narrative interludes using edge-tts
        and applies character-specific diegetic DSP radio filters via ffmpeg:
        - AWACS Christopher: 300Hz-3.5kHz bandpass, military squelch, compressor
        - Cockpit AI Aegis-7: Pristine synthetic stereo voice, crisp high-end EQ
        - Wingman Miller: Tactical cockpit radio filter with slight overdrive
        - Carrier Captain Ross: Command deck echo/reverb, authoritative warmth
        - Boss Warlord Vane: Heavy adversary broadcast saturation and flanger
        - Narrator Brian: Cinematic 21:9 warm documentary broadcast delivery

    python tools/audio_pipeline.py audit
        Comprehensive verification checking that all audio assets referenced
        across campaign manifests, mission scripts, cutscenes, and avionics
        exist, have valid sample rates, and have valid Godot .import files.
===============================================================================
"""

import os
import sys
import math
import wave
import json
import struct
import shutil
import asyncio
import subprocess
import argparse
import numpy as np

try:
    import scipy.io.wavfile as wavfile
    HAVE_SCIPY = True
except ImportError:
    HAVE_SCIPY = False

try:
    import edge_tts
    HAVE_EDGE_TTS = True
except ImportError:
    HAVE_EDGE_TTS = False

SAMPLE_RATE = 44100
WORKSPACE_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SFX_OUTPUT_DIR = os.path.join(WORKSPACE_ROOT, "godot_project", "audio", "sfx")
SFX_DOCS_DIR = os.path.join(WORKSPACE_ROOT, "docs", "lore", "audio", "sfx")
COMMS_OUTPUT_DIR = os.path.join(WORKSPACE_ROOT, "godot_project", "audio", "comms")
COMMS_DOCS_DIR = os.path.join(WORKSPACE_ROOT, "docs", "lore", "audio", "comms")
NARRATOR_OUTPUT_DIR = os.path.join(WORKSPACE_ROOT, "godot_project", "audio", "narrator")
NARRATOR_DOCS_DIR = os.path.join(WORKSPACE_ROOT, "docs", "lore", "audio", "narrator")

LOOPING_SFX = {
    "sfx_torpedo_alarm_loop.wav",
    "sfx_autocannon_brr_loop.wav"
}

# -----------------------------------------------------------------------------
# CORE DSP & WAV HELPER FUNCTIONS
# -----------------------------------------------------------------------------

def normalize_and_clamp(samples: np.ndarray, target_peak_db: float = -1.0) -> np.ndarray:
    """Removes DC bias and scales peak amplitude to target_peak_db (default -1.0 dBFS)."""
    # Remove DC offset
    samples = samples - np.mean(samples)
    peak = np.max(np.abs(samples))
    if peak > 1e-6:
        target_amplitude = 10.0 ** (target_peak_db / 20.0)
        samples = samples * (target_amplitude / peak)
    return np.clip(samples, -0.999, 0.999)


def apply_loop_crossfade(samples: np.ndarray, crossfade_samples: int = 256) -> np.ndarray:
    """Applies a smooth micro-crossfade between the start and end of a looping audio buffer
    to guarantee zero click/pop at loop seams."""
    if len(samples) <= crossfade_samples * 2:
        return samples
    out = samples.copy()
    fade_in = np.linspace(0.0, 1.0, crossfade_samples)
    fade_out = np.linspace(1.0, 0.0, crossfade_samples)
    # Blend end into start and start into end
    tail = out[-crossfade_samples:]
    head = out[:crossfade_samples]
    out[:crossfade_samples] = head * fade_in + tail * fade_out
    out[-crossfade_samples:] = tail * fade_in + head * fade_out
    return out


def save_sfx_wav(filename: str, samples: np.ndarray, is_loop: bool = False):
    """Normalizes and saves a 44.1kHz 16-bit mono WAV file, syncing to game and docs."""
    samples = normalize_and_clamp(samples)
    if is_loop:
        samples = apply_loop_crossfade(samples, crossfade_samples=512)

    os.makedirs(SFX_OUTPUT_DIR, exist_ok=True)
    os.makedirs(SFX_DOCS_DIR, exist_ok=True)

    int_samples = (samples * 32767.0).astype(np.int16)

    for target_dir in [SFX_OUTPUT_DIR, SFX_DOCS_DIR]:
        path = os.path.join(target_dir, filename)
        if HAVE_SCIPY:
            wavfile.write(path, SAMPLE_RATE, int_samples)
        else:
            with wave.open(path, 'wb') as wf:
                wf.setnchannels(1)
                wf.setsampwidth(2)
                wf.setframerate(SAMPLE_RATE)
                wf.writeframes(int_samples.tobytes())

    # Generate or update Godot .import file
    generate_godot_wav_import(filename, is_loop=is_loop)
    print(f"  [SFX] Generated: {filename} (Loop={is_loop})")


def generate_godot_wav_import(filename: str, is_loop: bool = False):
    """Generates or updates the corresponding Godot 4 .import descriptor with appropriate loop flags."""
    import_path = os.path.join(SFX_OUTPUT_DIR, f"{filename}.import")
    loop_mode = 1 if is_loop else 0

    if os.path.exists(import_path):
        # Update existing import file preserving uid and cache path
        with open(import_path, "r", encoding="utf-8") as f:
            lines = f.readlines()
        new_lines = []
        has_loop_param = False
        for line in lines:
            if line.startswith("edit/loop_mode="):
                new_lines.append(f"edit/loop_mode={loop_mode}\n")
                has_loop_param = True
            else:
                new_lines.append(line)
        if not has_loop_param:
            new_lines.append(f"edit/loop_mode={loop_mode}\n")
        with open(import_path, "w", encoding="utf-8") as f:
            f.writelines(new_lines)
        return

    content = f"""[remap]

importer="wav"
type="AudioStreamWAV"
uid="uid://{abs(hash(filename)):012x}"
path="res://.godot/imported/{filename}-{abs(hash(filename)):032x}.sample"

[deps]

source_file="res://audio/sfx/{filename}"
dest_files=["res://.godot/imported/{filename}-{abs(hash(filename)):032x}.sample"]

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode={loop_mode}
edit/loop_begin=0
edit/loop_end=-1
compress/mode=0
"""
    with open(import_path, "w", encoding="utf-8") as f:
        f.write(content)


def generate_godot_mp3_import(folder_res: str, folder_fs: str, filename: str):
    """Generates Godot 4 .import file for MP3 voice and narration tracks if not already present."""
    import_path = os.path.join(folder_fs, f"{filename}.import")
    if os.path.exists(import_path):
        return  # Preserve engine-generated cache bindings

    content = f"""[remap]

importer="mp3"
type="AudioStreamMP3"
uid="uid://{abs(hash(filename)):012x}"
path="res://.godot/imported/{filename}-{abs(hash(filename)):032x}.mp3str"

[deps]

source_file="res://{folder_res}/{filename}"
dest_files=["res://.godot/imported/{filename}-{abs(hash(filename)):032x}.mp3str"]

[params]

loop=false
loop_offset=0
bpm=0
beat_count=0
bar_beats=4
"""
    with open(import_path, "w", encoding="utf-8") as f:
        f.write(content)



# -----------------------------------------------------------------------------
# 1. PROCEDURAL SFX GENERATION METHODS
# -----------------------------------------------------------------------------

def gen_hud_target_locking():
    """Pulsed 800Hz beep ramping to steady tone when acquiring missile lock."""
    duration = 0.09
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    # 800 Hz pure sine with sharp attack and fast exponential decay
    freq = 800.0 + (40.0 * (t / duration))
    phase = 2 * np.pi * np.cumsum(freq) / SAMPLE_RATE
    env = np.exp(-t * 32.0)
    sound = np.sin(phase) * env
    save_sfx_wav("sfx_hud_target_locking.wav", sound, is_loop=False)


def gen_hud_target_locked():
    """Continuous high-pitch solid lock tone with military urgency (1320 Hz + 1760 Hz harmonic with 16 Hz warble)."""
    duration = 0.45
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    tremolo = 0.82 + 0.18 * np.sin(2 * np.pi * 16.0 * t)
    env = np.ones_like(t)
    fade_len = int(SAMPLE_RATE * 0.02)
    env[:fade_len] = np.linspace(0.0, 1.0, fade_len)
    env[-fade_len:] = np.linspace(1.0, 0.0, fade_len)
    tone = (0.7 * np.sin(2 * np.pi * 1320.0 * t) + 0.3 * np.sin(2 * np.pi * 1760.0 * t)) * env * tremolo
    save_sfx_wav("sfx_hud_target_locked.wav", tone, is_loop=False)


def gen_hud_missile_incoming_spike():
    """RWR spike alarm: Urgent alternating 1200Hz/1600Hz warble with soft-clipping grit."""
    duration = 0.6
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    mod = np.sign(np.sin(2 * np.pi * 14.0 * t))
    freq = np.where(mod > 0, 1200.0, 1600.0)
    phase = 2 * np.pi * np.cumsum(freq) / SAMPLE_RATE
    raw_alarm = np.sin(phase)
    # Speaker saturation grit
    grit = np.tanh(raw_alarm * 2.4) * 0.85
    save_sfx_wav("sfx_hud_missile_incoming_spike.wav", grit, is_loop=False)


def gen_hud_stall_warning():
    """Aerodynamic stall warning: 240 Hz sawtooth with pulse modulation."""
    duration = 0.5
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    burst = (np.sin(2 * np.pi * 4.0 * t) > 0.0).astype(float)
    saw = 2.0 * (t * 240.0 - np.floor(t * 240.0 + 0.5))
    tone = saw * burst * 0.75
    save_sfx_wav("sfx_hud_stall_warning.wav", tone, is_loop=False)


def gen_hud_low_altitude():
    """Low altitude warning chime: Dual urgent descending electronic chime (960 Hz -> 640 Hz)."""
    duration = 0.38
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    half = len(t) // 2
    chime1 = np.sin(2 * np.pi * 960.0 * t[:half]) * np.exp(-t[:half] * 18.0)
    chime2 = np.sin(2 * np.pi * 640.0 * t[half:]) * np.exp(-t[:len(t)-half] * 18.0)
    sound = np.concatenate([chime1, chime2])
    save_sfx_wav("sfx_hud_low_altitude.wav", sound, is_loop=False)


def gen_hud_capacitor_empty():
    """Capacitor empty buzz & descending electronic sweep (900 Hz down to 180 Hz)."""
    duration = 0.32
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    freq = 900.0 * np.exp(-t * 5.5) + 160.0
    phase = 2 * np.pi * np.cumsum(freq) / SAMPLE_RATE
    buzz = np.sin(phase) + 0.3 * np.sign(np.sin(2 * np.pi * 120.0 * t))
    env = np.linspace(1.0, 0.0, len(t))
    sound = buzz * env
    save_sfx_wav("sfx_hud_capacitor_empty.wav", sound, is_loop=False)


def gen_torpedo_alarm_loop():
    """Heavy anti-ship torpedo klaxon loop (deep sub-bass oscillating siren at 380Hz / 520Hz)."""
    duration = 0.5
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    f_carrier = 380.0 + 140.0 * (0.5 + 0.5 * np.sin(2 * np.pi * 4.0 * t))
    phase = 2 * np.pi * np.cumsum(f_carrier) / SAMPLE_RATE
    sub_bass = np.sin(2 * np.pi * 70.0 * t) * 0.4
    siren = np.sin(phase) * 0.7 + sub_bass
    save_sfx_wav("sfx_torpedo_alarm_loop.wav", siren, is_loop=True)


def gen_flight_high_g_whoosh():
    """High-G turn aerodynamic whoosh (wind envelope with sub-bass rumble)."""
    duration = 1.3
    n_samples = int(SAMPLE_RATE * duration)
    t = np.linspace(0, duration, n_samples)
    # Bandpass filtered pink noise
    white = np.random.randn(n_samples)
    pink = np.cumsum(white) * 0.02
    env = (np.sin(np.pi * (t / duration))) ** 2
    sub_rumble = np.sin(2 * np.pi * (55.0 + 35.0 * env) * t) * 0.45
    sound = (pink * env * 0.8) + (sub_rumble * env * 0.4)
    save_sfx_wav("sfx_flight_high_g_whoosh.wav", sound, is_loop=False)


def gen_flyby_enemy_doppler():
    """Enemy fighter flyby Doppler effect (high-pitch sweep down)."""
    duration = 1.6
    n_samples = int(SAMPLE_RATE * duration)
    t = np.linspace(-1.0, 1.0, n_samples)
    d_closest = 0.22
    v = 2.2
    dist = np.sqrt(d_closest**2 + (v * t)**2)
    vol = (1.0 / dist)
    vol = vol / np.max(vol)
    v_radial = (v**2 * t) / dist
    freq_shift = 1.0 / (1.0 + 0.38 * v_radial)
    base_freq = 460.0
    phase = 2 * np.pi * np.cumsum(base_freq * freq_shift) / SAMPLE_RATE
    turbine = np.sin(phase) + 0.4 * np.sin(2 * phase)
    rush = np.random.randn(n_samples) * 0.35
    sound = (turbine + rush) * vol
    save_sfx_wav("sfx_flyby_enemy_doppler.wav", sound, is_loop=False)


def gen_weapon_cannon_burst():
    """Autocannon 20mm rotary burst (sharp mechanical transient + punchy low-end crack)."""
    duration = 0.36
    n_samples = int(SAMPLE_RATE * duration)
    sound = np.zeros(n_samples)
    shot_times = [0.0, 0.05, 0.10]
    for st in shot_times:
        start_idx = int(st * SAMPLE_RATE)
        shot_len = int(0.12 * SAMPLE_RATE)
        t_shot = np.linspace(0, 0.12, shot_len)
        punch = np.sin(2 * np.pi * 85.0 * t_shot) * np.exp(-t_shot * 35.0)
        crack = np.random.randn(shot_len) * np.exp(-t_shot * 55.0)
        metal = np.sin(2 * np.pi * 1650.0 * t_shot) * np.exp(-t_shot * 40.0) * 0.25
        shot = punch * 0.65 + crack * 0.55 + metal * 0.2
        end_idx = min(n_samples, start_idx + shot_len)
        sound[start_idx:end_idx] += shot[:end_idx - start_idx]
    save_sfx_wav("sfx_weapon_cannon_burst.wav", sound, is_loop=False)


def gen_autocannon_brr_loop():
    """Autocannon continuous rotary loop (1200 RPM report, seamless zero-crossing loop)."""
    # Exact periodicity: 1200 RPM = 20 shots/sec = 50ms period.
    # We construct 4 full periods = 200ms = 8820 samples for perfectly seamless looping.
    period_samples = int(SAMPLE_RATE / 20.0) # 2205 samples
    periods = 4
    total_samples = period_samples * periods
    sound = np.zeros(total_samples)

    for p in range(periods):
        idx = p * period_samples
        t = np.linspace(0, 0.05, period_samples, False)
        punch = np.sin(2 * np.pi * 90.0 * t) * np.exp(-t * 40.0)
        crack = np.random.randn(period_samples) * np.exp(-t * 60.0)
        clack = np.sin(2 * np.pi * 1720.0 * t) * np.exp(-t * 50.0) * 0.3
        sound[idx:idx + period_samples] = punch * 0.7 + crack * 0.5 + clack * 0.2

    save_sfx_wav("sfx_autocannon_brr_loop.wav", sound, is_loop=True)


def gen_autocannon_shot():
    """Single autocannon shot."""
    duration = 0.10
    n_samples = int(SAMPLE_RATE * duration)
    t = np.linspace(0, duration, n_samples)
    punch = np.sin(2 * np.pi * 92.0 * t) * np.exp(-t * 45.0)
    crack = np.random.randn(n_samples) * np.exp(-t * 65.0)
    metal = np.sin(2 * np.pi * 1800.0 * t) * np.exp(-t * 50.0) * 0.25
    sound = punch * 0.7 + crack * 0.6 + metal * 0.25
    save_sfx_wav("sfx_autocannon_shot.wav", sound, is_loop=False)


def gen_autocannon_winddown():
    """Autocannon rotor deceleration clack."""
    duration = 0.22
    n_samples = int(SAMPLE_RATE * duration)
    t = np.linspace(0, duration, n_samples)
    freq = 600.0 * np.exp(-t * 12.0) + 80.0
    phase = 2 * np.pi * np.cumsum(freq) / SAMPLE_RATE
    clack = np.sin(phase) * np.exp(-t * 15.0)
    save_sfx_wav("sfx_autocannon_winddown.wav", clack, is_loop=False)


def gen_weapon_missile_launch():
    """Missile launch: Pneumatic ejector clunk + solid rocket ignition plume."""
    duration = 0.75
    n_samples = int(SAMPLE_RATE * duration)
    t = np.linspace(0, duration, n_samples)
    thump = np.sin(2 * np.pi * 60.0 * t) * np.exp(-t * 22.0) * 0.8
    plume_start = int(0.08 * SAMPLE_RATE)
    plume_len = n_samples - plume_start
    t_plume = np.linspace(0, duration - 0.08, plume_len)
    noise = np.random.randn(plume_len)
    combust = np.sin(2 * np.pi * 140.0 * t_plume) + 0.4 * np.sin(2 * np.pi * 320.0 * t_plume)
    plume_env = (1.0 - np.exp(-t_plume * 15.0)) * np.exp(-t_plume * 3.2)
    plume = (noise * 0.65 + combust * 0.35) * plume_env
    sound = thump.copy()
    sound[plume_start:] += plume
    save_sfx_wav("sfx_weapon_missile_launch.wav", sound, is_loop=False)


def gen_impact_shield_hit():
    """Shield deflection: High-frequency electromagnetic shimmer & plasma pop."""
    duration = 0.28
    n_samples = int(SAMPLE_RATE * duration)
    t = np.linspace(0, duration, n_samples)
    freq = 2400.0 * np.exp(-t * 14.0) + 400.0
    phase = 2 * np.pi * np.cumsum(freq) / SAMPLE_RATE
    env = np.exp(-t * 12.0)
    shimmer = np.sin(phase + np.sin(2 * np.pi * 80.0 * t) * 2.2) * env
    save_sfx_wav("sfx_impact_shield_hit.wav", shimmer, is_loop=False)


def gen_laser_sentry_beam():
    """Synthesized high-frequency plasma discharge pulse (sweep from 2400Hz to 600Hz)."""
    duration = 0.35
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    f = 2400.0 * np.exp(-t * 8.0) + 600.0
    phase = 2 * np.pi * np.cumsum(f) / SAMPLE_RATE
    laser = np.sin(phase) * np.exp(-t * 5.5) * 0.75
    noise = np.random.uniform(-1, 1, len(t)) * np.exp(-t * 12.0) * 0.25
    sound = laser + noise
    save_sfx_wav("sfx_laser_sentry_beam.wav", sound, is_loop=False)


def gen_near_miss_bullet_whiz():
    """Proximity bullet whiz / near-miss crackle."""
    duration = 0.25
    n_samples = int(SAMPLE_RATE * duration)
    t = np.linspace(0, duration, n_samples)
    snap = np.zeros(n_samples)
    snap[:8] = [0.0, 0.95, -0.9, 0.75, -0.5, 0.3, -0.15, 0.0]
    freq = 3400.0 * np.exp(-t * 8.5)
    phase = 2 * np.pi * np.cumsum(freq) / SAMPLE_RATE
    env = np.exp(-t * 13.0)
    whiz = np.sin(phase) * env * 0.8
    crackle = np.random.randn(n_samples) * np.exp(-t * 25.0) * 0.25
    sound = snap + whiz + crackle
    save_sfx_wav("sfx_near_miss_bullet_whiz.wav", sound, is_loop=False)


def gen_asteroid_scrape_impact():
    """Asteroid metal-scrape collision impact & hull friction transient."""
    duration = 0.65
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    noise = np.random.uniform(-1, 1, len(t))
    grind = noise * np.exp(-t * 3.5) * (0.6 + 0.4 * np.sin(2 * np.pi * 35.0 * t))
    boom = np.sin(2 * np.pi * 75.0 * t) * np.exp(-t * 6.0) * 0.75
    sound = grind * 0.65 + boom * 0.55
    save_sfx_wav("sfx_asteroid_scrape_impact.wav", sound, is_loop=False)


def gen_capital_ship_core_explosion():
    """Massive capital dreadnought core detonation & implosion rumble."""
    duration = 1.45
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    # Pre-detonation implosion dip at t=0.0 to 0.15s
    implosion_phase = np.where(t < 0.15, np.sin(2 * np.pi * 300.0 * (0.15 - t)**2), 0.0)
    f_sub = 45.0 * np.exp(-t * 1.5) + 18.0
    phase = 2 * np.pi * np.cumsum(f_sub) / SAMPLE_RATE
    sub_bass = np.sin(phase) * np.exp(-t * 2.0) * 0.85
    noise = np.random.uniform(-1, 1, len(t)) * np.exp(-t * 2.5) * 0.55
    secondary = np.zeros_like(t)
    sec_idx = int(0.38 * SAMPLE_RATE)
    if sec_idx < len(t):
        sec_t = t[sec_idx:] - 0.38
        secondary[sec_idx:] = np.sin(2 * np.pi * 55.0 * sec_t) * np.exp(-sec_t * 3.8) * 0.5
    sound = sub_bass + noise + secondary + implosion_phase * 0.4
    save_sfx_wav("sfx_capital_ship_core_explosion.wav", sound, is_loop=False)


def gen_ui_button_hover():
    """Tactile UI hover: High-tech subtle tick (1800 Hz)."""
    duration = 0.02
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    sound = np.sin(2 * np.pi * 1800.0 * t) * np.exp(-t * 200.0) * 0.6
    save_sfx_wav("sfx_ui_button_hover.wav", sound, is_loop=False)


def gen_ui_button_click():
    """Tactile UI click: Crisp dual-frequency confirmation (1200 Hz + 2400 Hz)."""
    duration = 0.05
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    sound = (np.sin(2 * np.pi * 1200.0 * t) + np.sin(2 * np.pi * 2400.0 * t) * 0.5) * np.exp(-t * 85.0)
    save_sfx_wav("sfx_ui_button_click.wav", sound, is_loop=False)


def gen_debrief_tally_tick():
    """Tactile score tally tick: Fast mechanical counter chirp (1650 Hz)."""
    duration = 0.025
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    sound = np.sin(2 * np.pi * 1650.0 * t) * np.exp(-t * 180.0) * 0.7
    save_sfx_wav("sfx_debrief_tally_tick.wav", sound, is_loop=False)


def gen_debrief_rank_slam():
    """Cinematic rank stamp slam: Heavy sub-bass boom layered with metallic hydraulic impact."""
    duration = 0.55
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    f_drop = 65.0 * np.exp(-t * 4.0) + 25.0
    phase = 2 * np.pi * np.cumsum(f_drop) / SAMPLE_RATE
    bass = np.sin(phase) * np.exp(-t * 5.0) * 0.85
    clack = np.sin(2 * np.pi * 480.0 * t) * np.exp(-t * 45.0) * 0.65
    noise = np.random.uniform(-1, 1, len(t)) * np.exp(-t * 70.0) * 0.4
    sound = bass + clack + noise
    save_sfx_wav("sfx_debrief_rank_slam.wav", sound, is_loop=False)


def generate_all_sfx():
    """Synthesizes the complete procedural SFX library."""
    print("=== [AUDIO PIPELINE] GENERATING PROCEDURAL SFX LIBRARY (44.1kHz / 16-bit WAV) ===")
    gen_hud_target_locking()
    gen_hud_target_locked()
    gen_hud_missile_incoming_spike()
    gen_hud_stall_warning()
    gen_hud_low_altitude()
    gen_hud_capacitor_empty()
    gen_torpedo_alarm_loop()
    gen_flight_high_g_whoosh()
    gen_flyby_enemy_doppler()
    gen_weapon_cannon_burst()
    gen_autocannon_brr_loop()
    gen_autocannon_shot()
    gen_autocannon_winddown()
    gen_weapon_missile_launch()
    gen_impact_shield_hit()
    gen_laser_sentry_beam()
    gen_near_miss_bullet_whiz()
    gen_asteroid_scrape_impact()
    gen_capital_ship_core_explosion()
    gen_ui_button_hover()
    gen_ui_button_click()
    gen_debrief_tally_tick()
    gen_debrief_rank_slam()
    print("=== [AUDIO PIPELINE] ALL SFX GENERATED & IMPORT DESCRIPTORS CREATED ===")


# -----------------------------------------------------------------------------
# 2. DIEGETIC VOCAL SYNTHESIS & RADIO DSP PROCESSING
# -----------------------------------------------------------------------------

# Character Definitions & DSP Configurations
CHARACTER_PROFILES = {
    "apex_command": {
        "voice": "en-US-ChristopherNeural",
        "pitch": "-2Hz",
        "rate": "+2%",
        # Military air traffic radio filter: bandpass 300Hz-3.5kHz + squelch/compressor
        "dsp_filter": "highpass=f=300,lowpass=f=3500,volume=1.25,acompressor=threshold=-18dB:ratio=4:attack=5:release=50"
    },
    "aegis_ai": {
        "voice": "en-GB-SoniaNeural",
        "pitch": "+0Hz",
        "rate": "+1%",
        # Pristine stereo synthetic voice with crisp high-end clarity
        "dsp_filter": "treble=g=2:f=6000,volume=1.05"
    },
    "wingman_miller": {
        "voice": "en-US-GuyNeural",
        "pitch": "+1Hz",
        "rate": "+3%",
        # Energetic wingman cockpit radio
        "dsp_filter": "highpass=f=350,lowpass=f=4000,volume=1.15,acompressor=threshold=-16dB:ratio=3.5:attack=5:release=50"
    },
    "olympus_captain": {
        "voice": "en-US-AndrewNeural",
        "pitch": "-2Hz",
        "rate": "+2%",
        # Authoritative command deck echo & PA resonance
        "dsp_filter": "highpass=f=220,lowpass=f=4800,aecho=0.8:0.6:35:0.25,volume=1.2"
    },
    "ghost_boss": {
        "voice": "en-US-EricNeural",
        "pitch": "-4Hz",
        "rate": "-1%",
        # Aggressive adversary broadcaster with overdrive and harsh compression
        "dsp_filter": "highpass=f=180,lowpass=f=4200,volume=1.35,acompressor=threshold=-14dB:ratio=5:attack=3:release=40"
    },
    "narrator": {
        "voice": "en-US-BrianNeural",
        "pitch": "-3Hz",
        "rate": "-4%",
        # Warm 21:9 cinematic documentary delivery with subtle warmth EQ and compression
        "dsp_filter": "bass=g=2:f=110,treble=g=1:f=7500,acompressor=threshold=-15dB:ratio=2.5:attack=10:release=100,volume=1.1"
    }
}

COMMS_SCRIPT = [
    # Mission 1
    {"filename": "m01_apex_scramble.mp3", "char": "apex_command", "text": "Vanguard 1, Apex Command on secure freq. Catapult pressure nominal. You are cleared for hot scramble. Cloud deck begins at two-thousand meters. Bogey vectors uploaded to your compass ribbon."},
    {"filename": "m01_aegis_launch.mp3", "char": "aegis_ai", "text": "Catapult release in three... two... one. Main thrusters engaged. Flight telemetry online."},
    {"filename": "m01_aegis_contact.mp3", "char": "aegis_ai", "text": "Radar contact. Four hostile signatures on three-fifty meter disc. Bearing zero-four-five."},
    {"filename": "m01_apex_weapons_free.mp3", "char": "apex_command", "text": "Hostiles confirmed autonomous Marauder drones. Weapons free, Vanguard 1. Show them the envelope belongs to the Directorate."},
    {"filename": "m01_aegis_lock_confirmed.mp3", "char": "aegis_ai", "text": "Target tracked. Solid lock confirmed on Station Two."},
    {"filename": "m01_apex_mission_complete.mp3", "char": "apex_command", "text": "Good splashes, Vanguard 1. All four signatures purged from the grid. Form up and RTB. Maintenance crews are prepping your ordnance for the next sortie."},
    # Mission 2
    {"filename": "m02_apex_briefing.mp3", "char": "apex_command", "text": "Vanguard 1, you are dropping into the Red Sinks. Keep your belly to the rock under 120 meters. If you pop above the rim, Helion radar will light you up in seconds."},
    {"filename": "m02_aegis_terrain.mp3", "char": "aegis_ai", "text": "Terrain proximity active. Scanning canyon floor for jamming repeaters."},
    {"filename": "m02_aegis_altitude_warning.mp3", "char": "aegis_ai", "text": "CAUTION: Altitude exceeding 120 meters. Enemy tracking radar detected. Dive immediately!"},
    {"filename": "m02_apex_relays_down.mp3", "char": "apex_command", "text": "Relay Alpha destroyed! Telemetry static clearing up. Keep hunting, Vanguard."},
    {"filename": "m02_apex_victory.mp3", "char": "apex_command", "text": "All jamming relays eliminated. Early-warning radar grid restored across the Red Sinks. Great flying, Ace."},
    # Mission 3
    {"filename": "m03_viper_wingman.mp3", "char": "wingman_miller", "text": "Miller on your wing, Vanguard 1. Look at that bird... Olympus-4 is charging capacitors. Let's make sure she makes orbit."},
    {"filename": "m03_apex_swarm_warning.mp3", "char": "apex_command", "text": "Threat grid lit up like a Christmas tree! Wave one incoming bearing one-eight-zero, angels four. Intercept!"},
    {"filename": "m03_olympus_under_fire.mp3", "char": "olympus_captain", "text": "Vanguard Flight, we are taking kinetic hits on starboard shields! Get these gnats off us!"},
    {"filename": "m03_apex_wave_cleared.mp3", "char": "apex_command", "text": "Wave eliminated! But sensors detect heavy dive bombers approaching from the east. Form up on the transport!"},
    {"filename": "m03_olympus_liftoff.mp3", "char": "olympus_captain", "text": "Main rocket ignition confirmed! Passing Mach 5 and climbing through fifty thousand feet. Thanks for the escort, Vanguard!"},
    # Mission 4
    {"filename": "m04_apex_vacuum_entry.mp3", "char": "apex_command", "text": "Vanguard 1, crossing forty thousand meters. Skies are turning black. Aerodynamic control surfaces decaying—you are on vectoring thrusters now."},
    {"filename": "m04_aegis_thin_air.mp3", "char": "aegis_ai", "text": "Atmospheric pressure minimal. Lift coefficient reduced eighty-five percent. Stall warning threshold adjusted to forty-five meters per second."},
    {"filename": "m04_ghost_challenge.mp3", "char": "ghost_boss", "text": "So the Directorate sent their prized pilot to freeze in the vacuum. Let's see how your precious V-hull handles true zero-G!"},
    {"filename": "m04_aegis_target_rupture.mp3", "char": "aegis_ai", "text": "Catastrophic core rupture on target. Threat destroyed."},
    {"filename": "m04_apex_ace_victory.mp3", "char": "apex_command", "text": "Combine Ghost is down! The entire drone network is offline across the hemisphere. Outstanding work, Vanguard 1... You saved Ascension!"},
    # Mission 5
    {"filename": "m05_apex_carrier_launch.mp3", "char": "apex_command", "text": "Vanguard 1, Apex Command. You are clear of the Dauntless hangar bay. Atmospheric seals disengaged—welcome to hard vacuum. Watch your RCS thrusters among those rocks."},
    {"filename": "m05_aegis_vacuum_online.mp3", "char": "aegis_ai", "text": "Orbital vacuum confirmed. Aerodynamic stall envelope disengaged. Inertial drift compensators online."},
    {"filename": "m05_miller_tether_warning.mp3", "char": "wingman_miller", "text": "Look at this junk field, Lead. The Combine seeded the rim with magnetic tether-mines. One wrong move and they'll clamp right onto your hull."},
    {"filename": "m05_aegis_mine_cleared.mp3", "char": "aegis_ai", "text": "Mine cluster eliminated. Proximity grid sector alpha clear."},
    {"filename": "m05_apex_stealth_warning.mp3", "char": "apex_command", "text": "Careful, Vanguard. Sensor signatures popping up on the radar disc—they're using the asteroid shadows to cloak!"},
    {"filename": "m05_miller_perimeter_clear.mp3", "char": "wingman_miller", "text": "Splash two! You got the others, Lead! Perimeter corridor is clean."},
    {"filename": "m05_apex_foundry_coords.mp3", "char": "apex_command", "text": "Good hunting, Vanguard Flight. Telemetry decoders just pulled coordinates to their internal foundry. Prep for cavern infiltration."},
    # Mission 6
    {"filename": "m06_apex_enter_cavern.mp3", "char": "apex_command", "text": "Vanguard 1, telemetry is degrading as you enter the rock. You're entering the Iron Hollow. Keep your nose steady—clearance in that trench is less than one-hundred-fifty meters."},
    {"filename": "m06_aegis_laser_warning.mp3", "char": "aegis_ai", "text": "Warning: Multiple automated laser cutting arrays active along cavern bulkheads. Recommend immediate evasive maneuvers."},
    {"filename": "m06_apex_generators_status.mp3", "char": "apex_command", "text": "Generator Alpha down! Two remaining! Keep moving, the facility is switching auxiliary power to automated sentry turrets!"},
    {"filename": "m06_aegis_core_destabilizing.mp3", "char": "aegis_ai", "text": "All three generators neutralized. Geothermal core destabilizing. Catastrophic thermal blowout in forty seconds."},
    {"filename": "m06_apex_afterburners_escape.mp3", "char": "apex_command", "text": "Hit full afterburners, Vanguard 1! Get out of that rock before the shaft collapses!"},
    {"filename": "m06_miller_exit_visual.mp3", "char": "wingman_miller", "text": "Punch it, Lead! I see your exhaust plume breaking through the exit fissure!"},
    # Mission 7
    {"filename": "m07_ross_general_quarters.mp3", "char": "olympus_captain", "text": "All stations, general quarters! Combine bombers jumping out of hyperspace on our port quarter! Flak batteries are tracking, but they've launched heavy torpedoes!"},
    {"filename": "m07_apex_defend_carrier.mp3", "char": "apex_command", "text": "Vanguard Flight, priority one is fleet defense! Those fusion torpedoes will crack the Dauntless flight deck in two hits! Splash those warheads!"},
    {"filename": "m07_miller_tally_torpedo.mp3", "char": "wingman_miller", "text": "Tally-ho on lead torpedo! Engaging with cannon!"},
    {"filename": "m07_aegis_torpedo_warning.mp3", "char": "aegis_ai", "text": "EMERGENCY: High-velocity fusion torpedo detected on intercept course with Carrier Starboard Engine. Distance fifteen-hundred meters and closing fast!"},
    {"filename": "m07_ross_carrier_saved.mp3", "char": "olympus_captain", "text": "Direct hit on the final bomber! Air boss reports all torpedo tracks dissipated. Outstanding flying, Vanguard! The Dauntless owes you her life."},
    {"filename": "m07_apex_forge_tracking.mp3", "char": "apex_command", "text": "We tracked the bombers' quantum telemetry trails back to their source: the Celestial Forge. Restock your ordnance, pilots. We're taking the fight to their front door."},
    # Mission 8
    {"filename": "m08_apex_nemesis_visual.mp3", "char": "apex_command", "text": "There she is... the Nemesis-9. Look at the armor plating on that monster. Standard missile strikes won't penetrate that hull."},
    {"filename": "m08_vane_challenge.mp3", "char": "ghost_boss", "text": "Directorate lapdogs. You bled for this rock, and here you shall be buried. Fire all flak batteries! Turn their composite hulls into slag!"},
    {"filename": "m08_aegis_flak_subsystems.mp3", "char": "aegis_ai", "text": "Targeting system calibrated. Priority sub-systems tagged: Four rotary flak pods on upper deck."},
    {"filename": "m08_miller_shields_exposed.mp3", "char": "wingman_miller", "text": "Upper flak turrets silenced! Her ventral shields are exposed, Lead! Hit those generator domes!"},
    {"filename": "m08_vane_railgun_charged.mp3", "char": "ghost_boss", "text": "Insolent gnats! Main railgun charged! Eradicate them!"},
    {"filename": "m08_aegis_core_rupture.mp3", "char": "aegis_ai", "text": "Thermal core breached! Critical containment failure imminent!"},
    {"filename": "m08_vane_death_cry.mp3", "char": "ghost_boss", "text": "Impossible... My forge... my empire... CURSE YOU, VANGUARD!"},
    {"filename": "m08_apex_chapter2_victory.mp3", "char": "apex_command", "text": "Confirmed! Dreadnought Nemesis-9 is detonating! The Celestial Forge is breaking apart! All Vanguard units, disengage and RTB! Chapter Two is ours!"}
]

INTERLUDES_SCRIPT = [
    {"filename": "interlude_01_red_sinks.mp3", "char": "narrator", "text": "The cloud corridor was secure, but the silence was short-lived. Beneath the radar horizon, in the deep rifts of the Red Sinks, the Combine planted their roots. Vanguard 1... dive beneath the radar shadow. Sanitize the canyon."},
    {"filename": "interlude_02_apex_liftoff.mp3", "char": "narrator", "text": "With the jamming towers shattered, the radar net screamed to life. The Helion swarm was already falling on the Ascension Catapult. The transport Olympus-4 is vulnerable on the rail. Scramble flight lead Vanguard 1 and wingman Miller. Protect the liftoff at all costs."},
    {"filename": "interlude_03_karman_zenith.mp3", "char": "narrator", "text": "Olympus-4 made orbit, but telemetry revealed the puppeteer. High above the atmosphere, where the sky turns to black, the Combine Ghost commands the swarm. Forty-five thousand meters. No air. No second chances. Ignite afterburners, Vanguard 1. Breach the void."},
    {"filename": "epilogue_chapter1_finale.mp3", "char": "narrator", "text": "The Combine Ghost burned across the mesosphere. With its core shattered, the swarm collapsed into the sea. The Ascension Corridors held. Chapter One is won... but deep in the Asteroid Belt, Helion shipyards are already waking up. Rest while you can, Ace. Chapter Two has just begun."},
    {"filename": "interlude_04_asteroid_belt.mp3", "char": "narrator", "text": "Beyond the Karman line, gravity releases its grip. The Sol Directorate launched the Dauntless into the Gordian Belt to sever the Combine's supply lines. Ahead lies a silent graveyard of stone and iron. Check your thrusters, Vanguard 1. Out here, there is no air to catch your fall."},
    {"filename": "interlude_05_iron_hollow.mp3", "char": "narrator", "text": "Telemetry from the perimeter probes unveiled the Combine's secret foundry. Deep within the hollowed heart of Asteroid Eros, automated smelters forge weapons in silence. Penetrate the excavation trench. Shatter their geothermal reactors, and burn your way back into the stars."},
    {"filename": "interlude_06_distress_dark.mp3", "char": "narrator", "text": "The explosion inside Eros sent shockwaves through the belt. But the Combine retaliated without mercy. A wolfpack of heavy bombers has intercepted the Dauntless while her catapults were cold. All callsigns scramble! Protect the flagship, or the fleet dies in the dark."},
    {"filename": "interlude_07_celestial_forge.mp3", "char": "narrator", "text": "The carrier stood her ground. Tracing the bombers' flight paths led directly to the Combine's command nexus: the Celestial Forge. Guarding the shipyard is their supreme flagship... the Dreadnought Nemesis-9. This is where their war machine ends, Ace. Strike the leviathan down."},
    {"filename": "epilogue_chapter2_finale.mp3", "char": "narrator", "text": "The Nemesis-9 burned like a newborn star, scattering the Combine's fleet to dust. The Belt is liberated. Chapter Two is won. Yet as the dreadnought shattered, her black box transmitted one final quantum pulse toward the deep Kuiper Veil. Someone answered. Prepare your wings, Vanguard. Chapter Three will take us into the unknown."}
]


async def synthesize_entry(item: dict, out_dir: str, docs_dir: str, res_folder: str, skip_existing: bool = True):
    filename = item["filename"]
    char_key = item["char"]
    text = item["text"]
    profile = CHARACTER_PROFILES[char_key]
    out_path = os.path.join(out_dir, filename)
    docs_path = os.path.join(docs_dir, filename)
    raw_tmp_path = os.path.join(out_dir, f"_raw_{filename}")

    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(docs_dir, exist_ok=True)

    if skip_existing and os.path.exists(out_path) and os.path.getsize(out_path) > 1000:
        if not os.path.exists(docs_path):
            shutil.copy2(out_path, docs_path)
        generate_godot_mp3_import(res_folder, out_dir, filename)
        print(f"  [VOICE] Skipping existing: {filename} ({char_key})")
        return

    if not HAVE_EDGE_TTS:
        print(f"  [VOICE ERROR] edge-tts not installed. Cannot synthesize {filename}")
        return

    print(f"  [VOICE] Synthesizing: {filename} [{char_key}]...")
    comm = edge_tts.Communicate(text, profile["voice"], pitch=profile["pitch"], rate=profile["rate"])
    await comm.save(raw_tmp_path)

    # Apply character-specific DSP filter with ffmpeg if available
    dsp_filter = profile.get("dsp_filter", "")
    has_ffmpeg = shutil.which("ffmpeg") is not None

    if has_ffmpeg and dsp_filter:
        cmd = [
            "ffmpeg", "-y", "-i", raw_tmp_path,
            "-af", dsp_filter,
            "-codec:a", "libmp3lame", "-b:a", "192k",
            out_path
        ]
        res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if res.returncode == 0:
            if os.path.exists(raw_tmp_path):
                os.remove(raw_tmp_path)
        else:
            shutil.move(raw_tmp_path, out_path)
    else:
        shutil.move(raw_tmp_path, out_path)

    # Mirror to docs/lore
    shutil.copy2(out_path, docs_path)
    generate_godot_mp3_import(res_folder, out_dir, filename)
    print(f"  [VOICE] Complete: {filename} ({os.path.getsize(out_path)/1024:.1f} KB)")


async def generate_all_voices(skip_existing: bool = True):
    print("=== [AUDIO PIPELINE] GENERATING DIEGETIC VOCAL & RADIO SUITE ===")
    print("--- 1. Mission Radio Comms (M01 - M08) ---")
    for item in COMMS_SCRIPT:
        await synthesize_entry(item, COMMS_OUTPUT_DIR, COMMS_DOCS_DIR, "audio/comms", skip_existing)

    print("--- 2. Cinematic Interludes & Epilogues ---")
    for item in INTERLUDES_SCRIPT:
        await synthesize_entry(item, NARRATOR_OUTPUT_DIR, NARRATOR_DOCS_DIR, "audio/narrator", skip_existing)
    print("=== [AUDIO PIPELINE] ALL VOCALS & INTERLUDES SYNTHESIZED ===")


# -----------------------------------------------------------------------------
# 3. VERIFICATION & AUDIT SUITE
# -----------------------------------------------------------------------------

def audit_audio_suite():
    """Validates that all audio files referenced in the project exist, have valid
    sample rates, headers, and Godot .import descriptors."""
    print("=== [AUDIO PIPELINE] EXECUTING AUDIO SUITE AUDIT & COMPLIANCE CHECK ===")

    failures = []
    checked_count = 0

    # 1. Audit SFX Files
    expected_sfx = [
        "sfx_hud_target_locking.wav",
        "sfx_hud_target_locked.wav",
        "sfx_hud_missile_incoming_spike.wav",
        "sfx_hud_stall_warning.wav",
        "sfx_hud_low_altitude.wav",
        "sfx_hud_capacitor_empty.wav",
        "sfx_torpedo_alarm_loop.wav",
        "sfx_flight_high_g_whoosh.wav",
        "sfx_flyby_enemy_doppler.wav",
        "sfx_weapon_cannon_burst.wav",
        "sfx_autocannon_brr_loop.wav",
        "sfx_autocannon_shot.wav",
        "sfx_autocannon_winddown.wav",
        "sfx_weapon_missile_launch.wav",
        "sfx_impact_shield_hit.wav",
        "sfx_laser_sentry_beam.wav",
        "sfx_near_miss_bullet_whiz.wav",
        "sfx_asteroid_scrape_impact.wav",
        "sfx_capital_ship_core_explosion.wav",
        "sfx_ui_button_hover.wav",
        "sfx_ui_button_click.wav",
        "sfx_debrief_tally_tick.wav",
        "sfx_debrief_rank_slam.wav"
    ]

    print(f"\n[1/3] Auditing SFX Library ({len(expected_sfx)} assets)...")
    for sfx in expected_sfx:
        checked_count += 1
        wav_path = os.path.join(SFX_OUTPUT_DIR, sfx)
        import_path = wav_path + ".import"

        if not os.path.exists(wav_path):
            failures.append(f"Missing SFX file: {wav_path}")
            continue

        # Check WAV header
        try:
            with wave.open(wav_path, 'rb') as wf:
                framerate = wf.getframerate()
                sampwidth = wf.getsampwidth()
                channels = wf.getnchannels()
                if framerate != SAMPLE_RATE:
                    failures.append(f"{sfx}: Expected {SAMPLE_RATE} Hz, got {framerate} Hz")
                if sampwidth != 2:
                    failures.append(f"{sfx}: Expected 16-bit, got {sampwidth*8}-bit")
        except Exception as e:
            failures.append(f"{sfx}: Failed to read WAV: {e}")

        # Check .import
        if not os.path.exists(import_path):
            failures.append(f"Missing .import descriptor for SFX: {import_path}")
        else:
            with open(import_path, "r", encoding="utf-8") as f:
                content = f.read()
                is_expected_loop = sfx in LOOPING_SFX
                expected_loop_val = "edit/loop_mode=1" if is_expected_loop else "edit/loop_mode=0"
                if expected_loop_val not in content:
                    failures.append(f"{sfx}.import: Loop mode incorrect (Expected {expected_loop_val})")

    # 2. Audit Mission Comms
    print(f"\n[2/3] Auditing Mission Comms ({len(COMMS_SCRIPT)} dialogue lines)...")
    for item in COMMS_SCRIPT:
        checked_count += 1
        fn = item["filename"]
        mp3_path = os.path.join(COMMS_OUTPUT_DIR, fn)
        import_path = mp3_path + ".import"

        if not os.path.exists(mp3_path):
            failures.append(f"Missing comms track: {mp3_path}")
            continue
        if os.path.getsize(mp3_path) < 500:
            failures.append(f"Corrupted or empty comms track: {mp3_path}")
        if not os.path.exists(import_path):
            failures.append(f"Missing .import descriptor: {import_path}")

    # 3. Audit Cinematic Interludes
    print(f"\n[3/3] Auditing Cutscene Narrator Interludes ({len(INTERLUDES_SCRIPT)} cutscenes)...")
    for item in INTERLUDES_SCRIPT:
        checked_count += 1
        fn = item["filename"]
        mp3_path = os.path.join(NARRATOR_OUTPUT_DIR, fn)
        import_path = mp3_path + ".import"

        if not os.path.exists(mp3_path):
            failures.append(f"Missing interlude track: {mp3_path}")
            continue
        if os.path.getsize(mp3_path) < 1000:
            failures.append(f"Corrupted or empty interlude track: {mp3_path}")
        if not os.path.exists(import_path):
            failures.append(f"Missing .import descriptor: {import_path}")

    print("\n----------------------------------------------------------------------")
    print(f"Audit Summary: {checked_count} audio items verified across project.")
    if failures:
        print(f"FAILED: {len(failures)} compliance issue(s) detected:")
        for f in failures:
            print(f"  [!] {f}")
        return False
    else:
        print("SUCCESS: 100% audio compliance verified. All assets ready for runtime.")
        return True


# -----------------------------------------------------------------------------
# CLI ENTRY POINT
# -----------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Project Vanguard Audio Pipeline & DSP Sound Engineering Suite"
    )
    subparsers = parser.add_subparsers(dest="command", help="Pipeline command to execute")

    # generate-sfx
    subparsers.add_parser("generate-sfx", help="Generate all procedural 44.1kHz 16-bit WAV SFX assets")

    # generate-voices
    voices_p = subparsers.add_parser("generate-voices", help="Synthesize all radio comms and narrator interludes")
    voices_p.add_argument("--force", action="store_true", help="Force re-generation of existing voice tracks")

    # audit
    subparsers.add_parser("audit", help="Audit all audio files and Godot import configurations")

    args = parser.parse_args()

    if args.command == "generate-sfx":
        generate_all_sfx()
    elif args.command == "generate-voices":
        skip_existing = not args.force
        asyncio.run(generate_all_voices(skip_existing=skip_existing))
    elif args.command == "audit":
        success = audit_audio_suite()
        sys.exit(0 if success else 1)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
