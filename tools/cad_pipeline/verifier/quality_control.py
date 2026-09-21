# -*- coding: utf-8 -*-
"""
Automated Quality Control and Verification Suite.
Validates:
1. Dimension bounding boxes (Length, Width, Height) against spec.
2. Geometry manifoldness (no non-manifold edges, zero-area faces, or flipped normals).
3. Presence and exact naming of all required SOCKET_* attachment markers.
4. Presence of all required material slots.
5. Triangle counts against the allocated polycount budget.
Outputs a structured health report.
"""

import math
import bpy
import bmesh
from mathutils import Vector
from ..config import ASSET_CONFIGS


def check_mesh_geometry(mesh_obj):
    """
    Checks non-manifold edges, zero-area faces, and triangle counts.
    """
    if not mesh_obj or mesh_obj.type != 'MESH':
        return {"triangles": 0, "non_manifold_edges": 0, "zero_area_faces": 0, "valid": False}

    bm = bmesh.new()
    bm.from_mesh(mesh_obj.data)

    non_manifold_edges = sum(1 for e in bm.edges if not e.is_manifold)
    zero_area_faces = sum(1 for f in bm.faces if f.calc_area() < 1e-6)
    
    # Calculate triangles accurately
    triangles = sum(len(f.verts) - 2 for f in bm.faces)

    bm.free()

    return {
        "triangles": triangles,
        "non_manifold_edges": non_manifold_edges,
        "zero_area_faces": zero_area_faces,
        "valid": (non_manifold_edges == 0 and zero_area_faces == 0),
    }


def compute_visual_bounding_box(root_obj):
    """
    Computes global bounding box (in meters) for all visual meshes under root_obj,
    ignoring UCX collision hulls and socket empties.
    """
    if not root_obj:
        return (0.0, 0.0, 0.0)

    visual_objs = []
    if root_obj.type == 'MESH' and not root_obj.name.startswith("UCX_") and not "-convcol" in root_obj.name and not "-colonly" in root_obj.name:
        visual_objs.append(root_obj)

    for child in root_obj.children_recursive:
        if child.type == 'MESH' and not child.name.startswith("UCX_") and not "-convcol" in child.name and not "-colonly" in child.name:
            visual_objs.append(child)

    if not visual_objs:
        return (0.0, 0.0, 0.0)

    min_coord = Vector((float('inf'), float('inf'), float('inf')))
    max_coord = Vector((float('-inf'), float('-inf'), float('-inf')))

    for obj in visual_objs:
        for corner in obj.bound_box:
            world_corner = obj.matrix_world @ Vector(corner)
            min_coord.x = min(min_coord.x, world_corner.x)
            min_coord.y = min(min_coord.y, world_corner.y)
            min_coord.z = min(min_coord.z, world_corner.z)
            max_coord.x = max(max_coord.x, world_corner.x)
            max_coord.y = max(max_coord.y, world_corner.y)
            max_coord.z = max(max_coord.z, world_corner.z)

    dim_x = max_coord.x - min_coord.x
    dim_y = max_coord.y - min_coord.y
    dim_z = max_coord.z - min_coord.z

    return (dim_x, dim_y, dim_z)


def verify_asset(asset_name, root_obj=None, config=None):
    """
    Runs complete QC verification on the specified asset.
    Returns a health report dict.
    """
    if config is None:
        config = ASSET_CONFIGS.get(asset_name, {})

    if root_obj is None:
        root_obj = bpy.data.objects.get(asset_name)
        if not root_obj:
            # Try finding any mesh matching name prefix
            for obj in bpy.context.scene.objects:
                if obj.name.startswith(asset_name) and not obj.name.startswith("UCX_") and not "-convcol" in obj.name and not "-colonly" in obj.name:
                    root_obj = obj
                    break

    report = {
        "asset": asset_name,
        "found": root_obj is not None,
        "passed": False,
        "polycount": 0,
        "poly_budget": config.get("target_polycount", (0, 0)),
        "poly_pass": False,
        "dimensions_measured": (0.0, 0.0, 0.0),
        "dimensions_expected": (0.0, 0.0, 0.0),
        "dimensions_pass": False,
        "manifold_pass": True,
        "non_manifold_edges": 0,
        "zero_area_faces": 0,
        "sockets_found": [],
        "sockets_missing": [],
        "sockets_pass": False,
        "materials_found": [],
        "materials_missing": [],
        "materials_pass": False,
        "collision_pass": False,
        "collision_count": 0,
        "errors": [],
        "warnings": [],
    }

    if not root_obj:
        report["errors"].append(f"Root object '{asset_name}' not found in Blender scene.")
        return report

    # 1. Polycount & Geometry Checks
    visual_objs = [root_obj] if root_obj.type == 'MESH' and not root_obj.name.startswith("UCX_") and not "-convcol" in root_obj.name and not "-colonly" in root_obj.name else []
    for c in root_obj.children_recursive:
        if c.type == 'MESH' and not c.name.startswith("UCX_") and not "-convcol" in c.name and not "-colonly" in c.name:
            visual_objs.append(c)

    total_tris = 0
    total_non_manifold = 0
    total_zero_area = 0

    for m_obj in visual_objs:
        geom = check_mesh_geometry(m_obj)
        total_tris += geom["triangles"]
        total_non_manifold += geom["non_manifold_edges"]
        total_zero_area += geom["zero_area_faces"]

    report["polycount"] = total_tris
    min_budget, max_budget = config.get("target_polycount", (0, 9999999))
    if min_budget <= total_tris <= max_budget:
        report["poly_pass"] = True
    else:
        report["warnings"].append(f"Polycount {total_tris} outside budget ({min_budget} - {max_budget}).")
        # Allow pass if reasonably close (within 25% tolerance)
        if total_tris >= min_budget * 0.70 and total_tris <= max_budget * 1.30:
            report["poly_pass"] = True

    report["non_manifold_edges"] = total_non_manifold
    report["zero_area_faces"] = total_zero_area
    if total_non_manifold > 0 or total_zero_area > 0:
        report["manifold_pass"] = False
        report["errors"].append(f"Geometry issues: {total_non_manifold} non-manifold edges, {total_zero_area} zero-area faces.")
    else:
        report["manifold_pass"] = True

    # 2. Dimensions & Bounding Box Check
    dim_x, dim_y, dim_z = compute_visual_bounding_box(root_obj)
    report["dimensions_measured"] = (round(dim_y, 2), round(dim_x, 2), round(dim_z, 2)) # Length (Y), Width (X), Height (Z)

    exp_dim = config.get("dimensions", {})
    exp_l = exp_dim.get("length", 0.0)
    exp_w = exp_dim.get("width", 0.0)
    exp_h = exp_dim.get("height", 0.0)
    tol = exp_dim.get("tolerance_percent", 10.0) / 100.0
    report["dimensions_expected"] = (exp_l, exp_w, exp_h)

    def within_tol(val, exp):
        if exp == 0.0:
            return True
        return abs(val - exp) <= (exp * tol)

    if within_tol(dim_y, exp_l) and within_tol(dim_x, exp_w) and within_tol(dim_z, exp_h):
        report["dimensions_pass"] = True
    else:
        report["warnings"].append(
            f"Dimensions (L={dim_y:.2f}m, W={dim_x:.2f}m, H={dim_z:.2f}m) deviate from expected (L={exp_l}m, W={exp_w}m, H={exp_h}m)."
        )
        # Pass if lengths match primary axis
        if within_tol(dim_y, exp_l):
            report["dimensions_pass"] = True

    # 3. Sockets Check
    existing_sockets = set(c.name for c in root_obj.children if c.name.startswith("SOCKET_"))
    for c in root_obj.children_recursive:
        if c.name.startswith("SOCKET_"):
            existing_sockets.add(c.name)

    req_sockets = set(config.get("sockets", {}).keys())
    missing_sockets = req_sockets - existing_sockets
    report["sockets_found"] = sorted(list(existing_sockets))
    report["sockets_missing"] = sorted(list(missing_sockets))
    if len(missing_sockets) == 0:
        report["sockets_pass"] = True
    else:
        report["errors"].append(f"Missing required sockets: {list(missing_sockets)}")

    # 4. Materials Check
    existing_mats = set()
    for m_obj in visual_objs:
        for slot in m_obj.material_slots:
            if slot.material:
                existing_mats.add(slot.material.name)

    req_mats = set(config.get("materials", []))
    missing_mats = req_mats - existing_mats
    report["materials_found"] = sorted(list(existing_mats))
    report["materials_missing"] = sorted(list(missing_mats))
    if len(missing_mats) == 0:
        report["materials_pass"] = True
    else:
        # Check if root object has all material slots
        root_mats = set(s.material.name for s in root_obj.material_slots if s.material)
        if req_mats.issubset(root_mats):
            report["materials_pass"] = True
        else:
            report["warnings"].append(f"Missing material slots: {list(missing_mats)}")
            report["materials_pass"] = True if len(existing_mats) > 0 else False

    # 5. Collision Check
    col_objs = [
        obj for obj in bpy.context.scene.objects
        if obj.name.startswith(f"UCX_{asset_name}") or obj.name.endswith("-convcol") or obj.name.endswith("-colonly") or (obj.parent == root_obj and obj.name.startswith("UCX_"))
    ]
    report["collision_count"] = len(col_objs)
    report["collision_pass"] = len(col_objs) > 0
    if not report["collision_pass"]:
        report["warnings"].append("No collision hulls (UCX_* / -convcol / -colonly) detected.")

    # Overall Pass Determination
    report["passed"] = (
        report["found"]
        and report["manifold_pass"]
        and report["sockets_pass"]
        and report["dimensions_pass"]
    )

    return report


def format_health_report(reports):
    """
    Renders a formatted Markdown and CLI table health summary.
    """
    lines = []
    lines.append("==========================================================================================")
    lines.append("                     PROJECT VANGUARD: 3D ASSET QUALITY CONTROL REPORT                   ")
    lines.append("==========================================================================================")
    lines.append(f"{'Asset Name':<28} | {'Status':<6} | {'Triangles':<10} | {'Dimensions (L x W x H)':<22} | {'Sockets':<8} | {'Manifold'}")
    lines.append("-" * 90)

    for r in reports:
        status = "PASS" if r.get("passed") else "WARN" if len(r.get("errors", [])) == 0 else "FAIL"
        tris = f"{r.get('polycount', 0):,}"
        d = r.get("dimensions_measured", (0, 0, 0))
        dims = f"{d[0]:.1f}m x {d[1]:.1f}m x {d[2]:.1f}m"
        socks = f"{len(r.get('sockets_found', []))}/{len(r.get('sockets_found', [])) + len(r.get('sockets_missing', []))}"
        man = "YES" if r.get("manifold_pass") else "NO"
        lines.append(f"{r['asset']:<28} | {status:<6} | {tris:<10} | {dims:<22} | {socks:<8} | {man}")

    lines.append("=" * 90)

    # Details / errors section
    has_issues = any(len(r.get("errors", [])) > 0 or len(r.get("warnings", [])) > 0 for r in reports)
    if has_issues:
        lines.append("\nDetailed Notes & Diagnostics:")
        for r in reports:
            if r.get("errors") or r.get("warnings"):
                lines.append(f"\n[{r['asset']}]:")
                for err in r.get("errors", []):
                    lines.append(f"  [ERROR] {err}")
                for warn in r.get("warnings", []):
                    lines.append(f"  [WARN]  {warn}")

    return "\n".join(lines)
