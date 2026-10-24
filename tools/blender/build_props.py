"""Environment kit for Vân Khê: flora, building modules, composed buildings and props.

blender --background --factory-startup --python tools/blender/build_props.py -- [names...] [--preview]
Outputs art/env/<name>.blend and assets/models/env/<name>.glb. Objects named *-convcolonly
become convex StaticBody3D colliders on Godot import. Fronts face -Y (Godot +Z).
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import vk_lib as vk  # noqa: E402

# Props are vertex-coloured: one material per building instead of ten (fewer draw calls).
vk.DEFAULT_VCOL = True

RNG = random.Random(284)


# ---------------------------------------------------------------- shared parts

def roof(b, width, depth, base_z, ridge, mat="roof", upturn=0.45, center=(0, 0), thickness=0.14, steps=(10, 6)):
    """Concave East Asian roof with upturned eave corners. width along X, depth along Y."""
    nu, nv = steps[1] * 2, steps[0]
    top, bottom = [], []
    for i in range(nu + 1):
        u = -1 + 2 * i / nu
        row_t, row_b = [], []
        for j in range(nv + 1):
            v = -1 + 2 * j / nv
            z = base_z + ridge * (1 - abs(u)) ** 1.6 + upturn * (abs(v) ** 6) * (abs(u) ** 2) + upturn * 0.35 * abs(u) ** 6
            co = Vector((center[0] + v * width * 0.5, center[1] + u * depth * 0.5, z))
            row_t.append(b.bm.verts.new(co))
            row_b.append(b.bm.verts.new(co - Vector((0, 0, thickness))))
        top.append(row_t)
        bottom.append(row_b)
    faces = []
    for i in range(nu):
        for j in range(nv):
            faces.append(b.bm.faces.new((top[i][j], top[i][j + 1], top[i + 1][j + 1], top[i + 1][j])))
            faces.append(b.bm.faces.new((bottom[i][j], bottom[i + 1][j], bottom[i + 1][j + 1], bottom[i][j + 1])))
    for i in range(nu):
        faces.append(b.bm.faces.new((top[i][0], top[i + 1][0], bottom[i + 1][0], bottom[i][0])))
        faces.append(b.bm.faces.new((top[i][nv], bottom[i][nv], bottom[i + 1][nv], top[i + 1][nv])))
    for j in range(nv):
        faces.append(b.bm.faces.new((top[0][j], bottom[0][j], bottom[0][j + 1], top[0][j + 1])))
        faces.append(b.bm.faces.new((top[nu][j], top[nu][j + 1], bottom[nu][j + 1], bottom[nu][j])))
    verts = [v for row in top + bottom for v in row]
    b._finish(verts, mat, None, vk._matrix((0, 0, 0), (0, 0, 0)), True, 40)
    # Separate stepped tile courses make the roof readable at gameplay distance.
    columns = max(6, round(width / 0.42))
    rows = max(3, round(depth / 0.75))
    for side in (-1, 1):
        for row in range(rows):
            u = side * (row + 0.5) / rows
            for col in range(columns):
                v = -1 + (col + 0.5) * 2 / columns
                z = base_z + ridge * (1-abs(u))**1.6 + upturn*abs(v)**6*abs(u)**2 + upturn*0.35*abs(u)**6
                slope = side * (-ridge*1.6*(1-abs(u))**0.6 + 2*upturn*abs(v)**6*abs(u) + 2.1*upturn*abs(u)**5) / (depth*0.5)
                b.box((width/columns*0.93, depth/(2*rows)*1.04, 0.065),
                      (center[0]+v*width*0.5, center[1]+u*depth*0.5, z+0.055),
                      (math.degrees(math.atan(slope)),0,0), mat=mat if (col+row)%4 else 'roof_dark')
    ridge_z = base_z + ridge
    b.cylinder(0.11, width * 0.92, (center[0], center[1], ridge_z + 0.02), (0, 90, 0), mat="roof_dark", segments=8)
    for side in (1, -1):
        b.cone(0.13, 0.5, (center[0] + side * width * 0.46, center[1], ridge_z + 0.2), (0, side * -35, 0), mat="vermilion", segments=6)
        for front in (1, -1):
            b.cone(0.07, 0.35, (center[0] + side * width * 0.5, center[1] + front * depth * 0.5, base_z + upturn + 0.12), (front * -40, side * 30, 0),
                   mat="gold", segments=5)
    b.box((width, 0.05, 0.12), (center[0], center[1] - depth * 0.5 + 0.02, base_z + upturn * 0.35 - thickness), mat="wood_dark")
    b.box((width, 0.05, 0.12), (center[0], center[1] + depth * 0.5 - 0.02, base_z + upturn * 0.35 - thickness), mat="wood_dark")


def post(b, x, y, z0, height, radius=0.12, mat="wood", base=True):
    b.cylinder(radius, height, (x, y, z0 + height / 2), mat=mat, segments=8)
    if base:
        b.box((radius * 3.2, radius * 3.2, 0.16), (x, y, z0 + 0.08), mat="stone", bevel=0.03)


def panel(b, x0, x1, y, z0, z1, mat="cream", frame="wood", window=False, door=False, axis="x"):
    """Wall panel between two posts with a wooden frame; optional lattice window or door."""
    length = abs(x1 - x0)
    mid = (x0 + x1) / 2
    height = z1 - z0

    def box(size, offset):
        if axis == "x":
            b.box(size, (mid + offset[0], y + offset[1], z0 + offset[2]), mat=current[0])
        else:
            b.box((size[1], size[0], size[2]), (y + offset[1], mid + offset[0], z0 + offset[2]), mat=current[0])
    current = [mat]
    if door:
        current[0] = mat
        side = (length - 1.1) / 2
        for sign in (1, -1):
            box((side, 0.1, height), (sign * (0.55 + side / 2), 0, height / 2))
        box((1.1, 0.1, height - 2.1), (0, 0, 2.1 + (height - 2.1) / 2))
        current[0] = "wood_dark"
        box((1.0, 0.08, 2.05), (0, -0.02, 1.03))
        current[0] = "gold"
        box((0.05, 0.1, 0.05), (0.2, -0.06, 1.0))
        box((0.05, 0.1, 0.05), (-0.2, -0.06, 1.0))
    elif window:
        box((length, 0.1, 0.9), (0, 0, 0.45))
        box((length, 0.1, height - 1.9), (0, 0, 1.9 + (height - 1.9) / 2))
        current[0] = "paper"
        box((length - 0.2, 0.06, 1.0), (0, 0, 1.4))
        current[0] = "wood_dark"
        for k in range(5):
            box((0.04, 0.09, 1.0), (-length / 2 + 0.1 + (k + 0.5) * (length - 0.2) / 5, -0.01, 1.4))
        for k in range(3):
            box((length - 0.2, 0.09, 0.04), (0, -0.01, 0.95 + (k + 0.5) * 0.33))
    else:
        box((length, 0.1, height), (0, 0, height / 2))
    current[0] = frame
    box((length, 0.14, 0.1), (0, 0, 0.05))
    box((length, 0.14, 0.12), (0, 0, height - 0.06))


def hanging_lantern(b, x, y, z, color="vermilion"):
    b.segment((x, y, z + 0.5), (x, y, z + 0.22), 0.01, mat="ink", segments=4)
    b.sphere(1.0, (x, y, z), scale=(0.17, 0.17, 0.22), mat=color, segments=10, rings=8)
    b.sphere(1.0, (x, y, z), scale=(0.12, 0.12, 0.18), mat="lantern", segments=8, rings=6)
    b.cylinder(0.1, 0.05, (x, y, z + 0.21), mat="gold", segments=8)
    b.cylinder(0.1, 0.05, (x, y, z - 0.21), mat="gold", segments=8)
    b.segment((x, y, z - 0.24), (x, y, z - 0.45), 0.02, 0.0, mat=color, segments=4)


# Flora (trees, bamboo, grass, rocks and ground cover) lives in build_flora.py.


# ---------------------------------------------------------------- buildings

def house(name, width=6.0, depth=4.5, wall="cream", roof_mat="roof", porch=False, lanterns=True):
    b = vk.MeshBuilder(name)
    h = 2.7
    b.box((width + 0.7, depth + 0.7, 0.3), (0, 0, 0.15), mat="stone", bevel=0.04)
    for step in range(2):
        b.box((1.6, 0.35, 0.15), (0, -depth / 2 - 0.5 - step * 0.3, 0.075 + (1 - step) * 0.15 - 0.075), mat="stone_light", bevel=0.02)
    xs = [-width / 2, -width / 6, width / 6, width / 2]
    for x in xs:
        for y in (-depth / 2, depth / 2):
            post(b, x, y, 0.3, h + 0.2)
    for y in (-depth / 4, depth / 4):
        post(b, -width / 2, y, 0.3, h + 0.2)
        post(b, width / 2, y, 0.3, h + 0.2)
    panel(b, xs[0], xs[1], -depth / 2, 0.3, 0.3 + h, mat=wall, window=True)
    panel(b, xs[1], xs[2], -depth / 2, 0.3, 0.3 + h, mat=wall, door=True)
    panel(b, xs[2], xs[3], -depth / 2, 0.3, 0.3 + h, mat=wall, window=True)
    for i in range(3):
        panel(b, xs[i], xs[i + 1], depth / 2, 0.3, 0.3 + h, mat=wall, window=(i == 1))
    for x in (-width / 2, width / 2):
        panel(b, -depth / 2, depth / 2, x, 0.3, 0.3 + h, mat=wall, window=True, axis="y")
    b.box((width + 0.3, depth + 0.3, 0.2), (0, 0, 0.3 + h + 0.1), mat="wood_dark")
    if porch:
        for x in (-width / 2, 0, width / 2):
            post(b, x, -depth / 2 - 1.6, 0.0, h + 0.4)
        b.box((width + 0.4, 1.7, 0.18), (0, -depth / 2 - 0.85, 0.09), mat="wood_light")
        roof(b, width + 1.4, 2.4, 0.3 + h - 0.15, 0.25, roof_mat, upturn=0.25, center=(0, -depth / 2 - 1.1), thickness=0.1, steps=(8, 2))
    roof(b, width + 1.6, depth + 1.8, 0.3 + h + 0.2, 1.5, roof_mat)
    if lanterns:
        hanging_lantern(b, width / 2 + 0.2, -depth / 2 - 0.6, 2.4)
        hanging_lantern(b, -width / 2 - 0.2, -depth / 2 - 0.6, 2.4)
    obj = b.build()
    vk.collider_box("Walls", (width + 0.2, depth + 0.2, h + 0.6), (0, 0, (h + 0.6) / 2))
    return obj


def house_small():
    return house("HouseSmall")


def house_long():
    return house("HouseLong", width=9.0, depth=5.5, wall="cream_dark", porch=True)


def house_teal():
    return house("HouseTeal", width=6.5, depth=4.8, wall="jade_light", roof_mat="roof_dark")


def smithy():
    b = vk.MeshBuilder("Smithy")
    b.box((6.4, 5.0, 0.2), (0, 0, 0.1), mat="stone_dark", bevel=0.03)
    for x in (-2.8, 2.8):
        for y in (-2.0, 2.0):
            post(b, x, y, 0.2, 3.0, radius=0.14, mat="wood_dark")
    panel(b, -2.8, 2.8, 2.0, 0.2, 2.6, mat="wood", frame="wood_dark")
    roof(b, 7.4, 5.8, 3.1, 1.1, "roof_dark", upturn=0.3)
    b.box((1.8, 1.4, 1.0), (-1.2, 1.1, 0.7), mat="stone", bevel=0.08)
    b.box((1.2, 0.9, 0.12), (-1.2, 1.1, 1.26), mat="lantern")
    b.cylinder(0.35, 2.4, (-1.2, 1.4, 2.4), mat="stone_dark", top=0.25, segments=8)
    b.box((0.7, 0.28, 0.3), (1.0, -0.4, 0.75), mat="metal_dark", bevel=0.04)
    b.box((0.3, 0.22, 0.45), (1.0, -0.4, 0.42), mat="metal_dark")
    b.cylinder(0.4, 0.75, (2.0, 1.2, 0.58), mat="wood", segments=10)
    b.cylinder(0.36, 0.05, (2.0, 1.2, 0.93), mat="jade_dark", segments=10)
    b.box((1.4, 0.08, 0.6), (0, -2.5, 2.75), mat="wood_light")
    b.box((1.2, 0.1, 0.45), (0, -2.55, 2.75), mat="vermilion_dark")
    b.build()
    vk.collider_box("Forge", (1.8, 1.4, 1.2), (-1.2, 1.1, 0.6))
    vk.collider_box("Back", (5.8, 0.3, 2.6), (0, 2.0, 1.3))
    for x in (-2.8, 2.8):
        for y in (-2.0, 2.0):
            vk.collider_cylinder(f"Post{x}{y}", 0.2, 3.0, (x, y, 1.5))


def gate_village():
    b = vk.MeshBuilder("Gate")
    for x in (-2.4, 2.4):
        b.box((0.6, 0.6, 0.5), (x, 0, 0.25), mat="stone", bevel=0.05)
        b.cylinder(0.22, 4.2, (x, 0, 2.6), mat="vermilion", segments=10)
    b.box((5.6, 0.36, 0.3), (0, 0, 4.3), mat="wood_dark")
    b.box((5.2, 0.3, 0.25), (0, 0, 3.7), mat="vermilion_dark")
    b.box((1.8, 0.12, 0.7), (0, -0.2, 4.0), mat="wood_light")
    b.box((1.6, 0.14, 0.55), (0, -0.22, 4.0), mat="jade_dark")
    roof(b, 7.0, 2.2, 4.45, 0.7, "roof", upturn=0.35, steps=(10, 3))
    hanging_lantern(b, -1.6, -0.3, 3.1)
    hanging_lantern(b, 1.6, -0.3, 3.1)
    b.build()
    for x in (-2.4, 2.4):
        vk.collider_cylinder(f"Pillar{x}", 0.32, 4.4, (x, 0, 2.2))


def shrine_wind():
    b = vk.MeshBuilder("Shrine")
    b.cylinder(1.5, 0.3, (0, 0, 0.15), mat="stone", segments=12)
    b.cylinder(1.15, 0.25, (0, 0, 0.42), mat="stone_light", segments=12)
    b.box((1.2, 1.0, 1.4), (0, 0.2, 1.25), mat="stone", bevel=0.06)
    b.box((0.7, 0.2, 0.9), (0, -0.32, 1.3), mat="ink")
    for x in (-0.7, 0.7):
        b.cylinder(0.08, 1.9, (x, -0.55, 1.5), mat="vermilion", segments=8)
    roof(b, 2.4, 2.1, 2.3, 0.6, "roof", upturn=0.3, steps=(8, 3))
    for x in (-0.9, 0.9):
        b.segment((x, -0.85, 2.3), (x, -0.85, 1.95), 0.006, mat="ink", segments=4)
        b.cylinder(0.05, 0.22, (x, -0.85, 1.85), mat="bronze", segments=8)
        b.box((0.08, 0.01, 0.2), (x, -0.85, 1.62), mat="paper")
    b.build()
    glow = vk.MeshBuilder("Glow")
    glow.sphere(0.22, (0, -0.3, 1.3), scale=(1, 0.6, 1.3), mat="spirit", segments=10, rings=8)
    glow.build()
    vk.collider_cylinder("Base", 1.2, 2.2, (0, 0, 1.1), segments=10)


def bridge_wood():
    b = vk.MeshBuilder("Bridge")
    length, width = 16.0, 3.2
    for i in range(int(length / 0.4)):
        y = -length / 2 + 0.2 + i * 0.4
        arch = 0.6 * (1 - (y / (length / 2)) ** 2)
        b.box((width, 0.36, 0.12), (0, y, arch), (math.degrees(math.atan(-2.4 * y / (length / 2) ** 2)), 0, 0), mat="wood_light" if i % 2 else "wood")
    for side in (1, -1):
        rail = []
        for i in range(9):
            y = -length / 2 + i * length / 8
            arch = 0.6 * (1 - (y / (length / 2)) ** 2)
            b.cylinder(0.07, 1.1, (side * width / 2, y, arch + 0.5), mat="wood_dark", segments=6)
            rail.append(Vector((side * width / 2, y, arch + 1.02)))
        for a, c in zip(rail, rail[1:]):
            b.segment(a, c, 0.05, mat="vermilion", segments=6)
        for y in (-length / 2 + 0.5, length / 2 - 0.5):
            b.cylinder(0.16, 5.0, (side * (width / 2 + 0.1), y, -2.0), mat="wood_dark", segments=8)
    b.build()
    for i in range(8):
        y0 = -length / 2 + i * length / 8
        y = y0 + length / 16
        arch = 0.6 * (1 - (y / (length / 2)) ** 2)
        slope = math.degrees(math.atan(-2.4 * y / (length / 2) ** 2))
        vk.collider_box(f"Deck{i}", (width, length / 8 + 0.05, 0.3), (0, y, arch - 0.09), (slope, 0, 0))
    for side in (1, -1):
        vk.collider_box(f"Rail{side}", (0.2, length, 1.3), (side * width / 2, 0, 0.9))


def dock():
    b = vk.MeshBuilder("Dock")
    length, width = 14.0, 3.6
    for i in range(int(length / 0.45)):
        b.box((width, 0.4, 0.1), (0, -i * 0.45, 0.55), mat="wood_light" if i % 3 else "wood")
    for i in range(5):
        y = -i * length / 4
        for side in (1, -1):
            b.cylinder(0.14, 3.4, (side * (width / 2 - 0.1), y, -1.0), mat="wood_dark", segments=8)
    for y in (-length + 0.6, -length / 2):
        for side in (1, -1):
            b.cylinder(0.11, 0.6, (side * (width / 2 - 0.05), y, 0.85), mat="wood_dark", segments=8)
            b.torus(0.12, 0.03, (side * (width / 2 - 0.05), y, 0.95), mat="cream_dark", segments=8, ring=4)
    b.build()
    vk.collider_box("Deck", (width, length + 0.4, 0.4), (0, -length / 2 + 0.2, 0.4))


def boat():
    b = vk.MeshBuilder("Boat")
    rings = []
    for y, w, d in ((-2.6, 0.05, 0.1), (-2.0, 0.7, 0.45), (-0.6, 1.25, 0.6), (0.8, 1.25, 0.6), (2.0, 0.8, 0.5), (2.6, 0.1, 0.2)):
        rings.append([(math.cos(a) * w * 0.5, y, 0.55 + min(0.0, math.sin(a)) * d + max(0.0, math.sin(a)) * 0.05) for a in [math.tau * i / 10 for i in range(10)]])
    rotated = [[(p[0], p[2] * 0 + p[1], p[2]) for p in ring] for ring in rings]
    b.loft([[(p[0], p[1], p[2]) for p in ring] for ring in rotated], mat="wood", sharp_angle=60)
    b.box((1.1, 4.6, 0.05), (0, 0, 0.5), mat="wood_light")
    rings = []
    for y in (-0.8, 0.0, 0.8):
        rings.append([(math.cos(a) * 0.65, y, 0.6 + math.sin(a) * 0.8) for a in [math.pi * i / 8 for i in range(9)]])
    for ring in rings:
        for a, c in zip(ring, ring[1:]):
            b.segment(a, c, 0.025, mat="bamboo_dark", segments=4)
    b.box((1.35, 1.8, 0.04), (0, 0, 1.42), mat="cream_dark")
    b.cylinder(0.04, 3.2, (0.2, 2.2, 0.9), (60, 0, 0), mat="bamboo", segments=6)
    b.build()


def lantern_stone():
    b = vk.MeshBuilder("LanternStone")
    b.box((0.6, 0.6, 0.15), (0, 0, 0.075), mat="stone", bevel=0.03)
    b.cylinder(0.12, 0.9, (0, 0, 0.6), mat="stone", segments=8)
    b.box((0.55, 0.55, 0.1), (0, 0, 1.1), mat="stone_dark", bevel=0.02)
    b.box((0.42, 0.42, 0.38), (0, 0, 1.34), mat="stone", bevel=0.03)
    b.box((0.26, 0.44, 0.24), (0, 0, 1.34), mat="lantern")
    b.cone(0.48, 0.32, (0, 0, 1.68), mat="stone_dark", segments=4)
    b.sphere(0.08, (0, 0, 1.88), mat="stone", segments=6, rings=4)
    b.build()
    vk.collider_box("Body", (0.5, 0.5, 1.8), (0, 0, 0.9))


def lantern_post():
    b = vk.MeshBuilder("LanternPost")
    b.cylinder(0.08, 3.0, (0, 0, 1.5), mat="wood_dark", segments=8)
    b.box((0.9, 0.08, 0.08), (0.4, 0, 2.9), mat="wood_dark")
    hanging_lantern(b, 0.75, 0, 2.3)
    b.build()
    vk.collider_cylinder("Post", 0.12, 3.0, (0, 0, 1.5))


def signboard():
    b = vk.MeshBuilder("Sign")
    for x in (-0.6, 0.6):
        b.cylinder(0.06, 1.8, (x, 0, 0.9), mat="wood_dark", segments=6)
    b.box((1.5, 0.08, 0.7), (0, 0, 1.35), mat="wood_light", bevel=0.02)
    b.box((1.3, 0.1, 0.5), (0, -0.01, 1.35), mat="paper")
    for k in range(3):
        b.box((0.08, 0.11, 0.3), (-0.35 + k * 0.35, -0.02, 1.35), mat="ink")
    b.box((1.7, 0.4, 0.08), (0, 0, 1.75), mat="roof", bevel=0.02)
    b.build()
    vk.collider_box("Body", (1.4, 0.2, 1.8), (0, 0, 0.9))


def table():
    b = vk.MeshBuilder("Table")
    b.box((1.6, 0.9, 0.08), (0, 0, 0.78), mat="wood", bevel=0.02)
    for x in (-0.7, 0.7):
        for y in (-0.35, 0.35):
            b.box((0.08, 0.08, 0.76), (x, y, 0.38), mat="wood_dark")
    b.cylinder(0.12, 0.2, (-0.4, 0, 0.92), mat="cream", top=0.08, segments=10)
    for x in (0.2, 0.4):
        b.cylinder(0.05, 0.07, (x, 0.1, 0.86), mat="white", top=0.04, segments=8)
    b.build()
    vk.collider_box("Body", (1.6, 0.9, 0.85), (0, 0, 0.42))


def bench():
    b = vk.MeshBuilder("Bench")
    b.box((1.8, 0.45, 0.08), (0, 0, 0.45), mat="wood_light", bevel=0.02)
    for x in (-0.75, 0.75):
        b.box((0.1, 0.4, 0.42), (x, 0, 0.21), mat="wood_dark")
    b.build()
    vk.collider_box("Body", (1.8, 0.45, 0.5), (0, 0, 0.25))


def chest():
    b = vk.MeshBuilder("ChestBase")
    b.box((1.0, 0.65, 0.5), (0, 0, 0.25), mat="wood", bevel=0.03)
    for x in (-0.45, 0.45):
        b.box((0.06, 0.68, 0.52), (x, 0, 0.26), mat="gold")
    b.box((0.16, 0.06, 0.16), (0, -0.33, 0.42), mat="gold")
    b.build()
    lid = vk.MeshBuilder("Lid")
    lid.cylinder(0.33, 1.0, (0, 0.0, 0.0), (0, 90, 0), mat="vermilion_dark", segments=12, scale=(1, 1, 1))
    lid.box((0.07, 0.68, 0.36), (0.45, 0, 0.0), mat="gold")
    lid.box((0.07, 0.68, 0.36), (-0.45, 0, 0.0), mat="gold")
    obj = lid.build()
    for vertex in obj.data.vertices:
        vertex.co.z = max(vertex.co.z, 0.0) * 0.6
        vertex.co.y -= 0.32
    obj.location = (0, 0.32, 0.5)
    vk.collider_box("Body", (1.0, 0.65, 0.6), (0, 0, 0.3))


def stele():
    b = vk.MeshBuilder("Stele")
    b.box((1.4, 1.0, 0.4), (0, 0, 0.2), mat="stone_dark", bevel=0.05)
    b.sphere(0.5, (0, 0.05, 0.62), scale=(1.1, 1.3, 0.55), mat="stone", segments=10, rings=6)
    b.box((0.9, 0.25, 1.8), (0, 0, 1.4), mat="stone_light", bevel=0.04)
    b.box((1.05, 0.3, 0.25), (0, 0, 2.35), mat="stone", bevel=0.04)
    for k in range(4):
        b.box((0.06, 0.27, 0.9), (-0.24 + k * 0.16, 0, 1.4), mat="stone_dark")
    b.build()
    vk.collider_box("Body", (1.3, 1.0, 2.4), (0, 0, 1.2))


def ruins_pillar():
    b = vk.MeshBuilder("RuinsPillar")
    b.box((0.9, 0.9, 0.3), (0, 0, 0.15), mat="stone_dark", bevel=0.04)
    b.cylinder(0.3, 2.4, (0, 0, 1.5), mat="stone", segments=8)
    b.cylinder(0.3, 0.5, (0.05, 0, 2.95), (8, 12, 0), mat="stone", top=0.22, segments=8)
    b.cylinder(0.3, 1.6, (1.1, 0.4, 0.3), (0, 82, 20), mat="stone", segments=8)
    b.sphere(0.35, (0.0, 0.1, 0.35), scale=(1, 1, 0.35), mat="moss", segments=8, rings=4)
    b.build()
    vk.collider_cylinder("Body", 0.35, 3.1, (0, 0, 1.55))


def ruins_wall():
    b = vk.MeshBuilder("RuinsWall")
    rng = random.Random(11)
    for i in range(6):
        for j in range(4 - abs(i - 2) // 2):
            b.box((0.7, 0.5, 0.4), (-1.75 + i * 0.7 + (j % 2) * 0.2, 0, 0.2 + j * 0.42), (0, 0, rng.uniform(-4, 4)), mat="stone" if (i + j) % 3 else "stone_dark", bevel=0.04)
    b.box((1.4, 0.52, 0.12), (-0.3, 0, 1.0), mat="moss")
    b.build()
    vk.collider_box("Body", (4.2, 0.6, 1.4), (0, 0, 0.7))


def well():
    b = vk.MeshBuilder("Well")
    for row in range(4):
        for i in range(12):
            a = math.tau*(i+0.5*(row%2))/12
            b.box((0.45,0.25,0.205),(math.sin(a)*0.84,math.cos(a)*0.84,0.108+row*0.213),
                  (0,0,-math.degrees(a)),mat='stone_light' if (i+row)%3 else 'stone',bevel=0.012)
    b.cylinder(0.70,0.025,(0,0,0.22),mat='jade_dark',segments=16)
    for x in (-0.9, 0.9):
        b.cylinder(0.07, 2.2, (x, 0, 1.1), mat="wood_dark", segments=6)
    b.cylinder(0.06, 1.9, (0, 0, 1.75), (0, 90, 0), mat="wood", segments=6)
    roof(b, 2.4, 1.6, 2.1, 0.45, "roof", upturn=0.2, steps=(6, 2))
    b.cylinder(0.16, 0.25, (0.3, 0, 1.3), mat="wood", segments=8)
    b.build()
    vk.collider_cylinder("Body", 1.0, 1.0, (0, 0, 0.5), segments=10)


def barrel():
    b = vk.MeshBuilder("Barrel")
    b.cylinder(0.32, 0.9, (0, 0, 0.45), mat="wood", segments=10)
    for z in (0.15, 0.75):
        b.torus(0.33, 0.02, (0, 0, z), mat="metal_dark", segments=10, ring=4)
    b.cylinder(0.3, 0.02, (0, 0, 0.9), mat="wood_dark", segments=10)
    b.build()
    vk.collider_cylinder("Body", 0.33, 0.9, (0, 0, 0.45))


def crate():
    b = vk.MeshBuilder("Crate")
    b.box((0.7, 0.7, 0.6), (0, 0, 0.3), mat="wood_light", bevel=0.02)
    b.box((0.72, 0.1, 0.62), (0, 0, 0.3), mat="wood")
    b.box((0.1, 0.72, 0.62), (0, 0, 0.3), mat="wood")
    b.cylinder(0.25, 0.3, (0.0, 0.0, 0.75), mat="bamboo_light", top=0.3, segments=8)
    b.build()
    vk.collider_box("Body", (0.7, 0.7, 0.6), (0, 0, 0.3))


def fence_bamboo():
    b = vk.MeshBuilder("Fence")
    for x in (-1.0, 1.0):
        b.cylinder(0.06, 1.3, (x, 0, 0.65), mat="bamboo_dark", segments=6)
    for z in (0.4, 0.9):
        b.cylinder(0.035, 2.1, (0, 0, z), (0, 90, 0), mat="bamboo", segments=6)
    for k in range(9):
        b.cylinder(0.025, 1.0, (-0.9 + k * 0.225, -0.05, 0.6), (0, 0, 0), mat="bamboo_light" if k % 2 else "bamboo", segments=5)
    b.build()
    vk.collider_box("Body", (2.1, 0.2, 1.1), (0, 0, 0.55))


def market_stall():
    b = vk.MeshBuilder("Stall")
    for x in (-1.2, 1.2):
        for y in (-0.8, 0.8):
            b.cylinder(0.06, 2.4 if y > 0 else 2.0, (x, y, 1.2 if y > 0 else 1.0), mat="wood_dark", segments=6)
    for k in range(6):
        b.box((0.45, 1.9, 0.04), (-1.15 + k * 0.46, 0, 2.2), (-12, 0, 0), mat="vermilion" if k % 2 else "cream")
        b.box((0.44,0.06,0.20),(-1.15+k*0.46,-0.94,2.29),mat='vermilion' if k%2 else 'cream',bevel=0.035)
    b.box((2.4, 1.0, 0.08), (0, -0.2, 0.85), mat="wood_light")
    b.box((2.3, 0.08, 0.8), (0, -0.7, 0.42), mat="wood")
    for k in range(10):
        b.box((0.19,0.045,0.7),(-1.04+k*0.23,-0.75,0.43),mat='wood_light',bevel=0.006)
    for tray in range(3):
        x=-0.78+tray*0.72
        b.box((0.64,0.55,0.09),(x,-0.17,0.94),mat='wood_dark')
        for i in range(3):
            for j in range(2):
                b.sphere(0.095,(x+(i-1)*0.18,-0.32+j*0.2,1.04),mat='fruit_orange' if tray%2 else 'fruit_green',segments=8,rings=5,smooth=False)
    for k in range(4):
        b.sphere(0.13, (-0.8 + k * 0.5, -0.2, 0.98), mat=["gold", "bamboo", "vermilion", "cream"][k], segments=8, rings=5)
    b.cylinder(0.18, 0.3, (0.9, 0.2, 1.04), mat="jade_dark", top=0.12, segments=8)
    b.build()
    vk.collider_box("Body", (2.5, 1.7, 1.0), (0, 0, 0.5))


def watchtower():
    b = vk.MeshBuilder("Watchtower")
    for x in (-1.4, 1.4):
        for y in (-1.4, 1.4):
            b.segment((x * 1.15, y * 1.15, 0), (x, y, 6.5), 0.14, 0.11, mat="wood_dark", segments=6)
    for z in (2.0, 4.2):
        for a, c in (((-1.5, -1.5), (1.5, 1.5)), ((1.5, -1.5), (-1.5, 1.5))):
            b.segment((a[0], -1.45, z - 1.0), (c[0], -1.45, z + 1.0), 0.05, mat="wood", segments=4)
    b.box((3.6, 3.6, 0.18), (0, 0, 6.5), mat="wood")
    for x in (-1.75, 1.75):
        b.box((0.1, 3.6, 0.9), (x, 0, 7.0), mat="wood_light")
    b.box((3.6, 0.1, 0.9), (0, 1.75, 7.0), mat="wood_light")
    b.box((1.6, 0.1, 0.9), (-1.0, -1.75, 7.0), (0, 0, 0), mat="wood_light")
    for x in (-1.6, 1.6):
        for y in (-1.6, 1.6):
            b.cylinder(0.06, 2.0, (x, y, 7.5), mat="wood_dark", segments=6)
    roof(b, 4.4, 4.4, 8.4, 0.9, "roof_dark", upturn=0.3, steps=(8, 3))
    b.box((1.4, 1.0, 0.16), (2.2, 0.8, 8.5), (25, 30, 10), mat="roof_dark")
    for k in range(10):
        b.box((0.6, 0.06, 0.05), (0, -1.9, 0.4 + k * 0.62), mat="wood_light")
    for x in (-0.3, 0.3):
        b.segment((x, -1.9, 0), (x, -1.9, 6.5), 0.035, mat="wood_dark", segments=4)
    b.build()
    vk.collider_box("Legs", (3.0, 3.0, 6.4), (0, 0, 3.2))


def wind_chime_post():
    b = vk.MeshBuilder("ChimePost")
    b.cylinder(0.3, 0.2, (0, 0, 0.1), mat="stone", segments=10)
    b.cylinder(0.07, 2.6, (0, 0, 1.4), mat="bamboo_dark", segments=8)
    b.box((1.1, 0.08, 0.08), (0.35, 0, 2.6), mat="wood_dark")
    for k in range(4):
        x = 0.1 + k * 0.22
        b.segment((x, 0, 2.58), (x, 0, 2.2 - k * 0.06), 0.005, mat="ink", segments=4)
        b.cylinder(0.03, 0.4 + k * 0.08, (x, 0, 2.0 - k * 0.1), mat="bamboo_light", segments=6)
    b.segment((0.5, 0, 2.58), (0.5, 0, 1.5), 0.005, mat="ink", segments=4)
    b.box((0.12, 0.01, 0.35), (0.5, 0, 1.3), mat="paper")
    b.build()
    vk.collider_cylinder("Body", 0.2, 2.7, (0, 0, 1.35))


def seal_gate():
    b = vk.MeshBuilder("SealGate")
    for x in (-3.4, 3.4):
        b.box((1.4, 1.4, 6.0), (x, 0, 3.0), mat="stone", bevel=0.08)
        b.box((1.6, 1.6, 0.4), (x, 0, 0.2), mat="stone_dark", bevel=0.05)
    b.box((8.6, 1.6, 1.0), (0, 0, 6.5), mat="stone_dark", bevel=0.08)
    roof(b, 9.6, 2.8, 7.0, 0.9, "roof_dark", upturn=0.4, steps=(10, 3))
    for k in range(5):
        b.box((0.28, 0.02, 0.8), (-1.6 + k * 0.8, -0.85, 5.2 - (k % 2) * 0.3), (0, 0, (k - 2) * 6), mat="paper")
        b.box((0.08, 0.025, 0.5), (-1.6 + k * 0.8, -0.86, 5.2 - (k % 2) * 0.3), (0, 0, (k - 2) * 6), mat="seal")
    b.segment((-2.8, -0.8, 5.8), (2.8, -0.8, 5.8), 0.05, mat="vermilion", segments=6)
    b.build()
    barrier = vk.MeshBuilder("Barrier")
    barrier.box((5.4, 0.1, 5.6), (0, 0, 2.8), mat="seal")
    barrier.build()
    for x in (-3.4, 3.4):
        vk.collider_box(f"Pillar{x}", (1.4, 1.4, 6.0), (x, 0, 3.0))


def campfire():
    b = vk.MeshBuilder("Campfire")
    for k in range(8):
        a = k * math.tau / 8
        b.sphere(0.16, (math.cos(a) * 0.55, math.sin(a) * 0.55, 0.08), scale=(1.2, 1, 0.7), mat="stone_dark", segments=6, rings=4)
    for k in range(4):
        a = k * math.tau / 4
        b.segment((math.cos(a) * 0.4, math.sin(a) * 0.4, 0.05), (0, 0, 0.5), 0.06, 0.04, mat="wood_dark", segments=6)
    b.cone(0.25, 0.55, (0, 0, 0.35), mat="lantern", segments=6)
    b.build()


def tent():
    b = vk.MeshBuilder("Tent")
    rings = []
    for y in (-1.6, 1.6):
        rings.append([(-1.4, y, 0.0), (0.0, y, 1.9), (1.4, y, 0.0)])
    for ring in rings:
        b.segment(ring[0], ring[1], 0.05, mat="wood_dark", segments=4)
        b.segment(ring[1], ring[2], 0.05, mat="wood_dark", segments=4)
    for side in (1, -1):
        b.box((1.75, 3.4, 0.04), (side * 0.7, 0, 0.95), (0, side * 53.6, 0), mat="cloth_brown" if side > 0 else "cream_dark")
    b.cylinder(0.04, 3.4, (0, 0, 1.92), (90, 0, 0), mat="wood_dark", segments=4)
    b.build()
    vk.collider_box("Body", (2.6, 3.2, 1.6), (0, 0, 0.8))


def steps_stone():
    b = vk.MeshBuilder("Steps")
    for k in range(6):
        b.box((3.0, 0.6, 0.22 + k * 0.2), (0, k * 0.55, (0.22 + k * 0.2) / 2), mat="stone" if k % 2 else "stone_light", bevel=0.03)
    b.build()
    vk.collider_box("Ramp", (3.0, 3.6, 0.2), (0, 1.35, 0.6), (-21, 0, 0))


def rock_cliff():
    b = vk.MeshBuilder("Cliff")
    rng = random.Random(21)

    for x,y,h in [(-1.6,0,3.5),(0,0.15,4.0),(1.6,0.3,3.1),(-0.8,-1.0,2.8),(1.0,-0.9,2.5)]:
        for tier in range(3):
            b.box((1.7-tier*0.08,1.75,h/3+0.06),(x,y,h/3*(tier+0.5)),
                  (0,0,rng.uniform(-5,5)),mat='stone' if tier%2 else 'stone_light',bevel=0.12)
        b.box((1.75,1.8,0.15),(x,y,h),mat='moss',bevel=0.05)
    b.build()
    vk.collider_box("Body", (5.5, 3.8, 4.0), (0.3, 0, 2.0))


def memory_stone():
    b = vk.MeshBuilder("MemoryStone")
    b.cylinder(0.6, 0.25, (0, 0, 0.12), mat="stone_dark", segments=10)
    b.cone(0.28, 1.4, (0, 0, 0.9), mat="stone_light", segments=6)
    b.build()
    glow = vk.MeshBuilder("Glow")
    glow.sphere(0.2, (0, 0, 1.75), scale=(1, 1, 1.4), mat="spirit", segments=8, rings=6)
    glow.build()
    vk.collider_cylinder("Body", 0.5, 1.6, (0, 0, 0.8))


# ---------------------------------------------------------------- temple and village dressing

def gate_tam_quan():
    """Three-bay temple gate (tam quan): vermilion pillars, a tall central roof over two lower wings."""
    b = vk.MeshBuilder("TamQuan")
    b.box((9.4, 2.4, 0.3), (0, 0, 0.15), mat="stone", bevel=0.05)
    for x in (-4.2, -1.6, 1.6, 4.2):
        tall = abs(x) < 2.0
        height = 5.2 if tall else 3.8
        b.cylinder(0.22, height, (x, 0, 0.3 + height / 2), mat="vermilion", segments=10)
        b.box((0.7, 0.7, 0.32), (x, 0, 0.46), mat="stone_light", bevel=0.05)
    b.box((3.6, 0.36, 0.38), (0, 0, 4.9), mat="vermilion_dark", bevel=0.04)
    b.box((1.6, 0.12, 0.7), (0, -0.22, 4.3), mat="gold", bevel=0.03)
    b.box((1.3, 0.14, 0.5), (0, -0.25, 4.3), mat="ink")
    for side in (-1, 1):
        b.box((2.8, 0.32, 0.3), (side * 2.9, 0, 3.7), mat="vermilion_dark", bevel=0.03)
        roof(b, 3.4, 2.6, 4.0, 0.7, center=(side * 2.9, 0), upturn=0.35)
    roof(b, 4.4, 3.2, 5.45, 1.0, center=(0, 0), upturn=0.5)
    b.build()
    for x in (-4.2, -1.6, 1.6, 4.2):
        vk.collider_cylinder(f"Pillar{x}", 0.3, 5.0, (x, 0, 2.6))


def pagoda_bell_tower():
    """Three-tier pagoda with a bronze bell under the lowest roof."""
    b = vk.MeshBuilder("Pagoda")
    b.box((4.6, 4.6, 0.5), (0, 0, 0.25), mat="stone", bevel=0.06)
    z = 0.5
    for tier, (width, height) in enumerate([(3.4, 2.6), (2.7, 2.0), (2.1, 1.7)]):
        for x in (-width / 2 + 0.15, width / 2 - 0.15):
            for y in (-width / 2 + 0.15, width / 2 - 0.15):
                b.cylinder(0.12, height, (x, y, z + height / 2), mat="vermilion", segments=8)
        b.box((width, width, 0.14), (0, 0, z + height - 0.07), mat="wood_dark")
        if tier > 0:
            b.box((width - 0.4, width - 0.4, height * 0.8), (0, 0, z + height * 0.45), mat="cream")
        roof(b, width + 1.3, width + 1.3, z + height, 0.55 + tier * 0.05, upturn=0.45)
        z += height + 0.55
    b.cylinder(0.05, 1.2, (0, 0, z + 0.4), mat="gold", top=0.0, segments=6)
    b.cylinder(0.55, 0.9, (0, 0, 1.9), mat="bronze", top=0.38, segments=14)
    b.sphere(0.4, (0, 0, 2.38), scale=(1, 1, 0.5), mat="bronze", segments=12, rings=6)
    b.build()
    vk.collider_box("Base", (3.6, 3.6, 3.2), (0, 0, 1.8))


def incense_burner():
    b = vk.MeshBuilder("Incense")
    b.box((1.4, 1.4, 0.3), (0, 0, 0.15), mat="stone", bevel=0.04)
    for k in range(3):
        a = k * math.tau / 3
        b.segment((math.cos(a) * 0.35, math.sin(a) * 0.35, 0.3), (math.cos(a) * 0.42, math.sin(a) * 0.42, 0.62), 0.07, 0.05, mat="bronze", segments=6)
    b.sphere(0.5, (0, 0, 0.92), scale=(1, 1, 0.62), mat="bronze", segments=14, rings=8)
    b.torus(0.48, 0.05, (0, 0, 1.18), mat="gold", segments=16, ring=5)
    for side in (-1, 1):
        b.torus(0.12, 0.03, (side * 0.52, 0, 1.15), (90, 0, 0), mat="bronze", segments=10, ring=4)
    b.cylinder(0.32, 0.18, (0, 0, 1.3), mat="bronze", top=0.12, segments=12)
    b.sphere(0.08, (0, 0, 1.45), mat="gold", segments=8, rings=4)
    for k in range(3):
        b.cylinder(0.012, 0.35, (0.08 * (k - 1), 0.05, 1.32), mat="wood_dark", segments=4)
    b.build()
    vk.collider_cylinder("Body", 0.6, 1.4, (0, 0, 0.7))


def stone_nghe():
    """Guardian lion (nghê) on a plinth, seated and facing forward (-Y)."""
    b = vk.MeshBuilder("Nghe")
    b.box((1.0, 1.4, 0.7), (0, 0, 0.35), mat="stone_dark", bevel=0.05)
    b.sphere(0.55, (0, 0.15, 1.15), scale=(0.75, 1.0, 0.95), mat="stone_light", segments=12, rings=8)
    b.sphere(0.48, (0, -0.42, 1.75), scale=(1.0, 0.9, 0.95), mat="stone_light", segments=12, rings=8)
    b.sphere(0.36, (0, -0.48, 1.62), scale=(1.5, 0.8, 1.2), mat="stone", segments=10, rings=6)
    for side in (-1, 1):
        b.sphere(0.1, (side * 0.18, -0.85, 1.82), mat="ink", segments=6, rings=4)
        b.segment((side * 0.22, -0.45, 0.72), (side * 0.22, -0.55, 1.15), 0.12, 0.1, mat="stone_light", segments=8)
        for curl in range(3):
            b.sphere(0.12, (side * 0.38, -0.25 + curl * 0.18, 2.0 - curl * 0.12), mat="stone", segments=6, rings=4)
    b.sphere(0.16, (0, -0.95, 1.6), scale=(1.6, 0.8, 0.8), mat="stone_dark", segments=8, rings=5)
    b.segment((0, 0.65, 1.0), (0, 0.95, 1.7), 0.08, 0.14, mat="stone", segments=6)
    b.build()
    vk.collider_box("Body", (1.0, 1.4, 2.2), (0, 0, 1.1))


def prayer_banner():
    """Tall pole with a long vertical cloth banner (sways in the wind in game)."""
    b = vk.MeshBuilder("Banner")
    b.cylinder(0.08, 6.0, (0, 0, 3.0), mat="wood_dark", segments=8)
    b.sphere(0.12, (0, 0, 6.05), mat="gold", segments=8, rings=4)
    b.cylinder(0.04, 1.3, (0.6, 0, 5.7), (0, 90, 0), mat="wood_dark", segments=6)
    b.box((1.1, 0.04, 3.6), (0.62, 0, 3.85), mat="banner_red")
    b.box((0.9, 0.05, 3.2), (0.62, -0.01, 3.9), mat="banner_cream")
    for k in range(5):
        b.box((0.5, 0.06, 0.08), (0.62, -0.02, 5.0 - k * 0.55), mat="ink")
    b.box((1.1, 0.06, 0.12), (0.62, 0, 2.05), mat="gold")
    b.build()
    vk.collider_cylinder("Pole", 0.15, 6.0, (0, 0, 3.0))


def rice_rack():
    """A-frame drying rack hung with golden rice sheaves."""
    b = vk.MeshBuilder("RiceRack")
    for x in (-1.8, 1.8):
        b.segment((x, -0.7, 0), (x, 0, 2.2), 0.06, mat="wood", segments=6)
        b.segment((x, 0.7, 0), (x, 0, 2.2), 0.06, mat="wood", segments=6)
    for z in (1.0, 1.6, 2.15):
        b.cylinder(0.045, 4.0, (0, 0, z), (0, 90, 0), mat="wood_dark", segments=6)
    for row, z in enumerate((1.0, 1.6)):
        for k in range(9):
            x = -1.6 + k * 0.4
            b.cone(0.16, 0.7, (x, 0, z - 0.32), (180, 0, 0), mat="hay" if (k + row) % 2 else "hay_dark", segments=6)
    b.build()
    vk.collider_box("Body", (3.8, 1.2, 2.2), (0, 0, 1.1))


def haystack():
    b = vk.MeshBuilder("Haystack")
    b.cylinder(1.2, 1.4, (0, 0, 0.7), mat="hay", top=1.05, segments=12)
    b.cone(1.15, 1.6, (0, 0, 2.2), mat="hay", segments=12)
    b.torus(1.08, 0.06, (0, 0, 1.35), mat="hay_dark", segments=16, ring=4)
    b.cylinder(0.06, 0.8, (0, 0, 3.1), mat="wood_dark", segments=6)
    b.build()
    vk.collider_cylinder("Body", 1.2, 2.6, (0, 0, 1.3))


def lantern_string():
    """Two posts with a sagging cord of red lanterns (spans about 8 m)."""
    b = vk.MeshBuilder("LanternString")
    for x in (-4.0, 4.0):
        b.cylinder(0.08, 3.6, (x, 0, 1.8), mat="wood_dark", segments=8)
    points = []
    for k in range(13):
        u = k / 12
        points.append((-4.0 + 8.0 * u, 0, 3.5 - math.sin(u * math.pi) * 0.7))
    for a, c in zip(points, points[1:]):
        b.segment(a, c, 0.015, mat="ink", segments=4)
    for k in range(1, 6):
        u = k / 6
        hanging_lantern(b, -4.0 + 8.0 * u, 0, 3.5 - math.sin(u * math.pi) * 0.7 - 0.55, "vermilion" if k % 2 else "gold")
    b.build()
    for x in (-4.0, 4.0):
        vk.collider_cylinder(f"Post{x}", 0.12, 3.6, (x, 0, 1.8))


def flower_pot():
    """Terracotta pot with a leafy shrub and blooms (doorsteps and stalls)."""
    rng = random.Random(101)
    b = vk.MeshBuilder("FlowerPot")
    b.cylinder(0.32, 0.5, (0, 0, 0.25), mat="pot", top=0.4, segments=12)
    b.torus(0.4, 0.04, (0, 0, 0.5), mat="pot_dark", segments=14, ring=4)
    for k in range(5):
        a = k * 1.26
        b.sphere(0.24, (math.cos(a) * 0.15, math.sin(a) * 0.15, 0.72 + rng.uniform(0, 0.12)), scale=(1, 1, 0.85), mat="leaf", segments=8, rings=5)
    for k in range(7):
        a = k * 0.9
        b.sphere(0.06, (math.cos(a) * 0.26, math.sin(a) * 0.26, 0.86 + rng.uniform(0, 0.1)), mat="petal_white" if k % 2 else "blossom", segments=6, rings=4)
    return b


def basket_produce():
    """Woven basket heaped with oranges and greens."""
    rng = random.Random(103)
    b = vk.MeshBuilder("Basket")
    b.cylinder(0.42, 0.36, (0, 0, 0.18), mat="wood_light", top=0.5, segments=12)
    b.torus(0.5, 0.04, (0, 0, 0.36), mat="wood", segments=14, ring=4)
    for k in range(10):
        a = k * 2.4
        r = rng.uniform(0.0, 0.33)
        b.sphere(0.11, (math.cos(a) * r, math.sin(a) * r, 0.42 + rng.uniform(0, 0.08)), mat="fruit_orange" if k % 3 else "fruit_green", segments=8, rings=5)
    return b


ASSETS = {
    "house_small": house_small, "house_long": house_long, "house_teal": house_teal, "smithy": smithy, "gate_village": gate_village,
    "shrine_wind": shrine_wind, "bridge_wood": bridge_wood, "dock": dock, "boat": boat, "lantern_stone": lantern_stone,
    "lantern_post": lantern_post, "signboard": signboard, "table": table, "bench": bench, "chest": chest, "stele": stele,
    "ruins_pillar": ruins_pillar, "ruins_wall": ruins_wall, "well": well, "barrel": barrel, "crate": crate, "fence_bamboo": fence_bamboo,
    "market_stall": market_stall, "watchtower": watchtower, "wind_chime_post": wind_chime_post, "seal_gate": seal_gate,
    "campfire": campfire, "tent": tent, "steps_stone": steps_stone, "rock_cliff": rock_cliff, "memory_stone": memory_stone,
    "gate_tam_quan": gate_tam_quan, "pagoda_bell_tower": pagoda_bell_tower, "incense_burner": incense_burner, "stone_nghe": stone_nghe,
    "prayer_banner": prayer_banner, "rice_rack": rice_rack, "haystack": haystack, "lantern_string": lantern_string,
    "flower_pot": flower_pot, "basket_produce": basket_produce,
}


def main(names, preview):
    out_dir = vk.MODELS / "env"
    out_dir.mkdir(parents=True, exist_ok=True)
    for name in names:
        vk.reset()
        built = ASSETS[name]()
        if isinstance(built, vk.MeshBuilder):
            built.build()
        original_art = vk.ART
        original_models = vk.MODELS
        vk.MODELS = out_dir
        vk.ART = original_art / "env"
        info = vk.save_and_export(name, extra={"kind": "prop"})
        vk.MODELS, vk.ART = original_models, original_art
        vk.write_manifest_entry(info, "env")
        if preview:
            dims = [max(abs(v.co[i]) for obj in bpy.context.scene.objects if obj.type == "MESH" for v in obj.data.vertices) for i in range(3)]
            size = max(dims[0], dims[1], dims[2] * 0.6) * 2.4 + 0.5
            vk.render_preview("env_" + name, {"q": (35, 18, size)}, size=(360, 300), target=(0, 0, dims[2] * 0.45))


if __name__ == "__main__":
    if not bpy.app.background:
        raise RuntimeError("Run this generator in a separate background Blender process.")
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    selected = [arg for arg in argv if not arg.startswith("--")] or list(ASSETS)
    main(selected, "--preview" in argv)
