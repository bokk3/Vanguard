# -*- coding: utf-8 -*-
"""
Project Vanguard: CAD Asset Generator & Polishing Pipeline Suite.
Main Command Line Interface (CLI) & Batch Script Runner.

Usage:
    python tools/cad_pipeline.py <command> [options]

Commands:
    generate   Generate raw procedural CAD models
    polish     Run topology cleanup, UVs, weighted normals, and socket assignment
    export     Export assets to Godot glTF (.glb) and Unreal Engine FBX (.fbx)
    build      End-to-end generate + polish + export pipeline execution
    verify     Run automated quality control and validation suite

Examples:
    python tools/cad_pipeline.py generate --asset player_fighter_v_hull
    python tools/cad_pipeline.py build --asset all --format all
    python tools/cad_pipeline.py verify --asset all
"""

import sys
import os
import argparse
import subprocess
import shutil

# Ensure tools directory is in sys.path
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

# Check if running inside Blender headless environment
INSIDE_BLENDER = False
try:
    import bpy
    INSIDE_BLENDER = True
except ImportError:
    INSIDE_BLENDER = False


def find_blender():
    """Finds the Blender executable on Windows or POSIX."""
    candidates = [
        shutil.which("blender"),
        os.path.expandvars(r"%USERPROFILE%\tools\blender\blender.exe"),
        r"C:\Users\Boris\tools\blender\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 4.2\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 4.1\blender.exe",
        r"C:\Program Files\Blender Foundation\Blender 4.0\blender.exe",
    ]
    for c in candidates:
        if c and os.path.exists(c):
            return c
    return None


def run_via_blender():
    """Re-executes this script headlessly inside Blender."""
    blender_exe = find_blender()
    if not blender_exe:
        print("[ERROR] Blender executable not found! Please ensure Blender 4.2+ is installed and on PATH.")
        sys.exit(1)

    # Pass all arguments forward through '--' separator
    cmd = [blender_exe, "-b", "--python", os.path.abspath(__file__), "--"] + sys.argv[1:]
    res = subprocess.run(cmd)
    sys.exit(res.returncode)


# =============================================================================
# BLENDER RUNTIME PIPELINE EXECUTION
# =============================================================================
def execute_blender_pipeline(args):
    from cad_pipeline.config import ASSET_CONFIGS
    from cad_pipeline.cad_generators import BUILDERS
    from cad_pipeline.polishing import (
        normalize_scale,
        polish_all_meshes,
        setup_asset_materials,
        create_sockets,
        generate_collision_hulls,
        generate_lods
    )
    from cad_pipeline.exporters import export_asset
    from cad_pipeline.verifier import verify_asset, format_health_report

    target_assets = list(ASSET_CONFIGS.keys()) if args.asset == "all" else [args.asset]

    if args.command == "generate":
        print(f"\n>>> Running CAD Generation for: {target_assets}")
        for asset_name in target_assets:
            if asset_name not in BUILDERS:
                print(f"[ERROR] No generator found for '{asset_name}'")
                continue
            print(f"Generating CAD model: {asset_name}...")
            builder = BUILDERS[asset_name]
            builder(ASSET_CONFIGS[asset_name])
            print(f"[SUCCESS] Generated: {asset_name}")

    elif args.command == "polish":
        print(f"\n>>> Running Hard-Surface Polishing for: {target_assets}")
        for asset_name in target_assets:
            config = ASSET_CONFIGS.get(asset_name)
            if not config:
                continue
            # Check if active scene already has object or build it
            root = bpy.data.objects.get(asset_name)
            if not root:
                builder = BUILDERS[asset_name]
                root = builder(config)

            print(f"Polishing hard-surface geometry for: {asset_name}...")
            normalize_scale(root)
            polish_all_meshes(root)
            setup_asset_materials(root, config["materials"])
            create_sockets(root, config["sockets"])
            generate_collision_hulls(config["name"], root, config.get("collision_parts"))
            if config.get("generate_lods", True):
                generate_lods(root)
            print(f"[SUCCESS] Polishing complete: {asset_name}")

    elif args.command == "export":
        print(f"\n>>> Running Multi-Engine Export for: {target_assets} (Format: {args.format})")
        for asset_name in target_assets:
            config = ASSET_CONFIGS.get(asset_name)
            if not config:
                continue
            root = bpy.data.objects.get(asset_name)
            if not root:
                builder = BUILDERS[asset_name]
                root = builder(config)

            results = export_asset(config, export_format=args.format)
            print(f"[SUCCESS] Exported {asset_name}: {results}")

    elif args.command == "build":
        print(f"\n>>> Running End-to-End Build Pipeline for: {target_assets} (Format: {args.format})")
        for asset_name in target_assets:
            config = ASSET_CONFIGS.get(asset_name)
            if not config or asset_name not in BUILDERS:
                print(f"[ERROR] Unknown asset: {asset_name}")
                continue
            print(f"\n=======================================================")
            print(f"  BUILDING ASSET: {asset_name}")
            print(f"=======================================================")
            # 1. Generate & Polish Asset
            builder = BUILDERS[asset_name]
            root = builder(config)

            # 2. Automated LOD generation (if enabled)
            if config.get("generate_lods", True):
                generate_lods(root)

            # 3. Export to Engines
            results = export_asset(config, export_format=args.format)
            print(f"[SUCCESS] Asset '{asset_name}' generated, polished, and exported: {results}")

    elif args.command == "verify":
        print(f"\n>>> Running Automated Quality Control Verification for: {target_assets}")
        reports = []
        for asset_name in target_assets:
            config = ASSET_CONFIGS.get(asset_name)
            if not config or asset_name not in BUILDERS:
                continue
            # Build asset in clean scene to inspect
            builder = BUILDERS[asset_name]
            root = builder(config)
            normalize_scale(root)
            polish_all_meshes(root)
            setup_asset_materials(root, config["materials"])
            create_sockets(root, config["sockets"])
            generate_collision_hulls(config["name"], root, config.get("collision_parts"))

            rep = verify_asset(asset_name, root, config)
            reports.append(rep)

        print("\n" + format_health_report(reports))
        # Determine exit code based on report pass
        all_passed = all(r.get("passed", False) for r in reports)
        if not all_passed:
            sys.exit(1)


def main():
    if not INSIDE_BLENDER:
        run_via_blender()
        return

    # Extract user arguments after '--' if present
    raw_args = sys.argv
    if "--" in raw_args:
        cli_args = raw_args[raw_args.index("--") + 1:]
    else:
        cli_args = raw_args[1:]

    parser = argparse.ArgumentParser(description="Project Vanguard CAD Asset Pipeline CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Subcommand: generate
    gen_parser = subparsers.add_parser("generate", help="Generate CAD models")
    gen_parser.add_argument("--asset", default="all", help="Asset name or 'all'")

    # Subcommand: polish
    pol_parser = subparsers.add_parser("polish", help="Polish geometry and prepare engine nodes")
    pol_parser.add_argument("--asset", default="all", help="Asset name or 'all'")

    # Subcommand: export
    exp_parser = subparsers.add_parser("export", help="Export to glTF or FBX")
    exp_parser.add_argument("--asset", default="all", help="Asset name or 'all'")
    exp_parser.add_argument("--format", default="all", choices=["glb", "fbx", "all"], help="Export format")

    # Subcommand: build
    bld_parser = subparsers.add_parser("build", help="End-to-end generate + polish + export")
    bld_parser.add_argument("--asset", default="all", help="Asset name or 'all'")
    bld_parser.add_argument("--format", default="all", choices=["glb", "fbx", "all"], help="Export format")

    # Subcommand: verify
    ver_parser = subparsers.add_parser("verify", help="Run automated QC checks")
    ver_parser.add_argument("--asset", default="all", help="Asset name or 'all'")

    args = parser.parse_args(cli_args)
    execute_blender_pipeline(args)


if __name__ == "__main__":
    main()
