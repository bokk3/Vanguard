# -*- coding: utf-8 -*-
"""
Configuration and Master Specification Catalog for Project Vanguard CAD Asset Pipeline.
Defines asset geometry dimensions, polycount budgets, material presets, socket markers,
and STAGED export file locations (isolated from active in-game runtime files).

CRITICAL POLICY:
All pipeline exports target 'assets/staging/' exclusively.
NEVER overwrite active runtime files in 'godot_project/' or 'assets/meshes/' directly.
"""

import os

# Root directory paths
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# DEDICATED STAGING DIRECTORIES - SAFE FOR RAPID ITERATION & HIGH-SURFACE DETAILING
STAGING_DIR = os.path.join(PROJECT_ROOT, "assets", "staging")
STAGING_GODOT_DIR = os.path.join(STAGING_DIR, "godot")
STAGING_UE5_DIR = os.path.join(STAGING_DIR, "ue5")
CAD_SOURCE_DIR = os.path.join(PROJECT_ROOT, "assets", "cad")

ASSET_CONFIGS = {
    # -------------------------------------------------------------------------
    # 1. CAPITAL & VEHICLE COMBATANTS
    # -------------------------------------------------------------------------
    "player_fighter_v_hull": {
        "name": "player_fighter_v_hull",
        "category": "vehicles",
        "target_polycount": (18000, 35000),
        "generate_lods": False,
        "dimensions": {
            "length": 10.30,
            "width": 9.78,
            "height": 2.70,
            "tolerance_percent": 6.0,
        },
        "materials": [
            "MI_Spaceship_Hull",
            "MI_Cockpit_Glass",
            "MI_Engine_Nozzles",
            "MI_Thrusters",
            "MI_Headlights",
            "MI_Weapon_Pylon",
        ],
        "sockets": {
            "SOCKET_Chase_Camera": (0.0, -9.50, 3.20),
            "SOCKET_Cockpit_Camera": (0.0, 1.85, 0.72),
            "SOCKET_Cockpit_View": (0.0, 1.85, 0.72),
            "SOCKET_Headlight_L": (-1.15, 4.55, 0.28),
            "SOCKET_Headlight_R": (1.15, 4.55, 0.28),
            "SOCKET_Thruster_L": (-0.95, -4.75, -0.05),
            "SOCKET_Engine_L": (-0.95, -4.75, -0.05),
            "SOCKET_Thruster_R": (0.95, -4.75, -0.05),
            "SOCKET_Engine_R": (0.95, -4.75, -0.05),
            "SOCKET_Muzzle_L": (-0.85, 2.60, -0.15),
            "SOCKET_Muzzle_R": (0.85, 2.60, -0.15),
            "SOCKET_Ventral_Sensor": (0.0, 2.75, -0.72),
            "SOCKET_Weapon_Hardpoint_01": (-3.60, -1.80, -0.25),
            "SOCKET_Weapon_Hardpoint_02": (-2.60, -1.80, -0.25),
            "SOCKET_Weapon_Hardpoint_03": (2.60, -1.80, -0.25),
            "SOCKET_Weapon_Hardpoint_04": (3.60, -1.80, -0.25),
        },
        "collision_parts": [
            ("Fuselage", (0.0, 0.35, 0.15), (2.10, 9.20, 1.50)),
            ("Wing_L", (-2.95, -1.50, -0.05), (3.90, 4.80, 0.35)),
            ("Wing_R", (2.95, -1.50, -0.05), (3.90, 4.80, 0.35)),
            ("Ventral_Keel", (0.0, 0.50, -0.52), (0.90, 6.20, 0.55)),
        ],
        "export_paths": {
            "godot_glb": os.path.join(STAGING_DIR, "godot", "player_fighter_v_hull", "player_fighter_v_hull.glb"),
            "ue5_fbx": os.path.join(STAGING_DIR, "ue5", "player_fighter_v_hull", "player_fighter_v_hull.fbx"),
        },
    },

    "Spaceship_Viper_Supreme_HD": {
        "name": "Spaceship_Viper_Supreme_HD",
        "category": "vehicles",
        "target_polycount": (15000, 30000),
        "dimensions": {
            "length": 11.20,
            "width": 9.80,
            "height": 2.90,
            "tolerance_percent": 8.0,
        },
        "materials": [
            "MI_Spaceship_Hull",
            "MI_Cockpit_Glass",
            "MI_Engine_Nozzles",
            "MI_Thrusters",
            "MI_Weapon_Pylon",
        ],
        "sockets": {
            "SOCKET_Camera_Cockpit": (0.0, 2.10, 0.85),
            "SOCKET_Camera_Chase": (0.0, -9.20, 3.10),
            "SOCKET_Thruster_Center": (0.0, -5.20, 0.10),
            "SOCKET_Thruster_L": (-1.10, -5.10, -0.10),
            "SOCKET_Thruster_R": (1.10, -5.10, -0.10),
            "SOCKET_Gun_Nose": (0.0, 5.20, -0.15),
        },
        "collision_parts": [
            ("Fuselage", (0.0, 0.50, 0.15), (2.30, 9.40, 1.70)),
            ("Wing_L", (-2.90, -1.50, -0.10), (4.00, 4.80, 0.45)),
            ("Wing_R", (2.90, -1.50, -0.10), (4.00, 4.80, 0.45)),
        ],
        "export_paths": {
            "godot_glb": os.path.join(STAGING_GODOT_DIR, "vehicles", "Spaceship_Viper_Supreme_HD.glb"),
            "ue5_fbx": os.path.join(STAGING_UE5_DIR, "vehicles", "Spaceship_Viper_Supreme_HD.fbx"),
        },
    },

    "heavy_anti_ship_torpedo": {
        "name": "heavy_anti_ship_torpedo",
        "category": "vehicles",
        "target_polycount": (1800, 3500),
        "dimensions": {
            "length": 6.80,
            "width": 2.20,
            "height": 2.20,
            "tolerance_percent": 6.0,
        },
        "materials": [
            "MI_Torpedo_Casing",
            "MI_Warhead_Glow",
            "MI_Thrusters",
        ],
        "sockets": {
            "SOCKET_Exhaust": (0.0, -3.40, 0.0),
            "SOCKET_Seeker_Head": (0.0, 3.40, 0.0),
        },
        "collision_parts": [
            ("Body", (0.0, 0.0, 0.0), (1.20, 6.80, 1.20)),
        ],
        "export_paths": {
            "godot_glb": os.path.join(STAGING_GODOT_DIR, "vehicles", "heavy_anti_ship_torpedo.glb"),
            "ue5_fbx": os.path.join(STAGING_UE5_DIR, "vehicles", "heavy_anti_ship_torpedo.fbx"),
        },
    },

    "carrier_soc_dauntless": {
        "name": "carrier_soc_dauntless",
        "category": "vehicles",
        "target_polycount": (70000, 120000),
        "dimensions": {
            "length": 480.0,
            "width": 135.0,
            "height": 72.0,
            "tolerance_percent": 6.0,
        },
        "materials": [
            "MI_Capital_Plating",
            "MI_Flight_Deck_Stripes",
            "MI_Bridge_Glass",
            "MI_Engine_Superglow",
        ],
        "sockets": {
            "SOCKET_FlightDeck_Spawn_01": (-32.0, 120.0, 14.5),
            "SOCKET_FlightDeck_Spawn_02": (-32.0, 60.0, 14.5),
            "SOCKET_FlightDeck_Spawn_03": (-32.0, 0.0, 14.5),
            "SOCKET_FlightDeck_Spawn_04": (-32.0, -60.0, 14.5),
            "SOCKET_FlightDeck_Spawn_05": (32.0, 120.0, 14.5),
            "SOCKET_FlightDeck_Spawn_06": (32.0, 60.0, 14.5),
            "SOCKET_FlightDeck_Spawn_07": (32.0, 0.0, 14.5),
            "SOCKET_FlightDeck_Spawn_08": (32.0, -60.0, 14.5),
            "SOCKET_Bridge_View": (0.0, 135.0, 42.0),
            "SOCKET_Engine_Exhaust_01": (-25.0, -238.0, 6.0),
            "SOCKET_Engine_Exhaust_02": (0.0, -238.0, 6.0),
            "SOCKET_Engine_Exhaust_03": (25.0, -238.0, 6.0),
            "SOCKET_Engine_Exhaust_04": (-25.0, -238.0, -10.0),
            "SOCKET_Engine_Exhaust_05": (0.0, -238.0, -10.0),
            "SOCKET_Engine_Exhaust_06": (25.0, -238.0, -10.0),
        },
        "collision_parts": [
            ("Hull_Central", (0.0, 0.0, 0.0), (70.0, 470.0, 45.0)),
            ("Deck_Port", (-38.0, 20.0, 8.0), (35.0, 320.0, 18.0)),
            ("Deck_Starboard", (38.0, 20.0, 8.0), (35.0, 320.0, 18.0)),
            ("Island_Superstructure", (0.0, 110.0, 28.0), (25.0, 80.0, 35.0)),
            ("Ventral_Keel", (0.0, -30.0, -24.0), (45.0, 280.0, 22.0)),
        ],
        "export_paths": {
            "godot_glb": os.path.join(STAGING_GODOT_DIR, "vehicles", "carrier_soc_dauntless.glb"),
            "ue5_fbx": os.path.join(STAGING_UE5_DIR, "vehicles", "carrier_soc_dauntless.fbx"),
        },
    },

    "dreadnought_nemesis9": {
        "name": "dreadnought_nemesis9",
        "category": "vehicles",
        "target_polycount": (85000, 140000),
        "dimensions": {
            "length": 620.0,
            "width": 176.0,
            "height": 92.0,
            "tolerance_percent": 6.0,
        },
        "materials": [
            "MI_Helion_Armor",
            "MI_Crimson_Plating",
            "MI_Reactor_Core_Glow",
            "MI_Shield_Emitter",
        ],
        "sockets": {
            "SOCKET_Railgun_Prow": (0.0, 290.0, 12.0),
            "SOCKET_Bridge_Overlook": (0.0, 40.0, 48.0),
            "SOCKET_Reactor_Core": (0.0, -80.0, -24.0),
            "SOCKET_Flak_Mount_01": (-45.0, 60.0, 25.0),
            "SOCKET_Flak_Mount_02": (45.0, 60.0, 25.0),
            "SOCKET_Flak_Mount_03": (-60.0, -40.0, 22.0),
            "SOCKET_Flak_Mount_04": (60.0, -40.0, 22.0),
            "SOCKET_Flak_Mount_05": (-40.0, -160.0, 20.0),
            "SOCKET_Flak_Mount_06": (40.0, -160.0, 20.0),
        },
        "collision_parts": [
            ("Prow_Spines", (0.0, 220.0, 0.0), (70.0, 180.0, 35.0)),
            ("Main_Superstructure", (0.0, 0.0, 10.0), (160.0, 280.0, 60.0)),
            ("Reactor_Ventral", (0.0, -80.0, -20.0), (90.0, 160.0, 45.0)),
            ("Stern_Thrusters", (0.0, -240.0, 0.0), (120.0, 140.0, 50.0)),
        ],
        "export_paths": {
            "godot_glb": os.path.join(STAGING_GODOT_DIR, "vehicles", "dreadnought_nemesis9.glb"),
            "ue5_fbx": os.path.join(STAGING_UE5_DIR, "vehicles", "dreadnought_nemesis9.fbx"),
        },
    },

    "vanguard_strike_missile": {
        "name": "vanguard_strike_missile",
        "category": "vehicles",
        "target_polycount": (1200, 2500),
        "dimensions": {
            "length": 2.35,
            "width": 0.53,
            "height": 0.53,
            "tolerance_percent": 8.0,
        },
        "materials": [
            "MI_Weapon_Pylon",
            "MI_Warhead_Glow",
            "MI_Thrusters",
        ],
        "sockets": {
            "SOCKET_Exhaust": (0.0, -1.18, 0.0),
            "SOCKET_Seeker_Head": (0.0, 1.18, 0.0),
        },
        "collision_parts": [
            ("Body", (0.0, 0.0, 0.0), (0.55, 2.35, 0.55)),
        ],
        "export_paths": {
            "godot_glb": os.path.join(STAGING_GODOT_DIR, "vehicles", "vanguard_strike_missile.glb"),
            "ue5_fbx": os.path.join(STAGING_UE5_DIR, "vehicles", "vanguard_strike_missile.fbx"),
        },
    },

    # -------------------------------------------------------------------------
    # 2. ENVIRONMENT & PROPS
    # -------------------------------------------------------------------------
    "laser_sentry_turret": {
        "name": "laser_sentry_turret",
        "category": "environment",
        "target_polycount": (3500, 6000),
        "dimensions": {
            "length": 3.30,
            "width": 3.20,
            "height": 2.40,
            "tolerance_percent": 8.0,
        },
        "materials": [
            "MI_Turret_Armor",
            "MI_Laser_Optics",
            "MI_Coolant_Vents",
        ],
        "sockets": {
            "SOCKET_Muzzle_L": (-0.60, 1.80, 1.40),
            "SOCKET_Muzzle_R": (0.60, 1.80, 1.40),
            "SOCKET_Targeting_Sensor": (0.0, 0.50, 2.00),
        },
        "collision_parts": [
            ("Base", (0.0, 0.0, 0.40), (3.20, 3.20, 0.80)),
            ("Gimbal", (0.0, 0.40, 1.40), (1.80, 2.60, 1.60)),
        ],
        "export_paths": {
            "godot_glb": os.path.join(STAGING_GODOT_DIR, "environment", "laser_sentry_turret.glb"),
            "ue5_fbx": os.path.join(STAGING_UE5_DIR, "environment", "laser_sentry_turret.fbx"),
        },
    },

    "cavern_generator_core": {
        "name": "cavern_generator_core",
        "category": "environment",
        "target_polycount": (6000, 10000),
        "dimensions": {
            "length": 16.0,
            "width": 16.0,
            "height": 24.0,
            "tolerance_percent": 8.0,
        },
        "materials": [
            "MI_Generator_Structure",
            "MI_Plasma_Coil_Glow",
            "MI_Coolant_Conduit",
        ],
        "sockets": {
            "SOCKET_Core_Emitter": (0.0, 0.0, 12.0),
            "SOCKET_Overload_Point_01": (-6.8, 0.0, 5.0),
            "SOCKET_Overload_Point_02": (6.8, 0.0, 5.0),
            "SOCKET_Overload_Point_03": (0.0, -6.8, 5.0),
            "SOCKET_Overload_Point_04": (0.0, 6.8, 5.0),
        },
        "collision_parts": [
            ("Main_Column", (0.0, 0.0, 0.0), (12.0, 12.0, 24.0)),
            ("Stabilizer_Base", (0.0, 0.0, -10.0), (15.5, 15.5, 4.0)),
        ],
        "export_paths": {
            "godot_glb": os.path.join(STAGING_GODOT_DIR, "environment", "cavern_generator_core.glb"),
            "ue5_fbx": os.path.join(STAGING_UE5_DIR, "environment", "cavern_generator_core.fbx"),
        },
    },

    "asteroid_tether_mine": {
        "name": "asteroid_tether_mine",
        "category": "environment",
        "target_polycount": (2000, 4000),
        "dimensions": {
            "length": 3.20,
            "width": 3.20,
            "height": 3.20,
            "tolerance_percent": 8.0,
        },
        "materials": [
            "MI_Mine_Metal",
            "MI_Mine_Core_Glow",
        ],
        "sockets": {
            "SOCKET_Tether_Origin": (0.0, 0.0, -1.60),
            "SOCKET_Detonation_Sensor": (0.0, 0.0, 1.60),
        },
        "collision_parts": [
            ("Mine_Hull", (0.0, 0.0, 0.0), (2.40, 2.40, 2.40)),
        ],
        "export_paths": {
            "godot_glb": os.path.join(STAGING_GODOT_DIR, "environment", "asteroid_tether_mine.glb"),
            "ue5_fbx": os.path.join(STAGING_UE5_DIR, "environment", "asteroid_tether_mine.fbx"),
        },
    },

    "asteroid_boulder_medium": {
        "name": "asteroid_boulder_medium",
        "category": "environment",
        "target_polycount": (2500, 6000),
        "dimensions": {
            "length": 28.0,
            "width": 28.0,
            "height": 28.0,
            "tolerance_percent": 10.0,
        },
        "materials": [
            "MI_Asteroid_Rock",
        ],
        "sockets": {
            "SOCKET_Center": (0.0, 0.0, 0.0),
        },
        "collision_parts": [
            ("Boulder_Body", (0.0, 0.0, 0.0), (28.0, 28.0, 28.0)),
        ],
        "export_paths": {
            "godot_glb": os.path.join(STAGING_GODOT_DIR, "environment", "asteroid_boulder_medium.glb"),
            "ue5_fbx": os.path.join(STAGING_UE5_DIR, "environment", "asteroid_boulder_medium.fbx"),
        },
    },

    "asteroid_cluster_large": {
        "name": "asteroid_cluster_large",
        "category": "environment",
        "target_polycount": (8000, 18000),
        "dimensions": {
            "length": 120.0,
            "width": 85.0,
            "height": 90.0,
            "tolerance_percent": 12.0,
        },
        "materials": [
            "MI_Asteroid_Rock",
        ],
        "sockets": {
            "SOCKET_Center": (0.0, 0.0, 0.0),
        },
        "collision_parts": [
            ("Cluster_Core", (0.0, 0.0, 0.0), (85.0, 120.0, 90.0)),
        ],
        "export_paths": {
            "godot_glb": os.path.join(STAGING_GODOT_DIR, "environment", "asteroid_cluster_large.glb"),
            "ue5_fbx": os.path.join(STAGING_UE5_DIR, "environment", "asteroid_cluster_large.fbx"),
        },
    },

    "cavern_tunnel_straight": {
        "name": "cavern_tunnel_straight",
        "category": "environment",
        "target_polycount": (6000, 12000),
        "dimensions": {
            "length": 100.0,
            "width": 45.0,
            "height": 38.0,
            "tolerance_percent": 12.0,
        },
        "materials": [
            "MI_Cavern_Rock",
            "MI_Cavern_Steel",
        ],
        "sockets": {
            "SOCKET_Snap_Front": (0.0, 50.0, 0.0),
            "SOCKET_Snap_Back": (0.0, -50.0, 0.0),
        },
        "collision_parts": [
            ("Tunnel_Shell", (0.0, 0.0, 0.0), (45.0, 100.0, 38.0)),
        ],
        "export_paths": {
            "godot_glb": os.path.join(STAGING_GODOT_DIR, "environment", "cavern_tunnel_straight.glb"),
            "ue5_fbx": os.path.join(STAGING_UE5_DIR, "environment", "cavern_tunnel_straight.fbx"),
        },
    },
}

MATERIAL_PRESETS = {
    "MI_Spaceship_Hull": {
        "base_color": (0.12, 0.14, 0.18, 1.0),
        "metallic": 0.85,
        "roughness": 0.35,
    },
    "MI_Cockpit_Glass": {
        "base_color": (0.08, 0.12, 0.15, 1.0),
        "metallic": 0.10,
        "roughness": 0.05,
        "transmission": 0.90,
    },
    "MI_Engine_Nozzles": {
        "base_color": (0.06, 0.06, 0.07, 1.0),
        "metallic": 0.95,
        "roughness": 0.20,
    },
    "MI_Thrusters": {
        "base_color": (0.10, 0.60, 1.0, 1.0),
        "metallic": 0.0,
        "roughness": 0.15,
        "emission": (0.15, 0.70, 1.0, 1.0),
        "emission_strength": 15.0,
    },
    "MI_Weapon_Pylon": {
        "base_color": (0.15, 0.15, 0.16, 1.0),
        "metallic": 0.80,
        "roughness": 0.40,
    },
    "MI_Torpedo_Casing": {
        "base_color": (0.22, 0.24, 0.26, 1.0),
        "metallic": 0.90,
        "roughness": 0.30,
    },
    "MI_Warhead_Glow": {
        "base_color": (1.0, 0.20, 0.05, 1.0),
        "metallic": 0.0,
        "roughness": 0.20,
        "emission": (1.0, 0.25, 0.05, 1.0),
        "emission_strength": 18.0,
    },
    "MI_Turret_Armor": {
        "base_color": (0.14, 0.16, 0.18, 1.0),
        "metallic": 0.90,
        "roughness": 0.30,
    },
    "MI_Laser_Optics": {
        "base_color": (0.05, 0.95, 0.30, 1.0),
        "metallic": 0.10,
        "roughness": 0.10,
        "emission": (0.05, 0.95, 0.30, 1.0),
        "emission_strength": 10.0,
    },
    "MI_Coolant_Vents": {
        "base_color": (0.08, 0.09, 0.10, 1.0),
        "metallic": 0.70,
        "roughness": 0.60,
    },
    "MI_Capital_Plating": {
        "base_color": (0.16, 0.22, 0.30, 1.0),
        "metallic": 0.88,
        "roughness": 0.28,
    },
    "MI_Flight_Deck_Stripes": {
        "base_color": (0.95, 0.70, 0.15, 1.0),
        "metallic": 0.75,
        "roughness": 0.35,
    },
    "MI_Bridge_Glass": {
        "base_color": (0.05, 0.45, 0.65, 1.0),
        "metallic": 0.10,
        "roughness": 0.10,
        "emission": (0.10, 0.60, 0.90, 1.0),
        "emission_strength": 3.0,
    },
    "MI_Engine_Superglow": {
        "base_color": (0.15, 0.85, 1.0, 1.0),
        "metallic": 0.0,
        "roughness": 0.10,
        "emission": (0.20, 0.90, 1.0, 1.0),
        "emission_strength": 30.0,
    },
    "MI_Helion_Armor": {
        "base_color": (0.10, 0.10, 0.12, 1.0),
        "metallic": 0.92,
        "roughness": 0.22,
    },
    "MI_Crimson_Plating": {
        "base_color": (0.85, 0.06, 0.10, 1.0),
        "metallic": 0.80,
        "roughness": 0.30,
    },
    "MI_Reactor_Core_Glow": {
        "base_color": (1.0, 0.10, 0.15, 1.0),
        "metallic": 0.0,
        "roughness": 0.10,
        "emission": (1.0, 0.12, 0.20, 1.0),
        "emission_strength": 25.0,
    },
    "MI_Shield_Emitter": {
        "base_color": (0.10, 0.50, 1.0, 1.0),
        "metallic": 0.10,
        "roughness": 0.20,
        "emission": (0.20, 0.60, 1.0, 1.0),
        "emission_strength": 12.0,
    },
    "MI_Generator_Structure": {
        "base_color": (0.18, 0.20, 0.24, 1.0),
        "metallic": 0.90,
        "roughness": 0.30,
    },
    "MI_Plasma_Coil_Glow": {
        "base_color": (0.0, 0.90, 1.0, 1.0),
        "metallic": 0.0,
        "roughness": 0.10,
        "emission": (0.0, 0.95, 1.0, 1.0),
        "emission_strength": 20.0,
    },
    "MI_Coolant_Conduit": {
        "base_color": (0.25, 0.28, 0.32, 1.0),
        "metallic": 0.85,
        "roughness": 0.35,
    },
    "MI_Mine_Metal": {
        "base_color": (0.20, 0.22, 0.25, 1.0),
        "metallic": 0.92,
        "roughness": 0.25,
    },
    "MI_Mine_Core_Glow": {
        "base_color": (1.0, 0.05, 0.10, 1.0),
        "metallic": 0.0,
        "roughness": 0.15,
        "emission": (1.0, 0.05, 0.10, 1.0),
        "emission_strength": 20.0,
    },
    "MI_Asteroid_Rock": {
        "base_color": (0.18, 0.16, 0.15, 1.0),
        "metallic": 0.15,
        "roughness": 0.85,
    },
    "MI_Cavern_Rock": {
        "base_color": (0.14, 0.13, 0.12, 1.0),
        "metallic": 0.10,
        "roughness": 0.90,
    },
    "MI_Cavern_Steel": {
        "base_color": (0.25, 0.28, 0.32, 1.0),
        "metallic": 0.85,
        "roughness": 0.35,
    },
    "MI_Headlights": {
        "base_color": (0.95, 0.95, 1.0, 1.0),
        "metallic": 0.10,
        "roughness": 0.10,
        "emission": (0.95, 0.95, 1.0, 1.0),
        "emission_strength": 12.0,
    },
}
