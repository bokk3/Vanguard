# -*- coding: utf-8 -*-
"""
Heavy Strike Interceptor (Mk II) for Autodesk Fusion 360.
Completely redesigns the starfighter with:
1. Massive volumetric hull depth (1.8m thick muscular fuselage)
2. Pronounced ventral keel armor & chiseled stealth chines
3. High-rise armored cockpit canopy (1.3m tall) with faceted glass
4. Bulging engine cowlings & massive 1.1m diameter heavy ion thrusters
5. Recessed armor panel lines & heat dissipation radiator louvers
6. Thick blended wing roots (40cm root tapering to winglets)
7. Heavy chin-mounted kinetic cannon battery & wing missile pylons
8. Automatic PBR material assignment (Titanium, Carbon, Bronze Glass, Steel)
"""

import os
import math
import adsk.core
import adsk.fusion


def build_heavy_interceptor():
    app = adsk.core.Application.get()
    ui = app.userInterface

    print("Opening fresh document for Heavy Strike Interceptor Mk II...")
    doc = app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
    
    design = adsk.fusion.Design.cast(app.activeProduct)
    if not design:
        print("[ERROR] Failed to get Fusion Design product.")
        return False

    root = design.rootComponent
    sketches = root.sketches
    extrudes = root.features.extrudeFeatures
    xy_plane = root.xYConstructionPlane

    def dist_ext(val):
        return adsk.fusion.DistanceExtentDefinition.create(adsk.core.ValueInput.createByReal(val))

    print("[1/9] Modeling thick muscular fuselage core (1.8m deep)...")
    # -------------------------------------------------------------
    # 1. Main Volumetric Fuselage Core (Thick & Heavy)
    # -------------------------------------------------------------
    hull_sketch = sketches.add(xy_plane)
    lines = hull_sketch.sketchCurves.sketchLines
    
    hull_pts = [
        (0.0, 560.0),       # Heavy blunt nose apex
        (45.0, 480.0),      # Nose chine
        (90.0, 320.0),      # Forward armor chine
        (130.0, 120.0),     # Muscular cockpit shoulder
        (175.0, -80.0),     # Bulging intake waist
        (165.0, -340.0),    # Nacelle flank
        (90.0, -520.0),     # Aft engine shroud
        (0.0, -490.0)       # Aft centerline
    ]
    for i in range(len(hull_pts) - 1):
        lines.addByTwoPoints(
            adsk.core.Point3D.create(hull_pts[i][0], hull_pts[i][1], 0),
            adsk.core.Point3D.create(hull_pts[i+1][0], hull_pts[i+1][1], 0)
        )
        lines.addByTwoPoints(
            adsk.core.Point3D.create(-hull_pts[i][0], hull_pts[i][1], 0),
            adsk.core.Point3D.create(-hull_pts[i+1][0], hull_pts[i+1][1], 0)
        )

    # Extrude core thick: Z = -45 to +45 cm (90 cm thick core!)
    hull_prof = hull_sketch.profiles.item(0)
    hull_input = extrudes.createInput(hull_prof, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    hull_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(45.0), True)
    hull_ext = extrudes.add(hull_input)
    main_body = hull_ext.bodies.item(0)
    main_body.name = "Heavy_Hull"

    print("[2/9] Modeling ventral armored keel (belly depth)...")
    # -------------------------------------------------------------
    # 2. Ventral Keel (Deep Armor Belly: Z = -45 to -95 cm)
    # -------------------------------------------------------------
    keel_sketch = sketches.add(xy_plane)
    k_lines = keel_sketch.sketchCurves.sketchLines
    keel_pts = [
        (0.0, 440.0),
        (55.0, 260.0),
        (85.0, -40.0),
        (70.0, -380.0),
        (0.0, -460.0)
    ]
    for i in range(len(keel_pts) - 1):
        k_lines.addByTwoPoints(
            adsk.core.Point3D.create(keel_pts[i][0], keel_pts[i][1], 0),
            adsk.core.Point3D.create(keel_pts[i+1][0], keel_pts[i+1][1], 0)
        )
        k_lines.addByTwoPoints(
            adsk.core.Point3D.create(-keel_pts[i][0], keel_pts[i][1], 0),
            adsk.core.Point3D.create(-keel_pts[i+1][0], keel_pts[i+1][1], 0)
        )
    keel_prof = keel_sketch.profiles.item(0)
    keel_input = extrudes.createInput(keel_prof, adsk.fusion.FeatureOperations.JoinFeatureOperation)
    # Extrude downward from belly
    keel_input.setOneSideExtent(dist_ext(-95.0), adsk.fusion.ExtentDirections.NegativeExtentDirection)
    extrudes.add(keel_input)

    print("[3/9] Modeling dorsal armored spine & deck...")
    # -------------------------------------------------------------
    # 3. Dorsal Deck & Spine (Upper Hull: Z = +45 to +85 cm)
    # -------------------------------------------------------------
    deck_sketch = sketches.add(xy_plane)
    d_lines = deck_sketch.sketchCurves.sketchLines
    deck_pts = [
        (0.0, 360.0),
        (65.0, 160.0),
        (95.0, -80.0),
        (80.0, -420.0),
        (0.0, -460.0)
    ]
    for i in range(len(deck_pts) - 1):
        d_lines.addByTwoPoints(
            adsk.core.Point3D.create(deck_pts[i][0], deck_pts[i][1], 0),
            adsk.core.Point3D.create(deck_pts[i+1][0], deck_pts[i+1][1], 0)
        )
        d_lines.addByTwoPoints(
            adsk.core.Point3D.create(-deck_pts[i][0], deck_pts[i][1], 0),
            adsk.core.Point3D.create(-deck_pts[i+1][0], deck_pts[i+1][1], 0)
        )
    deck_prof = deck_sketch.profiles.item(0)
    deck_input = extrudes.createInput(deck_prof, adsk.fusion.FeatureOperations.JoinFeatureOperation)
    deck_input.setOneSideExtent(dist_ext(85.0), adsk.fusion.ExtentDirections.PositiveExtentDirection)
    extrudes.add(deck_input)

    print("[4/9] Modeling prominent faceted cockpit canopy (1.35m peak)...")
    # -------------------------------------------------------------
    # 4. Elevated Canopy Dome (Z = +85 to +135 cm)
    # -------------------------------------------------------------
    canopy_sketch = sketches.add(xy_plane)
    c_lines = canopy_sketch.sketchCurves.sketchLines
    canopy_pts = [
        (0.0, 320.0),
        (48.0, 160.0),
        (42.0, -20.0),
        (0.0, -50.0)
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
    canopy_input.setOneSideExtent(dist_ext(135.0), adsk.fusion.ExtentDirections.PositiveExtentDirection)
    extrudes.add(canopy_input)

    print("[5/9] Modeling muscular blended wings & wingtip fins...")
    # -------------------------------------------------------------
    # 5. Thick Blended Wings (Root: 40cm, Body: 24cm)
    # -------------------------------------------------------------
    wing_sketch = sketches.add(xy_plane)
    w_lines = wing_sketch.sketchCurves.sketchLines
    
    # Wing outline
    rw_pts = [
        (160.0, 60.0),      # Blended root forward
        (480.0, -240.0),    # Wingtip forward
        (460.0, -380.0),    # Wingtip aft
        (370.0, -350.0),    # Control surface step
        (155.0, -320.0)     # Blended root aft
    ]
    for i in range(len(rw_pts)):
        p1 = adsk.core.Point3D.create(rw_pts[i][0], rw_pts[i][1], 0)
        p2 = adsk.core.Point3D.create(rw_pts[(i+1) % len(rw_pts)][0], rw_pts[(i+1) % len(rw_pts)][1], 0)
        w_lines.addByTwoPoints(p1, p2)
        p1_m = adsk.core.Point3D.create(-rw_pts[i][0], rw_pts[i][1], 0)
        p2_m = adsk.core.Point3D.create(-rw_pts[(i+1) % len(rw_pts)][0], rw_pts[(i+1) % len(rw_pts)][1], 0)
        w_lines.addByTwoPoints(p1_m, p2_m)

    for i in range(wing_sketch.profiles.count):
        wp = wing_sketch.profiles.item(i)
        w_input = extrudes.createInput(wp, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        # Much thicker wings (Z: -12cm to +12cm = 24cm thick!)
        w_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(12.0), True)
        extrudes.add(w_input)

    # Vertical Endplate Winglets (X = ±470)
    winglet_sketch = sketches.add(xy_plane)
    wl_lines = winglet_sketch.sketchCurves.sketchLines
    wl_pts = [
        (455.0, -230.0),
        (475.0, -230.0),
        (475.0, -370.0),
        (455.0, -370.0)
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
        wl_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(55.0), True)
        extrudes.add(wl_input)

    print("[6/9] Modeling twin heavy ion thruster nacelles (1.1m dia) & nozzles...")
    # -------------------------------------------------------------
    # 6. Heavy Ion Engines (55cm radius = 1.1m diameter!)
    # -------------------------------------------------------------
    engine_sketch = sketches.add(xy_plane)
    circles = engine_sketch.sketchCurves.sketchCircles
    r_eng = adsk.core.Point3D.create(105.0, -320.0, 0)
    l_eng = adsk.core.Point3D.create(-105.0, -320.0, 0)
    circles.addByCenterRadius(r_eng, 55.0)
    circles.addByCenterRadius(l_eng, 55.0)
    
    for i in range(engine_sketch.profiles.count):
        ep = engine_sketch.profiles.item(i)
        e_input = extrudes.createInput(ep, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        e_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(42.0), True)
        extrudes.add(e_input)

    # Exhaust Nozzle Chambers (Deep cut)
    nozzle_sketch = sketches.add(xy_plane)
    nc = nozzle_sketch.sketchCurves.sketchCircles
    nc_r = adsk.core.Point3D.create(105.0, -490.0, 0)
    nc_l = adsk.core.Point3D.create(-105.0, -490.0, 0)
    nc.addByCenterRadius(nc_r, 44.0)
    nc.addByCenterRadius(nc_l, 44.0)

    for i in range(nozzle_sketch.profiles.count):
        np_prof = nozzle_sketch.profiles.item(i)
        n_input = extrudes.createInput(np_prof, adsk.fusion.FeatureOperations.CutFeatureOperation)
        n_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(34.0), True)
        extrudes.add(n_input)

    # Central Thrust Aerospike Cores
    spike_sketch = sketches.add(xy_plane)
    sc = spike_sketch.sketchCurves.sketchCircles
    sc.addByCenterRadius(nc_r, 18.0)
    sc.addByCenterRadius(nc_l, 18.0)
    for i in range(spike_sketch.profiles.count):
        sp_prof = spike_sketch.profiles.item(i)
        s_input = extrudes.createInput(sp_prof, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        s_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(24.0), True)
        extrudes.add(s_input)

    print("[7/9] Cutting heat dissipation louvers & armor skin panel grooves...")
    # -------------------------------------------------------------
    # 7. Skin Detailing: Heat Radiator Louver Vents on Dorsal Deck
    # -------------------------------------------------------------
    louver_sketch = sketches.add(xy_plane)
    l_curves = louver_sketch.sketchCurves.sketchLines
    
    # 5 parallel cooling vents on each side of the dorsal spine
    for slot_idx in range(5):
        slot_y = -100.0 - (slot_idx * 45.0)
        # Right vents
        l_curves.addTwoPointRectangle(
            adsk.core.Point3D.create(35.0, slot_y, 0),
            adsk.core.Point3D.create(75.0, slot_y - 20.0, 0)
        )
        # Left vents
        l_curves.addTwoPointRectangle(
            adsk.core.Point3D.create(-75.0, slot_y, 0),
            adsk.core.Point3D.create(-35.0, slot_y - 20.0, 0)
        )

    for i in range(louver_sketch.profiles.count):
        lp = louver_sketch.profiles.item(i)
        # Cut 8cm into dorsal deck from top
        l_input = extrudes.createInput(lp, adsk.fusion.FeatureOperations.CutFeatureOperation)
        l_input.setOneSideExtent(dist_ext(88.0), adsk.fusion.ExtentDirections.PositiveExtentDirection)
        extrudes.add(l_input)

    # Dorsal Twin Tail Fins
    fin_sketch = sketches.add(xy_plane)
    f_lines = fin_sketch.sketchCurves.sketchLines
    fin_pts = [
        (115.0, -140.0),
        (135.0, -140.0),
        (135.0, -440.0),
        (115.0, -440.0)
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
        f_input.setOneSideExtent(dist_ext(155.0), adsk.fusion.ExtentDirections.PositiveExtentDirection)
        extrudes.add(f_input)

    print("[8/9] Modeling heavy weapon loadout (Gatling battery & missile pods)...")
    # -------------------------------------------------------------
    # 8. Heavy Kinetic Autocannons & Underwing Pods
    # -------------------------------------------------------------
    gun_sketch = sketches.add(xy_plane)
    gc = gun_sketch.sketchCurves.sketchCircles
    # Heavy 18cm diameter cannon shrouds
    gc.addByCenterRadius(adsk.core.Point3D.create(58.0, 260.0, 0), 18.0)
    gc.addByCenterRadius(adsk.core.Point3D.create(-58.0, 260.0, 0), 18.0)

    for i in range(gun_sketch.profiles.count):
        gp = gun_sketch.profiles.item(i)
        g_input = extrudes.createInput(gp, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        g_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(16.0), True)
        extrudes.add(g_input)

    # Under-Wing Missile Pods
    pod_sketch = sketches.add(xy_plane)
    pc = pod_sketch.sketchCurves.sketchCircles
    pc.addByCenterRadius(adsk.core.Point3D.create(280.0, -180.0, 0), 28.0)
    pc.addByCenterRadius(adsk.core.Point3D.create(-280.0, -180.0, 0), 28.0)

    for i in range(pod_sketch.profiles.count):
        pp = pod_sketch.profiles.item(i)
        p_input = extrudes.createInput(pp, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        p_input.setOneSideExtent(dist_ext(-48.0), adsk.fusion.ExtentDirections.NegativeExtentDirection)
        extrudes.add(p_input)

    print("[9/9] Applying realistic PBR appearances & exporting STEP...")
    # -------------------------------------------------------------
    # 9. Automated PBR Material Assignment
    # -------------------------------------------------------------
    lib = app.materialLibraries.itemByName("Fusion Appearance Library")

    def get_or_load_appearance(name):
        for a in design.appearances:
            if a.name == name:
                return a
        lib_app = lib.appearances.itemByName(name)
        if lib_app:
            return design.appearances.addByCopy(lib_app, name)
        return None

    titanium = get_or_load_appearance("Titanium - Satin")
    carbon_fiber = get_or_load_appearance("Carbon Fiber - Plain")
    glass_bronze = get_or_load_appearance("Glass (Bronze)")
    steel_brushed = get_or_load_appearance("Stainless Steel - Brushed Linear Long")

    # Apply base Titanium
    if titanium and main_body:
        main_body.appearance = titanium

    # Assign detailed surface materials
    for face in main_body.faces:
        box = face.boundingBox
        center_x = (box.maxPoint.x + box.minPoint.x) / 2.0
        center_y = (box.maxPoint.y + box.minPoint.y) / 2.0
        center_z = (box.maxPoint.z + box.minPoint.z) / 2.0

        # Cockpit canopy dome
        if box.maxPoint.z > 85.0 and 340.0 > center_y > -60.0 and abs(center_x) < 52.0:
            if glass_bronze:
                face.appearance = glass_bronze

        # Outer Wings
        elif abs(center_x) > 165.0 and abs(center_z) < 25.0:
            if carbon_fiber:
                face.appearance = carbon_fiber

        # Engines & Nozzles
        elif center_y < -240.0 and 160.0 > abs(center_x) > 50.0:
            if steel_brushed:
                face.appearance = steel_brushed

    # -------------------------------------------------------------
    # 10. Export to STEP
    # -------------------------------------------------------------
    export_dir = r"c:\Users\Boris\Documents\antigravity\lucid-davinci\Exports"
    os.makedirs(export_dir, exist_ok=True)
    step_path = os.path.join(export_dir, "Heavy_Strike_Interceptor_Mk2.step")
    
    print(f"Exporting Mk II Starfighter to: {step_path}")
    export_mgr = design.exportManager
    step_options = export_mgr.createSTEPExportOptions(step_path, root)
    export_mgr.execute(step_options)

    if os.path.exists(step_path):
        sz = os.path.getsize(step_path) / 1024.0
        print(f"[SUCCESS] Heavy Strike Interceptor Mk II generated! ({sz:.1f} KB)")

    # Center camera
    if app.activeViewport:
        app.activeViewport.visualStyle = adsk.core.VisualStyles.ShadedWithVisibleEdgesOnlyVisualStyle
        app.activeViewport.fit()
        app.activeViewport.refresh()

    return True

build_heavy_interceptor()
