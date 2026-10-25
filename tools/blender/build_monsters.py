"""Chapter-one monsters in the blocky kit: bandit archer, shield guard and storm mage, the memory
wraith and the stone golem on the 20-bone humanoid rig; the frost wolf and its pack leader on a
14-bone quadruped rig. Rigged, animated GLBs into assets/models/characters/.

blender --background --factory-startup --python tools/blender/build_monsters.py -- [names...] [--preview]
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import anim_monsters as monster_anims  # noqa: E402
import blocky_humanoid  # noqa: E402
import compact_palette  # noqa: E402
import humanoid as hu  # noqa: E402
import vk_lib as vk  # noqa: E402
from anim_humanoid import TIMINGS  # noqa: E402

HUMANOIDS = {
    "cung_thu": {
        # Hooded forest archer: moss cloak and hood, cloth half-mask, quiver on the back, bow in the left hand.
        "role": "archer", "scale": 0.98, "hair_style": "none", "outer": "leaf_dark", "sleeve": "cloth_dark", "inner": "cloth_brown",
        "trim": "wood_light", "sash": "leather", "tails": "leaf_dark", "pants": "cloth_brown", "boots": "leather", "bracer": "leather",
        "extras": ["tails", "mask"], "mask": "cloth_dark", "mask_mark": "leaf_light", "eye_glow": "ink",
    },
    "ho_ve": {
        # Heavy shield guard: iron helmet, lamellar coat, vermilion tower shield on the left arm, spear in the right.
        "role": "shield", "scale": 1.12, "width": 1.2, "hair_style": "none", "outer": "metal_dark", "sleeve": "cloth_dark", "inner": "vermilion_dark",
        "trim": "gold", "sash": "vermilion_dark", "tails": "cloth_dark", "pants": "stone_dark", "boots": "leather", "bracer": "metal_dark",
        "extras": ["tails", "mask"], "mask": "metal_dark", "mask_mark": "gold", "eye_glow": "seal",
    },
    "phap_su": {
        # Storm mage of the bandits: indigo robe to the ground, wide hat with a veil, paper talismans, staff with a thunder orb.
        "role": "mage", "scale": 1.0, "hair_style": "long", "hair": "hair", "outer": "storm_robe", "sleeve": "storm_robe", "inner": "cream",
        "trim": "storm_trim", "sash": "storm_trim", "skirt": "storm_robe", "pants": "storm_robe", "boots": "cloth_dark", "bracer": "storm_robe",
        "extras": ["skirt", "mask"], "mask": "mask", "mask_mark": "thunder_glow", "eye_glow": "thunder_glow",
    },
    "hon_anh": {
        # Memory wraith: a pale drowned shade in a long robe that trails off into mist, hair streaming, claws of light.
        "role": "wraith", "scale": 1.02, "hair_style": "long", "hair": "ghost", "brow": "ghost", "skin": "ghost", "outer": "ghost_dark",
        "sleeve": "ghost_dark", "inner": "ghost", "trim": "spirit", "sash": "spirit", "skirt": "ghost_dark", "pants": "ghost_dark", "boots": "ghost_dark",
        "bracer": "ghost_dark", "extras": ["skirt"], "iris": "spirit",
    },
}


def _box(b, size, pos, mat, bone, rot=(0, 0, 0), bevel=0.012):
    return b.box(size, pos, rot, mat=mat, bone=bone, bevel=bevel, segments=2)


def archer_parts(b, spec):
    hood = spec.get("outer", "leaf_dark")
    _box(b, (0.33, 0.3, 0.13), (0, 0.012, 1.74), hood, "head", bevel=0.03)
    _box(b, (0.34, 0.07, 0.3), (0, 0.15, 1.6), hood, "head", bevel=0.02)
    for side in (-1, 1):
        _box(b, (0.05, 0.27, 0.26), (side * 0.165, 0.0, 1.6), hood, "head", bevel=0.015)
    b.cone(0.08, 0.16, (0, 0.2, 1.72), (-60, 0, 0), mat=hood, bone="head", segments=4, smooth=False)
    # Quiver across the back with fletched arrows.
    b.cylinder(0.065, 0.52, (0.08, 0.17, 1.2), (-12, 0, 18), mat="leather", bone="chest", segments=8)
    b.torus(0.066, 0.008, (0.1, 0.165, 1.42), (-12, 0, 18), mat="gold", bone="chest", segments=8, ring=4)
    for index, (dx, dy) in enumerate(((0.0, 0.0), (0.03, 0.015), (-0.025, 0.02), (0.012, -0.022))):
        base = Vector((0.15 + dx, 0.2 + dy, 1.44))
        b.segment(tuple(base), tuple(base + Vector((0.03, 0.02, 0.14))), 0.006, mat="wood_light", bone="chest", segments=4)
        b.box((0.008, 0.035, 0.06), tuple(base + Vector((0.032, 0.022, 0.12))), (0, 0, 18), mat="vermilion" if index % 2 else "cream", bone="chest")
    b.strip([(0.13, -0.1, 1.38), (0.02, -0.13, 1.2), (-0.12, -0.12, 1.02)], 0.03, normal=(0, -1, 0), mat="leather", bone="chest", thickness=0.004)
    # Bow in the left fist: limbs along Y at rest (vertical once the arm is raised to aim), tips
    # bent back toward the archer, string between the tips.
    grip = Vector((0.226, -0.004, 0.795))
    limb = "wood_dark"
    b.segment(tuple(grip + Vector((0, -0.06, 0))), tuple(grip + Vector((0, 0.06, 0))), 0.022, mat="leather", bone="hand.L", segments=6)
    for sign in (-1, 1):
        mid = grip + Vector((0, sign * 0.3, 0.035))
        tip = grip + Vector((0, sign * 0.56, 0.11))
        b.segment(tuple(grip + Vector((0, sign * 0.05, 0))), tuple(mid), 0.02, 0.016, mat=limb, bone="hand.L", segments=6)
        b.segment(tuple(mid), tuple(tip), 0.016, 0.01, mat=limb, bone="hand.L", segments=6)
        b.sphere(0.016, tuple(tip), mat="gold", bone="hand.L", segments=6, rings=4)
    b.segment(tuple(grip + Vector((0, -0.56, 0.11))), tuple(grip + Vector((0, 0.56, 0.11))), 0.004, mat="cream", bone="hand.L", segments=4)


def shield_parts(b, spec):
    hu.helmet(b, dict(spec, plate="metal_dark", plate_light="metal"))
    # Lamellar plates on the chest.
    for row, z in enumerate((1.33, 1.23, 1.13)):
        for col in range(-3, 4):
            _box(b, (0.05, 0.03, 0.085), (col * 0.052, -0.14, z), "metal" if (row + col) % 2 else "metal_dark", "chest" if z > 1.2 else "spine", bevel=0.004)
        _box(b, (0.37, 0.034, 0.012), (0, -0.145, z - 0.048), "gold", "chest" if z > 1.2 else "spine", bevel=0.002)
    for side in (-1, 1):
        s = "L" if side > 0 else "R"
        _box(b, (0.2, 0.26, 0.07), (side * 0.215, 0, 1.4), "metal_dark", "upper_arm." + s, (0, side * 14, 0), 0.012)
        _box(b, (0.205, 0.265, 0.014), (side * 0.22, 0, 1.37), "gold", "upper_arm." + s, (0, side * 14, 0), 0.003)
    # Tower shield on the left forearm, faced outward at rest so it covers the body when the
    # forearm is held across the chest.
    center = Vector((0.31, 0.0, 0.94))
    _box(b, (0.05, 0.56, 0.82), tuple(center), "vermilion_dark", "forearm.L", bevel=0.02)
    _box(b, (0.056, 0.5, 0.76), tuple(center + Vector((0.004, 0, 0))), "vermilion", "forearm.L", bevel=0.015)
    for z in (-0.3, 0.0, 0.3):
        _box(b, (0.062, 0.52, 0.03), tuple(center + Vector((0.006, 0, z))), "metal_dark", "forearm.L", bevel=0.004)
    b.cylinder(0.11, 0.03, tuple(center + Vector((0.04, 0, 0.0))), (0, 90, 0), mat="gold", bone="forearm.L", segments=12)
    b.cylinder(0.05, 0.034, tuple(center + Vector((0.05, 0, 0.0))), (0, 90, 0), mat="seal", bone="forearm.L", segments=10)


def mage_parts(b, spec):
    # Wide hat with a hanging veil and a thunder talisman pinned to the brim.
    b.cone(0.3, 0.12, (0, 0.0, 1.78), mat="storm_robe", bone="head", segments=8, smooth=False)
    b.cylinder(0.33, 0.02, (0, 0.0, 1.72), mat="storm_trim", bone="head", top=0.33, segments=8)
    for index in range(8):
        angle = math.tau * index / 8 + math.pi / 8
        if math.sin(angle) < -0.4:
            continue  # leave the face open
        x, y = math.cos(angle) * 0.3, math.sin(angle) * 0.3
        b.box((0.2, 0.01, 0.2), (x, y, 1.6), (0, 0, math.degrees(angle) + 90), mat="cloth_dark", bone="head")
    b.box((0.05, 0.01, 0.14), (0.0, -0.33, 1.66), mat="paper", bone="head")
    b.box((0.03, 0.012, 0.08), (0.0, -0.335, 1.66), mat="thunder_glow", bone="head")
    # Paper talismans hanging from the sash.
    for index, x in enumerate((-0.12, -0.04, 0.05, 0.13)):
        b.box((0.045, 0.008, 0.15), (x, -0.15, 0.9), (4, 0, 0), mat="paper", bone="hips")
        b.box((0.025, 0.01, 0.08), (x, -0.156, 0.9), (4, 0, 0), mat="vermilion" if index % 2 else "thunder_glow", bone="hips")


def wraith_parts(b, spec):
    # Long tattered hem trailing behind, glowing claws, a faint mist collar.
    for index in range(7):
        x = (index - 3) * 0.07
        b.cone(0.06, 0.32, (x, 0.08 + abs(x) * 0.3, 0.02), (180 - 20, 0, 0), mat="ghost_dark", bone="hips", segments=4, smooth=False)
    for side in (-1, 1):
        s = "L" if side > 0 else "R"
        for finger in range(3):
            b.cone(0.012, 0.11, (side * (0.215 + finger * 0.012), -0.03 - finger * 0.012, 0.73), (170, 0, side * (finger - 1) * 10), mat="spirit", bone="hand." + s, segments=4)
    b.torus(0.12, 0.03, (0, 0.0, 1.41), mat="spirit", bone={"chest": 0.6, "neck": 0.4}, segments=12, ring=5)
    for side in (-1, 1):
        b.box((0.05, 0.01, 0.02), (side * 0.061, -0.15, 1.59), (0, side * 8, 0), mat="spirit", bone="head")


PART_BUILDERS = {"archer": archer_parts, "shield": shield_parts, "mage": mage_parts, "wraith": wraith_parts}
ANIMATIONS = {"archer": monster_anims.archer_animations, "shield": monster_anims.shield_animations, "mage": monster_anims.mage_animations,
              "wraith": monster_anims.wraith_animations}


def build_humanoid(name, preview):
    spec = dict(HUMANOIDS[name])
    scale = spec["scale"]
    vk.reset()
    builder = blocky_humanoid.build_mesh("Body", spec)
    PART_BUILDERS[spec["role"]](builder, spec)
    body = builder.build()
    compact_palette.compact(body, name)
    body.data.transform(Matrix.Scale(scale, 4))
    rig = hu.create_rig(scale)
    hu.bind(body, rig)
    hu.add_socket(rig, "SwordSocket", "hand.R", hu.hand_grip(scale), hu.BLADE_REST, hu.EDGE_REST)
    _finish(name, rig, scale, ANIMATIONS[spec["role"]](), spec["role"], preview)


# ---------------------------------------------------------------- stone golem

def golem_mesh():
    """A walking cairn: boulder torso, slab shoulders, huge fists, a small head with one rune eye,
    moss on the top surfaces and amber rune lines down the chest and arms. Unit humanoid proportions;
    the rig scale makes it about 3.4 m tall."""
    b = vk.MeshBuilder("Body", vcol=False)
    rock, dark, light = "rock", "rock_dark", "rock_light"
    _box(b, (0.5, 0.36, 0.42), (0, 0.0, 1.18), rock, "chest", bevel=0.04)
    _box(b, (0.42, 0.32, 0.22), (0, 0.0, 0.98), dark, {"spine": 0.6, "hips": 0.4}, bevel=0.03)
    _box(b, (0.38, 0.3, 0.16), (0, 0.0, 0.86), rock, "hips", bevel=0.03)
    _box(b, (0.52, 0.38, 0.06), (0, 0.0, 1.42), "moss", "chest", bevel=0.02)
    _box(b, (0.2, 0.2, 0.18), (0, -0.03, 1.55), dark, "head", bevel=0.03)
    _box(b, (0.22, 0.04, 0.035), (0, -0.13, 1.56), "rune", "head", bevel=0.005)
    _box(b, (0.21, 0.21, 0.04), (0, -0.03, 1.66), "moss", "head", bevel=0.01)
    # Rune lines on the chest.
    for z, w in ((1.3, 0.24), (1.18, 0.16), (1.06, 0.1)):
        _box(b, (w, 0.02, 0.025), (0, -0.185, z), "rune", "chest", bevel=0.004)
    _box(b, (0.025, 0.02, 0.26), (0, -0.186, 1.18), "rune", "chest", bevel=0.004)
    for side in (-1, 1):
        s = "L" if side > 0 else "R"
        _box(b, (0.24, 0.3, 0.2), (side * 0.3, 0.0, 1.36), light, "upper_arm." + s, (0, side * 10, 0), 0.03)
        _box(b, (0.25, 0.31, 0.05), (side * 0.3, 0.0, 1.47), "moss", "upper_arm." + s, (0, side * 10, 0), 0.015)
        _box(b, (0.15, 0.16, 0.28), (side * 0.25, 0.0, 1.14), rock, "upper_arm." + s, bevel=0.025)
        _box(b, (0.17, 0.18, 0.26), (side * 0.26, 0.0, 0.92), dark, "forearm." + s, bevel=0.025)
        _box(b, (0.03, 0.19, 0.02), (side * 0.345, 0.0, 0.94), "rune", "forearm." + s, bevel=0.004)
        _box(b, (0.24, 0.24, 0.22), (side * 0.27, -0.01, 0.72), rock, "hand." + s, bevel=0.035)
        for knuckle in range(3):
            _box(b, (0.06, 0.05, 0.06), (side * 0.27 + (knuckle - 1) * 0.07, -0.13, 0.69), light, "hand." + s, bevel=0.012)
        _box(b, (0.2, 0.22, 0.38), (side * 0.11, 0.0, 0.66), rock, "thigh." + s, bevel=0.03)
        _box(b, (0.19, 0.21, 0.36), (side * 0.11, 0.0, 0.3), dark, "shin." + s, bevel=0.03)
        _box(b, (0.22, 0.3, 0.1), (side * 0.11, -0.05, 0.05), rock, "foot." + s, bevel=0.025)
    # A few boulders grown into the back.
    for x, z, size in ((-0.12, 1.32, 0.14), (0.1, 1.2, 0.12), (0.0, 1.05, 0.1)):
        _box(b, (size, size * 0.8, size), (x, 0.2, z), light, "chest", (15, 10, 20), 0.02)
    return b


def build_golem(preview):
    scale = 1.9
    vk.reset()
    body = golem_mesh().build()
    compact_palette.compact(body, "khoi_loi")
    body.data.transform(Matrix.Scale(scale, 4))
    rig = hu.create_rig(scale)
    hu.bind(body, rig)
    _finish("khoi_loi", rig, scale, monster_anims.golem_animations(), "golem", preview)


# ---------------------------------------------------------------- frost wolves

WOLF_BONES = [
    ("root", None, (0, 0, 0), (0, 0, 0.2)),
    ("hips", "root", (0, 0.3, 0.64), (0, 0.3, 0.76)),
    ("chest", "hips", (0, 0.3, 0.74), (0, -0.26, 0.78)),
    ("neck", "chest", (0, -0.26, 0.8), (0, -0.42, 0.96)),
    ("head", "neck", (0, -0.42, 0.96), (0, -0.66, 0.92)),
    ("jaw", "head", (0, -0.5, 0.88), (0, -0.74, 0.84)),
    ("tail", "hips", (0, 0.42, 0.74), (0, 0.62, 0.66)),
    ("tail_tip", "tail", (0, 0.62, 0.66), (0, 0.84, 0.56)),
    ("leg_fl", "chest", (0.11, -0.2, 0.66), (0.11, -0.2, 0.36)),
    ("foot_fl", "leg_fl", (0.11, -0.2, 0.36), (0.11, -0.24, 0.03)),
    ("leg_fr", "chest", (-0.11, -0.2, 0.66), (-0.11, -0.2, 0.36)),
    ("foot_fr", "leg_fr", (-0.11, -0.2, 0.36), (-0.11, -0.24, 0.03)),
    ("leg_bl", "hips", (0.11, 0.34, 0.64), (0.11, 0.42, 0.36)),
    ("foot_bl", "leg_bl", (0.11, 0.42, 0.36), (0.11, 0.36, 0.03)),
    ("leg_br", "hips", (-0.11, 0.34, 0.64), (-0.11, 0.42, 0.36)),
    ("foot_br", "leg_br", (-0.11, 0.42, 0.36), (-0.11, 0.36, 0.03)),
]


def wolf_mesh(alpha):
    fur = "fur_alpha" if alpha else "fur_frost"
    dark = "fur_frost_dark" if not alpha else "ink"
    light = "fur_alpha_light" if alpha else "white"
    b = vk.MeshBuilder("Body", vcol=False)
    _box(b, (0.3, 0.46, 0.3), (0, 0.24, 0.66), fur, "hips", bevel=0.04)
    _box(b, (0.36, 0.42, 0.38), (0, -0.12, 0.72), fur, "chest", bevel=0.045)
    _box(b, (0.28, 0.5, 0.1), (0, 0.08, 0.88), dark, {"chest": 0.6, "hips": 0.4}, bevel=0.03)
    _box(b, (0.3, 0.2, 0.16), (0, -0.16, 0.56), light, "chest", bevel=0.03)
    _box(b, (0.22, 0.22, 0.24), (0, -0.36, 0.88), fur, "neck", (-30, 0, 0), 0.04)
    _box(b, (0.24, 0.24, 0.2), (0, -0.52, 0.95), fur, "head", bevel=0.04)
    _box(b, (0.14, 0.2, 0.1), (0, -0.7, 0.92), light, "head", bevel=0.025)
    _box(b, (0.06, 0.04, 0.04), (0, -0.8, 0.94), "ink", "head", bevel=0.01)
    _box(b, (0.13, 0.18, 0.05), (0, -0.66, 0.85), dark, "jaw", bevel=0.015)
    for side in (-1, 1):
        b.cone(0.05, 0.13, (side * 0.08, -0.48, 1.09), (-10, side * 12, 0), mat=fur, bone="head", segments=4, smooth=False)
        b.cone(0.03, 0.08, (side * 0.08, -0.495, 1.08), (-10, side * 12, 0), mat=dark, bone="head", segments=4, smooth=False)
        _box(b, (0.045, 0.02, 0.026), (side * 0.065, -0.645, 0.99), "frost_glow", "head", (0, 0, side * 10), 0.005)
        b.cone(0.012, 0.05, (side * 0.04, -0.77, 0.875), (180, 0, 0), mat="white", bone="head", segments=4, smooth=False)
    if alpha:
        # Pack leader: shaggy pale ruff and a crown of ice.
        for index in range(9):
            angle = math.pi * (index / 8.0)
            _box(b, (0.08, 0.16, 0.16), (math.cos(angle) * 0.2, -0.3, 0.8 + math.sin(angle) * 0.18), light, {"neck": 0.5, "chest": 0.5}, (30, 0, math.degrees(angle) - 90), 0.02)
        for x in (-0.07, 0.0, 0.07):
            b.cone(0.03, 0.14, (x, -0.47, 1.08), (-20, 0, 0), mat="frost_glow", bone="head", segments=4, smooth=False)
    # Ice crystals along the spine.
    count = 6 if alpha else 4
    for index in range(count):
        y = -0.2 + index * (0.5 / count)
        height = 0.16 + 0.05 * math.sin(index * 1.7) + (0.06 if alpha else 0.0)
        b.cone(0.045, height, (0.0, y, 0.93 + height * 0.4), (-15, 0, (index % 2) * 18 - 9), mat="frost_glow", bone="chest" if y < 0.08 else "hips", segments=4, smooth=False)
    _box(b, (0.1, 0.24, 0.1), (0, 0.52, 0.71), fur, "tail", (-20, 0, 0), 0.03)
    _box(b, (0.09, 0.24, 0.09), (0, 0.73, 0.61), light, "tail_tip", (-28, 0, 0), 0.03)
    for leg, x, y in (("fl", 0.11, -0.2), ("fr", -0.11, -0.2), ("bl", 0.11, 0.38), ("br", -0.11, 0.38)):
        _box(b, (0.1, 0.13, 0.32), (x, y, 0.52), fur, "leg_" + leg, bevel=0.025)
        _box(b, (0.08, 0.1, 0.32), (x, y - 0.02, 0.2), dark if leg[0] == "f" else fur, "foot_" + leg, bevel=0.02)
        _box(b, (0.1, 0.14, 0.05), (x, y - 0.05, 0.025), dark, "foot_" + leg, bevel=0.012)
    return b


def wolf_rig(scale):
    data = bpy.data.armatures.new("Armature")
    rig = bpy.data.objects.new("Armature", data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, parent, head, tail in WOLF_BONES:
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = Vector(head) * scale, Vector(tail) * scale
        bone.align_roll(Vector((1, 0, 0)).cross((bone.tail - bone.head).normalized()))
        if parent:
            bone.parent = data.edit_bones[parent]
        bone.use_deform = name != "root"
    bpy.ops.object.mode_set(mode="OBJECT")
    for pose_bone in rig.pose.bones:
        pose_bone.rotation_mode = "QUATERNION"
    return rig


def _legs(fl, fr, bl, br, knee=0.0):
    """Leg swing angles (+ back). Lower legs fold so the paws stay under the body."""
    pose = {}
    for name, angle in (("fl", fl), ("fr", fr), ("bl", bl), ("br", br)):
        pose["leg_" + name] = (angle, 0, 0)
        bend = knee + max(0.0, angle) * 0.7 if name[0] == "f" else knee + max(0.0, -angle) * 0.7
        pose["foot_" + name] = (bend if name[0] == "f" else -bend, 0, 0)
    return pose


def wolf_animations():
    timing = TIMINGS["wolf"]
    anims = {}
    rest = dict(_legs(0, 0, 0, 0), chest=(0, 0, 0), neck=(0, 0, 0), head=(0, 0, 0), jaw=(0, 0, 0), tail=(10, 0, 0), tail_tip=(10, 0, 0))
    breathe = dict(rest, chest=(-2, 0, 0), head=(4, 6, 0), tail=(14, 0, 10), tail_tip=(16, 0, 10), off=(0, 0, -0.01))
    anims["idle"] = ([(0.0, rest), (0.9, breathe), (1.6, dict(rest, head=(2, -8, 0), tail=(10, 0, -8)))], 2.2, True)
    keys = []
    for i in range(4):
        s = 1 if i % 2 == 0 else -1
        keys.append((i * 0.18, dict(_legs(-22 * s, 22 * s, 22 * s, -22 * s), head=(4, 0, 4 * s), tail=(12, 0, 10 * s), tail_tip=(10, 0, 12 * s), off=(0, 0, 0.012 * (i % 2)))))
    anims["walk"] = (keys, 0.72, True)
    keys = []
    for i, (front, back, pitch, height) in enumerate(((-40, 34, -8, 0.06), (30, -40, 8, -0.02), (-40, 34, -8, 0.06), (30, -40, 8, -0.02))):
        keys.append((i * 0.1, dict(_legs(front, front + 8, back, back - 8), chest=(pitch, 0, 0), neck=(-10, 0, 0), head=(12, 0, 0),
                                   tail=(-20, 0, 0), tail_tip=(-10, 0, 0), off=(0, 0, height))))
    anims["run"] = (keys, 0.4, True)
    # Bite: a snap of the head with the jaw open, front paws planted.
    hs, he = timing["bite"]["hit_start"], timing["bite"]["hit_end"]
    coil = dict(_legs(-14, -14, 18, 18, knee=10), chest=(10, 0, 0), neck=(16, 0, 0), head=(-10, 0, 0), jaw=(20, 0, 0), tail=(-20, 0, 0), off=(0, 0.06, -0.06))
    snap = dict(_legs(-30, -24, 10, 10), chest=(-6, 0, 0), neck=(-18, 0, 0), head=(10, 0, 0), jaw=(30, 0, 0), tail=(0, 0, 0), off=(0, -0.16, 0.02))
    shut = dict(snap, jaw=(0, 0, 0), head=(16, 0, 6))
    anims["bite"] = ([(0.0, rest), (hs - 0.18, coil), (hs, snap), (he, shut), (timing["bite"]["length"], rest)], timing["bite"]["length"], False)
    # Pounce: crouch, spring, fly with paws forward, land.
    hs, he = timing["pounce"]["hit_start"], timing["pounce"]["hit_end"]
    crouch = dict(_legs(-10, -10, 30, 30, knee=26), chest=(14, 0, 0), neck=(10, 0, 0), head=(-6, 0, 0), tail=(-30, 0, 0), off=(0, 0.08, -0.12))
    flight = dict(_legs(-70, -66, 50, 54), chest=(-14, 0, 0), neck=(-14, 0, 0), head=(14, 0, 0), jaw=(28, 0, 0), tail=(-40, 0, 0), off=(0, -0.2, 0.22))
    land = dict(_legs(-20, -16, 26, 26, knee=20), chest=(10, 0, 0), head=(6, 0, 0), jaw=(8, 0, 0), tail=(-10, 0, 0), off=(0, -0.1, -0.08))
    anims["pounce"] = ([(0.0, rest), (hs - 0.2, crouch), (hs, flight), (he, flight), (he + 0.12, land), (timing["pounce"]["length"], rest)],
                       timing["pounce"]["length"], False)
    # Howl: sits back, muzzle to the sky.
    howl = dict(_legs(-6, -6, 30, 30, knee=30), chest=(-10, 0, 0), neck=(-26, 0, 0), head=(-14, 0, 0), jaw=(26, 0, 0), tail=(24, 0, 0), off=(0, 0.08, -0.1))
    anims["howl"] = ([(0.0, rest), (0.4, dict(howl, jaw=(0, 0, 0))), (0.7, howl), (1.3, dict(howl, head=(-18, 0, 4))), (timing["howl"]["length"], rest)],
                     timing["howl"]["length"], False)
    snarl = dict(rest, chest=(8, 0, 0), neck=(10, 0, 0), head=(-6, 0, 0), jaw=(14, 0, 0), tail=(-10, 0, 0), off=(0, 0.04, -0.04))
    anims["alert"] = ([(0.0, rest), (0.25, snarl), (0.6, snarl), (0.8, rest)], 0.8, False)
    recoil = dict(rest, chest=(-10, 0, 8), head=(-18, 12, 0), off=(0, 0.12, 0.02), tail=(30, 0, 0))
    anims["hit"] = ([(0.0, rest), (0.08, recoil), (0.35, rest)], 0.35, False)
    dazed = dict(_legs(-10, 10, 0, 0, knee=12), chest=(6, 0, 14), head=(26, 18, 10), off=(0, 0, -0.1), tail=(20, 0, 0))
    anims["stagger"] = ([(0.0, rest), (0.15, recoil), (0.5, dazed), (1.0, dict(dazed, chest=(6, 0, -10), head=(26, -18, -10))), (1.4, dazed), (1.6, rest)], 1.6, False)
    down = dict(_legs(-40, -30, 30, 40), hips=(0, 0, 84), chest=(0, 0, 0), head=(14, 0, 20), off=(0.28, 0, -0.4), tail=(0, 0, 0))
    anims["death"] = ([(0.0, rest), (0.15, recoil), (0.6, dict(down, hips=(0, 0, 60), off=(0.2, 0, -0.28))), (1.0, down)], 1.0, False)
    return anims


def build_wolf(name, preview):
    alpha = name == "soi_chua"
    scale = 1.3 if alpha else 1.0
    vk.reset()
    body = wolf_mesh(alpha).build()
    compact_palette.compact(body, name)
    body.data.transform(Matrix.Scale(scale, 4))
    rig = wolf_rig(scale)
    hu.bind(body, rig)
    _finish(name, rig, scale, wolf_animations(), "beast", preview, quadruped=True)


# ---------------------------------------------------------------- export

def _finish(name, rig, scale, sets, role, preview, quadruped=False):
    poser = hu.Poser(rig, scale)
    for anim_name, (keys, length, loop) in sets.items():
        hu.add_action(rig, poser, anim_name, keys, length, loop)
    rig.animation_data.action = None
    poser.reset()
    bpy.context.view_layer.update()
    out_dir = vk.MODELS / "characters"
    out_dir.mkdir(parents=True, exist_ok=True)
    original, original_art = vk.MODELS, vk.ART
    vk.MODELS = out_dir
    vk.ART = original_art / "characters"
    info = vk.save_and_export(name, animations=True, extra={"animations": sorted(sets.keys()), "role": role})
    vk.MODELS, vk.ART = original, original_art
    vk.write_manifest_entry(info, "characters")
    if preview:
        height = (1.0 if quadruped else 1.8) * scale
        target = (0, 0, height * 0.5)
        size = height * 1.35
        vk.render_preview(name + "_rest", {"front": (0, 0, size), "side": (90, 0, size), "three_quarter": (35, 8, size)}, size=(520, 560), target=target)
        for anim_name in sets:
            action = bpy.data.actions[anim_name]
            rig.animation_data.action = action
            end = int(action.frame_end)
            for index, frame in enumerate(sorted({0, end // 3, (2 * end) // 3, end})):
                vk.render_preview(f"{name}_{anim_name}_{index}", {"q": (40, 8, size * 1.15)}, size=(260, 300), target=target, frame=frame)
        rig.animation_data.action = None


BUILDERS = {name: (lambda preview, key=name: build_humanoid(key, preview)) for name in HUMANOIDS}
BUILDERS["khoi_loi"] = build_golem
BUILDERS["soi_suong"] = lambda preview: build_wolf("soi_suong", preview)
BUILDERS["soi_chua"] = lambda preview: build_wolf("soi_chua", preview)


if __name__ == "__main__":
    if not bpy.app.background:
        raise RuntimeError("Run this generator in a separate background Blender process.")
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = [arg for arg in argv if not arg.startswith("--")] or list(BUILDERS)
    for monster in names:
        BUILDERS[monster]("--preview" in argv)
