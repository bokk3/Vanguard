# -*- coding: utf-8 -*-
"""
Automated PBR Material & Appearance Painter for the Starfighter Interceptor in Autodesk Fusion 360.
Assigns realistic material finishes:
- Stealth Hull: Titanium - Satin
- Cockpit Canopy: Glass (Bronze) tinted windshield
- Swept Wings: Carbon Fiber - Plain weave
- Engine Thrusters & Afterburners: Stainless Steel - Brushed Linear
- Weapon Pods & Cannons: Paint - Enamel Glossy (Black)
"""

import adsk.core
import adsk.fusion

def apply_spaceship_textures():
    app = adsk.core.Application.get()
    doc = app.activeDocument
    prod = doc.products.itemByProductType("DesignProductType")
    design = adsk.fusion.Design.cast(prod)
    if not design:
        print("[ERROR] No active Design document found.")
        return False

    root = design.rootComponent
    lib = app.materialLibraries.itemByName("Fusion Appearance Library")

    def get_or_load_appearance(name):
        for a in design.appearances:
            if a.name == name:
                return a
        lib_app = lib.appearances.itemByName(name)
        if lib_app:
            return design.appearances.addByCopy(lib_app, name)
        return None

    print("Loading material appearances from Fusion library...")
    titanium = get_or_load_appearance("Titanium - Satin")
    carbon_fiber = get_or_load_appearance("Carbon Fiber - Plain")
    glass_bronze = get_or_load_appearance("Glass (Bronze)")
    steel_brushed = get_or_load_appearance("Stainless Steel - Brushed Linear Long")
    paint_black = get_or_load_appearance("Paint - Enamel Glossy (Black)")

    print(f"Loaded: Titanium={bool(titanium)}, Carbon={bool(carbon_fiber)}, Glass={bool(glass_bronze)}, Steel={bool(steel_brushed)}, Black={bool(paint_black)}")

    # 1. Base Hull Assignment
    hull_body = None
    for b in root.bRepBodies:
        if "Hull" in b.name or "Fuselage" in b.name:
            hull_body = b
            break
    if not hull_body and root.bRepBodies.count > 0:
        hull_body = root.bRepBodies.item(0)

    if hull_body:
        print(f"Applying base Titanium armor to {hull_body.name}...")
        if titanium:
            hull_body.appearance = titanium

        # 2. Detail Face Assignments on the main hull
        glass_count = 0
        carbon_count = 0
        steel_count = 0

        for face in hull_body.faces:
            box = face.boundingBox
            center_x = (box.maxPoint.x + box.minPoint.x) / 2.0
            center_y = (box.maxPoint.y + box.minPoint.y) / 2.0
            center_z = (box.maxPoint.z + box.minPoint.z) / 2.0

            # Cockpit Canopy Faces: High Z, forward-mid Y, narrow X
            if box.maxPoint.z > 24.0 and 360.0 > center_y > -40.0 and abs(center_x) < 50.0:
                if glass_bronze:
                    face.appearance = glass_bronze
                    glass_count += 1

            # Wing Faces: Wide X (> 150 cm) and relatively flat Z
            elif abs(center_x) > 150.0 and abs(center_z) < 18.0:
                if carbon_fiber:
                    face.appearance = carbon_fiber
                    carbon_count += 1

            # Engine Thrusters & Nozzles: Rear Y (< -240 cm), mid X (50 to 140 cm)
            elif center_y < -240.0 and 145.0 > abs(center_x) > 50.0:
                if steel_brushed:
                    face.appearance = steel_brushed
                    steel_count += 1

        print(f"Detailed faces assigned: Canopy Glass={glass_count}, Wing Carbon={carbon_count}, Engine Steel={steel_count}")

    # 3. Secondary Bodies (Missile Pods, Cannons, RCS)
    for i in range(root.bRepBodies.count):
        b = root.bRepBodies.item(i)
        if b != hull_body:
            print(f"Painting accessory body '{b.name}' in Tactical Black...")
            if paint_black:
                b.appearance = paint_black

    # Refresh the viewport to show updated materials immediately
    if app.activeViewport:
        app.activeViewport.refresh()
        print("[SUCCESS] Fusion viewport refreshed with new materials!")

    return True

apply_spaceship_textures()
