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
    },

    # -------------------------------------------------------------
    # MISSION 05: OPERATION SILENT ORBIT
    # -------------------------------------------------------------
    {
        "filename": "m05_apex_carrier_launch.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+2%",
        "text": "Vanguard 1, Apex Command. You are clear of the Dauntless hangar bay. Atmospheric seals disengaged—welcome to hard vacuum. Watch your RCS thrusters among those rocks."
    },
    {
        "filename": "m05_aegis_vacuum_online.mp3",
        "voice": "aegis_ai",
        "pitch": "+0Hz",
        "rate": "+1%",
        "text": "Orbital vacuum confirmed. Aerodynamic stall envelope disengaged. Inertial drift compensators online."
    },
    {
        "filename": "m05_miller_tether_warning.mp3",
        "voice": "wingman_miller",
        "pitch": "+1Hz",
        "rate": "+3%",
        "text": "Look at this junk field, Lead. The Combine seeded the rim with magnetic tether-mines. One wrong move and they'll clamp right onto your hull."
    },
    {
        "filename": "m05_aegis_mine_cleared.mp3",
        "voice": "aegis_ai",
        "pitch": "+0Hz",
        "rate": "+3%",
        "text": "Mine cluster eliminated. Proximity grid sector alpha clear."
    },
    {
        "filename": "m05_apex_stealth_warning.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+3%",
        "text": "Careful, Vanguard. Sensor signatures popping up on the radar disc—they're using the asteroid shadows to cloak!"
    },
    {
        "filename": "m05_miller_perimeter_clear.mp3",
        "voice": "wingman_miller",
        "pitch": "+1Hz",
        "rate": "+2%",
        "text": "Splash two! You got the others, Lead! Perimeter corridor is clean."
    },
    {
        "filename": "m05_apex_foundry_coords.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+2%",
        "text": "Good hunting, Vanguard Flight. Telemetry decoders just pulled coordinates to their internal foundry. Prep for cavern infiltration."
    },

    # -------------------------------------------------------------
    # MISSION 06: OPERATION GHOST REEF
    # -------------------------------------------------------------
    {
        "filename": "m06_apex_enter_cavern.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+2%",
        "text": "Vanguard 1, telemetry is degrading as you enter the rock. You're entering the Iron Hollow. Keep your nose steady—clearance in that trench is less than one-hundred-fifty meters."
    },
    {
        "filename": "m06_aegis_laser_warning.mp3",
        "voice": "aegis_ai",
        "pitch": "+0Hz",
        "rate": "+2%",
        "text": "Warning: Multiple automated laser cutting arrays active along cavern bulkheads. Recommend immediate evasive maneuvers."
    },
    {
        "filename": "m06_apex_generators_status.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+3%",
        "text": "Generator Alpha down! Two remaining! Keep moving, the facility is switching auxiliary power to automated sentry turrets!"
    },
    {
        "filename": "m06_aegis_core_destabilizing.mp3",
        "voice": "aegis_ai",
        "pitch": "+0Hz",
        "rate": "+1%",
        "text": "All three generators neutralized. Geothermal core destabilizing. Catastrophic thermal blowout in forty seconds."
    },
    {
        "filename": "m06_apex_afterburners_escape.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+4%",
        "text": "Hit full afterburners, Vanguard 1! Get out of that rock before the shaft collapses!"
    },
    {
        "filename": "m06_miller_exit_visual.mp3",
        "voice": "wingman_miller",
        "pitch": "+1Hz",
        "rate": "+3%",
        "text": "Punch it, Lead! I see your exhaust plume breaking through the exit fissure!"
    },

    # -------------------------------------------------------------
    # MISSION 07: OPERATION DAUNTLESS DEFENDER
    # -------------------------------------------------------------
    {
        "filename": "m07_ross_general_quarters.mp3",
        "voice": "olympus_captain",
        "pitch": "-3Hz",
        "rate": "+1%",
        "text": "All stations, general quarters! Combine bombers jumping out of hyperspace on our port quarter! Flak batteries are tracking, but they've launched heavy torpedoes!"
    },
    {
        "filename": "m07_apex_defend_carrier.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+3%",
        "text": "Vanguard Flight, priority one is fleet defense! Those fusion torpedoes will crack the Dauntless flight deck in two hits! Splash those warheads!"
    },
    {
        "filename": "m07_miller_tally_torpedo.mp3",
        "voice": "wingman_miller",
        "pitch": "+1Hz",
        "rate": "+2%",
        "text": "Tally-ho on lead torpedo! Engaging with cannon!"
    },
    {
        "filename": "m07_aegis_torpedo_warning.mp3",
        "voice": "aegis_ai",
        "pitch": "+0Hz",
        "rate": "+2%",
        "text": "EMERGENCY: High-velocity fusion torpedo detected on intercept course with Carrier Starboard Engine. Distance fifteen-hundred meters and closing fast!"
    },
    {
        "filename": "m07_ross_carrier_saved.mp3",
        "voice": "olympus_captain",
        "pitch": "-3Hz",
        "rate": "+0%",
        "text": "Direct hit on the final bomber! Air boss reports all torpedo tracks dissipated. Outstanding flying, Vanguard! The Dauntless owes you her life."
    },
    {
        "filename": "m07_apex_forge_tracking.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+2%",
        "text": "We tracked the bombers' quantum telemetry trails back to their source: the Celestial Forge. Restock your ordnance, pilots. We're taking the fight to their front door."
    },

    # -------------------------------------------------------------
    # MISSION 08: OPERATION NEXUS CRUCIBLE
    # -------------------------------------------------------------
    {
        "filename": "m08_apex_nemesis_visual.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+2%",
        "text": "There she is... the Nemesis-9. Look at the armor plating on that monster. Standard missile strikes won't penetrate that hull."
    },
    {
        "filename": "m08_vane_challenge.mp3",
        "voice": "ghost_boss",
        "pitch": "-4Hz",
        "rate": "-1%",
        "text": "Directorate lapdogs. You bled for this rock, and here you shall be buried. Fire all flak batteries! Turn their composite hulls into slag!"
    },
    {
        "filename": "m08_aegis_flak_subsystems.mp3",
        "voice": "aegis_ai",
        "pitch": "+0Hz",
        "rate": "+1%",
        "text": "Targeting system calibrated. Priority sub-systems tagged: Four rotary flak pods on upper deck."
    },
    {
        "filename": "m08_miller_shields_exposed.mp3",
        "voice": "wingman_miller",
        "pitch": "+1Hz",
        "rate": "+2%",
        "text": "Upper flak turrets silenced! Her ventral shields are exposed, Lead! Hit those generator domes!"
    },
    {
        "filename": "m08_vane_railgun_charged.mp3",
        "voice": "ghost_boss",
        "pitch": "-4Hz",
        "rate": "-1%",
        "text": "Insolent gnats! Main railgun charged! Eradicate them!"
    },
    {
        "filename": "m08_aegis_core_rupture.mp3",
        "voice": "aegis_ai",
        "pitch": "+0Hz",
        "rate": "+1%",
        "text": "Thermal core breached! Critical containment failure imminent!"
    },
    {
        "filename": "m08_vane_death_cry.mp3",
        "voice": "ghost_boss",
        "pitch": "-4Hz",
        "rate": "-1%",
        "text": "Impossible... My forge... my empire... CURSE YOU, VANGUARD!"
    },
    {
        "filename": "m08_apex_chapter2_victory.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+2%",
        "text": "Confirmed! Dreadnought Nemesis-9 is detonating! The Celestial Forge is breaking apart! All Vanguard units, disengage and RTB! Chapter Two is ours!"
    },

    # -------------------------------------------------------------
    # GAME-01 ADDITIONS: Catapult launch & M08 phase gate lines
    # (generated separately from the original manifest — new GAME-01 wiring)
    # -------------------------------------------------------------
    {
        "filename": "m07_ross_catapult_clear.mp3",
        "voice": "olympus_captain",
        "pitch": "-3Hz",
        "rate": "+0%",
        "text": "Dauntless actual — you're clear of the deck. Good hunting, Vanguard."
    },
    {
        "filename": "m07_ross_torps_cleared.mp3",
        "voice": "olympus_captain",
        "pitch": "-3Hz",
        "rate": "+0%",
        "text": "All torpedoes neutralised! Dauntless battle group is secure. Outstanding work, Vanguard."
    },
    {
        "filename": "m08_vane_phase2.mp3",
        "voice": "ghost_boss",
        "pitch": "-4Hz",
        "rate": "-1%",
        "text": "Vanguard-1! You've punched through our flak screen. Shields at maximum!"
    },
    {
        "filename": "m08_apex_phase2_unlock.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+3%",
        "text": "Phase 1 cleared. Nemesis-9's shield emitter pylons are now exposed. Destroy them!"
    },
    {
        "filename": "m08_vane_phase3.mp3",
        "voice": "ghost_boss",
        "pitch": "-4Hz",
        "rate": "-2%",
        "text": "Impossible... the shield dome is shattered! PROTECT THE CORE!"
    },
    {
        "filename": "m08_apex_phase3_unlock.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+3%",
        "text": "Reactor core is exposed! One strike run — make it count, Vanguard."
    },
    {
        "filename": "m08_apex_victory.mp3",
        "voice": "apex_command",
        "pitch": "-2Hz",
        "rate": "+2%",
        "text": "NEMESIS-9 DESTROYED. The Helion flagship is gone. The Belt is ours. Mission accomplished, Vanguard-1!"
    }
]

async def generate_all():
    print(f"Generating vocal transmissions across all missions...", flush=True)
    for item in SCRIPT:
        voice_id = VOICES[item["voice"]]
        out_path = os.path.join(OUTPUT_DIR, item["filename"])
        docs_path = os.path.join(DOCS_AUDIO_DIR, item["filename"])
        
        if os.path.exists(out_path) and os.path.getsize(out_path) > 1000:
            print(f"Skipping existing: {item['filename']}", flush=True)
            if not os.path.exists(docs_path):
                with open(out_path, "rb") as f_in, open(docs_path, "wb") as f_out:
                    f_out.write(f_in.read())
            continue
            
        print(f"Synthesizing: {item['filename']} [{item['voice']}]...", flush=True)
        communicate = edge_tts.Communicate(
            text=item["text"],
            voice=voice_id,
            pitch=item["pitch"],
            rate=item["rate"]
        )
        await communicate.save(out_path)
        
        with open(out_path, "rb") as f_in, open(docs_path, "wb") as f_out:
            f_out.write(f_in.read())
            
        print(f"Generated: {item['filename']} [{item['voice']}]", flush=True)

if __name__ == "__main__":
    asyncio.run(generate_all())
