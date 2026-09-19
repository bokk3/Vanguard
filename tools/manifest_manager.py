# -*- coding: utf-8 -*-
"""
Asset Manifest Manager for Antigravity Game Studio.
Tracks 3D assets, dimensions, collision setup, and Unreal Engine paths.
"""

import os
import json
import argparse

DEFAULT_MANIFEST_PATH = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "data", "asset_manifest.json")
)


class ManifestManager:
    def __init__(self, manifest_path=DEFAULT_MANIFEST_PATH):
        self.manifest_path = manifest_path
        self.data = self._load()

    def _load(self):
        if os.path.exists(self.manifest_path):
            try:
                with open(self.manifest_path, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception as e:
                print(f"[WARNING] Failed to load manifest: {e}. Starting empty.")
        return {"version": "1.0", "project_name": "lucid-davinci", "grid_size_cm": 200.0, "assets": {}}

    def save(self):
        os.makedirs(os.path.dirname(self.manifest_path), exist_ok=True)
        with open(self.manifest_path, "w", encoding="utf-8") as f:
            json.dump(self.data, f, indent=2)

    def register_asset(self, name, category, width, height, depth, fbx_file, step_file=None, ue5_path=None, sockets=None):
        if not ue5_path:
            clean_cat = category.strip("/").replace(" ", "_")
            ue5_path = f"/Game/{clean_cat}/SM_{name}"

        self.data["assets"][name] = {
            "category": category,
            "dimensions_cm": {
                "width": float(width),
                "height": float(height),
                "depth": float(depth)
            },
            "grid_units": [
                round(float(width) / self.data.get("grid_size_cm", 200.0), 1),
                round(float(depth) / self.data.get("grid_size_cm", 200.0), 1)
            ],
            "files": {
                "fbx": fbx_file,
                "step": step_file
            },
            "ue5_package_path": ue5_path,
            "has_collision": True,
            "nanite_enabled": True,
            "sockets": sockets or []
        }
        self.save()
        print(f"[MANIFEST] Asset '{name}' successfully registered.")

    def get_asset(self, name):
        return self.data.get("assets", {}).get(name)

    def list_assets(self, category=None):
        assets = self.data.get("assets", {})
        if not category:
            return assets
        return {k: v for k, v in assets.items() if category.lower() in v.get("category", "").lower()}


def main():
    parser = argparse.ArgumentParser(description="Asset Manifest CLI Manager")
    parser.add_argument("--list", action="store_true", help="List all registered assets")
    parser.add_argument("--category", help="Filter listing by category")
    parser.add_argument("--get", help="Get details for a specific asset")
    args = parser.parse_args()

    mgr = ManifestManager()

    if args.list:
        assets = mgr.list_assets(args.category)
        print(f"=== Registered Assets ({len(assets)}) ===")
        print(json.dumps(assets, indent=2))
        return

    if args.get:
        asset = mgr.get_asset(args.get)
        if asset:
            print(json.dumps(asset, indent=2))
        else:
            print(f"[ERROR] Asset '{args.get}' not found in manifest.")
        return

    parser.print_help()


if __name__ == "__main__":
    main()
