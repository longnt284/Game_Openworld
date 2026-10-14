"""Shared humanoid rig, stylised anime body kit and pose/animation engine.

Bone frames are rolled so every bone's local X matches the character's lateral
axis (+X = character left). That keeps Euler poses readable:
  up-chain bones (hips..head): +x bends forward, +y turns left, +z leans right
  down-chain bones (arms, legs): +x swings back, -x forward; shin +x bends knee
Arms are usually posed by aiming directions in character space instead
(x left, y back, z up), which keeps sword lines precise.
"""
import math

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

import vk_lib as vk

THIGH = 0.43
SHIN = 0.41
LEG = THIGH + SHIN

BONES = [
    ("root", None, (0, 0, 0), (0, 0, 0.2)),
    ("hips", "root", (0, 0, 0.95), (0, 0, 1.05)),
    ("spine", "hips", (0, 0, 1.05), (0, 0, 1.2)),
    ("chest", "spine", (0, 0, 1.2), (0, 0, 1.38)),
    ("neck", "chest", (0, 0, 1.38), (0, 0, 1.46)),
    ("head", "neck", (0, 0, 1.46), (0, 0, 1.72)),
    ("ponytail", "head", (0, 0.11, 1.665), (0, 0.2, 1.42)),
    ("scarf", "chest", (0, 0.07, 1.39), (0, 0.24, 1.16)),
    ("upper_arm.L", "chest", (0.19, 0, 1.355), (0.215, 0, 1.08)),
    ("forearm.L", "upper_arm.L", (0.215, 0, 1.08), (0.225, 0, 0.84)),
    ("hand.L", "forearm.L", (0.225, 0, 0.84), (0.225, 0, 0.75)),
    ("upper_arm.R", "chest", (-0.19, 0, 1.355), (-0.215, 0, 1.08)),
    ("forearm.R", "upper_arm.R", (-0.215, 0, 1.08), (-0.225, 0, 0.84)),
    ("hand.R", "forearm.R", (-0.225, 0, 0.84), (-0.225, 0, 0.75)),
    ("thigh.L", "hips", (0.09, 0, 0.93), (0.095, 0, 0.5)),
    ("shin.L", "thigh.L", (0.095, 0, 0.5), (0.1, 0, 0.09)),
    ("foot.L", "shin.L", (0.1, 0, 0.09), (0.1, -0.14, 0.03)),
    ("thigh.R", "hips", (-0.09, 0, 0.93), (-0.095, 0, 0.5)),
    ("shin.R", "thigh.R", (-0.095, 0, 0.5), (-0.1, 0, 0.09)),
    ("foot.R", "shin.R", (-0.1, 0, 0.09), (-0.1, -0.14, 0.03)),
]
BONE_NAMES = [bone[0] for bone in BONES]
# Grip frame inside the right fist: blade (+Z) points forward-down while the arm hangs.
BLADE_REST = Vector((0, -0.7071, -0.7071))
EDGE_REST = Vector((0, -0.7071, 0.7071))


def norm(*values):
    return Vector(values).normalized()


# ---------------------------------------------------------------- body kit

def head_point(x, z, out=0.0, center=(0, 0, 1.585), radii=(0.102, 0.112, 0.125)):
    """Point on the shaped face surface (front), plus its outward yaw in degrees."""
    rx, ry, rz = radii
    inner = max(0.0, 1.0 - (x / rx) ** 2 - (z / rz) ** 2)
    local = Vector((x, -ry * math.sqrt(inner), z))
    shaped = chin(local.copy())
    normal = Vector((local.x / rx ** 2, local.y / ry ** 2, local.z / rz ** 2)).normalized()
    point = Vector(center) + shaped + normal * out
    yaw = math.degrees(math.atan2(normal.x, -normal.y))
    pitch = math.degrees(math.atan2(normal.z, -normal.y))
    return point, yaw, pitch


def chin(co):
    if co.z < -0.015:
        t = min(1.0, (-co.z - 0.015) / 0.11)
        co.x *= 1.0 - 0.45 * t
        co.y *= (1.0 - 0.16 * t) if co.y < 0 else (1.0 - 0.38 * t)
    return co


def face(b, spec):
    skin = spec.get("skin", "skin")
    b.sphere(1.0, (0, 0, 1.585), scale=(0.102, 0.112, 0.125), mat=skin, bone="head", segments=16, rings=12, shape=chin)
    for side in (1, -1):
        b.sphere(1.0, (side * 0.103, 0.004, 1.575), scale=(0.014, 0.026, 0.03), mat=skin, bone="head", segments=8, rings=6)
    eye_scale = spec.get("eye_scale", 1.0)
    iris = spec.get("iris", "iris")
    for side in (1, -1):
        x = side * 0.04
        point, yaw, pitch = head_point(x, -0.012, 0.002)
        rot = (-pitch, 0, side * abs(yaw))
        b.sphere(1.0, point, rot, scale=(0.024 * eye_scale, 0.006, 0.022 * eye_scale), mat="white", bone="head", segments=10, rings=6)
        point, yaw, pitch = head_point(x - side * 0.002, -0.013, 0.006)
        b.sphere(1.0, point, rot, scale=(0.015 * eye_scale, 0.005, 0.02 * eye_scale), mat=iris, bone="head", segments=10, rings=6)
        point, _, _ = head_point(x - side * 0.002, -0.014, 0.0095)
        b.sphere(1.0, point, rot, scale=(0.0075 * eye_scale, 0.003, 0.011 * eye_scale), mat="ink", bone="head", segments=8, rings=5)
        point, _, _ = head_point(x + side * 0.005, -0.006, 0.012)
        b.sphere(1.0, point, rot, scale=(0.0045, 0.002, 0.0055), mat="white", bone="head", segments=6, rings=4)
        point, yaw, pitch = head_point(x + side * 0.002, 0.009, 0.006)
        b.box((0.054 * eye_scale, 0.008, 0.008), point, (-pitch, side * spec.get("lash_tilt", 10), side * abs(yaw)), mat="ink", bone="head")
        point, yaw, pitch = head_point(x - side * 0.002, 0.042, 0.004)
        b.box((0.042, 0.006, 0.0065), point, (-pitch, -side * spec.get("brow_tilt", 8), side * abs(yaw)), mat=spec.get("brow", spec.get("hair", "hair")), bone="head")
    point, yaw, pitch = head_point(0, -0.078, 0.002)
    b.box((spec.get("mouth", 0.018), 0.005, 0.0045), point, (-pitch, 0, 0), mat="vermilion_dark", bone="head")
    point, _, pitch = head_point(0, -0.04, 0.0)
    b.cone(0.007, 0.016, point, (90 - pitch, 0, 0), mat=skin, bone="head", segments=4)
    b.cylinder(0.046, 0.12, (0, 0.008, 1.44), mat=skin, bone={"neck": 0.7, "head": 0.3}, segments=10)


HEAD_CENTER = Vector((0, 0.012, 1.6))


def hair_cap(b, mat, center=(0, 0.012, 1.605), radii=(0.121, 0.132, 0.137), front_line=0.05):
    def shape(co):
        if co.y < -0.02 and co.z < front_line:
            co.z = front_line + (front_line - co.z) * 0.12
            co.y *= 0.95
        if co.z < -0.075 and co.y < 0.05:
            co.z = -0.075
            co.x *= 0.7
        return co
    b.sphere(1.0, center, scale=radii, mat=mat, bone="head", segments=18, rings=12, shape=shape)


def clump(b, points, widths, mat, bone="head", flat=0.38, center=None, segments=6):
    """Tapered, flattened hair lock following `points`; flat side faces away from the skull."""
    center = Vector(center or HEAD_CENTER)
    points = [Vector(p) for p in points]
    rings = []
    for i, point in enumerate(points):
        tangent = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        out = (point - center)
        out = (out - tangent * out.dot(tangent)).normalized()
        side = tangent.cross(out).normalized()
        width = max(widths[i], 0.0015)
        rings.append([point + side * math.cos(a) * width + out * math.sin(a) * width * flat
                      for a in [math.tau * k / segments for k in range(segments)]])
    if isinstance(bone, list):
        return b.loft(rings, mat=mat, bone=bone, sharp_angle=75)
    return b.loft(rings, mat=mat, bone=bone, sharp_angle=75)


def lock(b, root, bend, tip, width, mat, bone="head", flat=0.38):
    """Three-point curved lock with a soft taper."""
    root, bend, tip = Vector(root), Vector(bend), Vector(tip)
    points = [root, root.lerp(bend, 0.6), bend, bend.lerp(tip, 0.55), tip]
    return clump(b, points, [width * 0.8, width, width * 0.85, width * 0.5, 0.0], mat, bone, flat)


def spike(b, root, tip, width, mat, bone="head", flat=0.45, segments=4):
    b.segment(tip, root, 0.0, width, mat=mat, bone=bone, segments=segments, flat=flat, smooth=False)


def hair_hero(b, spec):
    mat = spec.get("hair", "hair")
    hair_cap(b, mat)
    # fringe: parted slightly off-centre, locks sweep outward and stop above the eyes
    fringe = [(-0.012, -0.03, 0.035), (0.022, 0.0, 0.034), (0.055, 0.035, 0.03), (0.082, 0.06, 0.026), (-0.045, -0.07, 0.032), (-0.078, -0.095, 0.026)]
    for x, tip_x, width in fringe:
        root = (x * 0.8, -0.085, 1.72)
        bend = (x * 1.05, -0.132, 1.67)
        tip = (tip_x, -0.128, 1.615 + abs(x) * 0.25)
        lock(b, root, bend, tip, width, mat)
    for side in (1, -1):
        lock(b, (side * 0.09, -0.06, 1.69), (side * 0.118, -0.085, 1.6), (side * 0.11, -0.075, 1.47), 0.03, mat)
        lock(b, (side * 0.11, -0.02, 1.7), (side * 0.135, -0.04, 1.6), (side * 0.13, -0.03, 1.5), 0.034, mat)
        lock(b, (side * 0.1, 0.06, 1.71), (side * 0.13, 0.08, 1.6), (side * 0.11, 0.1, 1.5), 0.04, mat)
    for x, y in ((0.0, -0.02), (0.05, 0.02), (-0.05, 0.02), (0.0, 0.05)):
        lock(b, (x, y - 0.06, 1.735), (x * 1.3, y + 0.04, 1.765), (x * 1.6, y + 0.13, 1.71), 0.045, mat, flat=0.45)
    for x in (-0.07, 0.0, 0.07):
        lock(b, (x, 0.08, 1.7), (x * 1.2, 0.14, 1.6), (x * 0.9, 0.12, 1.5), 0.045, mat)
    b.torus(0.028, 0.012, (0, 0.128, 1.672), (90 - 25, 0, 0), mat=spec.get("tie", "vermilion"), bone="head", segments=12, ring=6)
    weights = [{"head": 1.0}, {"ponytail": 0.5, "head": 0.5}, {"ponytail": 1.0}, {"ponytail": 1.0}, {"ponytail": 1.0}, {"ponytail": 1.0}]
    center = (0, 0.05, 1.62)
    clump(b, [(0, 0.13, 1.675), (0, 0.17, 1.66), (0, 0.215, 1.58), (0, 0.23, 1.47), (0, 0.215, 1.37), (0, 0.19, 1.28)],
          [0.03, 0.045, 0.05, 0.045, 0.03, 0.0], mat, weights, flat=0.75, center=center, segments=8)
    clump(b, [(0.0, 0.13, 1.68), (0.02, 0.18, 1.67), (0.04, 0.23, 1.6), (0.05, 0.25, 1.52), (0.05, 0.24, 1.45), (0.045, 0.22, 1.4)],
          [0.02, 0.03, 0.032, 0.028, 0.018, 0.0], mat, weights, flat=0.6, center=center)
    clump(b, [(0.0, 0.13, 1.68), (-0.02, 0.18, 1.67), (-0.035, 0.225, 1.59), (-0.04, 0.235, 1.5), (-0.035, 0.22, 1.42), (-0.03, 0.2, 1.36)],
          [0.02, 0.03, 0.03, 0.026, 0.016, 0.0], mat, weights, flat=0.6, center=center)


def hair_bun(b, spec):
    mat = spec.get("hair", "hair_white")
    hair_cap(b, mat, front_line=0.06)
    b.sphere(1.0, (0, 0.085, 1.69), scale=(0.07, 0.065, 0.06), mat=mat, bone="head", segments=12, rings=8)
    b.segment((-0.1, 0.07, 1.71), (0.1, 0.1, 1.67), 0.006, mat=spec.get("pin", "gold"), bone="head", segments=6)
    for side in (1, -1):
        b.sphere(1.0, (side * 0.085, -0.02, 1.64), scale=(0.035, 0.05, 0.05), mat=mat, bone="head", segments=8, rings=6)


def hair_short(b, spec):
    mat = spec.get("hair", "hair_brown")
    hair_cap(b, mat, front_line=0.055)
    for x, tip_x, width in ((-0.06, -0.075, 0.03), (-0.025, -0.03, 0.032), (0.012, 0.018, 0.032), (0.05, 0.062, 0.03), (0.082, 0.098, 0.024)):
        lock(b, (x * 0.8, -0.085, 1.72), (x * 1.05, -0.13, 1.68), (tip_x, -0.128, 1.635 + abs(x) * 0.15), width, mat)
    for side in (1, -1):
        lock(b, (side * 0.1, -0.04, 1.7), (side * 0.128, -0.06, 1.62), (side * 0.122, -0.05, 1.54), 0.03, mat)
    for x in (-0.06, 0.0, 0.06):
        lock(b, (x, 0.06, 1.72), (x * 1.2, 0.13, 1.64), (x, 0.12, 1.53), 0.042, mat)
    for x, y in ((0.0, -0.02), (0.05, 0.02), (-0.05, 0.02)):
        lock(b, (x, y - 0.05, 1.735), (x * 1.3, y + 0.03, 1.762), (x * 1.5, y + 0.11, 1.72), 0.042, mat, flat=0.45)


def hair_bun(b, spec):
    mat = spec.get("hair", "hair_white")
    hair_cap(b, mat, front_line=0.06)
    b.sphere(1.0, (0, 0.085, 1.7), scale=(0.072, 0.066, 0.062), mat=mat, bone="head", segments=14, rings=8)
    b.segment((-0.1, 0.07, 1.72), (0.1, 0.1, 1.68), 0.006, mat=spec.get("pin", "gold"), bone="head", segments=6)
    for side in (1, -1):
        lock(b, (side * 0.02, -0.11, 1.72), (side * 0.08, -0.12, 1.69), (side * 0.118, -0.05, 1.62), 0.035, mat, flat=0.5)
        lock(b, (side * 0.1, -0.03, 1.69), (side * 0.125, -0.03, 1.6), (side * 0.11, 0.02, 1.53), 0.03, mat)


def hair_long(b, spec):
    mat = spec.get("hair", "hair_white")
    hair_cap(b, mat, front_line=0.06)
    for side in (1, -1):
        lock(b, (side * 0.02, -0.11, 1.72), (side * 0.085, -0.125, 1.67), (side * 0.12, -0.07, 1.56), 0.04, mat, flat=0.5)
        lock(b, (side * 0.1, -0.05, 1.68), (side * 0.13, -0.07, 1.48), (side * 0.12, -0.07, 1.3), 0.032, mat, bone={"head": 0.6, "chest": 0.4})
    center = (0, 0.0, 1.55)
    for x in (-0.08, -0.03, 0.03, 0.08):
        clump(b, [(x * 0.8, 0.07, 1.72), (x, 0.13, 1.62), (x * 1.1, 0.14, 1.45), (x * 1.15, 0.13, 1.28), (x * 1.1, 0.12, 1.12)],
              [0.03, 0.05, 0.05, 0.045, 0.0], mat, [{"head": 1.0}, {"head": 1.0}, {"head": 0.5, "chest": 0.5}, {"chest": 1.0}, {"chest": 1.0}],
              flat=0.4, center=center)


def hat_conical(b, spec):
    """Nón lá: wide leaf hat with a chin strap."""
    b.cone(0.26, 0.15, (0, 0.0, 1.75), mat=spec.get("hat", "paper"), bone="head", segments=16, smooth=False)
    b.torus(0.205, 0.006, (0, 0.0, 1.69), mat="wood_light", bone="head", segments=16, ring=4)
    for side in (1, -1):
        b.segment((side * 0.1, -0.02, 1.68), (side * 0.06, -0.06, 1.47), 0.004, mat="vermilion", bone="head", segments=4)


def bandana(b, spec):
    b.sphere(1.0, (0, 0.006, 1.615), scale=(0.114, 0.124, 0.115), mat=spec.get("bandana", "vermilion"), bone="head", segments=14, rings=10,
             shape=lambda co: Vector((co.x, co.y, max(co.z, 0.02 - co.y * 0.4))))
    b.strip([(0.0, 0.12, 1.62), (0.03, 0.2, 1.55), (0.05, 0.24, 1.47)], 0.04, normal=(1, 0, 0), mat=spec.get("bandana", "vermilion"), bone="head")


def mask_face(b, spec):
    """Half mask over the upper face plus a cloth wrap over mouth and nose."""
    mat = spec.get("mask", "mask")
    b.sphere(1.0, (0, -0.012, 1.6), scale=(0.11, 0.115, 0.075), mat=mat, bone="head", segments=14, rings=8,
             shape=lambda co: Vector((co.x, min(co.y, -0.02) if co.y < 0 else co.y * 0.2 - 0.02, co.z)))
    for side in (1, -1):
        point, yaw, pitch = head_point(side * 0.04, -0.005, 0.016)
        b.box((0.036, 0.006, 0.012), point, (-pitch, side * 12, side * abs(yaw)), mat=spec.get("eye_glow", "ink"), bone="head")
        point, yaw, pitch = head_point(side * 0.06, 0.03, 0.017)
        b.box((0.012, 0.005, 0.05), point, (-pitch, side * -20, side * abs(yaw)), mat=spec.get("mask_mark", "vermilion"), bone="head")

    def wrap(co):
        co = chin(co)
        if co.z > -0.035:
            co.z = -0.035
        if co.y > 0.02:
            co.y = 0.02
        return co
    b.sphere(1.0, (0, -0.004, 1.585), scale=(0.108, 0.12, 0.13), mat=spec.get("cloth_mask", "cloth_dark"), bone="head", segments=14, rings=10, shape=wrap)


def helmet(b, spec):
    plate = spec.get("plate", "bamboo_dark")
    b.sphere(1.0, (0, 0.01, 1.64), scale=(0.135, 0.145, 0.12), mat=plate, bone="head", segments=16, rings=10,
             shape=lambda co: Vector((co.x, co.y, max(co.z, -0.02 - max(0.0, co.y) * 0.6))))
    b.torus(0.138, 0.01, (0, 0.01, 1.625), mat="gold", bone="head", segments=18, ring=4)
    b.cylinder(0.22, 0.02, (0, 0.01, 1.63), mat=spec.get("plate_light", "bamboo"), bone="head", top=0.16, segments=18)
    b.cone(0.035, 0.12, (0, 0.0, 1.8), mat="gold", bone="head", segments=8)
    b.strip([(0, 0.0, 1.83), (0, 0.08, 1.8), (0, 0.18, 1.7), (0, 0.24, 1.58)], [0.05, 0.06, 0.05, 0.03], normal=(1, 0, 0), mat="vermilion", bone="head")


def beard(b, spec):
    mat = spec.get("beard", "hair_brown")
    point, _, pitch = head_point(0, -0.105, 0.0)
    b.cone(0.035, 0.08, point + Vector((0, -0.005, -0.03)), (180 + pitch * 0.3, 0, 0), mat=mat, bone="head", segments=6, scale=(1, 0.6, 1))
    for side in (1, -1):
        point, _, _ = head_point(side * 0.02, -0.06, 0.004)
        b.segment(point, point + Vector((side * 0.035, -0.005, -0.012)), 0.007, 0.003, mat=mat, bone="head", segments=5)


def torso_rings(spec):
    width = spec.get("width", 1.0)
    belly = spec.get("belly", 1.0)
    profile = [(0.92, 0.3, 0.2), (1.02, 0.27 * belly, 0.18 * belly), (1.14, 0.29 * belly, 0.19 * belly), (1.26, 0.34, 0.21),
               (1.34, 0.36, 0.2), (1.385, 0.3, 0.17), (1.415, 0.13, 0.11)]
    rings = []
    for z, w, d in profile:
        w *= width if z > 1.2 else 1.0
        rings.append([(math.cos(a) * w * 0.5, math.sin(a) * d * 0.5, z) for a in [math.tau * i / 12 for i in range(12)]])
    return rings, profile


def torso_front(z, spec):
    _, profile = torso_rings(spec)
    for (z0, _, d0), (z1, _, d1) in zip(profile, profile[1:]):
        if z0 <= z <= z1:
            t = (z - z0) / (z1 - z0)
            return -(d0 + (d1 - d0) * t) * 0.5
    return -0.1


def torso(b, spec):
    rings, _ = torso_rings(spec)
    weights = ["hips", {"hips": 0.6, "spine": 0.4}, "spine", "chest", "chest", "chest", {"chest": 0.6, "neck": 0.4}]
    b.loft(rings, mat=spec.get("outer", "jade"), bone=weights, sharp_angle=70)
    inner = spec.get("inner", "cream")
    trim = spec.get("trim", "white")
    collar = [[(math.cos(a) * r, 0.006 + math.sin(a) * r * 0.95, z) for a in [math.tau * i / 12 for i in range(12)]] for z, r in ((1.395, 0.075), (1.445, 0.06))]
    b.loft(collar, mat=inner, bone={"chest": 0.5, "neck": 0.5}, cap_bottom=False, sharp_angle=40)
    for side, mat, offset in ((1, inner, 0.006), (-1, trim, 0.009)):
        points = []
        for i in range(6):
            t = i / 5
            z = 1.405 - t * 0.27
            x = side * (0.065 - t * 0.11)
            points.append((x, torso_front(z, spec) - offset - 0.004 * (1 - abs(x) * 6), z))
        b.strip(points, [0.045 - i * 0.004 for i in range(6)], normal=(0, -1, 0), mat=mat, bone="chest", thickness=0.004)
    sash = spec.get("sash", "vermilion")
    if sash:
        ring = []
        for z in (1.0, 1.075):
            ring.append([(math.cos(a) * 0.152 * spec.get("belly", 1.0), math.sin(a) * 0.102 * spec.get("belly", 1.0), z) for a in [math.tau * i / 12 for i in range(12)]])
        b.loft(ring, mat=sash, bone={"spine": 0.5, "hips": 0.5}, sharp_angle=40)
        b.sphere(1.0, (0.07, -0.1, 1.035), scale=(0.035, 0.022, 0.03), mat=sash, bone="hips", segments=8, rings=6)
        for dx, end in ((0.06, 0.78), (0.09, 0.82)):
            b.strip([(dx, -0.11, 1.02), (dx + 0.01, -0.115, 0.92), (dx + 0.02, -0.11, end)], [0.035, 0.03, 0.026], normal=(0, -1, 0), mat=sash,
                    bone={"hips": 0.6, "thigh.L": 0.4}, thickness=0.004)


def coat_tails(b, spec):
    mat = spec.get("tails", spec.get("outer", "jade"))
    length = spec.get("tail_length", 0.46)
    for side in (1, -1):
        thigh = "thigh.L" if side > 0 else "thigh.R"
        for front in (1, -1):
            y = -0.088 if front > 0 else 0.088
            b.box((0.15, 0.022, length), (side * 0.075, y, 0.99 - length * 0.5), (-8 * front, side * 4 * front, 0), mat=mat,
                  bone={thigh: 0.55, "hips": 0.45}, taper=(0.82, 1.0))
            b.box((0.152, 0.024, 0.035), (side * 0.075, y - 0.002 * front, 0.99 - length + 0.02), (-8 * front, side * 4 * front, 0),
                  mat=spec.get("trim", "white"), bone={thigh: 0.6, "hips": 0.4})


def skirt(b, spec):
    mat = spec.get("skirt", "cloth_brown")
    rings = []
    for z, w, d in ((1.0, 0.31, 0.21), (0.6, 0.4, 0.3), (0.12, 0.46, 0.36)):
        rings.append([(math.cos(a) * w * 0.5, math.sin(a) * d * 0.5, z) for a in [math.tau * i / 12 for i in range(12)]])
    rings.reverse()
    weights = [{"thigh.L": 0.25, "thigh.R": 0.25, "hips": 0.5}, {"thigh.L": 0.2, "thigh.R": 0.2, "hips": 0.6}, "hips"]
    b.loft(rings, mat=mat, bone=weights, sharp_angle=70)


def legs(b, spec):
    pants = spec.get("pants", "cloth_dark")
    boots = spec.get("boots", "leather")
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        b.segment((side * 0.09, 0, 0.95), (side * 0.096, 0, 0.5), 0.078, 0.06, mat=pants, bone="thigh." + s, segments=10)
        b.sphere(0.06, (side * 0.096, 0, 0.5), mat=pants, bone={"thigh." + s: 0.5, "shin." + s: 0.5}, segments=10, rings=6)
        b.segment((side * 0.096, 0, 0.5), (side * 0.099, 0, 0.3), 0.056, 0.048, mat=pants, bone="shin." + s, segments=10)
        b.segment((side * 0.099, 0.004, 0.34), (side * 0.1, 0.004, 0.065), 0.057, 0.05, mat=boots, bone="shin." + s, segments=10)
        for z in (0.29, 0.2):
            b.torus(0.056, 0.007, (side * 0.0995, 0.004, z), mat=spec.get("wrap", "cream"), bone="shin." + s, segments=10, ring=4)
        b.box((0.088, 0.2, 0.075), (side * 0.1, -0.045, 0.04), mat=boots, bone="foot." + s, bevel=0.018)
        b.box((0.092, 0.205, 0.016), (side * 0.1, -0.045, 0.006), mat="wood_dark", bone="foot." + s)


def arms(b, spec):
    sleeve = spec.get("sleeve", spec.get("outer", "jade"))
    bracer = spec.get("bracer", "leather")
    skin = spec.get("skin", "skin")
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        b.sphere(0.064, (side * 0.185, 0, 1.345), mat=sleeve, bone={"upper_arm." + s: 0.7, "chest": 0.3}, segments=10, rings=8)
        if spec.get("bare_forearms"):
            b.segment((side * 0.19, 0, 1.355), (side * 0.214, 0, 1.06), 0.058, 0.064, mat=sleeve, bone="upper_arm." + s, segments=10)
            b.segment((side * 0.215, 0, 1.08), (side * 0.225, 0, 0.83), 0.045, 0.036, mat=skin, bone="forearm." + s, segments=10)
        else:
            b.segment((side * 0.19, 0, 1.355), (side * 0.218, 0, 1.03), 0.06, spec.get("sleeve_flare", 0.078), mat=sleeve, bone="upper_arm." + s, segments=10)
            b.torus(spec.get("sleeve_flare", 0.078) - 0.004, 0.008, (side * 0.218, 0, 1.03), (0, side * 5, 0), mat=spec.get("trim", "white"),
                    bone="upper_arm." + s, segments=12, ring=4)
            b.segment((side * 0.215, 0, 1.08), (side * 0.225, 0, 0.84), 0.044, 0.039, mat=bracer, bone="forearm." + s, segments=10)
            b.torus(0.04, 0.006, (side * 0.225, 0, 0.865), mat=spec.get("bracer_trim", "gold"), bone="forearm." + s, segments=10, ring=4)
        b.sphere(1.0, (side * 0.226, -0.004, 0.795), scale=(0.034, 0.042, 0.05), mat=skin, bone="hand." + s, segments=10, rings=6)
        b.sphere(1.0, (side * 0.214, -0.04, 0.81), scale=(0.014, 0.016, 0.026), mat=skin, bone="hand." + s, segments=6, rings=4)


def pauldron(b, spec):
    b.sphere(1.0, (0.205, 0.0, 1.372), (0, -18, 0), scale=(0.085, 0.09, 0.055), mat=spec.get("pauldron", "jade_dark"), bone="upper_arm.L",
             segments=12, rings=8, shape=lambda co: Vector((co.x, co.y, max(co.z, -0.01))))
    b.torus(0.083, 0.007, (0.205, 0.0, 1.365), (0, -18, 0), mat="gold", bone="upper_arm.L", segments=14, ring=4)


def scarf(b, spec):
    mat = spec.get("scarf", "jade_light")
    b.torus(0.07, 0.024, (0, 0.004, 1.405), mat=mat, bone={"chest": 0.6, "neck": 0.4}, segments=14, ring=6)
    b.strip([(0.02, 0.07, 1.4), (0.04, 0.15, 1.33), (0.05, 0.21, 1.24), (0.06, 0.24, 1.14)], [0.08, 0.075, 0.07, 0.06], normal=(-1, 0, 0),
            mat=mat, bone="scarf", thickness=0.008)


def sheath(b, spec):
    mouth, direction = sheath_frame()
    end = mouth + direction * 0.8
    b.segment(mouth, end, 0.024, 0.019, mat=spec.get("sheath", "wood_dark"), bone="hips", segments=8, flat=0.55)
    b.segment(mouth - direction * 0.005, mouth + direction * 0.05, 0.027, mat="gold", bone="hips", segments=8, flat=0.6)
    b.segment(end - direction * 0.06, end, 0.022, 0.016, mat="gold", bone="hips", segments=8, flat=0.6)


def sheath_frame():
    direction = Vector((0.06, 0.78, -0.62)).normalized()
    return Vector((0.17, -0.12, 1.02)), direction


def bag(b, spec):
    b.box((0.07, 0.2, 0.17), (-0.17, 0.02, 0.98), (0, 0, 0), mat=spec.get("bag", "cloth_brown"), bone="hips", bevel=0.02)
    b.strip([(-0.15, -0.1, 0.99), (-0.05, -0.115, 1.15), (0.07, -0.11, 1.33), (0.13, -0.02, 1.4)], 0.035, normal=(0, -1, 0), mat="leather",
            bone="chest", thickness=0.004)


def apron(b, spec):
    b.box((0.3, 0.02, 0.6), (0, -0.115, 0.82), (-4, 0, 0), mat=spec.get("apron", "leather"), bone={"hips": 0.6, "spine": 0.4}, taper=(1.1, 1.0))


def guardian_armor(b, spec):
    """Bamboo lamellar plates for the Trúc Hải guardian."""
    plate = spec.get("plate", "bamboo_dark")
    light = spec.get("plate_light", "bamboo_light")
    for row, z in enumerate((1.3, 1.2, 1.1)):
        for i in range(-3, 4):
            x = i * 0.05
            y = torso_front(z, spec) - 0.012
            b.box((0.045, 0.02, 0.1), (x, y, z), (-6, 0, 0), mat=plate, bone="chest" if z > 1.2 else "spine", bevel=0.006)
        b.box((0.36, 0.024, 0.012), (0, torso_front(z, spec) - 0.02, z - 0.05), (-6, 0, 0), mat="gold", bone="chest" if z > 1.2 else "spine")
    for side in (1, -1):
        s = "L" if side > 0 else "R"
        b.sphere(1.0, (side * 0.22, 0, 1.39), (0, side * 25, 0), scale=(0.13, 0.12, 0.07), mat=plate, bone="upper_arm." + s, segments=12, rings=6,
                 shape=lambda co: Vector((co.x, co.y, max(co.z, -0.012))))
        for k in range(3):
            b.box((0.05, 0.13, 0.012), (side * (0.25 + k * 0.012), 0, 1.33 - k * 0.04), (0, side * (30 + k * 5), 0), mat=light, bone="upper_arm." + s)
    for i in range(-2, 3):
        b.cylinder(0.022, 0.5, (i * 0.06, -0.11, 0.78), (6, 0, 0), mat=light if i % 2 else plate, bone={"hips": 0.6, "thigh.L" if i > 0 else "thigh.R": 0.4}, segments=6)
        b.cylinder(0.022, 0.5, (i * 0.06, 0.11, 0.78), (-6, 0, 0), mat=plate, bone={"hips": 0.6, "thigh.L" if i > 0 else "thigh.R": 0.4}, segments=6)
    helmet(b, spec)


def build_mesh(name, spec):
    b = vk.MeshBuilder(name)
    face(b, spec)
    {"hero": hair_hero, "bun": hair_bun, "short": hair_short, "long": hair_long, "none": lambda *_: None}[spec.get("hair_style", "hero")](b, spec)
    for extra in spec.get("extras", []):
        {"hat": hat_conical, "bandana": bandana, "mask": mask_face, "beard": beard, "pauldron": pauldron, "scarf": scarf, "sheath": sheath,
         "bag": bag, "apron": apron, "armor": guardian_armor, "skirt": skirt, "tails": coat_tails}[extra](b, spec)
    torso(b, spec)
    arms(b, spec)
    legs(b, spec)
    return b


# ---------------------------------------------------------------- rig

def create_rig(scale):
    data = bpy.data.armatures.new("Armature")
    rig = bpy.data.objects.new("Armature", data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, parent, head, tail in BONES:
        bone = data.edit_bones.new(name)
        bone.head = Vector(head) * scale
        bone.tail = Vector(tail) * scale
        direction = (bone.tail - bone.head).normalized()
        bone.align_roll(Vector((1, 0, 0)).cross(direction))
        if parent:
            bone.parent = data.edit_bones[parent]
        bone.use_deform = name != "root"
    bpy.ops.object.mode_set(mode="OBJECT")
    for pose_bone in rig.pose.bones:
        pose_bone.rotation_mode = "QUATERNION"
    return rig


def bind(mesh_obj, rig):
    mesh_obj.parent = rig
    modifier = mesh_obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = rig


def add_socket(rig, name, bone, location, z_axis, x_axis):
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_size = 0.1
    bpy.context.scene.collection.objects.link(empty)
    empty.parent = rig
    empty.parent_type = "BONE"
    empty.parent_bone = bone
    bpy.context.view_layer.update()
    z_axis = Vector(z_axis).normalized()
    x_axis = (Vector(x_axis) - z_axis * Vector(x_axis).dot(z_axis)).normalized()
    y_axis = z_axis.cross(x_axis)
    basis = Matrix.Identity(3)
    basis.col[0], basis.col[1], basis.col[2] = x_axis, y_axis, z_axis
    world = basis.to_4x4()
    world.translation = Vector(location)
    empty.matrix_world = world
    return empty


def hand_grip(scale):
    return Vector((-0.226, -0.01, 0.795)) * scale


# ---------------------------------------------------------------- poses

def leg_shin_for(thigh_deg, reach):
    thigh = math.radians(thigh_deg)
    value = (reach - THIGH * math.cos(thigh)) / SHIN
    value = max(-1.0, min(1.0, value))
    shin_world = math.degrees(math.acos(value))
    return max(0.0, shin_world - thigh_deg)


class Poser:
    def __init__(self, rig, scale=1.0):
        self.rig = rig
        self.scale = scale
        self.rest = {bone.name: bone.matrix_local.copy() for bone in rig.data.bones}

    def reset(self):
        for pose_bone in self.rig.pose.bones:
            pose_bone.rotation_quaternion = Quaternion()
            pose_bone.location = Vector()

    def apply(self, pose):
        self.reset()
        bones = self.rig.pose.bones
        stance = pose.get("legs")
        if stance:
            drop = pose.get("drop", 0.0)
            left, right = stance[0], stance[1]
            splay = stance[2] if len(stance) > 2 else 4.0
            reach = LEG - drop
            for side, thigh, sign in (("L", left, -1), ("R", right, 1)):
                shin = leg_shin_for(thigh, reach)
                pose.setdefault("thigh." + side, (thigh, 0, sign * splay))
                pose.setdefault("shin." + side, (shin, 0, 0))
                pose.setdefault("foot." + side, (-(thigh + shin), 0, 0))
        for name, value in pose.items():
            if name in bones and isinstance(value, tuple) and len(value) == 3 and not isinstance(value[0], tuple):
                bones[name].rotation_quaternion = Euler([math.radians(v) for v in value], "XYZ").to_quaternion()
        offset = Vector(pose.get("off", (0, 0, 0)))
        offset.z -= pose.get("drop", 0.0)
        offset *= self.scale
        bones["hips"].location = Vector((offset.x, offset.z, -offset.y))
        bpy.context.view_layer.update()
        yaw = self._hips_yaw()
        for side in ("L", "R"):
            arm = pose.get("arm" + side)
            if arm:
                self._aim_arm(side, [yaw @ Vector(d).normalized() if d else None for d in arm])

    def _hips_yaw(self):
        matrix = self.rig.pose.bones["hips"].matrix.to_3x3()
        lateral = matrix.col[0]
        angle = math.atan2(lateral.y, lateral.x)
        return Matrix.Rotation(angle, 3, "Z")

    def _set_bone(self, name, y_axis, x_hint):
        pose_bone = self.rig.pose.bones[name]
        y_axis = y_axis.normalized()
        x_axis = x_hint - y_axis * x_hint.dot(y_axis)
        if x_axis.length < 1e-4:
            x_axis = Vector((0, -1, 0)) - y_axis * y_axis.y
        x_axis.normalize()
        z_axis = x_axis.cross(y_axis)
        basis = Matrix.Identity(3)
        basis.col[0], basis.col[1], basis.col[2] = x_axis, y_axis, z_axis
        matrix = basis.to_4x4()
        matrix.translation = pose_bone.head.copy()
        pose_bone.matrix = matrix
        bpy.context.view_layer.update()

    def _aim_arm(self, side, dirs):
        upper, fore = dirs[0], dirs[1]
        blade = dirs[2] if len(dirs) > 2 else None
        hinge = fore.cross(upper)
        if hinge.length < 0.05:
            hinge = Vector((1, 0, 0)) if abs(upper.x) < 0.8 else Vector((0, 0, 1)) * (1 if side == "L" else -1)
        self._set_bone("upper_arm." + side, upper, hinge)
        self._set_bone("forearm." + side, fore, hinge)
        if blade is None:
            self._set_bone("hand." + side, fore, hinge)
            return
        # Rigid frame mapping (blade, hand-Y) at rest onto (blade target, closest wrist direction).
        rest_y = Vector((0, 0, -1))
        angle = BLADE_REST.angle(rest_y)
        perp = fore - blade * fore.dot(blade)
        if perp.length < 1e-4:
            perp = Vector((0, 0, -1)) - blade * blade.z
        perp.normalize()
        hand_y = blade * math.cos(angle) + perp * math.sin(angle)
        source = _frame(BLADE_REST, rest_y)
        target = _frame(blade, hand_y)
        rotation = target @ source.inverted()
        x_axis = rotation @ Vector((1, 0, 0))
        self._set_bone("hand." + side, hand_y, x_axis)

    def capture(self):
        return {pb.name: (pb.rotation_quaternion.copy(), pb.location.copy()) for pb in self.rig.pose.bones}


def _frame(primary, secondary):
    a = primary.normalized()
    b = (secondary - a * secondary.dot(a)).normalized()
    c = a.cross(b)
    matrix = Matrix.Identity(3)
    matrix.col[0], matrix.col[1], matrix.col[2] = a, b, c
    return matrix


def add_action(rig, poser, name, keys, length, loop=False, fps=30):
    """keys: list of (time_seconds, pose_dict). Loops repeat the first key at the end."""
    if loop:
        keys = list(keys) + [(length, dict(keys[0][1]))]
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = action
    previous = {}
    for time, pose in keys:
        frame = round(time * fps)
        poser.apply(dict(pose))
        captured = poser.capture()
        for bone_name, (quat, loc) in captured.items():
            if bone_name in previous and previous[bone_name].dot(quat) < 0:
                quat.negate()
            previous[bone_name] = quat
            pose_bone = rig.pose.bones[bone_name]
            pose_bone.rotation_quaternion = quat
            pose_bone.keyframe_insert("rotation_quaternion", frame=frame, group=bone_name)
            if bone_name == "hips":
                pose_bone.location = loc
                pose_bone.keyframe_insert("location", frame=frame, group=bone_name)
    action.use_frame_range = True
    action.frame_start = 0
    action.frame_end = max(1, round(length * fps))
    rig.animation_data.action = None
    poser.reset()
    return action
