"""Weapons held through the SwordSocket: grip centre at origin, blade along +Z, edge along X.

blender --background --factory-startup --python tools/blender/build_weapons.py -- [--preview]
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bpy  # noqa: E402

import vk_lib as vk  # noqa: E402


def blade(b, start, length, width, thickness, mat, curve=0.0, tip=0.12, fuller=None):
    """Diamond cross-section blade with an optional sabre curve along +X."""
    rings = []
    steps = 8
    for i in range(steps + 1):
        u = i / steps
        z = start + length * u
        taper = 1.0 if z < start + length - tip else max(0.02, (start + length - z) / tip)
        w = width * (1.0 - 0.18 * u) * taper
        offset = curve * (u ** 2)
        rings.append([(offset + w * 0.5, 0, z), (offset, thickness * 0.5, z), (offset - w * 0.5, 0, z), (offset, -thickness * 0.5, z)])
    b.loft(rings, mat=mat, smooth=False, cap_top=False)
    if fuller:
        b.box((width * 0.18, thickness * 1.05, length * 0.62), (curve * 0.15, 0, start + length * 0.36), mat=fuller)


def grip(b, length, radius, mat, wrap=None):
    b.cylinder(radius, length, (0, 0, 0), mat=mat, segments=8)
    if wrap:
        for i in range(5):
            b.torus(radius + 0.002, 0.0035, (0, 0, -length * 0.4 + i * length * 0.2), mat=wrap, segments=8, ring=4)


def sword_old():
    b = vk.MeshBuilder("Sword")
    grip(b, 0.2, 0.016, "wood_dark", "cloth_dark")
    b.sphere(0.022, (0, 0, -0.11), mat="bronze", segments=8, rings=6)
    b.box((0.1, 0.034, 0.022), (0, 0, 0.11), mat="bronze", bevel=0.006)
    blade(b, 0.12, 0.78, 0.058, 0.01, "metal", fuller="metal_dark")
    return b


def sword_bamboo():
    b = vk.MeshBuilder("Sword")
    b.cylinder(0.017, 0.21, (0, 0, 0), mat="bamboo", segments=8)
    for z in (-0.07, 0.0, 0.07):
        b.torus(0.018, 0.004, (0, 0, z), mat="bamboo_dark", segments=8, ring=4)
    b.sphere(0.02, (0, 0, -0.115), mat="jade_dark", segments=8, rings=6)
    for side in (1, -1):
        b.cone(0.022, 0.07, (side * 0.04, 0, 0.115), (0, side * 90, 0), mat="jade", segments=6, scale=(1, 0.6, 1))
    b.box((0.05, 0.036, 0.026), (0, 0, 0.115), mat="jade_dark", bevel=0.008)
    blade(b, 0.13, 0.82, 0.056, 0.01, "metal", fuller="jade_light")
    b.strip([(0, 0, -0.12), (0.01, 0.02, -0.2), (0.02, 0.03, -0.3)], 0.016, normal=(1, 0, 0), mat="vermilion")
    return b


def sword_wind():
    b = vk.MeshBuilder("Sword")
    grip(b, 0.22, 0.016, "cloth_blue", "gold")
    b.sphere(0.024, (0, 0, -0.125), mat="gold", segments=10, rings=6)
    for side in (1, -1):
        b.strip([(side * 0.012, 0, 0.115), (side * 0.06, 0, 0.13), (side * 0.095, 0, 0.165)], [0.05, 0.035, 0.008], normal=(0, 1, 0), mat="gold", thickness=0.008)
    b.box((0.05, 0.034, 0.03), (0, 0, 0.12), mat="gold", bevel=0.01)
    blade(b, 0.135, 0.86, 0.058, 0.01, "metal", fuller="spirit")
    b.strip([(0, 0, -0.14), (0.01, 0.03, -0.24), (0.03, 0.05, -0.36)], [0.03, 0.025, 0.015], normal=(1, 0, 0), mat="jade_light")
    return b


def sabre():
    b = vk.MeshBuilder("Sword")
    grip(b, 0.22, 0.017, "leather", "cloth_dark")
    b.sphere(0.02, (0, 0, -0.12), mat="metal_dark", segments=8, rings=6)
    b.cylinder(0.05, 0.016, (0, 0, 0.115), mat="metal_dark", segments=10)
    blade(b, 0.125, 0.68, 0.075, 0.01, "metal", curve=0.06, tip=0.2)
    return b


def glaive():
    b = vk.MeshBuilder("Sword")
    b.cylinder(0.026, 2.1, (0, 0, 0.35), mat="bamboo_dark", segments=8)
    for z in (-0.4, 0.0, 0.4, 0.8, 1.2):
        b.torus(0.028, 0.006, (0, 0, z), mat="bamboo_light", segments=8, ring=4)
    b.cone(0.03, 0.14, (0, 0, -0.76), (180, 0, 0), mat="gold", segments=8)
    b.box((0.12, 0.06, 0.05), (0, 0, 1.42), mat="gold", bevel=0.01)
    blade(b, 1.44, 0.7, 0.16, 0.016, "metal", curve=0.14, tip=0.25, fuller="seal")
    b.strip([(0, 0, 1.4), (0.03, 0.05, 1.3), (0.06, 0.07, 1.15)], [0.05, 0.04, 0.02], normal=(1, 0, 0), mat="vermilion")
    return b


WEAPONS = {"sword_old": sword_old, "sword_bamboo": sword_bamboo, "sword_wind": sword_wind, "sabre": sabre, "glaive": glaive}


def main(preview):
    out_dir = vk.MODELS / "weapons"
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, factory in WEAPONS.items():
        vk.reset()
        factory().build()
        original = vk.MODELS
        original_art = vk.ART
        vk.MODELS = out_dir
        vk.ART = original_art / "weapons"
        info = vk.save_and_export(name)
        vk.MODELS = original
        vk.ART = original_art
        vk.write_manifest_entry(info, "weapons")
        if preview:
            size = 2.4 if name == "glaive" else 1.1
            vk.render_preview(name, {"side": (90, 0, size), "front": (0, 0, size)}, size=(320, 480), target=(0, 0, 0.6 if name == "glaive" else 0.35))


if __name__ == "__main__":
    if not bpy.app.background:
        raise RuntimeError("Run this generator in a separate background Blender process.")
    main("--preview" in sys.argv)
