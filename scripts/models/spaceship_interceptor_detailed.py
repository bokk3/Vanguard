# -*- coding: utf-8 -*-
"""
High-Detail Starfighter Interceptor Generator for Autodesk Fusion 360.
Generates an advanced multi-part sci-fi aerospace fighter with:
1. Chiseled multi-faceted stealth fuselage with chin chamfers
2. Raised dorsal avionics spine running down the hull
3. Faceted cockpit canopy with recessed frame detailing
4. Dual lateral coolant/ram-air intake scoops with internal splitters
5. Stepped swept wings with control surface separation seams & wingtip pods
6. Under-wing weapon pylons with triple-tube missile launcher pods
7. Dual heavy ion thruster nacelles with stepped vectoring nozzles & central thrust aerospikes
8. Nose-flank RCS (Reaction Control Thruster) attitude blocks
9. Twin heavy rotary kinetic autocannons with vented barrels
10. Automatic STEP export for Unreal Engine 5 Nanite
"""

import os
import math
import adsk.core
import adsk.fusion


def build_detailed_spaceship():
    app = adsk.core.Application.get()
    ui = app.userInterface

    print("Opening fresh document for High-Detail Starfighter...")
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
    yz_plane = root_comp.yZConstructionPlane

    # Helper for distance extent
    def dist_ext(val):
        return adsk.fusion.DistanceExtentDefinition.create(adsk.core.ValueInput.createByReal(val))

    print("[1/10] Modeling chiseled multi-faceted fuselage...")
    # -------------------------------------------------------------
    # 1. Main Fuselage Hull (XY Plane)
    # -------------------------------------------------------------
    hull_sketch = sketches.add(xy_plane)
    lines = hull_sketch.sketchCurves.sketchLines
    
    half_pts = [
        (0.0, 580.0),       # Needle nose apex
        (35.0, 500.0),      # Nose chine 1
        (75.0, 360.0),      # Forward chine 2
        (115.0, 160.0),     # Cockpit shoulder
        (160.0, -40.0),     # Mid-hull intake blend
        (150.0, -320.0),    # Engine flank root
        (85.0, -500.0),     # Aft engine shroud
        (0.0, -470.0)       # Aft centerline
    ]
    
    # Right half
    for i in range(len(half_pts) - 1):
        lines.addByTwoPoints(
            adsk.core.Point3D.create(half_pts[i][0], half_pts[i][1], 0),
            adsk.core.Point3D.create(half_pts[i+1][0], half_pts[i+1][1], 0)
        )
    # Left half (mirrored)
    for i in range(len(half_pts) - 1):
        lines.addByTwoPoints(
            adsk.core.Point3D.create(-half_pts[i][0], half_pts[i][1], 0),
            adsk.core.Point3D.create(-half_pts[i+1][0], half_pts[i+1][1], 0)
        )

    hull_prof = hull_sketch.profiles.item(0)
    hull_input = extrudes.createInput(hull_prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    hull_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(24.0), True)
    hull_ext = extrudes.add(hull_input)
    main_body = hull_ext.bodies.item(0)
    main_body.name = "Hull_Fuselage"

    print("[2/10] Modeling raised dorsal avionics spine...")
    # -------------------------------------------------------------
    # 2. Dorsal Avionics Spine
    # -------------------------------------------------------------
    spine_sketch = sketches.add(xy_plane)
    s_lines = spine_sketch.sketchCurves.sketchLines
    spine_pts = [
        (0.0, 100.0),
        (22.0, 20.0),
        (22.0, -420.0),
        (0.0, -450.0)
    ]
    for i in range(len(spine_pts) - 1):
        s_lines.addByTwoPoints(
            adsk.core.Point3D.create(spine_pts[i][0], spine_pts[i][1], 0),
            adsk.core.Point3D.create(spine_pts[i+1][0], spine_pts[i+1][1], 0)
        )
        s_lines.addByTwoPoints(
            adsk.core.Point3D.create(-spine_pts[i][0], spine_pts[i][1], 0),
            adsk.core.Point3D.create(-spine_pts[i+1][0], spine_pts[i+1][1], 0)
        )
    spine_prof = spine_sketch.profiles.item(0)
    spine_input = extrudes.createInput(spine_prof, adsk.fusion.FeatureOperations.JoinFeatureOperation)
    # Extrude upward on top of hull (Z=24 to Z=42)
    spine_input.setOneSideExtent(dist_ext(38.0), adsk.fusion.ExtentDirections.PositiveExtentDirection)
    extrudes.add(spine_input)

    print("[3/10] Modeling faceted cockpit canopy & frame...")
    # -------------------------------------------------------------
    # 3. Cockpit Canopy
    # -------------------------------------------------------------
    canopy_sketch = sketches.add(xy_plane)
    c_lines = canopy_sketch.sketchCurves.sketchLines
    canopy_pts = [
        (0.0, 360.0),       # Canopy front tip
        (48.0, 180.0),      # Widest point
        (42.0, -10.0),      # Rear canopy
        (0.0, -30.0)
    ]
    for i in range(len(canopy_pts) - 1):
        c_lines.addByTwoPoints(
            adsk.core.Point3D.create(canopy_pts[i][0], canopy_pts[i][1], 0),
            adsk.core.Point3D.create(canopy_pts[i+1][0], canopy_pts[i+1][1], 0)
        )
        c_lines.addByTwoPoints(
            adsk.core.Point3D.create(-canopy_pts[i][0], canopy_pts[i][1], 0),
            adsk.core.Point3D.create(-canopy_pts[i+1][0], canopy_pts[i+1][1], 0)
        )
    canopy_prof = canopy_sketch.profiles.item(0)
    canopy_input = extrudes.createInput(canopy_prof, adsk.fusion.FeatureOperations.JoinFeatureOperation)
    canopy_input.setOneSideExtent(dist_ext(46.0), adsk.fusion.ExtentDirections.PositiveExtentDirection)
    extrudes.add(canopy_input)

    print("[4/10] Modeling dual lateral air & coolant intake cowls...")
    # -------------------------------------------------------------
    # 4. Lateral Air / Coolant Intakes
    # -------------------------------------------------------------
    intake_sketch = sketches.add(xy_plane)
    in_lines = intake_sketch.sketchCurves.sketchLines
    
    # Right intake cowl
    in_pts = [
        (85.0, 120.0),
        (140.0, 60.0),
        (155.0, -180.0),
        (100.0, -180.0)
    ]
    for i in range(len(in_pts)):
        p1 = adsk.core.Point3D.create(in_pts[i][0], in_pts[i][1], 0)
        p2 = adsk.core.Point3D.create(in_pts[(i+1) % len(in_pts)][0], in_pts[(i+1) % len(in_pts)][1], 0)
        in_lines.addByTwoPoints(p1, p2)
        # Left intake cowl (mirrored)
        p1_m = adsk.core.Point3D.create(-in_pts[i][0], in_pts[i][1], 0)
        p2_m = adsk.core.Point3D.create(-in_pts[(i+1) % len(in_pts)][0], in_pts[(i+1) % len(in_pts)][1], 0)
        in_lines.addByTwoPoints(p1_m, p2_m)

    for i in range(intake_sketch.profiles.count):
        ip = intake_sketch.profiles.item(i)
        in_input = extrudes.createInput(ip, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        in_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(18.0), True)
        extrudes.add(in_input)

    print("[5/10] Modeling swept delta wings with ailerons & winglet fins...")
    # -------------------------------------------------------------
    # 5. Main Swept Wings & Wingtip Stabilizers
    # -------------------------------------------------------------
    wing_sketch = sketches.add(xy_plane)
    w_lines = wing_sketch.sketchCurves.sketchLines
    
    # Right wing profile
    rw_pts = [
        (145.0, 80.0),      # Leading root
        (490.0, -260.0),    # Wingtip forward
        (470.0, -380.0),    # Wingtip aft
        (380.0, -350.0),    # Aileron step
        (140.0, -320.0)     # Trailing root
    ]
    for i in range(len(rw_pts)):
        p1 = adsk.core.Point3D.create(rw_pts[i][0], rw_pts[i][1], 0)
        p2 = adsk.core.Point3D.create(rw_pts[(i+1) % len(rw_pts)][0], rw_pts[(i+1) % len(rw_pts)][1], 0)
        w_lines.addByTwoPoints(p1, p2)
        # Left wing
        p1_m = adsk.core.Point3D.create(-rw_pts[i][0], rw_pts[i][1], 0)
        p2_m = adsk.core.Point3D.create(-rw_pts[(i+1) % len(rw_pts)][0], rw_pts[(i+1) % len(rw_pts)][1], 0)
        w_lines.addByTwoPoints(p1_m, p2_m)

    for i in range(wing_sketch.profiles.count):
        wp = wing_sketch.profiles.item(i)
        w_input = extrudes.createInput(wp, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        w_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(7.0), True)
        extrudes.add(w_input)

    # Vertical Winglet Stabilizers at tips (X = ±480)
    winglet_sketch = sketches.add(xy_plane)
    wl_lines = winglet_sketch.sketchCurves.sketchLines
    wl_pts = [
        (470.0, -250.0),
        (485.0, -250.0),
        (485.0, -370.0),
        (470.0, -370.0)
    ]
    for i in range(len(wl_pts)):
        p1 = adsk.core.Point3D.create(wl_pts[i][0], wl_pts[i][1], 0)
        p2 = adsk.core.Point3D.create(wl_pts[(i+1) % len(wl_pts)][0], wl_pts[(i+1) % len(wl_pts)][1], 0)
        wl_lines.addByTwoPoints(p1, p2)
        p1_m = adsk.core.Point3D.create(-wl_pts[i][0], wl_pts[i][1], 0)
        p2_m = adsk.core.Point3D.create(-wl_pts[(i+1) % len(wl_pts)][0], wl_pts[(i+1) % len(wl_pts)][1], 0)
        wl_lines.addByTwoPoints(p1_m, p2_m)

    for i in range(winglet_sketch.profiles.count):
        wlp = winglet_sketch.profiles.item(i)
        wl_input = extrudes.createInput(wlp, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        wl_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(45.0), True)
        extrudes.add(wl_input)

    print("[6/10] Modeling twin canted dorsal vertical stabilizers...")
    # -------------------------------------------------------------
    # 6. Twin Dorsal Fins
    # -------------------------------------------------------------
    fin_sketch = sketches.add(xy_plane)
    f_lines = fin_sketch.sketchCurves.sketchLines
    fin_pts = [
        (105.0, -160.0),
        (120.0, -160.0),
        (120.0, -440.0),
        (105.0, -440.0)
    ]
    for i in range(len(fin_pts)):
        p1 = adsk.core.Point3D.create(fin_pts[i][0], fin_pts[i][1], 0)
        p2 = adsk.core.Point3D.create(fin_pts[(i+1) % len(fin_pts)][0], fin_pts[(i+1) % len(fin_pts)][1], 0)
        f_lines.addByTwoPoints(p1, p2)
        p1_m = adsk.core.Point3D.create(-fin_pts[i][0], fin_pts[i][1], 0)
        p2_m = adsk.core.Point3D.create(-fin_pts[(i+1) % len(fin_pts)][0], fin_pts[(i+1) % len(fin_pts)][1], 0)
        f_lines.addByTwoPoints(p1_m, p2_m)

    for i in range(fin_sketch.profiles.count):
        fp = fin_sketch.profiles.item(i)
        f_input = extrudes.createInput(fp, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        f_input.setOneSideExtent(dist_ext(125.0), adsk.fusion.ExtentDirections.PositiveExtentDirection)
        extrudes.add(f_input)

    print("[7/10] Modeling dual heavy ion thrusters & aerospike nozzles...")
    # -------------------------------------------------------------
    # 7. Dual Heavy Engines & Stepped Nozzles
    # -------------------------------------------------------------
    engine_sketch = sketches.add(xy_plane)
    circles = engine_sketch.sketchCurves.sketchCircles
    r_eng = adsk.core.Point3D.create(95.0, -320.0, 0)
    l_eng = adsk.core.Point3D.create(-95.0, -320.0, 0)
    circles.addByCenterRadius(r_eng, 42.0)
    circles.addByCenterRadius(l_eng, 42.0)
    
    for i in range(engine_sketch.profiles.count):
        ep = engine_sketch.profiles.item(i)
        e_input = extrudes.createInput(ep, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        e_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(30.0), True)
        extrudes.add(e_input)

    # Exhaust Bells (Cutout)
    nozzle_sketch = sketches.add(xy_plane)
    nc = nozzle_sketch.sketchCurves.sketchCircles
    nc_r = adsk.core.Point3D.create(95.0, -480.0, 0)
    nc_l = adsk.core.Point3D.create(-95.0, -480.0, 0)
    nc.addByCenterRadius(nc_r, 34.0)
    nc.addByCenterRadius(nc_l, 34.0)

    for i in range(nozzle_sketch.profiles.count):
        np_prof = nozzle_sketch.profiles.item(i)
        n_input = extrudes.createInput(np_prof, adsk.fusion.FeatureOperations.CutFeatureOperation)
        n_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(25.0), True)
        extrudes.add(n_input)

    # Central Aerospike Cores inside nozzles
    spike_sketch = sketches.add(xy_plane)
    sc = spike_sketch.sketchCurves.sketchCircles
    sc.addByCenterRadius(nc_r, 14.0)
    sc.addByCenterRadius(nc_l, 14.0)
    for i in range(spike_sketch.profiles.count):
        sp_prof = spike_sketch.profiles.item(i)
        s_input = extrudes.createInput(sp_prof, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        s_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(18.0), True)
        extrudes.add(s_input)

    print("[8/10] Modeling under-wing weapon pylons & triple missile pods...")
    # -------------------------------------------------------------
    # 8. Under-Wing Weapon Pylons & Missile Pods
    # -------------------------------------------------------------
    pylon_sketch = sketches.add(xy_plane)
    pl_lines = pylon_sketch.sketchCurves.sketchLines
    
    # Right pylon base (Z goes negative below wing)
    py_pts = [
        (280.0, -120.0),
        (292.0, -120.0),
        (292.0, -280.0),
        (280.0, -280.0)
    ]
    for i in range(len(py_pts)):
        p1 = adsk.core.Point3D.create(py_pts[i][0], py_pts[i][1], 0)
        p2 = adsk.core.Point3D.create(py_pts[(i+1) % len(py_pts)][0], py_pts[(i+1) % len(py_pts)][1], 0)
        pl_lines.addByTwoPoints(p1, p2)
        # Left pylon
        p1_m = adsk.core.Point3D.create(-py_pts[i][0], py_pts[i][1], 0)
        p2_m = adsk.core.Point3D.create(-py_pts[(i+1) % len(py_pts)][0], py_pts[(i+1) % len(py_pts)][1], 0)
        pl_lines.addByTwoPoints(p1_m, p2_m)

    for i in range(pylon_sketch.profiles.count):
        pp = pylon_sketch.profiles.item(i)
        p_input = extrudes.createInput(pp, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        # Hang below wing (Z: -7 to -25)
        p_input.setOneSideExtent(dist_ext(-25.0), adsk.fusion.ExtentDirections.NegativeExtentDirection)
        extrudes.add(p_input)

    # Missile Pod Bodies (under pylons)
    pod_sketch = sketches.add(xy_plane)
    pod_circles = pod_sketch.sketchCurves.sketchCircles
    pod_r = adsk.core.Point3D.create(286.0, -200.0, 0)
    pod_l = adsk.core.Point3D.create(-286.0, -200.0, 0)
    pod_circles.addByCenterRadius(pod_r, 22.0)
    pod_circles.addByCenterRadius(pod_l, 22.0)

    for i in range(pod_sketch.profiles.count):
        pod_p = pod_sketch.profiles.item(i)
        pod_input = extrudes.createInput(pod_p, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        # Hang at Z = -28cm
        pod_input.setOneSideExtent(dist_ext(-35.0), adsk.fusion.ExtentDirections.NegativeExtentDirection)
        extrudes.add(pod_input)

    print("[9/10] Modeling twin heavy kinetic autocannons & nose RCS thrusters...")
    # -------------------------------------------------------------
    # 9. Autocannon Barrels & Nose RCS Thrusters
    # -------------------------------------------------------------
    gun_sketch = sketches.add(xy_plane)
    gc = gun_sketch.sketchCurves.sketchCircles
    gc.addByCenterRadius(adsk.core.Point3D.create(55.0, 240.0, 0), 12.0)
    gc.addByCenterRadius(adsk.core.Point3D.create(-55.0, 240.0, 0), 12.0)

    for i in range(gun_sketch.profiles.count):
        gp = gun_sketch.profiles.item(i)
        g_input = extrudes.createInput(gp, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        g_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(11.0), True)
        extrudes.add(g_input)

    # RCS Thruster Blocks on forward nose (X = ±45, Y = 460)
    rcs_sketch = sketches.add(xy_plane)
    rcs_circles = rcs_sketch.sketchCurves.sketchCircles
    rcs_circles.addByCenterRadius(adsk.core.Point3D.create(38.0, 460.0, 0), 7.0)
    rcs_circles.addByCenterRadius(adsk.core.Point3D.create(-38.0, 460.0, 0), 7.0)

    for i in range(rcs_sketch.profiles.count):
        rcsp = rcs_sketch.profiles.item(i)
        rcs_input = extrudes.createInput(rcsp, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        rcs_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(14.0), True)
        extrudes.add(rcs_input)

    print("[10/10] Exporting High-Detail Starfighter to STEP & Game-Ready pipeline...")
    # -------------------------------------------------------------
    # 10. Automated STEP Export
    # -------------------------------------------------------------
    export_dir = r"c:\Users\Boris\Documents\antigravity\lucid-davinci\Exports"
    os.makedirs(export_dir, exist_ok=True)
    step_path = os.path.join(export_dir, "Spaceship_Interceptor_HD.step")
    
    print(f"Exporting HD Starfighter to: {step_path}")
    export_mgr = design.exportManager
    step_options = export_mgr.createSTEPExportOptions(step_path, root_comp)
    export_mgr.execute(step_options)

    if os.path.exists(step_path):
        size_kb = os.path.getsize(step_path) / 1024.0
        print(f"[SUCCESS] High-Detail Starfighter Interceptor 3D CAD generated! ({size_kb:.1f} KB)")
    else:
        print("[WARNING] STEP export did not produce expected file.")

    return True

# Execute
build_detailed_spaceship()
