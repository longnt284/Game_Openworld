"""Quadruped enemies. Currently: heo_gio (wind boar, charging beast).

blender --background --factory-startup --python tools/blender/build_creatures.py -- [--preview]
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import humanoid as hu  # noqa: E402
import vk_lib as vk  # noqa: E402
from anim_humanoid import TIMINGS  # noqa: E402

BOAR_BONES = [
    ("root", None, (0, 0, 0), (0, 0, 0.2)),
    ("hips", "root", (0, 0.05, 0.7), (0, 0.05, 0.82)),
    ("head", "hips", (0, -0.42, 0.78), (0, -0.82, 0.6)),
    ("tail", "hips", (0, 0.55, 0.78), (0, 0.72, 0.6)),
    ("leg_fl", "hips", (0.17, -0.26, 0.6), (0.17, -0.26, 0.32)),
    ("foot_fl", "leg_fl", (0.17, -0.26, 0.32), (0.17, -0.28, 0.02)),
    ("leg_fr", "hips", (-0.17, -0.26, 0.6), (-0.17, -0.26, 0.32)),
    ("foot_fr", "leg_fr", (-0.17, -0.26, 0.32), (-0.17, -0.28, 0.02)),
    ("leg_bl", "hips", (0.16, 0.38, 0.62), (0.16, 0.4, 0.33)),
    ("foot_bl", "leg_bl", (0.16, 0.4, 0.33), (0.16, 0.36, 0.02)),
    ("leg_br", "hips", (-0.16, 0.38, 0.62), (-0.16, 0.4, 0.33)),
    ("foot_br", "leg_br", (-0.16, 0.4, 0.33), (-0.16, 0.36, 0.02)),
]


def boar_mesh():
    b = vk.MeshBuilder("Body")

    def body_shape(co):
        if co.z > 0.0:
            co.z *= 1.0 + 0.25 * max(0.0, -co.y) / 0.6
        return co
    b.sphere(1.0, (0, 0.05, 0.68), scale=(0.3, 0.62, 0.3), mat="boar", bone="hips", segments=16, rings=10, shape=body_shape)
    for i in range(9):
        y = -0.42 + i * 0.1
        b.cone(0.05, 0.16 - abs(i - 3) * 0.012, (0, y, 0.98 - abs(y + 0.15) * 0.18), (-25, 0, 0), mat="boar_dark", bone="hips", segments=4, scale=(0.5, 1, 1))
    for side in (1, -1):
        for k in range(3):
            b.strip([(side * 0.27, -0.25 + k * 0.22, 0.82), (side * 0.3, -0.18 + k * 0.22, 0.7), (side * 0.29, -0.12 + k * 0.22, 0.56)], 0.035,
                    normal=(side, 0, 0), mat="spirit", bone="hips", thickness=0.004)
    b.sphere(1.0, (0, -0.55, 0.7), scale=(0.2, 0.25, 0.2), mat="boar", bone="head", segments=12, rings=8)
    b.segment((0, -0.7, 0.66), (0, -0.88, 0.6), 0.1, 0.085, mat="boar", bone="head", segments=10)
    b.cylinder(0.085, 0.04, (0, -0.9, 0.6), (80, 0, 0), mat="skin_shadow", bone="head", segments=10)
    for side in (1, -1):
        b.sphere(0.012, (side * 0.03, -0.925, 0.61), mat="ink", bone="head", segments=6, rings=4)
        b.segment((side * 0.07, -0.84, 0.56), (side * 0.13, -0.92, 0.7), 0.018, 0.004, mat="tusk", bone="head", segments=6)
        b.sphere(1.0, (side * 0.12, -0.66, 0.77), scale=(0.022, 0.012, 0.016), mat="spirit", bone="head", segments=8, rings=4)
        b.cone(0.05, 0.12, (side * 0.13, -0.5, 0.88), (-20, side * 30, 0), mat="boar_dark", bone="head", segments=5, scale=(1, 0.5, 1))
    b.segment((0, 0.66, 0.74), (0, 0.78, 0.58), 0.025, 0.006, mat="boar_dark", bone="tail", segments=6)
    for leg, x, y in (("fl", 0.17, -0.26), ("fr", -0.17, -0.26), ("bl", 0.16, 0.39), ("br", -0.16, 0.39)):
        b.segment((x, y, 0.66), (x, y, 0.32), 0.095, 0.068, mat="boar", bone="leg_" + leg, segments=8)
        b.segment((x, y, 0.33), (x, y - 0.01, 0.06), 0.06, 0.05, mat="boar_dark", bone="foot_" + leg, segments=8)
        b.box((0.09, 0.1, 0.07), (x, y - 0.02, 0.035), mat="ink", bone="foot_" + leg, bevel=0.01)
    return b


def create_rig():
    data = bpy.data.armatures.new("Armature")
    rig = bpy.data.objects.new("Armature", data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, parent, head, tail in BOAR_BONES:
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = Vector(head), Vector(tail)
        bone.align_roll(Vector((1, 0, 0)).cross((bone.tail - bone.head).normalized()))
        if parent:
            bone.parent = data.edit_bones[parent]
        bone.use_deform = name != "root"
    bpy.ops.object.mode_set(mode="OBJECT")
    for pose_bone in rig.pose.bones:
        pose_bone.rotation_mode = "QUATERNION"
    return rig


def legs(fl, fr, bl, br, knee=0.0):
    """Leg swing angles (+ back). Lower legs fold opposite to keep hooves under the body."""
    pose = {}
    for name, angle in (("fl", fl), ("fr", fr), ("bl", bl), ("br", br)):
        pose["leg_" + name] = (angle, 0, 0)
        bend = knee + max(0.0, angle) * 0.6 if name[0] == "f" else knee + max(0.0, -angle) * 0.6
        pose["foot_" + name] = (bend if name[0] == "f" else -bend, 0, 0)
    return pose


def boar_animations():
    anims = {}
    rest = dict(legs(0, 0, 0, 0), head=(0, 0, 0), tail=(0, 0, 0))
    breathe = dict(rest, hips=(-1.5, 0, 0), head=(4, 4, 0), tail=(10, 0, 8), off=(0, 0, -0.01))
    anims["idle"] = ([(0.0, rest), (0.9, breathe), (1.5, dict(rest, head=(2, -5, 0)))], 2.0, True)
    keys = []
    for i in range(4):
        s = 1 if i % 2 == 0 else -1
        keys.append((i * 0.2, dict(legs(-20 * s, 20 * s, 20 * s, -20 * s), head=(3 * s, 0, 0), tail=(10, 0, 12 * s), off=(0, 0, 0.01 * (i % 2)))))
    anims["walk"] = (keys, 0.8, True)
    keys = []
    for i, (front, back, pitch, height) in enumerate(((-35, 30, -6, 0.04), (25, -35, 6, -0.02), (-35, 30, -6, 0.04), (25, -35, 6, -0.02))):
        keys.append((i * 0.11, dict(legs(front, front + 6, back, back - 6), hips=(pitch, 0, 0), head=(14, 0, 0), tail=(-30, 0, 0), off=(0, 0, height))))
    anims["run"] = (keys, 0.44, True)
    scrape = [(0.0, dict(rest, head=(18, 0, 0)))]
    for i in range(4):
        scrape.append((0.12 + i * 0.18, dict(legs(-30 if i % 2 == 0 else 15, 0, 0, 0), hips=(6, 0, 0), head=(26, 0, 6 * (1 if i % 2 else -1)), off=(0, 0.04, -0.06), tail=(-20, 0, 0))))
    scrape.append((TIMINGS["boar"]["windup"]["length"], dict(legs(-10, -10, 20, 20), hips=(8, 0, 0), head=(28, 0, 0), off=(0, 0.08, -0.08), tail=(-35, 0, 0))))
    anims["windup"] = (scrape, TIMINGS["boar"]["windup"]["length"], False)
    keys = []
    for i, (front, back, pitch, height) in enumerate(((-45, 40, -8, 0.06), (35, -45, 8, -0.03), (-45, 40, -8, 0.06), (35, -45, 8, -0.03))):
        keys.append((i * 0.0833, dict(legs(front, front, back, back), hips=(pitch, 0, 0), head=(30, 0, 0), tail=(-50, 0, 0), off=(0, 0, height))))
    anims["charge"] = (keys, 0.333, True)
    recoil = dict(rest, hips=(-10, 0, 6), head=(-20, 10, 0), off=(0, 0.12, 0.02), tail=(30, 0, 0))
    anims["hit"] = ([(0.0, rest), (0.08, recoil), (0.35, rest)], 0.35, False)
    dazed = dict(legs(-10, 10, 0, 0, knee=10), hips=(6, 0, 12), head=(30, 20, 10), off=(0, 0, -0.12), tail=(20, 0, 0))
    anims["stagger"] = ([(0.0, rest), (0.15, recoil), (0.5, dazed), (1.0, dict(dazed, hips=(6, 0, -8), head=(30, -20, -10))), (1.4, dazed), (1.6, rest)], 1.6, False)
    down = dict(legs(-40, -30, 30, 40), hips=(0, 0, 85), head=(10, 0, 20), off=(0.3, 0, -0.45), tail=(0, 0, 0))
    anims["death"] = ([(0.0, rest), (0.15, recoil), (0.6, dict(down, hips=(0, 0, 60), off=(0.2, 0, -0.3))), (1.0, down)], 1.0, False)
    return anims


def build(preview):
    vk.reset()
    body = boar_mesh().build()
    rig = create_rig()
    hu.bind(body, rig)
    poser = hu.Poser(rig, 1.0)
    sets = boar_animations()
    for anim_name, (keys, length, loop) in sets.items():
        hu.add_action(rig, poser, anim_name, keys, length, loop)
    poser.reset()
    out_dir = vk.MODELS / "characters"
    original = vk.MODELS
    original_art = vk.ART
    vk.MODELS = out_dir
    vk.ART = original_art / "characters"
    info = vk.save_and_export("heo_gio", animations=True, extra={"animations": sorted(sets), "role": "beast"})
    vk.MODELS = original
    vk.ART = original_art
    vk.write_manifest_entry(info, "characters")
    if preview:
        vk.render_preview("heo_gio_rest", {"side": (90, 0, 2.0), "q": (35, 10, 2.0)}, size=(520, 420), target=(0, 0, 0.5))
        for anim_name in sets:
            action = bpy.data.actions[anim_name]
            rig.animation_data.action = action
            end = int(action.frame_end)
            for index, frame in enumerate(sorted({0, end // 3, (2 * end) // 3, end})):
                vk.render_preview(f"heo_gio_{anim_name}_{index}", {"q": (60, 8, 2.2)}, size=(260, 220), target=(0, 0, 0.5), frame=frame)


if __name__ == "__main__":
    if not bpy.app.background:
        raise RuntimeError("Run this generator in a separate background Blender process.")
    build("--preview" in sys.argv)
