# -*- coding: utf-8 -*-
"""
CAD Generators package for Project Vanguard core assets.
"""

from .player_fighter import build_player_fighter
from .torpedo import build_heavy_torpedo
from .laser_sentry import build_laser_sentry
from .carrier import build_carrier_dauntless
from .dreadnought import build_dreadnought_nemesis
from .cavern_core import build_cavern_generator_core

BUILDERS = {
    "player_fighter_v_hull": build_player_fighter,
    "heavy_anti_ship_torpedo": build_heavy_torpedo,
    "laser_sentry_turret": build_laser_sentry,
    "carrier_soc_dauntless": build_carrier_dauntless,
    "dreadnought_nemesis9": build_dreadnought_nemesis,
    "cavern_generator_core": build_cavern_generator_core,
}

__all__ = [
    "build_player_fighter",
    "build_heavy_torpedo",
    "build_laser_sentry",
    "build_carrier_dauntless",
    "build_dreadnought_nemesis",
    "build_cavern_generator_core",
    "BUILDERS",
]
