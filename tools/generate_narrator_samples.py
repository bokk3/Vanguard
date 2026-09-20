import asyncio
import os
import edge_tts

OUTPUT_DIR = r"godot_project/audio/narrator"
DOCS_DIR = r"docs/lore/audio/narrator"
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(DOCS_DIR, exist_ok=True)

AUDITION_TEXT = (
    "For half a century, humanity believed the stars had been conquered by code. "
    "To protect our ascent, we surrendered the sky to autonomous machines... until the algorithms turned. "
    "Now, the swarms darken our horizon. "
    "Machines calculate odds. Humans defy them. "
    "When the automated sky falls... we are the Vanguard."
)

CANDIDATES = [
    {
        "filename": "narrator_sample_01_brian.mp3",
        "voice": "en-US-BrianNeural",
        "pitch": "-3Hz",
        "rate": "-4%",
        "label": "Brian (American Blockbuster Trailer)"
    },
    {
        "filename": "narrator_sample_02_andrew.mp3",
        "voice": "en-US-AndrewNeural",
        "pitch": "-2Hz",
        "rate": "-4%",
        "label": "Andrew (Resonant Military Historian)"
    },
    {
        "filename": "narrator_sample_03_thomas.mp3",
        "voice": "en-GB-ThomasNeural",
        "pitch": "-1Hz",
        "rate": "-5%",
        "label": "Thomas (Epic Dramatic British Sci-Fi)"
    },
    {
        "filename": "narrator_sample_04_christopher_deep.mp3",
        "voice": "en-US-ChristopherNeural",
        "pitch": "-6Hz",
        "rate": "-6%",
        "label": "Christopher Deep (Deep Bass Heavy Titan)"
    }
]

async def generate_samples():
    print("Generating 4 epic narrator voice audition samples...")
    for c in CANDIDATES:
        out_godot = os.path.join(OUTPUT_DIR, c["filename"])
        out_docs = os.path.join(DOCS_DIR, c["filename"])
        
        communicate = edge_tts.Communicate(
            text=AUDITION_TEXT,
            voice=c["voice"],
            pitch=c["pitch"],
            rate=c["rate"]
        )
        await communicate.save(out_godot)
        
        with open(out_godot, "rb") as f_in, open(out_docs, "wb") as f_out:
            f_out.write(f_in.read())
            
        print(f"Generated {c['filename']} -> {c['label']}")

if __name__ == "__main__":
    asyncio.run(generate_samples())
