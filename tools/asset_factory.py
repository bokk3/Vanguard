# -*- coding: utf-8 -*-
"""
Unified Asset Factory for Antigravity Game Studio.
Orchestrates the complete pipeline: Fusion 360 -> Blender -> UE5 -> Manifest.
"""

import os
import sys
import argparse
import subprocess

# Ensure workspace root is in sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from tools.manifest_manager import ManifestManager
from tools.blender_pipeline import process_asset as run_blender_pipeline
from tools.ue5_client import UE5RemoteClient
from tools.fusion_client import FusionBridgeClient


class AssetFactory:
    def __init__(self):
        self.manifest_mgr = ManifestManager()
        self.ue5_client = UE5RemoteClient()
        self.fusion_client = FusionBridgeClient()
        self.exports_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "Exports"))
        os.makedirs(self.exports_dir, exist_ok=True)

    def process_and_stage_asset(self, input_mesh, asset_name, category="Environment", dimensions=(200, 300, 25), step_file=None):
        """Run asset through Blender, register in manifest, and stage for UE5."""
        print(f"\n==========================================")
        print(f"  Asset Factory: Processing '{asset_name}'")
        print(f"==========================================")

        # 1. Blender Pipeline (UVs, Collision, Game-Ready FBX)
        output_fbx = os.path.join(self.exports_dir, f"{asset_name}_game_ready.fbx")
        print(f"[1/4] Running Blender pipeline on {input_mesh}...")
        success = run_blender_pipeline(
            input_file=input_mesh,
            output_file=output_fbx,
            uv=True,
            collision=True
        )
        if not success:
            print(f"[ERROR] Blender pipeline failed for '{asset_name}'.")
            return False

        # 2. Register in Asset Manifest
        print(f"[2/4] Registering '{asset_name}' in asset manifest...")
        rel_fbx = os.path.relpath(output_fbx, os.path.dirname(self.exports_dir)).replace("\\", "/")
        rel_step = os.path.relpath(step_file, os.path.dirname(self.exports_dir)).replace("\\", "/") if step_file else None

        w, h, d = dimensions
        clean_cat = category.strip("/").replace(" ", "_")
        ue5_path = f"/Game/{clean_cat}/SM_{asset_name}"

        self.manifest_mgr.register_asset(
            name=asset_name,
            category=category,
            width=w,
            height=h,
            depth=d,
            fbx_file=rel_fbx,
            step_file=rel_step,
            ue5_path=ue5_path,
            sockets=["Socket_Top", "Socket_Base"]
        )

        # 3. Generate UE5 Import Script
        print(f"[3/4] Generating UE5 import script...")
        ue5_script_path = os.path.join(self.exports_dir, f"import_{asset_name}.py")
        import_code = self.ue5_client.generate_import_script(
            fbx_path=output_fbx,
            destination_path=f"/Game/{clean_cat}",
            enable_nanite=True
        )
        with open(ue5_script_path, "w", encoding="utf-8") as f:
            f.write(import_code)
        print(f"[SUCCESS] UE5 import script saved: {ue5_script_path}")

        # 4. Attempt Live Remote Execution into UE5 if running
        print(f"[4/4] Checking live Unreal Engine connection...")
        online, _ = self.ue5_client.ping()
        if online:
            print(f"Unreal Engine detected! Auto-importing '{asset_name}' directly into Editor...")
            res = self.ue5_client.execute_code(import_code)
            print(f"[UE5 RESULT]: {res}")
        else:
            print(f"Unreal Engine is currently offline. Import script is ready to run once UE5 is open.")

        print(f"\n[DONE] Asset '{asset_name}' is fully game-ready!\n")
        return True


def main():
    parser = argparse.ArgumentParser(description="Antigravity Unified Asset Factory")
    parser.add_argument("--name", "-n", required=True, help="Asset name (e.g. Modular_Door_01)")
    parser.add_argument("--mesh", "-m", help="Path to raw input mesh (OBJ, STL, FBX)")
    parser.add_argument("--step", help="Path to original STEP CAD file (optional)")
    parser.add_argument("--category", "-c", default="Environment", help="Asset category (default: Environment)")
    parser.add_argument("--dims", nargs=3, type=float, default=[200.0, 300.0, 25.0], help="Dimensions: Width Height Depth in cm")

    args = parser.parse_args()
    factory = AssetFactory()

    if not args.mesh:
        print("[ERROR] Please provide an input mesh via --mesh")
        sys.exit(1)

    success = factory.process_and_stage_asset(
        input_mesh=args.mesh,
        asset_name=args.name,
        category=args.category,
        dimensions=args.dims,
        step_file=args.step
    )
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
