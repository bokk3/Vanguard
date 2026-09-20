# -*- coding: utf-8 -*-
"""
Configuration and Master Specification Catalog for Project Vanguard CAD Asset Pipeline.
Defines asset geometry dimensions, polycount budgets, material presets, socket markers,
and export file locations for both Godot 4 and Unreal Engine 5.
"""

import os

# Root directory paths
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GODOT_MESHES_DIR = os.path.join(PROJECT_ROOT, "godot_project", "assets", "meshes")
UE5_MESHES_DIR = os.path.join(PROJECT_ROOT, "assets", "meshes")
CAD_SOURCE_DIR = os.path.join(PROJECT_ROOT, "assets", "cad")

ASSET_CONFIGS = {
    "player_fighter_v_hull": {
        "name": "player_fighter_v_hull",
        "category": "vehicles",
        "target_polycount": (18000, 35000),
        "dimensions": {
            # In real-world meters: X=Wingspan (9.78m), Y=Length (10.30m), Z=Height (2.70m)
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
            "MI_Weapon_Pylon",
        ],
        "sockets": {
            "SOCKET_Camera_Cockpit": (0.0, 1.85, 0.72),
            "SOCKET_Camera_Chase": (0.0, -8.50, 2.80),
            "SOCKET_Thruster_L": (-0.95, -4.75, -0.05),
            "SOCKET_Thruster_R": (0.95, -4.75, -0.05),
            "SOCKET_Pylon_L1": (-2.40, -0.20, -0.35),
            "SOCKET_Pylon_L2": (-3.60, -0.80, -0.30),
            "SOCKET_Pylon_R1": (2.40, -0.20, -0.35),
            "SOCKET_Pylon_R2": (3.60, -0.80, -0.30),
            "SOCKET_Gun_Nose": (0.0, 4.80, -0.20),
        },
        "collision_parts": [
            ("Fuselage", (0.0, 0.45, 0.10), (2.10, 8.80, 1.60)),
            ("Wing_L", (-2.80, -1.60, -0.10), (3.80, 4.50, 0.40)),
            ("Wing_R", (2.80, -1.60, -0.10), (3.80, 4.50, 0.40)),
            ("Canopy", (0.0, 1.80, 0.65), (1.40, 3.00, 0.90)),
        ],
        "export_paths": {
            "godot_glb": os.path.join(GODOT_MESHES_DIR, "vehicles", "player_fighter_v_hull.glb"),
            "godot_legacy_glb": os.path.join(PROJECT_ROOT, "godot_project", "Spaceship_Sculpted_V_Hull.glb"),
            "ue5_fbx": os.path.join(UE5_MESHES_DIR, "vehicles", "player_fighter_v_hull.fbx"),
        },
    },

    "heavy_anti_ship_torpedo": {
        "name": "heavy_anti_ship_torpedo",
        "category": "vehicles",
        "target_polycount": (1800, 3500),
        "dimensions": {
            # In meters: Diameter 1.10m, Length 6.80m, Fin span 2.20m
            "length": 6.80,
            "width": 2.20,
            "height": 2.20,
            "tolerance_percent": 6.0,
        },
        "materials": [
            "MI_Torpedo_Hull",
            "MI_Warhead_Glow",
            "MI_Thrusters",
        ],
        "sockets": {
            "SOCKET_Thruster": (0.0, -3.40, 0.0),
            "SOCKET_Detonation_Apex": (0.0, 3.40, 0.0),
        },
        "collision_parts": [
            ("Body", (0.0, 0.0, 0.0), (1.20, 6.80, 1.20)),
        ],
        "export_paths": {
            "godot_glb": os.path.join(GODOT_MESHES_DIR, "vehicles", "heavy_anti_ship_torpedo.glb"),
            "ue5_fbx": os.path.join(UE5_MESHES_DIR, "vehicles", "heavy_anti_ship_torpedo.fbx"),
        },
    },

    "laser_sentry_turret": {
        "name": "laser_sentry_turret",
        "category": "environment",
        "target_polycount": (3500, 6000),
        "dimensions": {
            # Base diameter 3.20m, Height 2.40m, Length ~3.30m with barrels
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
            "godot_glb": os.path.join(GODOT_MESHES_DIR, "environment", "laser_sentry_turret.glb"),
            "ue5_fbx": os.path.join(UE5_MESHES_DIR, "environment", "laser_sentry_turret.fbx"),
        },
    },

    "carrier_soc_dauntless": {
        "name": "carrier_soc_dauntless",
        "category": "vehicles",
        "target_polycount": (65000, 120000),
        "dimensions": {
            # Length 480.0m, Width 135.0m, Height 72.0m
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
            "SOCKET_Catapult_1": (-25.0, 80.0, 12.0),
            "SOCKET_Catapult_2": (25.0, 80.0, 12.0),
            "SOCKET_Bridge_Camera": (38.0, -40.0, 45.0),
            "SOCKET_Defense_Turret_01": (-45.0, 120.0, 10.0),
            "SOCKET_Defense_Turret_02": (45.0, 120.0, 10.0),
            "SOCKET_Defense_Turret_03": (-50.0, -60.0, 14.0),
            "SOCKET_Defense_Turret_04": (50.0, -60.0, 14.0),
            "SOCKET_Defense_Turret_05": (-30.0, -180.0, 12.0),
            "SOCKET_Defense_Turret_06": (30.0, -180.0, 12.0),
            "SOCKET_Engine_Exhaust_01": (-25.0, -240.0, 8.0),
            "SOCKET_Engine_Exhaust_02": (0.0, -240.0, 8.0),
            "SOCKET_Engine_Exhaust_03": (25.0, -240.0, 8.0),
            "SOCKET_Engine_Exhaust_04": (-25.0, -240.0, -8.0),
            "SOCKET_Engine_Exhaust_05": (0.0, -240.0, -8.0),
            "SOCKET_Engine_Exhaust_06": (25.0, -240.0, -8.0),
        },
        "collision_parts": [
            ("Bow", (0.0, 160.0, 0.0), (80.0, 160.0, 40.0)),
            ("Center_Deck", (0.0, 0.0, 10.0), (120.0, 240.0, 40.0)),
            ("Island", (42.0, 20.0, 36.0), (30.0, 80.0, 50.0)),
            ("Stern", (0.0, -160.0, 0.0), (95.0, 160.0, 45.0)),
        ],
        "export_paths": {
            "godot_glb": os.path.join(GODOT_MESHES_DIR, "vehicles", "carrier_soc_dauntless.glb"),
            "ue5_fbx": os.path.join(UE5_MESHES_DIR, "vehicles", "carrier_soc_dauntless.fbx"),
        },
    },

    "dreadnought_nemesis9": {
        "name": "dreadnought_nemesis9",
        "category": "vehicles",
        "target_polycount": (80000, 150000),
        "dimensions": {
            # Length 620.0m, Width 180.0m, Height 95.0m
            "length": 620.0,
            "width": 180.0,
            "height": 95.0,
            "tolerance_percent": 6.0,
        },
        "materials": [
            "MI_Helion_Armor",
            "MI_Crimson_Plating",
            "MI_Reactor_Core_Glow",
            "MI_Shield_Emitter",
        ],
        "sockets": {
            "SOCKET_Railgun_Muzzle_L": (-14.0, 310.0, 4.0),
            "SOCKET_Railgun_Muzzle_R": (14.0, 310.0, 4.0),
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
            "godot_glb": os.path.join(GODOT_MESHES_DIR, "vehicles", "dreadnought_nemesis9.glb"),
            "ue5_fbx": os.path.join(UE5_MESHES_DIR, "vehicles", "dreadnought_nemesis9.fbx"),
        },
    },

    "cavern_generator_core": {
        "name": "cavern_generator_core",
        "category": "environment",
        "target_polycount": (6000, 10000),
        "dimensions": {
            # Total frame: 16.0m x 16.0m x 24.0m, Core dia 8.0m
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
            "SOCKET_Core_Emitter": (0.0, 0.0, 0.0),
            "SOCKET_Coolant_Port_01": (7.5, 0.0, 0.0),
            "SOCKET_Coolant_Port_02": (-7.5, 0.0, 0.0),
            "SOCKET_Coolant_Port_03": (0.0, 7.5, 0.0),
            "SOCKET_Coolant_Port_04": (0.0, -7.5, 0.0),
        },
        "collision_parts": [
            ("Core", (0.0, 0.0, 0.0), (10.0, 10.0, 22.0)),
            ("Frame_Cross", (0.0, 0.0, 0.0), (16.0, 16.0, 24.0)),
        ],
        "export_paths": {
            "godot_glb": os.path.join(GODOT_MESHES_DIR, "environment", "cavern_generator_core.glb"),
            "ue5_fbx": os.path.join(UE5_MESHES_DIR, "environment", "cavern_generator_core.glb".replace(".glb", ".fbx")),
        },
    },
}

# Material definition profiles (PBR parameter defaults)
MATERIAL_PRESETS = {
    "MI_Spaceship_Hull": {
        "base_color": (0.08, 0.09, 0.11, 1.0),
        "metallic": 0.88,
        "roughness": 0.32,
    },
    "MI_Cockpit_Glass": {
        "base_color": (0.05, 0.25, 0.35, 0.35),
        "metallic": 0.10,
        "roughness": 0.08,
        "alpha": 0.35,
        "transmission": 0.85,
    },
    "MI_Engine_Nozzles": {
        "base_color": (0.22, 0.22, 0.25, 1.0),
        "metallic": 0.95,
        "roughness": 0.45,
    },
    "MI_Thrusters": {
        "base_color": (0.10, 0.60, 1.0, 1.0),
        "metallic": 0.0,
        "roughness": 0.20,
        "emission": (0.10, 0.65, 1.0, 1.0),
        "emission_strength": 25.0,
    },
    "MI_Weapon_Pylon": {
        "base_color": (0.04, 0.04, 0.05, 1.0),
        "metallic": 0.90,
        "roughness": 0.40,
    },
    "MI_Torpedo_Hull": {
        "base_color": (0.12, 0.12, 0.14, 1.0),
        "metallic": 0.90,
        "roughness": 0.28,
    },
    "MI_Warhead_Glow": {
        "base_color": (1.0, 0.20, 0.05, 1.0),
        "metallic": 0.0,
        "roughness": 0.15,
        "emission": (1.0, 0.22, 0.05, 1.0),
        "emission_strength": 20.0,
    },
    "MI_Turret_Armor": {
        "base_color": (0.14, 0.15, 0.18, 1.0),
        "metallic": 0.88,
        "roughness": 0.32,
    },
    "MI_Laser_Optics": {
        "base_color": (1.0, 0.10, 0.20, 1.0),
        "metallic": 0.0,
        "roughness": 0.10,
        "emission": (1.0, 0.15, 0.25, 1.0),
        "emission_strength": 18.0,
    },
    "MI_Coolant_Vents": {
        "base_color": (0.05, 0.50, 0.80, 1.0),
        "metallic": 0.60,
        "roughness": 0.20,
        "emission": (0.10, 0.60, 0.90, 1.0),
        "emission_strength": 5.0,
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
}
