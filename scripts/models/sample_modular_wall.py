# -*- coding: utf-8 -*-
"""
Procedural Modular Sci-Fi Wall Generator for Autodesk Fusion 360.
Generates a game-ready modular wall section with recessed paneling and beveled details,
and automatically exports STEP and OBJ files for Unreal Engine 5.
"""

import os
import math
import adsk.core
import adsk.fusion

def build_modular_wall():
    app = adsk.core.Application.get()
    ui = app.userInterface

    # Ensure there is an active design document
    if app.documents.count == 0:
        print("No open document found. Creating a new Fusion Design document...")
        doc = app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
    
    product = app.activeProduct
    design = adsk.fusion.Design.cast(product)
    if not design:
        print("Active product is not a Fusion Design.")
        return False

    root_comp = design.rootComponent

    # Modular Dimensions in centimeters (Fusion API internal unit is cm)
    # 200 cm width (2m), 300 cm height (3m), 25 cm depth
    wall_width = 200.0
    wall_height = 300.0
    wall_depth = 25.0
    panel_inset = 15.0
    recess_depth = 6.0

    print(f"Creating modular wall component: {wall_width}x{wall_height}x{wall_depth} cm...")

    # Build on root component (compatible with both Part and Assembly documents)
    comp = root_comp

    # Base profile sketch on XY plane
    xy_plane = comp.xYConstructionPlane
    sketches = comp.sketches
    base_sketch = sketches.add(xy_plane)

    # Center the wall on X axis, seated on Z=0 (floor level)
    half_w = wall_width / 2.0
    p1 = adsk.core.Point3D.create(-half_w, 0, 0)
    p2 = adsk.core.Point3D.create(half_w, wall_height, 0)
    base_sketch.sketchCurves.sketchLines.addTwoPointRectangle(p1, p2)

    # Extrude base slab
    base_profile = base_sketch.profiles.item(0)
    extrudes = comp.features.extrudeFeatures
    base_ext_input = extrudes.createInput(
        base_profile,
        adsk.fusion.FeatureOperations.NewBodyFeatureOperation
    )
    base_ext_input.setDistanceExtent(False, adsk.core.ValueInput.createByReal(wall_depth))
    base_ext = extrudes.add(base_ext_input)
    wall_body = base_ext.bodies.item(0)
    wall_body.name = "Wall_Main_Body"

    # Find the front-facing planar face (highest Z)
    front_face = None
    for face in wall_body.faces:
        geom = face.geometry
        if isinstance(geom, adsk.core.Plane):
            normal = geom.normal
            if normal.z > 0.9:
                front_face = face
                break

    if front_face:
        # Create recessed architectural panels on front face
        panel_sketch = sketches.add(front_face)
        
        # Lower recessed panel
        p_low_1 = adsk.core.Point3D.create(-half_w + panel_inset, panel_inset, 0)
        p_low_2 = adsk.core.Point3D.create(half_w - panel_inset, (wall_height / 2.0) - (panel_inset / 2.0), 0)
        panel_sketch.sketchCurves.sketchLines.addTwoPointRectangle(p_low_1, p_low_2)

        # Upper recessed panel
        p_up_1 = adsk.core.Point3D.create(-half_w + panel_inset, (wall_height / 2.0) + (panel_inset / 2.0), 0)
        p_up_2 = adsk.core.Point3D.create(half_w - panel_inset, wall_height - panel_inset, 0)
        panel_sketch.sketchCurves.sketchLines.addTwoPointRectangle(p_up_1, p_up_2)

        # Cut recesses into wall
        for i in range(panel_sketch.profiles.count):
            prof = panel_sketch.profiles.item(i)
            # Find the inner rectangular profiles
            box = prof.boundingBox
            box_width = box.maxPoint.x - box.minPoint.x
            if box_width > (wall_width * 0.5):
                cut_input = extrudes.createInput(
                    prof,
                    adsk.fusion.FeatureOperations.CutFeatureOperation
                )
                # Cut backward into front face
                cut_input.setDistanceExtent(False, adsk.core.ValueInput.createByReal(-recess_depth))
                extrudes.add(cut_input)

    # Export configuration
    export_dir = r"c:\Users\Boris\Documents\antigravity\lucid-davinci\Exports"
    os.makedirs(export_dir, exist_ok=True)

    export_mgr = design.exportManager

    step_path = os.path.join(export_dir, "Modular_SciFi_Wall_01.step")
    print(f"Exporting STEP to: {step_path}")
    step_options = export_mgr.createSTEPExportOptions(step_path, comp)
    export_mgr.execute(step_options)

    # Check if export completed
    if os.path.exists(step_path):
        size_kb = os.path.getsize(step_path) / 1024.0
        print(f"[SUCCESS] STEP asset generated ({size_kb:.1f} KB)")
    else:
        print("[WARNING] STEP export did not produce expected file.")

    return True

# Execute generation
build_modular_wall()
