import asyncio
import os
import edge_tts

VOICE = "en-US-BrianNeural"
PITCH = "-3Hz"
RATE = "-4%"

OUTPUT_DIRS = [
    r"godot_project/audio/narrator",
    r"docs/lore/audio/narrator"
]

INTERLUDES = [
    {
        "id": "interlude_01_red_sinks",
        "title": "CHAPTER 1 // INTERLUDE I: INTO THE RED SINKS",
        "text": "The cloud corridor was secure, but the silence was short-lived. Beneath the radar horizon, in the deep rifts of the Red Sinks, the Combine planted their roots. Vanguard 1... dive beneath the radar shadow. Sanitize the canyon."
    },
    {
        "id": "interlude_02_apex_liftoff",
        "title": "CHAPTER 1 // INTERLUDE II: THE LIFTOFF PROTOCOL",
        "text": "With the jamming towers shattered, the radar net screamed to life. The Helion swarm was already falling on the Ascension Catapult. The transport Olympus-4 is vulnerable on the rail. Scramble flight lead Vanguard 1 and wingman Miller. Protect the liftoff at all costs."
    },
    {
        "id": "interlude_03_karman_zenith",
        "title": "CHAPTER 1 // INTERLUDE III: THE KARMAN ZENITH",
        "text": "Olympus-4 made orbit, but telemetry revealed the puppeteer. High above the atmosphere, where the sky turns to black, the Combine Ghost commands the swarm. Forty-five thousand meters. No air. No second chances. Ignite afterburners, Vanguard 1. Breach the void."
    },
    {
        "id": "epilogue_chapter1_finale",
        "title": "CHAPTER 1 // FINALE: THE BROKEN SWARM",
        "text": "The Combine Ghost burned across the mesosphere. With its core shattered, the swarm collapsed into the sea. The Ascension Corridors held. Chapter One is won... but deep in the Asteroid Belt, Helion shipyards are already waking up. Rest while you can, Ace. Chapter Two has just begun."
    },
    {
        "id": "interlude_04_asteroid_belt",
        "title": "CHAPTER 2 // INTERLUDE IV: INTO THE ASTEROID BELT",
        "text": "Beyond the Karman line, gravity releases its grip. The Sol Directorate launched the Dauntless into the Gordian Belt to sever the Combine's supply lines. Ahead lies a silent graveyard of stone and iron. Check your thrusters, Vanguard 1. Out here, there is no air to catch your fall."
    },
    {
        "id": "interlude_05_iron_hollow",
        "title": "CHAPTER 2 // INTERLUDE V: THE IRON HOLLOW",
        "text": "Telemetry from the perimeter probes unveiled the Combine's secret foundry. Deep within the hollowed heart of Asteroid Eros, automated smelters forge weapons in silence. Penetrate the excavation trench. Shatter their geothermal reactors, and burn your way back into the stars."
    },
    {
        "id": "interlude_06_distress_dark",
        "title": "CHAPTER 2 // INTERLUDE VI: DISTRESS IN THE DARK",
        "text": "The explosion inside Eros sent shockwaves through the belt. But the Combine retaliated without mercy. A wolfpack of heavy bombers has intercepted the Dauntless while her catapults were cold. All callsigns scramble! Protect the flagship, or the fleet dies in the dark."
    },
    {
        "id": "interlude_07_celestial_forge",
        "title": "CHAPTER 2 // INTERLUDE VII: THE CELESTIAL FORGE",
        "text": "The carrier stood her ground. Tracing the bombers' flight paths led directly to the Combine's command nexus: the Celestial Forge. Guarding the shipyard is their supreme flagship... the Dreadnought Nemesis-9. This is where their war machine ends, Ace. Strike the leviathan down."
    },
    {
        "id": "epilogue_chapter2_finale",
        "title": "CHAPTER 2 // FINALE: BEYOND THE KUIPER VEIL",
        "text": "The Nemesis-9 burned like a newborn star, scattering the Combine's fleet to dust. The Belt is liberated. Chapter Two is won. Yet as the dreadnought shattered, her black box transmitted one final quantum pulse toward the deep Kuiper Veil. Someone answered. Prepare your wings, Vanguard. Chapter Three will take us into the unknown."
    }
]

async def generate_track(entry):
    filename = f"{entry['id']}.mp3"
    for d in OUTPUT_DIRS:
        os.makedirs(d, exist_ok=True)
        
    master_path = os.path.join(OUTPUT_DIRS[0], filename)
    docs_path = os.path.join(OUTPUT_DIRS[1], filename)
    
    if os.path.exists(master_path) and os.path.getsize(master_path) > 1000:
        print(f"Skipping existing: {filename}", flush=True)
        if not os.path.exists(docs_path):
            with open(master_path, "rb") as src, open(docs_path, "wb") as dst:
                dst.write(src.read())
        return

    print(f"Synthesizing: {filename}...", flush=True)
    communicate = edge_tts.Communicate(entry["text"], VOICE, pitch=PITCH, rate=RATE)
    await communicate.save(master_path)
    
    with open(master_path, "rb") as src, open(docs_path, "wb") as dst:
        dst.write(src.read())
        
    size_kb = os.path.getsize(master_path) / 1024
    print(f"Synthesized: {filename} ({size_kb:.1f} KB) -> {master_path}", flush=True)

async def main():
    print(f"Synthesizing Chapter 1 & 2 Cutscenes with Brian '{VOICE}' ({PITCH}, {RATE})...", flush=True)
    for entry in INTERLUDES:
        await generate_track(entry)
    print("All cutscenes ready.", flush=True)

if __name__ == "__main__":
    asyncio.run(main())
