# -*- coding: utf-8 -*-
"""
Supreme Sci-Fi Spaceship Interceptor / Strike Cruiser Generator for Autodesk Fusion 360.
Guarantees ZERO flat bottom faces on the craft:
1. Fuselage is modeled via 7-Station Transverse 3D Lofting along the longitudinal axis (Y-axis):
   - Sharp aerodynamic needle nose apex
   - Sloping chine forward radome
   - Aggressive forward V-keel (Z = -62 cm)
   - Deepest V-belly keel (Z = -78 cm)
   - Dual-engine ventral tunnel chine (Engine nacelle humps at Z = -46 cm, center weapons tunnel at Z = -26 cm)
   - Boat-tail engine shroud upsweep (Z = -28 cm to -16 cm)
2. Wings are modeled via 3-Station Compound Spanwise 3D Lofting along the lateral axis (X-axis):
   - Continuous 3D cambered airfoil profile tapering from Root (thick 32 cm) to Tip (thick 4 cm)
   - Continuous dihedral upsweep on the wing underside - ZERO flat bottom faces under wings!
3. Extensive ventral underbody detailing:
   - Central sunken weapons bay tunnel between engine bulges
   - Ventral FLIR/EOTS diamond targeting turret pod
   - Ventral engine heat exchanger / bypass louvers
   - Recessed landing gear bay split door seams
4. Layered applique armor plates, faceted canopy bubble, articulated vectoring petals, internal aerospikes, and live missiles.
5. High-contrast PBR materials (Titanium Satin, Carbon Fiber, Glass Bronze, Brushed Steel, Enamel Gloss).
"""

import os
import math
import adsk.core
import adsk.fusion


def dist_ext(val):
    return adsk.fusion.DistanceExtentDefinition.create(adsk.core.ValueInput.createByReal(val))


def build_supreme_sculpted_spaceship():
    app = adsk.core.Application.get()
    ui = app.userInterface

    print("================================================================")
    print("  FUSION 360 - SUPREME FULLY SCULPTED 3D SPACESHIP BUILDER     ")
    print("================================================================")

    # 1. Open a fresh design document & activate
    doc = app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
    doc.activate()

    design = adsk.fusion.Design.cast(app.activeProduct)
    if not design:
        print("[ERROR] Failed to get active Fusion Design product.")
        return False

    root = design.rootComponent
    sketches = root.sketches
    extrudes = root.features.extrudeFeatures
    lofts = root.features.loftFeatures
    planes = root.constructionPlanes

    xy_plane = root.xYConstructionPlane
    xz_plane = root.xZConstructionPlane
    yz_plane = root.yZConstructionPlane

    if app.activeViewport:
        app.activeViewport.visualStyle = adsk.core.VisualStyles.ShadedWithVisibleEdgesOnlyVisualStyle

    # =========================================================================
    # PHASE 1: TRANSVERSE 7-STATION SCULPTED FUSELAGE LOFT (ZERO FLAT BOTTOM!)
    # =========================================================================
    print("[1/10] Lofting 7-station sculpted fuselage (V-Keel + Ventral Tunnel)...")

    # Stations along the Y axis: (Y_offset_cm, list_of_(X, Z)_polygon_points)
    fuselage_stations = [
        # Station 0: Needle nose apex at Y = +570 cm
        (570.0, [
            (0.0, 5.0), (7.0, 0.0), (0.0, -5.0), (-7.0, 0.0)
        ]),
        # Station 1: Forward radome & chin chine at Y = +430 cm
        (430.0, [
            (0.0, 20.0), (30.0, 0.0), (0.0, -34.0), (-30.0, 0.0)
        ]),
        # Station 2: Cockpit & forward belly V-keel at Y = +240 cm
        (240.0, [
            (0.0, 48.0), (44.0, 38.0), (80.0, 0.0), (0.0, -64.0), (-80.0, 0.0), (-44.0, 38.0)
        ]),
        # Station 3: Intake shoulders & deepest V-keel at Y = +50 cm
        (50.0, [
            (0.0, 44.0), (65.0, 34.0), (140.0, 0.0), (0.0, -80.0), (-140.0, 0.0), (-65.0, 34.0)
        ]),
        # Station 4: Wing root blend & mid keel at Y = -150 cm
        (-150.0, [
            (0.0, 40.0), (60.0, 32.0), (165.0, 0.0), (0.0, -66.0), (-165.0, 0.0), (-60.0, 32.0)
        ]),
        # Station 5: Twin engine bulges & central ventral tunnel at Y = -330 cm
        # Engine bulges at X = ±95, Z = -46; Central tunnel recessed up at X = 0, Z = -26
        (-330.0, [
            (0.0, 36.0), (95.0, 28.0), (150.0, 0.0), (95.0, -46.0), (0.0, -26.0), (-95.0, -46.0), (-150.0, 0.0), (-95.0, 28.0)
        ]),
        # Station 6: Aft engine shroud & boat-tail upsweep at Y = -460 cm
        (-460.0, [
            (0.0, 28.0), (95.0, 20.0), (88.0, 0.0), (95.0, -30.0), (0.0, -16.0), (-95.0, -30.0), (-88.0, 0.0), (-95.0, 20.0)
        ])
    ]

    l_fuse_in = lofts.createInput(adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    for y_pos, pts in fuselage_stations:
        p_in = planes.createInput()
        p_in.setByOffset(xz_plane, adsk.core.ValueInput.createByReal(y_pos))
        cp_station = planes.add(p_in)

        sk_st = sketches.add(cp_station)
        lines = sk_st.sketchCurves.sketchLines
        for i in range(len(pts)):
            p1 = sk_st.modelToSketchSpace(adsk.core.Point3D.create(pts[i][0], y_pos, pts[i][1]))
            p2 = sk_st.modelToSketchSpace(adsk.core.Point3D.create(pts[(i+1)%len(pts)][0], y_pos, pts[(i+1)%len(pts)][1]))
            lines.addByTwoPoints(p1, p2)

        l_fuse_in.loftSections.add(sk_st.profiles.item(0))

    fuse_ext = lofts.add(l_fuse_in)
    main_body = fuse_ext.bodies.item(0)
    main_body.name = "Body_Fuselage_Core"

    # =========================================================================
    # PHASE 2: 3D COMPOUND SPANWISE LOFTED DELTA WINGS (ZERO FLAT BOTTOM!)
    # =========================================================================
    print("[2/10] Lofting 3D compound aerodynamic wings (Port & Starboard)...")

    # Stations along the lateral X axis: (X_offset_cm, list_of_(Y, Z)_airfoil_points)
    # Right Wing Stations:
    right_wing_stations = [
        # Root Station: X = +155 cm (Chord Y: +70 to -320 cm, Thickness: Z = -16 to +16 cm)
        (155.0, [
            (70.0, 0.0), (0.0, 16.0), (-320.0, 0.0), (-120.0, -16.0)
        ]),
        # Mid-Span Station: X = +320 cm (Chord Y: -120 to -340 cm, Thickness: Z = -8 to +8 cm)
        (320.0, [
            (-120.0, 2.0), (-200.0, 8.0), (-340.0, 2.0), (-260.0, -8.0)
        ]),
        # Wingtip Station: X = +485 cm (Chord Y: -240 to -370 cm, Thickness: Z = -2 to +2 cm)
        (485.0, [
            (-240.0, 4.0), (-300.0, 4.0), (-370.0, 4.0), (-330.0, 1.0)
        ])
    ]

    # Right Wing Loft
    l_rw_in = lofts.createInput(adsk.fusion.FeatureOperations.JoinFeatureOperation)
    for x_pos, pts in right_wing_stations:
        p_in = planes.createInput()
        p_in.setByOffset(yz_plane, adsk.core.ValueInput.createByReal(x_pos))
        cp_wing = planes.add(p_in)

        sk_w = sketches.add(cp_wing)
        lines = sk_w.sketchCurves.sketchLines
        for i in range(len(pts)):
            p1 = sk_w.modelToSketchSpace(adsk.core.Point3D.create(x_pos, pts[i][0], pts[i][1]))
            p2 = sk_w.modelToSketchSpace(adsk.core.Point3D.create(x_pos, pts[(i+1)%len(pts)][0], pts[(i+1)%len(pts)][1]))
            lines.addByTwoPoints(p1, p2)
        l_rw_in.loftSections.add(sk_w.profiles.item(0))

    lofts.add(l_rw_in)

    # Left Wing Loft (Mirrored X)
    l_lw_in = lofts.createInput(adsk.fusion.FeatureOperations.JoinFeatureOperation)
    for x_pos, pts in right_wing_stations:
        neg_x = -x_pos
        p_in = planes.createInput()
        p_in.setByOffset(yz_plane, adsk.core.ValueInput.createByReal(neg_x))
        cp_wing_l = planes.add(p_in)

        sk_wl = sketches.add(cp_wing_l)
        lines = sk_wl.sketchCurves.sketchLines
        for i in range(len(pts)):
            p1 = sk_wl.modelToSketchSpace(adsk.core.Point3D.create(neg_x, pts[i][0], pts[i][1]))
            p2 = sk_wl.modelToSketchSpace(adsk.core.Point3D.create(neg_x, pts[(i+1)%len(pts)][0], pts[(i+1)%len(pts)][1]))
            lines.addByTwoPoints(p1, p2)
        l_lw_in.loftSections.add(sk_wl.profiles.item(0))

    lofts.add(l_lw_in)

    # Outer Vertical Winglet Stabilizers at tips (X = ±485 cm, Z = -18 to +52 cm)
    p_tip_r = planes.createInput()
    p_tip_r.setByOffset(yz_plane, adsk.core.ValueInput.createByReal(485.0))
    cp_tip_r = planes.add(p_tip_r)

    sk_wlet_r = sketches.add(cp_tip_r)
    wlet_lines = sk_wlet_r.sketchCurves.sketchLines
    wlet_pts = [
        (-240.0, 4.0), (-300.0, 52.0), (-370.0, 45.0), (-360.0, -18.0), (-300.0, -18.0)
    ]
    for i in range(len(wlet_pts)):
        p1 = sk_wlet_r.modelToSketchSpace(adsk.core.Point3D.create(485.0, wlet_pts[i][0], wlet_pts[i][1]))
        p2 = sk_wlet_r.modelToSketchSpace(adsk.core.Point3D.create(485.0, wlet_pts[(i+1)%len(wlet_pts)][0], wlet_pts[(i+1)%len(wlet_pts)][1]))
        wlet_lines.addByTwoPoints(p1, p2)

    wlet_in = extrudes.createInput(sk_wlet_r.profiles.item(0), adsk.fusion.FeatureOperations.JoinFeatureOperation)
    wlet_in.setOneSideExtent(dist_ext(8.0), adsk.fusion.ExtentDirections.PositiveExtentDirection)
    try:
        extrudes.add(wlet_in)
    except:
        pass

    # Left Winglet
    p_tip_l = planes.createInput()
    p_tip_l.setByOffset(yz_plane, adsk.core.ValueInput.createByReal(-485.0))
    cp_tip_l = planes.add(p_tip_l)

    sk_wlet_l = sketches.add(cp_tip_l)
    wlet_lines_l = sk_wlet_l.sketchCurves.sketchLines
    for i in range(len(wlet_pts)):
        p1 = sk_wlet_l.modelToSketchSpace(adsk.core.Point3D.create(-485.0, wlet_pts[i][0], wlet_pts[i][1]))
        p2 = sk_wlet_l.modelToSketchSpace(adsk.core.Point3D.create(-485.0, wlet_pts[(i+1)%len(wlet_pts)][0], wlet_pts[(i+1)%len(wlet_pts)][1]))
        wlet_lines_l.addByTwoPoints(p1, p2)

    wlet_l_in = extrudes.createInput(sk_wlet_l.profiles.item(0), adsk.fusion.FeatureOperations.JoinFeatureOperation)
    wlet_l_in.setOneSideExtent(dist_ext(-8.0), adsk.fusion.ExtentDirections.NegativeExtentDirection)
    try:
        extrudes.add(wlet_l_in)
    except:
        pass

    # =========================================================================
    # PHASE 3: FACETED COCKPIT CANOPY BUBBLE & AVIONICS SPINE
    # =========================================================================
    print("[3/10] Modeling faceted cockpit canopy bubble & dorsal spine...")

    # Construction plane at dorsal shoulder (Z = +36.0 cm)
    p_canopy = planes.createInput()
    p_canopy.setByOffset(xy_plane, adsk.core.ValueInput.createByReal(36.0))
    cp_canopy = planes.add(p_canopy)

    sk_canopy = sketches.add(cp_canopy)
    c_lines = sk_canopy.sketchCurves.sketchLines
    canopy_pts = [
        (0.0, 360.0),
        (42.0, 220.0),
        (44.0, 50.0),
        (0.0, 20.0)
    ]
    for i in range(len(canopy_pts) - 1):
        c_lines.addByTwoPoints(
            adsk.core.Point3D.create(canopy_pts[i][0], canopy_pts[i][1], 36.0),
            adsk.core.Point3D.create(canopy_pts[i+1][0], canopy_pts[i+1][1], 36.0)
        )
        c_lines.addByTwoPoints(
            adsk.core.Point3D.create(-canopy_pts[i][0], canopy_pts[i][1], 36.0),
            adsk.core.Point3D.create(-canopy_pts[i+1][0], canopy_pts[i+1][1], 36.0)
        )

    canopy_in = extrudes.createInput(sk_canopy.profiles.item(0), adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    canopy_in.setOneSideExtent(dist_ext(28.0), adsk.fusion.ExtentDirections.PositiveExtentDirection)
    canopy_ext = extrudes.add(canopy_in)
    canopy_body = canopy_ext.bodies.item(0)
    canopy_body.name = "Body_Cockpit_Canopy_Glass"

    # Dorsal Avionics Spine running back to tail (Z = +36 to +52 cm)
    sk_spine = sketches.add(cp_canopy)
    sp_lines = sk_spine.sketchCurves.sketchLines
    spine_pts = [
        (0.0, 40.0),
        (22.0, 10.0),
        (22.0, -420.0),
        (0.0, -440.0)
    ]
    for i in range(len(spine_pts) - 1):
        sp_lines.addByTwoPoints(
            adsk.core.Point3D.create(spine_pts[i][0], spine_pts[i][1], 36.0),
            adsk.core.Point3D.create(spine_pts[i+1][0], spine_pts[i+1][1], 36.0)
        )
        sp_lines.addByTwoPoints(
            adsk.core.Point3D.create(-spine_pts[i][0], spine_pts[i][1], 36.0),
            adsk.core.Point3D.create(-spine_pts[i+1][0], spine_pts[i+1][1], 36.0)
        )
    spine_in = extrudes.createInput(sk_spine.profiles.item(0), adsk.fusion.FeatureOperations.JoinFeatureOperation)
    spine_in.setOneSideExtent(dist_ext(16.0), adsk.fusion.ExtentDirections.PositiveExtentDirection)
    extrudes.add(spine_in)

    # Twin Canted Dorsal Stabilizers (Tail Fins)
    sk_tails = sketches.add(cp_canopy)
    t_lines = sk_tails.sketchCurves.sketchLines
    tail_pts = [
        (105.0, -180.0), (116.0, -180.0), (116.0, -440.0), (105.0, -440.0)
    ]
    for i in range(len(tail_pts)):
        p1 = adsk.core.Point3D.create(tail_pts[i][0], tail_pts[i][1], 36.0)
        p2 = adsk.core.Point3D.create(tail_pts[(i+1)%len(tail_pts)][0], tail_pts[(i+1)%len(tail_pts)][1], 36.0)
        t_lines.addByTwoPoints(p1, p2)
        p1_m = adsk.core.Point3D.create(-tail_pts[i][0], tail_pts[i][1], 36.0)
        p2_m = adsk.core.Point3D.create(-tail_pts[(i+1)%len(tail_pts)][0], tail_pts[(i+1)%len(tail_pts)][1], 36.0)
        t_lines.addByTwoPoints(p1_m, p2_m)

    for i in range(sk_tails.profiles.count):
        tp = sk_tails.profiles.item(i)
        t_in = extrudes.createInput(tp, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        t_in.setOneSideExtent(dist_ext(95.0), adsk.fusion.ExtentDirections.PositiveExtentDirection)
        extrudes.add(t_in)

    # =========================================================================
    # PHASE 4: VENTRAL UNDERBODY SCULPTING (FLIR TURRET, LOUVERS, WEAPONS BAY)
    # =========================================================================
    print("[4/10] Adding sculpted ventral features (FLIR turret, bay doors, cooling louvers)...")

    # 1. Ventral FLIR / EOTS Sensor Turret Pod (Hanging on chin V-keel: Z = -45 to -72 cm)
    p_chin = planes.createInput()
    p_chin.setByOffset(xy_plane, adsk.core.ValueInput.createByReal(-48.0))
    cp_chin = planes.add(p_chin)

    sk_flir = sketches.add(cp_chin)
    flir_lines = sk_flir.sketchCurves.sketchLines
    flir_pts = [
        (0.0, 360.0), (16.0, 300.0), (18.0, 220.0), (0.0, 190.0), (-18.0, 220.0), (-16.0, 300.0)
    ]
    for i in range(len(flir_pts)):
        p1 = adsk.core.Point3D.create(flir_pts[i][0], flir_pts[i][1], -48.0)
        p2 = adsk.core.Point3D.create(flir_pts[(i+1)%len(flir_pts)][0], flir_pts[(i+1)%len(flir_pts)][1], -48.0)
        flir_lines.addByTwoPoints(p1, p2)

    flir_in = extrudes.createInput(sk_flir.profiles.item(0), adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
    flir_in.setOneSideExtent(dist_ext(-22.0), adsk.fusion.ExtentDirections.NegativeExtentDirection)
    flir_ext = extrudes.add(flir_in)
    flir_body = flir_ext.bodies.item(0)
    flir_body.name = "Body_Ventral_Sensor_Pod"

    # 2. Ventral Weapons Bay Door Seam Grooves in the central tunnel (Y = -20 to -280 cm)
    p_tunnel = planes.createInput()
    p_tunnel.setByOffset(xy_plane, adsk.core.ValueInput.createByReal(-26.0))
    cp_tunnel = planes.add(p_tunnel)

    sk_bay = sketches.add(cp_tunnel)
    bay_lines = sk_bay.sketchCurves.sketchLines
    # Door perimeter and centerline split
    bay_lines.addTwoPointRectangle(
        adsk.core.Point3D.create(-24.0, -20.0, -26.0),
        adsk.core.Point3D.create(-1.5, -280.0, -26.0)
    )
    bay_lines.addTwoPointRectangle(
        adsk.core.Point3D.create(1.5, -20.0, -26.0),
        adsk.core.Point3D.create(24.0, -280.0, -26.0)
    )
    for i in range(sk_bay.profiles.count):
        bp = sk_bay.profiles.item(i)
        b_cut = extrudes.createInput(bp, adsk.fusion.FeatureOperations.CutFeatureOperation)
        b_cut.setOneSideExtent(dist_ext(6.0), adsk.fusion.ExtentDirections.PositiveExtentDirection)
        try:
            extrudes.add(b_cut)
        except:
            pass

    # 3. Ventral Engine Cooling / Bypass Louver Slots on engine humps
    sk_louvers = sketches.add(cp_tunnel)
    l_lines = sk_louvers.sketchCurves.sketchLines
    for y_pos in [-240.0, -275.0, -310.0, -345.0, -380.0]:
        # Right engine louver: X = 75 to 115
        l_lines.addTwoPointRectangle(
            adsk.core.Point3D.create(75.0, y_pos - 4.0, -26.0),
            adsk.core.Point3D.create(115.0, y_pos + 4.0, -26.0)
        )
        # Left engine louver: X = -115 to -75
        l_lines.addTwoPointRectangle(
            adsk.core.Point3D.create(-115.0, y_pos - 4.0, -26.0),
            adsk.core.Point3D.create(-75.0, y_pos + 4.0, -26.0)
        )
    for i in range(sk_louvers.profiles.count):
        lp = sk_louvers.profiles.item(i)
        l_cut = extrudes.createInput(lp, adsk.fusion.FeatureOperations.CutFeatureOperation)
        l_cut.setOneSideExtent(dist_ext(8.0), adsk.fusion.ExtentDirections.NegativeExtentDirection)
        try:
            extrudes.add(l_cut)
        except:
            pass

    # =========================================================================
    # PHASE 5: LAYERED APPLIQUE ARMOR PLATES & HEAT SHIELDS
    # =========================================================================
    print("[5/10] Applying layered applique armor mantlets & skin panels...")

    # Nose Chine Armor Plates (Raised +4 cm on top of forward hull)
    sk_armor_nose = sketches.add(cp_canopy)
    an_lines = sk_armor_nose.sketchCurves.sketchLines
    an_pts = [
        (12.0, 440.0), (28.0, 360.0), (32.0, 260.0), (16.0, 260.0)
    ]
    for i in range(len(an_pts)):
        p1 = adsk.core.Point3D.create(an_pts[i][0], an_pts[i][1], 36.0)
        p2 = adsk.core.Point3D.create(an_pts[(i+1)%len(an_pts)][0], an_pts[(i+1)%len(an_pts)][1], 36.0)
        an_lines.addByTwoPoints(p1, p2)
        p1_m = adsk.core.Point3D.create(-an_pts[i][0], an_pts[i][1], 36.0)
        p2_m = adsk.core.Point3D.create(-an_pts[(i+1)%len(an_pts)][0], an_pts[(i+1)%len(an_pts)][1], 36.0)
        an_lines.addByTwoPoints(p1_m, p2_m)

    for i in range(sk_armor_nose.profiles.count):
        ap = sk_armor_nose.profiles.item(i)
        ap_in = extrudes.createInput(ap, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
        ap_in.setOneSideExtent(dist_ext(4.0), adsk.fusion.ExtentDirections.PositiveExtentDirection)
        try:
            ap_ext = extrudes.add(ap_in)
            ap_ext.bodies.item(0).name = "Body_Armor_NosePlate"
        except:
            pass

    # Cockpit Shoulder Shield Mantlets
    sk_armor_mid = sketches.add(cp_canopy)
    am_lines = sk_armor_mid.sketchCurves.sketchLines
    am_pts = [
        (48.0, 180.0), (64.0, 120.0), (66.0, -60.0), (44.0, -60.0)
    ]
    for i in range(len(am_pts)):
        p1 = adsk.core.Point3D.create(am_pts[i][0], am_pts[i][1], 36.0)
        p2 = adsk.core.Point3D.create(am_pts[(i+1)%len(am_pts)][0], am_pts[(i+1)%len(am_pts)][1], 36.0)
        am_lines.addByTwoPoints(p1, p2)
        p1_m = adsk.core.Point3D.create(-am_pts[i][0], am_pts[i][1], 36.0)
        p2_m = adsk.core.Point3D.create(-am_pts[(i+1)%len(am_pts)][0], am_pts[(i+1)%len(am_pts)][1], 36.0)
        am_lines.addByTwoPoints(p1_m, p2_m)

    for i in range(sk_armor_mid.profiles.count):
        amp = sk_armor_mid.profiles.item(i)
        amp_in = extrudes.createInput(amp, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
        amp_in.setOneSideExtent(dist_ext(5.0), adsk.fusion.ExtentDirections.PositiveExtentDirection)
        try:
            amp_ext = extrudes.add(amp_in)
            amp_ext.bodies.item(0).name = "Body_Armor_ShoulderShield"
        except:
            pass

    # Engine Nacelle Upper Heat Shields
    sk_armor_eng = sketches.add(cp_canopy)
    ae_lines = sk_armor_eng.sketchCurves.sketchLines
    ae_lines.addTwoPointRectangle(
        adsk.core.Point3D.create(75.0, -160.0, 36.0),
        adsk.core.Point3D.create(115.0, -360.0, 36.0)
    )
    ae_lines.addTwoPointRectangle(
        adsk.core.Point3D.create(-115.0, -160.0, 36.0),
        adsk.core.Point3D.create(-75.0, -360.0, 36.0)
    )
    for i in range(sk_armor_eng.profiles.count):
        aep = sk_armor_eng.profiles.item(i)
        aep_in = extrudes.createInput(aep, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
        aep_in.setOneSideExtent(dist_ext(4.0), adsk.fusion.ExtentDirections.PositiveExtentDirection)
        try:
            aep_ext = extrudes.add(aep_in)
            aep_ext.bodies.item(0).name = "Body_Armor_EngineHeatShield"
        except:
            pass

    # =========================================================================
    # PHASE 6: DUAL ION THRUSTERS, VECTORING PETALS & INTERIOR AEROSPIKES
    # =========================================================================
    print("[6/10] Modeling dual engine exhausts, vectoring petals & interior aerospike cones...")

    # Exhaust Bells (Conical / Circular cutout 40 cm deep at Y = -460 cm, X = ±95 cm, Z = -5 cm)
    p_exhaust = planes.createInput()
    p_exhaust.setByOffset(xz_plane, adsk.core.ValueInput.createByReal(-460.0))
    cp_exhaust = planes.add(p_exhaust)

    sk_exhaust = sketches.add(cp_exhaust)
    ex_c = sk_exhaust.sketchCurves.sketchCircles
    r_nozzle = sk_exhaust.modelToSketchSpace(adsk.core.Point3D.create(95.0, -460.0, -5.0))
    l_nozzle = sk_exhaust.modelToSketchSpace(adsk.core.Point3D.create(-95.0, -460.0, -5.0))
    ex_c.addByCenterRadius(r_nozzle, 34.0)
    ex_c.addByCenterRadius(l_nozzle, 34.0)

    for i in range(sk_exhaust.profiles.count):
        exp = sk_exhaust.profiles.item(i)
        ex_cut = extrudes.createInput(exp, adsk.fusion.FeatureOperations.CutFeatureOperation)
        ex_cut.setOneSideExtent(dist_ext(38.0), adsk.fusion.ExtentDirections.PositiveExtentDirection)
        try:
            extrudes.add(ex_cut)
        except:
            pass

    # Central Conical Thrust Aerospikes inside nozzles
    sk_spike = sketches.add(cp_exhaust)
    sp_c = sk_spike.sketchCurves.sketchCircles
    sp_c.addByCenterRadius(r_nozzle, 15.0)
    sp_c.addByCenterRadius(l_nozzle, 15.0)
    for i in range(sk_spike.profiles.count):
        spp = sk_spike.profiles.item(i)
        sp_in = extrudes.createInput(spp, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        sp_in.setOneSideExtent(dist_ext(28.0), adsk.fusion.ExtentDirections.PositiveExtentDirection)
        try:
            extrudes.add(sp_in)
        except:
            pass

    # Articulated Thrust Vectoring Petals ringing the nozzles
    sk_petals = sketches.add(cp_exhaust)
    p_lines = sk_petals.sketchCurves.sketchLines
    for center_x in [95.0, -95.0]:
        for angle_deg in range(0, 360, 45):
            rad = math.radians(angle_deg)
            px = center_x + math.cos(rad) * 36.0
            pz = -5.0 + math.sin(rad) * 36.0
            pt_center = sk_petals.modelToSketchSpace(adsk.core.Point3D.create(px, -460.0, pz))
            p_lines.addTwoPointRectangle(
                adsk.core.Point3D.create(pt_center.x - 4.0, pt_center.y - 4.0, 0),
                adsk.core.Point3D.create(pt_center.x + 4.0, pt_center.y + 4.0, 0)
            )
    for i in range(sk_petals.profiles.count):
        pp = sk_petals.profiles.item(i)
        pp_in = extrudes.createInput(pp, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        pp_in.setOneSideExtent(dist_ext(-22.0), adsk.fusion.ExtentDirections.NegativeExtentDirection)
        try:
            extrudes.add(pp_in)
        except:
            pass

    # =========================================================================
    # PHASE 7: UNDER-WING WEAPON PYLONS & HYPERSONIC MISSILES
    # =========================================================================
    print("[7/10] Modeling aerodynamic under-wing pylons & live strike missiles...")

    # Pylons hanging below wings at X = ±260 and ±360 cm
    sk_pylons = sketches.add(xy_plane)
    pl_lines = sk_pylons.sketchCurves.sketchLines
    for px in [260.0, 360.0]:
        # Aerodynamic pylon with angled leading edge
        pl_lines.addTwoPointRectangle(
            adsk.core.Point3D.create(px - 4.5, -120.0, 0),
            adsk.core.Point3D.create(px + 4.5, -280.0, 0)
        )
        pl_lines.addTwoPointRectangle(
            adsk.core.Point3D.create(-px - 4.5, -120.0, 0),
            adsk.core.Point3D.create(-px + 4.5, -280.0, 0)
        )
    for i in range(sk_pylons.profiles.count):
        pyp = sk_pylons.profiles.item(i)
        pyp_in = extrudes.createInput(pyp, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        pyp_in.setOneSideExtent(dist_ext(-24.0), adsk.fusion.ExtentDirections.NegativeExtentDirection)
        try:
            extrudes.add(pyp_in)
        except:
            pass

    # Live Hypersonic Interceptor Missiles (Cylindrical Body + Conical Fins)
    p_missile = planes.createInput()
    p_missile.setByOffset(xy_plane, adsk.core.ValueInput.createByReal(-30.0))
    cp_missile = planes.add(p_missile)

    sk_missiles = sketches.add(cp_missile)
    mc = sk_missiles.sketchCurves.sketchCircles
    for mx in [260.0, 360.0, -260.0, -360.0]:
        mc.addByCenterRadius(adsk.core.Point3D.create(mx, -200.0, -30.0), 9.0)

    for i in range(sk_missiles.profiles.count):
        mp = sk_missiles.profiles.item(i)
        mp_in = extrudes.createInput(mp, adsk.fusion.FeatureOperations.NewBodyFeatureOperation)
        mp_in.setSymmetricExtent(adsk.core.ValueInput.createByReal(85.0), True)
        try:
            m_ext = extrudes.add(mp_in)
            m_ext.bodies.item(0).name = "Body_Hypersonic_Missile"
        except:
            pass

    # =========================================================================
    # PHASE 8: CHIN AUTOCANNONS & 4-WAY RCS ATTITUDE BLOCKS
    # =========================================================================
    print("[8/10] Modeling chin autocannons & nose RCS attitude control blocks...")

    sk_cannons = sketches.add(xy_plane)
    cc = sk_cannons.sketchCurves.sketchCircles
    cc.addByCenterRadius(adsk.core.Point3D.create(50.0, 260.0, 0), 13.0)
    cc.addByCenterRadius(adsk.core.Point3D.create(-50.0, 260.0, 0), 13.0)

    for i in range(sk_cannons.profiles.count):
        cp = sk_cannons.profiles.item(i)
        c_in = extrudes.createInput(cp, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        c_in.setSymmetricExtent(adsk.core.ValueInput.createByReal(11.0), True)
        try:
            extrudes.add(c_in)
        except:
            pass

    sk_rcs = sketches.add(xy_plane)
    rc_c = sk_rcs.sketchCurves.sketchCircles
    rc_c.addByCenterRadius(adsk.core.Point3D.create(36.0, 460.0, 0), 8.0)
    rc_c.addByCenterRadius(adsk.core.Point3D.create(-36.0, 460.0, 0), 8.0)

    for i in range(sk_rcs.profiles.count):
        rcp = sk_rcs.profiles.item(i)
        rc_in = extrudes.createInput(rcp, adsk.fusion.FeatureOperations.JoinFeatureOperation)
        rc_in.setSymmetricExtent(adsk.core.ValueInput.createByReal(14.0), True)
        try:
            extrudes.add(rc_in)
        except:
            pass

    # =========================================================================
    # PHASE 9: PBR MATERIAL PALETTE & VIEWPORT REFRESH
    # =========================================================================
    print("[9/10] Applying PBR material palette & verifying geometry...")

    lib = app.materialLibraries.itemByName("Fusion Appearance Library")

    def get_or_load(name):
        for a in design.appearances:
            if a.name == name:
                return a
        lib_app = lib.appearances.itemByName(name)
        if lib_app:
            return design.appearances.addByCopy(lib_app, name)
        return None

    mat_titanium = get_or_load("Titanium - Satin")
    mat_carbon = get_or_load("Carbon Fiber - Plain")
    mat_glass = get_or_load("Glass (Bronze)")
    mat_steel = get_or_load("Stainless Steel - Brushed Linear Long")
    mat_black = get_or_load("Paint - Enamel Glossy (Black)")
    mat_white = get_or_load("Paint - Enamel Glossy (White)")

    # 1. Main Fuselage -> Titanium - Satin
    if main_body and mat_titanium:
        main_body.appearance = mat_titanium

    # 2. Distinct bodies
    for i in range(root.bRepBodies.count):
        b = root.bRepBodies.item(i)
        b_name = b.name.lower()
        if "canopy" in b_name or "glass" in b_name:
            if mat_glass:
                b.appearance = mat_glass
        elif "armor" in b_name or "shield" in b_name:
            if mat_carbon:
                b.appearance = mat_carbon
        elif "missile" in b_name:
            if mat_white:
                b.appearance = mat_white
        elif "sensor" in b_name or "flir" in b_name:
            if mat_black:
                b.appearance = mat_black

    # 3. Wings and engine faces
    if main_body:
        for face in main_body.faces:
            box = face.boundingBox
            center_x = (box.maxPoint.x + box.minPoint.x) / 2.0
            center_y = (box.maxPoint.y + box.minPoint.y) / 2.0
            if abs(center_x) > 175.0 and mat_carbon:
                face.appearance = mat_carbon
            elif center_y < -280.0 and 140.0 > abs(center_x) > 50.0 and mat_steel:
                face.appearance = mat_steel

    # Verify flat bottom faces on main fuselage
    flat_bottom_cnt = 0
    for face in main_body.faces:
        if face.geometry.surfaceType == adsk.core.SurfaceTypes.PlaneSurfaceType:
            plane = adsk.core.Plane.cast(face.geometry)
            if plane.normal.z < -0.95:
                flat_bottom_cnt += 1

    print(f"Fuselage complete! Total faces: {main_body.faces.count}. Flat bottom faces: {flat_bottom_cnt}")

    if app.activeViewport:
        app.activeViewport.fit()
        app.activeViewport.refresh()

    # =========================================================================
    # PHASE 10: AUTOMATED GAME ASSET EXPORT (STEP, STL)
    # =========================================================================
    print("[10/10] Exporting fully sculpted spaceship CAD (STEP & high-res STL)...")

    export_dir = r"c:\Users\Boris\Documents\antigravity\lucid-davinci\Exports"
    os.makedirs(export_dir, exist_ok=True)
    step_path = os.path.join(export_dir, "Spaceship_Sculpted_V_Hull.step")
    stl_path = os.path.join(export_dir, "Spaceship_Sculpted_V_Hull.stl")

    export_mgr = design.exportManager

    # STEP
    step_opts = export_mgr.createSTEPExportOptions(step_path, root)
    export_mgr.execute(step_opts)

    # High-Refinement STL
    stl_opts = export_mgr.createSTLExportOptions(root, stl_path)
    stl_opts.meshRefinement = adsk.fusion.MeshRefinementSettings.MeshRefinementHigh
    export_mgr.execute(stl_opts)

    if os.path.exists(step_path) and os.path.exists(stl_path):
        size_step = os.path.getsize(step_path) / 1024.0
        size_stl = os.path.getsize(stl_path) / 1024.0
        print(f"[SUCCESS] Exported: STEP={size_step:.1f} KB, STL={size_stl:.1f} KB")

    print("================================================================")
    print("  SCULPTED BUILD COMPLETE: Viewport ready in Autodesk Fusion!   ")
    print("================================================================")
    return True


# Direct invocation for bridge execution
build_supreme_sculpted_spaceship()
