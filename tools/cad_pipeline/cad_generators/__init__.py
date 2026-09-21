# -*- coding: utf-8 -*-
"""
CAD Generators package for Project Vanguard core assets (all 12 assets).
"""

from .player_fighter import build_player_fighter
from .viper_fighter import build_viper_fighter
from .torpedo import build_heavy_torpedo
from .missile import build_strike_missile
from .carrier import build_carrier_dauntless
from .dreadnought import build_dreadnought_nemesis
from .laser_sentry import build_laser_sentry
from .cavern_core import build_cavern_generator_core
from .asteroids import build_asteroid_boulder, build_asteroid_cluster, build_tether_mine
from .cavern_tunnel import build_cavern_tunnel

BUILDERS = {
    "player_fighter_v_hull": build_player_fighter,
    "Spaceship_Viper_Supreme_HD": build_viper_fighter,
    "heavy_anti_ship_torpedo": build_heavy_torpedo,
    "vanguard_strike_missile": build_strike_missile,
    "carrier_soc_dauntless": build_carrier_dauntless,
    "dreadnought_nemesis9": build_dreadnought_nemesis,
    "laser_sentry_turret": build_laser_sentry,
    "cavern_generator_core": build_cavern_generator_core,
    "asteroid_tether_mine": build_tether_mine,
    "asteroid_boulder_medium": build_asteroid_boulder,
    "asteroid_cluster_large": build_asteroid_cluster,
    "cavern_tunnel_straight": build_cavern_tunnel,
}

__all__ = [
    "build_player_fighter",
    "build_viper_fighter",
    "build_heavy_torpedo",
    "build_strike_missile",
    "build_carrier_dauntless",
    "build_dreadnought_nemesis",
    "build_laser_sentry",
    "build_cavern_generator_core",
    "build_tether_mine",
    "build_asteroid_boulder",
    "build_asteroid_cluster",
    "build_cavern_tunnel",
    "BUILDERS",
]
