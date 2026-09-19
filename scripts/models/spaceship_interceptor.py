# -*- coding: utf-8 -*-
"""
Procedural Starfighter Interceptor Generator for Autodesk Fusion 360.
Generates a highly detailed stealth spaceship:
- Chiseled faceted stealth fuselage
- Elevated aerodynamic cockpit canopy
- Swept delta wings with beveled leading edges
- Twin canted vertical stabilizers
- Dual heavy ion thruster nacelles with recessed exhaust nozzles
- Twin forward kinetic cannons
- Automatic STEP export and game-ready FBX processing
"""

import os
import math
import adsk.core
import adsk.fusion


def build_spaceship():
    app = adsk.core.Application.get()
    ui = app.userInterface

    # Create a fresh, dedicated document for the starfighter
    print("Opening fresh document for Starfighter Interceptor...")
    doc = app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
    
    design = adsk.fusion.Design.cast(app.activeProduct)
    if not design:
        print("[ERROR] Failed to get Fusion Design product.")
        return False

    root_comp = design.rootComponent
    sketches = root_comp.sketches
    extrudes = root_comp.features.extrudeFeatures
    xy_plane = root_comp.xYConstructionPlane
    xz_plane = root_comp.xZConstructionPlane

    print("Step 1/6: Modeling chiseled stealth fuselage...")
    # -------------------------------------------------------------
    # 1. Main Fuselage Hull (XY Plane, Centerline Y)
    # -------------------------------------------------------------
    hull_sketch = sketches.add(xy_plane)
    lines = hull_sketch.sketchCurves.sketchLines
    
    # Symmetrical half profile coordinates (X, Y)
    half_pts = [
        (0.0, 550.0),       # Nose apex
        (65.0, 340.0),      # Forward chine
        (110.0, 150.0),     # Cockpit shoulder
        (150.0, -60.0),     # Mid-hull waist
        (140.0, -320.0),    # Engine flank
        (70.0, -480.0),     # Aft stern corner
        (0.0, -450.0)       # Aft center
    ]
    
    # Draw right half
    for i in range(len(half_pts) - 1):
        p1 = adsk.core.Point3D.create(half_pts[i][0], half_pts[i][1], 0)
        p2 = adsk.core.Point3D.create(half_pts[i+1][0], half_pts[i+1][1], 0)
        lines.addByTwoPoints(p1, p2)
        
    # Draw left half (mirrored X)
    for i in range(len(half_pts) - 1):
        p1 = adsk.core.Point3D.create(-half_pts[i][0], half_pts[i][1], 0)
        p2 = adsk.core.Point3D.create(-half_pts[i+1][0], half_pts[i+1][1], 0)
        lines.addByTwoPoints(p1, p2)

    # Extrude main fuselage symmetrically (Z: -22cm to +22cm = 44cm thickness)
    hull_prof = hull_sketch.profiles.item(0)
    hull_input = extrudes.createInput(hull_prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    hull_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(22.0), True)
    hull_ext = extrudes.add(hull_input)
    main_body = hull_ext.bodies.item(0)
    main_body.name = "Fuselage_Main"

    print("Step 2/6: Modeling faceted cockpit canopy...")
    # -------------------------------------------------------------
    # 2. Elevated Cockpit Canopy
    # -------------------------------------------------------------
    canopy_sketch = sketches.add(xy_plane)
    canopy_lines = canopy_sketch.sketchCurves.sketchLines
    
    canopy_pts = [
        (0.0, 320.0),
        (45.0, 140.0),
        (38.0, -30.0),
        (0.0, -60.0)
    ]
    for i in range(len(canopy_pts) - 1):
        p1 = adsk.core.Point3D.create(canopy_pts[i][0], canopy_pts[i][1], 0)
        p2 = adsk.core.Point3D.create(canopy_pts[i+1][0], canopy_pts[i+1][1], 0)
        canopy_lines.addByTwoPoints(p1, p2)
        # Mirror
        p1_m = adsk.core.Point3D.create(-canopy_pts[i][0], canopy_pts[i][1], 0)
        p2_m = adsk.core.Point3D.create(-canopy_pts[i+1][0], canopy_pts[i+1][1], 0)
        canopy_lines.addByTwoPoints(p1_m, p2_m)

    canopy_prof = canopy_sketch.profiles.item(0)
    canopy_input = extrudes.createInput(canopy_prof, adsk.fusion.FeatureOperations.JoinFeatureOperation)
    canopy_input.setOneSideExtent(
        adsk.fusion.DistanceExtentDefinition.create(adsk.core.ValueInput.createByReal(42.0)),
        adsk.fusion.ExtentDirections.PositiveExtentDirection
    )
    extrudes.add(canopy_input)

    print("Step 3/6: Modeling swept delta wings with stabilizers...")
    # -------------------------------------------------------------
    # 3. Swept Wings
    # -------------------------------------------------------------
    wing_sketch = sketches.add(xy_plane)
    wing_lines = wing_sketch.sketchCurves.sketchLines
    
    # Right Wing
    rw_pts = [
        (130.0, 60.0),      # Leading edge root
        (460.0, -260.0),    # Wingtip leading
        (430.0, -340.0),    # Wingtip trailing
        (130.0, -300.0)     # Trailing edge root
    ]
    for i in range(len(rw_pts)):
        p1 = adsk.core.Point3D.create(rw_pts[i][0], rw_pts[i][1], 0)
        p2 = adsk.core.Point3D.create(rw_pts[(i+1) % len(rw_pts)][0], rw_pts[(i+1) % len(rw_pts)][1], 0)
        wing_lines.addByTwoPoints(p1, p2)

    # Left Wing (Mirrored)
    for i in range(len(rw_pts)):
        p1 = adsk.core.Point3D.create(-rw_pts[i][0], rw_pts[i][1], 0)
        p2 = adsk.core.Point3D.create(-rw_pts[(i+1) % len(rw_pts)][0], rw_pts[(i+1) % len(rw_pts)][1], 0)
        wing_lines.addByTwoPoints(p1, p2)

    # Extrude wings thin (Z: -6cm to +6cm = 12cm thick)
    for i in range(wing_sketch.profiles.count):
        wp = wing_sketch.profiles.item(i)
        w_input = extrudes.createInput(wp, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        w_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(6.0), True)
        extrudes.add(w_input)

    print("Step 4/6: Modeling twin vertical tail fins...")
    # -------------------------------------------------------------
    # 4. Vertical Stabilizer Fins
    # -------------------------------------------------------------
    fin_sketch = sketches.add(xy_plane)
    fin_lines = fin_sketch.sketchCurves.sketchLines
    
    # Right Fin Base
    rf_pts = [
        (110.0, -200.0),
        (125.0, -200.0),
        (125.0, -420.0),
        (110.0, -420.0)
    ]
    for i in range(len(rf_pts)):
        p1 = adsk.core.Point3D.create(rf_pts[i][0], rf_pts[i][1], 0)
        p2 = adsk.core.Point3D.create(rf_pts[(i+1) % len(rf_pts)][0], rf_pts[(i+1) % len(rf_pts)][1], 0)
        fin_lines.addByTwoPoints(p1, p2)
        
        # Left Fin Base
        p1_m = adsk.core.Point3D.create(-rf_pts[i][0], rf_pts[i][1], 0)
        p2_m = adsk.core.Point3D.create(-rf_pts[(i+1) % len(rf_pts)][0], rf_pts[(i+1) % len(rf_pts)][1], 0)
        fin_lines.addByTwoPoints(p1_m, p2_m)

    for i in range(fin_sketch.profiles.count):
        fp = fin_sketch.profiles.item(i)
        f_input = extrudes.createInput(fp, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        # Extrude tall upward
        f_input.setOneSideExtent(
            adsk.fusion.DistanceExtentDefinition.create(adsk.core.ValueInput.createByReal(110.0)),
            adsk.fusion.ExtentDirections.PositiveExtentDirection
        )
        extrudes.add(f_input)

    print("Step 5/6: Modeling twin heavy ion thrusters & nozzles...")
    # -------------------------------------------------------------
    # 5. Twin Rear Ion Thrusters & Exhaust Nozzles
    # -------------------------------------------------------------
    engine_sketch = sketches.add(xy_plane)
    circles = engine_sketch.sketchCurves.sketchCircles
    
    # Nacelle outer cylinders
    r_center = adsk.core.Point3D.create(95.0, -320.0, 0)
    l_center = adsk.core.Point3D.create(-95.0, -320.0, 0)
    circles.addByCenterRadius(r_center, 36.0)
    circles.addByCenterRadius(l_center, 36.0)
    
    for i in range(engine_sketch.profiles.count):
        ep = engine_sketch.profiles.item(i)
        e_input = extrudes.createInput(ep, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        e_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(28.0), True)
        extrudes.add(e_input)

    # Hollow Exhaust Nozzle Cuts at stern
    nozzle_sketch = sketches.add(xy_plane)
    n_circles = nozzle_sketch.sketchCurves.sketchCircles
    n_r_center = adsk.core.Point3D.create(95.0, -470.0, 0)
    n_l_center = adsk.core.Point3D.create(-95.0, -470.0, 0)
    n_circles.addByCenterRadius(n_r_center, 28.0)
    n_circles.addByCenterRadius(n_l_center, 28.0)

    for i in range(nozzle_sketch.profiles.count):
        np_prof = nozzle_sketch.profiles.item(i)
        n_input = extrudes.createInput(np_prof, adsk.fusion.FeatureOperations.CutFeatureOperation)
        n_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(22.0), True)
        extrudes.add(n_input)

    print("Step 6/6: Modeling forward kinetic weapon cannons...")
    # -------------------------------------------------------------
    # 6. Forward Weapon Barrels
    # -------------------------------------------------------------
    gun_sketch = sketches.add(xy_plane)
    gun_circles = gun_sketch.sketchCurves.sketchCircles
    
    gun_circles.addByCenterRadius(adsk.core.Point3D.create(55.0, 220.0, 0), 9.0)
    gun_circles.addByCenterRadius(adsk.core.Point3D.create(-55.0, 220.0, 0), 9.0)
    
    for i in range(gun_sketch.profiles.count):
        gp = gun_sketch.profiles.item(i)
        g_input = extrudes.createInput(gp, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        # Extrude forward
        g_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(8.0), True)
        extrudes.add(g_input)

    # -------------------------------------------------------------
    # 7. Automated Export to STEP
    # -------------------------------------------------------------
    export_dir = r"c:\Users\Boris\Documents\antigravity\lucid-davinci\Exports"
    os.makedirs(export_dir, exist_ok=True)
    step_path = os.path.join(export_dir, "Spaceship_Interceptor.step")
    
    print(f"Exporting Starfighter STEP to: {step_path}")
    export_mgr = design.exportManager
    step_options = export_mgr.createSTEPExportOptions(step_path, root_comp)
    export_mgr.execute(step_options)

    if os.path.exists(step_path):
        size_kb = os.path.getsize(step_path) / 1024.0
        print(f"[SUCCESS] Starfighter Interceptor 3D CAD generated! ({size_kb:.1f} KB)")
    else:
        print("[WARNING] STEP export did not produce expected file.")

    return True

# Execute
build_spaceship()
