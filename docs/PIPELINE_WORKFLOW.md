# Asset Pipeline

## 1. Overview & Architecture

Models start as parametric CAD in Fusion 360, go through Blender for cleanup, and are exported to Godot 4 (the game) and Unreal Engine 5 (an experimental port).

```mermaid
graph LR
    subgraph CAD [1. Engineering: Fusion 360]
        C1[Parametric Lofts & Sketches] --> C2[STEP / STL High-Density Export]
    end

    subgraph DCC [2. Processing: Blender 4.2 LTS]
        B1[Bridge Server: Port 9877] --> B2[Scale Normalization: mm -> m]
        B2 --> B3[Multi-Material Slot Separation]
        B3 --> B4[Unreal SOCKET_ Empties]
        B4 --> B5[Modular UCX_ Collision Hulls]
        B5 --> B6[Smart UV & Custom Split Normals]
    end

    subgraph TARGETS [3. Target Runtimes]
        DCC -->|glTF 2.0 .glb| G1[Godot 4 Engine]
        DCC -->|Autodesk .fbx| U1[Unreal Engine 5]
    end

    G1 --> G2[Instant Prototype & Aerodynamics]
    U1 --> U2[Nanite Virtualized Geometry & Lumen]
```

---

## 2. Unit Scales & Coordinate Conventions

Each tool uses different units and axes. These are the conventions:

| Software | Measurement Unit | Forward Vector | Up Vector | Handedness |
| :--- | :--- | :--- | :--- | :--- |
| **Autodesk Fusion 360** | Millimeters ($mm$) / Centimeters ($cm$) | $+Y$ | $+Z$ | Right-Handed |
| **Blender 4.2 LTS** | Real-World Meters ($m$) | $+Y$ (Nose) | $+Z$ (Canopy) | Right-Handed |
| **Godot 4 (glTF 2.0)** | Real-World Meters ($m$) | **$-Z$** (glTF standard) | $+Y$ (Sky) | Right-Handed |
| **Unreal Engine 5** | Centimeters ($cm$) | **$+X$** | $+Z$ (Sky) | Left-Handed |

### Transformation Rules:
1. **Scale Normalization:**
   * Fusion 360 exports in millimeters ($10,300\text{ mm}$ fighter length).
   * The Blender bridge scripts apply a $0.001$ scale to any mesh with a dimension over 150 units.
   * Final dimensions in meters: $10.30\text{m} \times 9.78\text{m} \times 2.70\text{m}$.
2. **glTF Export for Godot 4:**
   * Blender's glTF exporter converts Blender's $+Y$ forward to glTF's $-Z$.
3. **FBX Export for Unreal Engine 5:**
   * Exported with `axis_forward='-Z'`, `axis_up='Y'` and `apply_scale_options='FBX_SCALE_ALL'`.

---

## 3. Collision Mesh Standards

CAD meshes are too dense to use for physics directly, so each ship gets simple collision hulls:

```
Fighter Jet Collision Composition:
├── UCX_Spaceship_Fuselage_01   (Center fuselage & nose)
├── UCX_Spaceship_Wing_L_01     (Left delta wing)
├── UCX_Spaceship_Wing_R_01     (Right delta wing)
└── UCX_Spaceship_Canopy_01     (Cockpit canopy bubble)
```

### Engine-Specific Conventions:
* **Unreal Engine 5:** imports objects named `UCX_<MeshName>_<Index>` as hidden convex collision.
* **Godot 4:** uses name suffixes:
  * `-colonly`: Mesh is hidden and turned purely into a static collision shape.
  * `-convcol`: Generates a convex collision shape from the mesh.

---

## 4. Multi-Material PBR Shading Standards

Vehicles use separate material slots so glass and emissive parts can have their own shaders:

| Material Name | Shader Type | Visual Characteristics |
| :--- | :--- | :--- |
| **`MI_Spaceship_Hull`** | Opaque PBR | Dark military carbon-armor ($Metallic=0.88$, $Roughness=0.32$). |
| **`MI_Cockpit_Glass`** | Translucent Glass | Tinted cyan canopy ($Transmission=0.85$, $Roughness=0.08$, $Alpha=0.35$). |
| **`MI_Headlights`** | High Emissive | Forward projector lenses with emissive glow ($Strength=18.0$, Cyan/White). |
| **`MI_Thrusters`** | High Emissive | Engine afterburner plasma cores ($Strength=25.0$, Cyan/Blue). |
| **`MI_Weapon_Pylon`** | Opaque PBR | Matte dark composite mounting rails ($Metallic=0.90$, $Roughness=0.40$). |

---

## 5. Gameplay Hardpoint Sockets (`SOCKET_*`)

Blender empties named `SOCKET_*` become Static Mesh Sockets in Unreal's FBX importer and plain `Node3D` markers in Godot.

### Spaceship Socket Directory:
| Socket Name | Coordinates ($x, y, z$) in Meters | Function |
| :--- | :--- | :--- |
| `SOCKET_Headlight_L` | `(-1.15, 4.55, 0.28)` | Left forward spotlight projector |
| `SOCKET_Headlight_R` | `(1.15, 4.55, 0.28)` | Right forward spotlight projector |
| `SOCKET_Thruster_L` | `(-0.95, -4.75, -0.05)` | Left engine exhaust Niagara particle emitter |
| `SOCKET_Thruster_R` | `(0.95, -4.75, -0.05)` | Right engine exhaust Niagara particle emitter |
| `SOCKET_Cockpit_Camera`| `(0.00, 1.85, 0.72)` | First-person pilot head / HUD camera |
| `SOCKET_Chase_Camera` | `(0.00, -9.50, 3.20)` | Third-person follow camera anchor |
| `SOCKET_Ventral_Sensor`| `(0.00, 2.75, -0.72)` | Ventral FLIR / target designation gimbal |
| `SOCKET_Weapon_Hardpoint_01` | `(-3.60, -1.80, -0.25)` | Left outer wing missile pylon |
| `SOCKET_Weapon_Hardpoint_02` | `(-2.60, -1.80, -0.25)` | Left inner wing missile pylon |
| `SOCKET_Weapon_Hardpoint_03` | `(2.60, -1.80, -0.25)` | Right inner wing missile pylon |
| `SOCKET_Weapon_Hardpoint_04` | `(3.60, -1.80, -0.25)` | Right outer wing missile pylon |
