import asyncio
import os
import edge_tts

OUTPUT_DIR = r"godot_project/audio/comms"
DOCS_AUDIO_DIR = r"docs/lore/audio"
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(DOCS_AUDIO_DIR, exist_ok=True)

# Cast definitions
VOICES = {
    "apex_command":   "en-US-ChristopherNeural",  # Male, authoritative AWACS Tactical Commander
    "aegis_ai":       "en-GB-SoniaNeural",         # Female, calm, crisp aerospace cockpit flight computer
    "wingman_miller": "en-US-GuyNeural",          # Male, eager tactical wingman (Viper 2)
    "olympus_captain":"en-US-AndrewNeural",       # Male, heavy transport captain
    "ghost_boss":     "en-US-EricNeural",         # Male, sinister, cold Helion ace commander
}

# Dialogue manifest for All 4 Campaign Missions
SCRIPT = [
    # -------------------------------------------------------------
    # MISSION 01: OPERATION CLOUDBURST
    # -------------------------------------------------------------
    {
        "filename": "m01_apex_scramble.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+2%",
        "text": "Vanguard 1, Apex Command on secure freq. Catapult pressure nominal. You are cleared for hot scramble. Cloud deck begins at two-thousand meters. Bogey vectors uploaded to your compass ribbon."
    },
    {
        "filename": "m01_aegis_launch.mp3",
        "voice": "aegis_ai",
        "pitch": "+0Hz",
        "rate": "+0%",
        "text": "Catapult release in three... two... one. Main thrusters engaged. Flight telemetry online."
    },
    {
        "filename": "m01_aegis_contact.mp3",
        "voice": "aegis_ai",
        "pitch": "+0Hz",
        "rate": "+4%",
        "text": "Radar contact. Four hostile signatures on three-fifty meter disc. Bearing zero-four-five."
    },
    {
        "filename": "m01_apex_weapons_free.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+4%",
        "text": "Hostiles confirmed autonomous Marauder drones. Weapons free, Vanguard 1. Show them the envelope belongs to the Directorate."
    },
    {
        "filename": "m01_aegis_lock_confirmed.mp3",
        "voice": "aegis_ai",
        "pitch": "+0Hz",
        "rate": "+2%",
        "text": "Target tracked. Solid lock confirmed on Station Two."
    },
    {
        "filename": "m01_apex_mission_complete.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+2%",
        "text": "Good splashes, Vanguard 1. All four signatures purged from the grid. Form up and RTB. Maintenance crews are prepping your ordnance for the next sortie."
    },

    # -------------------------------------------------------------
    # MISSION 02: OPERATION IRON CANYON
    # -------------------------------------------------------------
    {
        "filename": "m02_apex_briefing.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+2%",
        "text": "Vanguard 1, you are dropping into the Red Sinks. Keep your belly to the rock under 120 meters. If you pop above the rim, Helion radar will light you up in seconds."
    },
    {
        "filename": "m02_aegis_terrain.mp3",
        "voice": "aegis_ai",
        "pitch": "+0Hz",
        "rate": "+2%",
        "text": "Terrain proximity active. Scanning canyon floor for jamming repeaters."
    },
    {
        "filename": "m02_aegis_altitude_warning.mp3",
        "voice": "aegis_ai",
        "pitch": "+0Hz",
        "rate": "+6%",
        "text": "CAUTION: Altitude exceeding 120 meters. Enemy tracking radar detected. Dive immediately!"
    },
    {
        "filename": "m02_apex_relays_down.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+3%",
        "text": "Relay Alpha destroyed! Telemetry static clearing up. Keep hunting, Vanguard."
    },
    {
        "filename": "m02_apex_victory.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+2%",
        "text": "All jamming relays eliminated. Early-warning radar grid restored across the Red Sinks. Great flying, Ace."
    },

    # -------------------------------------------------------------
    # MISSION 03: OPERATION APEX LIFTOFF
    # -------------------------------------------------------------
    {
        "filename": "m03_viper_wingman.mp3",
        "voice": "wingman_miller",
        "pitch": "+0Hz",
        "rate": "+4%",
        "text": "Miller on your wing, Vanguard 1. Look at that bird... Olympus-4 is charging capacitors. Let's make sure she makes orbit."
    },
    {
        "filename": "m03_apex_swarm_warning.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+3%",
        "text": "Threat grid lit up like a Christmas tree! Wave one incoming bearing one-eight-zero, angels four. Intercept!"
    },
    {
        "filename": "m03_olympus_under_fire.mp3",
        "voice": "olympus_captain",
        "pitch": "-2Hz",
        "rate": "+4%",
        "text": "Vanguard Flight, we are taking kinetic hits on starboard shields! Get these gnats off us!"
    },
    {
        "filename": "m03_apex_wave_cleared.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+3%",
        "text": "Wave eliminated! But sensors detect heavy dive bombers approaching from the east. Form up on the transport!"
    },
    {
        "filename": "m03_olympus_liftoff.mp3",
        "voice": "olympus_captain",
        "pitch": "-2Hz",
        "rate": "+1%",
        "text": "Main rocket ignition confirmed! Passing Mach 5 and climbing through fifty thousand feet. Thanks for the escort, Vanguard!"
    },

    # -------------------------------------------------------------
    # MISSION 04: OPERATION STRATOSPHERE ZERO
    # -------------------------------------------------------------
    {
        "filename": "m04_apex_vacuum_entry.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+2%",
        "text": "Vanguard 1, crossing forty thousand meters. Skies are turning black. Aerodynamic control surfaces decaying—you are on vectoring thrusters now."
    },
    {
        "filename": "m04_aegis_thin_air.mp3",
        "voice": "aegis_ai",
        "pitch": "+0Hz",
        "rate": "+2%",
        "text": "Atmospheric pressure minimal. Lift coefficient reduced eighty-five percent. Stall warning threshold adjusted to forty-five meters per second."
    },
    {
        "filename": "m04_ghost_challenge.mp3",
        "voice": "ghost_boss",
        "pitch": "-4Hz",
        "rate": "-2%",
        "text": "So the Directorate sent their prized pilot to freeze in the vacuum. Let's see how your precious V-hull handles true zero-G!"
    },
    {
        "filename": "m04_aegis_target_rupture.mp3",
        "voice": "aegis_ai",
        "pitch": "+0Hz",
        "rate": "+1%",
        "text": "Catastrophic core rupture on target. Threat destroyed."
    },
    {
        "filename": "m04_apex_ace_victory.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+2%",
        "text": "Combine Ghost is down! The entire drone network is offline across the hemisphere. Outstanding work, Vanguard 1... You saved Ascension!"
    }
]

async def generate_all():
    print(f"Generating {len(SCRIPT)} vocal transmissions across all 4 missions...")
    for item in SCRIPT:
        voice_id = VOICES[item["voice"]]
        out_path = os.path.join(OUTPUT_DIR, item["filename"])
        docs_path = os.path.join(DOCS_AUDIO_DIR, item["filename"])
        
        # Only generate if not exists or updating
        communicate = edge_tts.Communicate(
            text=item["text"],
            voice=voice_id,
            pitch=item["pitch"],
            rate=item["rate"]
        )
        await communicate.save(out_path)
        
        with open(out_path, "rb") as f_in, open(docs_path, "wb") as f_out:
            f_out.write(f_in.read())
            
        print(f"Generated: {item['filename']} [{item['voice']}]")

if __name__ == "__main__":
    asyncio.run(generate_all())
