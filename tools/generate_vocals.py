import asyncio
import os
import edge_tts

OUTPUT_DIR = r"godot_project/audio/comms"
DOCS_AUDIO_DIR = r"docs/lore/audio"
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(DOCS_AUDIO_DIR, exist_ok=True)

# Cast definitions
VOICES = {
    "apex_command": "en-US-ChristopherNeural",   # Male, authoritative AWACS Tactical Commander
    "aegis_ai":     "en-GB-SoniaNeural",          # Female, calm, crisp aerospace cockpit flight computer
    "wingman_miller":"en-US-GuyNeural",           # Male, eager tactical wingman (Viper 2)
}

# Dialogue manifest for Mission 1
SCRIPT = [
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
    }
]

async def generate_all():
    print(f"Generating {len(SCRIPT)} vocal transmissions...")
    for item in SCRIPT:
        voice_id = VOICES[item["voice"]]
        out_path = os.path.join(OUTPUT_DIR, item["filename"])
        docs_path = os.path.join(DOCS_AUDIO_DIR, item["filename"])
        
        communicate = edge_tts.Communicate(
            text=item["text"],
            voice=voice_id,
            pitch=item["pitch"],
            rate=item["rate"]
        )
        await communicate.save(out_path)
        
        # Copy to docs/lore/audio
        with open(out_path, "rb") as f_in, open(docs_path, "wb") as f_out:
            f_out.write(f_in.read())
            
        print(f"Generated: {item['filename']} [{item['voice']}]")

if __name__ == "__main__":
    asyncio.run(generate_all())
