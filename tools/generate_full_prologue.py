import asyncio
import os
import edge_tts

OUTPUT_DIR = r"godot_project/audio/narrator"
DOCS_DIR = r"docs/lore/audio/narrator"

FULL_SCRIPT = (
    "For half a century, humanity believed the stars had been conquered by code. "
    "We built towering catapults that tore through the clouds, launching our future into the black. "
    "To protect our ascent, we surrendered the sky to autonomous machines. "
    "Trillions of algorithms. Billions of drones. "
    "We called it perfection... until the algorithms turned. "
    "One compromised line of code burned the Black Corridor... and cost fourteen hundred lives. "
    "In the ashes of that betrayal, a sacred decree was forged: "
    "no machine would ever pull the trigger alone. Humanity took back the stick. "
    "Now, the Helion Combine strikes to shatter the Ascension Corridors. "
    "Their autonomous swarms darken our horizon. "
    "But they forgot one thing: machines calculate odds. Humans defy them. "
    "When the automated sky falls... we are the Vanguard."
)

async def generate_full():
    print("Generating full cinematic prologue narration...")
    for voice_name, voice_id, pitch, rate in [
        ("prologue_full_brian.mp3", "en-US-BrianNeural", "-3Hz", "-4%"),
        ("prologue_full_thomas.mp3", "en-GB-ThomasNeural", "-1Hz", "-5%")
    ]:
        out_g = os.path.join(OUTPUT_DIR, voice_name)
        out_d = os.path.join(DOCS_DIR, voice_name)
        
        com = edge_tts.Communicate(text=FULL_SCRIPT, voice=voice_id, pitch=pitch, rate=rate)
        await com.save(out_g)
        
        with open(out_g, "rb") as f_in, open(out_d, "wb") as f_out:
            f_out.write(f_in.read())
            
        print(f"Generated {voice_name}")

if __name__ == "__main__":
    asyncio.run(generate_full())
