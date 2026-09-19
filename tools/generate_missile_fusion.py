# -*- coding: utf-8 -*-
"""
Parametric Strike Missile & Pylon Generator for Autodesk Fusion 360.
Generates:
1. Aerodynamic ogive fuselage with rocket exhaust cavity.
2. 4-fin cruciform supersonic tail stabilization fins via circular pattern.
3. 4-fin cruciform forward canard steering fins via circular pattern.
4. Aerodynamic wing pylon adapter with swept leading edge on +Z mounting rail.
5. Clean combine of components and export to STEP & STL.
"""

import os
import math
import traceback

print(">>> Generating Precision Strike Missile & Pylon in Fusion 360...")

try:
    app = adsk.core.Application.get()
    doc = app.activeDocument
    if not doc:
        doc = app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
    
    design = adsk.fusion.Design.cast(app.activeProduct)
    design.designType = adsk.fusion.DesignTypes.DirectDesignType
    rootComp = design.rootComponent

    # Clean existing bodies/sketches
    for b in list(rootComp.bRepBodies):
        b.deleteMe()

    sketches = rootComp.sketches
    features = rootComp.features
    xyPlane = rootComp.xYConstructionPlane
    yAxis = rootComp.yConstructionAxis

    # Dimensions in centimeters (Fusion API native units)
    # Missile specs: Length = 240 cm (2.4m), Diameter = 18 cm (0.18m)
    r_body = 9.0        # Radius 9 cm
    r_nozzle_outer = 7.0
    r_nozzle_inner = 5.2
    
    l_nose = 48.0       # Nose length (cm)
    l_body = 162.0      # Cylindrical body length (cm)
    l_boat = 25.0       # Tapered tail length (cm)
    l_cavity = 14.0     # Exhaust cavity depth (cm)

    y0 = 0.0            # Nose tip
    y1 = -l_nose        # -48 cm (End of nose cone)
    y2 = y1 - l_body    # -210 cm (End of cylindrical body)
    y3 = y2 - l_boat    # -235 cm (Base of missile / tail)
    y4 = y3 + l_cavity  # -221 cm (Depth of exhaust cavity)

    # ----------------------------------------------------
    # 1. Revolved Fuselage Profile
    # ----------------------------------------------------
    print("[1/5] Sketching and revolving missile fuselage...")
    sketch_fuse = sketches.add(xyPlane)
    lines_f = sketch_fuse.sketchCurves.sketchLines
    arcs_f = sketch_fuse.sketchCurves.sketchArcs

    # Axis of revolution (Y axis)
    axis_line = lines_f.addByTwoPoints(
        adsk.core.Point3D.create(0, y0, 0),
        adsk.core.Point3D.create(0, y3, 0)
    )

    p_tip = adsk.core.Point3D.create(0, y0, 0)
    p_mid_nose = adsk.core.Point3D.create(r_body * 0.70, y0 - (l_nose * 0.48), 0)
    p_shoulder = adsk.core.Point3D.create(r_body, y1, 0)
    p_cyl_end = adsk.core.Point3D.create(r_body, y2, 0)
    p_tail_base = adsk.core.Point3D.create(r_nozzle_outer, y3, 0)
    p_nozzle_lip = adsk.core.Point3D.create(r_nozzle_inner, y3, 0)
    p_cavity_top = adsk.core.Point3D.create(r_nozzle_inner, y4, 0)
    p_cavity_center = adsk.core.Point3D.create(0, y4, 0)

    # Tangent ogive arc
    arcs_f.addByThreePoints(p_tip, p_mid_nose, p_shoulder)
    # Cylindrical motor body
    lines_f.addByTwoPoints(p_shoulder, p_cyl_end)
    # Boat-tail
    lines_f.addByTwoPoints(p_cyl_end, p_tail_base)
    # Exhaust rim
    lines_f.addByTwoPoints(p_tail_base, p_nozzle_lip)
    # Recessed nozzle cavity walls
    lines_f.addByTwoPoints(p_nozzle_lip, p_cavity_top)
    # Cavity top to center
    lines_f.addByTwoPoints(p_cavity_top, p_cavity_center)
    # Centerline closure
    lines_f.addByTwoPoints(p_cavity_center, adsk.core.Point3D.create(0, y3, 0))

    rev_input = features.revolveFeatures.createInput(
        sketch_fuse.profiles.item(0),
        axis_line,
        adsk.fusion.FeatureOperations.NewBodyFeatureOperation
    )
    rev_input.setAngleExtent(False, adsk.core.ValueInput.createByReal(2 * math.pi))
    missile_body = features.revolveFeatures.add(rev_input).bodies.item(0)
    missile_body.name = "Missile_Airframe"
    print("Revolved aerodynamic missile airframe.")

    # ----------------------------------------------------
    # 2. Tail Stabilization Fins (Cruciform 4x via Pattern)
    # ----------------------------------------------------
    print("[2/5] Modeling cruciform tail fins...")
    sketch_tail = sketches.add(xyPlane)
    lines_t = sketch_tail.sketchCurves.sketchLines

    # Trapezoidal fin profile on +X side
    t_p1 = adsk.core.Point3D.create(r_body * 0.9, -192.0, 0)
    t_p2 = adsk.core.Point3D.create(r_body + 17.5, -214.0, 0)
    t_p3 = adsk.core.Point3D.create(r_body + 17.5, -232.0, 0)
    t_p4 = adsk.core.Point3D.create(r_nozzle_outer * 0.95, -234.0, 0)

    lines_t.addByTwoPoints(t_p1, t_p2)
    lines_t.addByTwoPoints(t_p2, t_p3)
    lines_t.addByTwoPoints(t_p3, t_p4)
    lines_t.addByTwoPoints(t_p4, t_p1)

    tail_ext_input = features.extrudeFeatures.createInput(
        sketch_tail.profiles.item(0),
        adsk.fusion.FeatureOperations.NewBodyFeatureOperation
    )
    tail_ext_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(0.35), True) # 7mm total
    fin_tail_0 = features.extrudeFeatures.add(tail_ext_input).bodies.item(0)

    # Circular pattern x4
    tail_col = adsk.core.ObjectCollection.create()
    tail_col.add(fin_tail_0)
    tail_circ_input = features.circularPatternFeatures.createInput(tail_col, yAxis)
    tail_circ_input.quantity = adsk.core.ValueInput.createByString("4")
    tail_circ_input.totalAngle = adsk.core.ValueInput.createByString("360 deg")
    features.circularPatternFeatures.add(tail_circ_input)
    print("Cruciform tail fins patterned.")

    # ----------------------------------------------------
    # 3. Forward Canard Steering Fins (Cruciform 4x via Pattern)
    # ----------------------------------------------------
    print("[3/5] Modeling cruciform forward canards...")
    sketch_canard = sketches.add(xyPlane)
    lines_c = sketch_canard.sketchCurves.sketchLines

    # Swept canard profile on +X side
    c_p1 = adsk.core.Point3D.create(r_body * 0.95, -52.0, 0)
    c_p2 = adsk.core.Point3D.create(r_body + 11.5, -67.0, 0)
    c_p3 = adsk.core.Point3D.create(r_body * 0.98, -69.0, 0)

    lines_c.addByTwoPoints(c_p1, c_p2)
    lines_c.addByTwoPoints(c_p2, c_p3)
    lines_c.addByTwoPoints(c_p3, c_p1)

    canard_ext_input = features.extrudeFeatures.createInput(
        sketch_canard.profiles.item(0),
        adsk.fusion.FeatureOperations.NewBodyFeatureOperation
    )
    canard_ext_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(0.25), True) # 5mm total
    fin_canard_0 = features.extrudeFeatures.add(canard_ext_input).bodies.item(0)

    # Circular pattern x4
    canard_col = adsk.core.ObjectCollection.create()
    canard_col.add(fin_canard_0)
    canard_circ_input = features.circularPatternFeatures.createInput(canard_col, yAxis)
    canard_circ_input.quantity = adsk.core.ValueInput.createByString("4")
    canard_circ_input.totalAngle = adsk.core.ValueInput.createByString("360 deg")
    features.circularPatternFeatures.add(canard_circ_input)
    print("Cruciform canard fins patterned.")

    # ----------------------------------------------------
    # 4. Aerodynamic Wing Pylon Adapter
    # ----------------------------------------------------
    print("[4/5] Designing aerodynamic wing pylon...")
    # Model pylon on xyPlane on +X side, then rotate 90 degrees around Y axis to +Z
    sketch_pylon = sketches.add(xyPlane)
    lines_p = sketch_pylon.sketchCurves.sketchLines

    # Pylon profile from X = 8.5 (missile fuselage contact) to X = 23.0 (wing mount contact)
    # Length along Y: -70 cm to -185 cm
    pyl_p1 = adsk.core.Point3D.create(8.2, -70.0, 0)
    pyl_p2 = adsk.core.Point3D.create(23.0, -88.0, 0)   # 45-degree swept leading edge
    pyl_p3 = adsk.core.Point3D.create(23.0, -178.0, 0)  # Wing mounting rail
    pyl_p4 = adsk.core.Point3D.create(8.2, -188.0, 0)  # Tapered trailing edge

    lines_p.addByTwoPoints(pyl_p1, pyl_p2)
    lines_p.addByTwoPoints(pyl_p2, pyl_p3)
    lines_p.addByTwoPoints(pyl_p3, pyl_p4)
    lines_p.addByTwoPoints(pyl_p4, pyl_p1)

    pylon_ext_input = features.extrudeFeatures.createInput(
        sketch_pylon.profiles.item(0),
        adsk.fusion.FeatureOperations.NewBodyFeatureOperation
    )
    pylon_ext_input.setSymmetricExtent(adsk.core.ValueInput.createByReal(2.6), True) # Width = 5.2 cm
    pylon_body = features.extrudeFeatures.add(pylon_ext_input).bodies.item(0)
    pylon_body.name = "Wing_Pylon_Mount"

    # Rotate Pylon 90 degrees around Y axis so it sits on +Z (mounting to wing underside)
    transform = adsk.core.Matrix3D.create()
    transform.setToRotation(math.radians(90), adsk.core.Vector3D.create(0, 1, 0), adsk.core.Point3D.create(0, 0, 0))
    
    move_col = adsk.core.ObjectCollection.create()
    move_col.add(pylon_body)
    move_input = features.moveFeatures.createInput(move_col, transform)
    features.moveFeatures.add(move_input)
    print("Wing pylon rotated to +Z wing mount position.")

    # ----------------------------------------------------
    # 5. Export STEP and STL Models
    # ----------------------------------------------------
    print("[5/5] Exporting STEP and STL assets...")
    exportMgr = design.exportManager
    output_dir = r"c:\Users\Boris\Documents\antigravity\lucid-davinci\assets\cad\vehicles"
    os.makedirs(output_dir, exist_ok=True)

    step_path = os.path.join(output_dir, "Vanguard_Strike_Missile.step")
    stl_path = os.path.join(output_dir, "Vanguard_Strike_Missile.stl")

    # STEP Export
    step_opts = exportMgr.createSTEPExportOptions(step_path, rootComp)
    exportMgr.execute(step_opts)
    print(f"Exported STEP: {step_path}")

    # High-Density STL Export
    stl_opts = exportMgr.createSTLExportOptions(rootComp, stl_path)
    stl_opts.meshRefinement = adsk.fusion.MeshRefinementSettings.MeshRefinementHigh
    exportMgr.execute(stl_opts)
    print(f"Exported High-Density STL: {stl_path}")

    # Inspect all bodies
    print("\n--- Final Generated Bodies ---")
    for i, b in enumerate(rootComp.bRepBodies):
        bb = b.boundingBox
        print(f"Body [{b.name}]: Min=({bb.minPoint.x:.1f}, {bb.minPoint.y:.1f}, {bb.minPoint.z:.1f}) Max=({bb.maxPoint.x:.1f}, {bb.maxPoint.y:.1f}, {bb.maxPoint.z:.1f})")

    print("\n>>> SUCCESS: Strike Missile & Pylon successfully created in Fusion 360!")

except Exception as e:
    print(f"[ERROR]: {e}")
    traceback.print_exc()
