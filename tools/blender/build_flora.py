"""Vertex-coloured flora kit for Vân Khê (one material per asset, one draw call per chunk).

blender --background --factory-startup --python tools/blender/build_flora.py -- [names...] [--preview]
Outputs art/env/<name>.blend and assets/models/env/<name>.glb. Origins sit on the ground.
Canopies are shaded in the mesh (dark underside, sunlit top) for the painted anime look;
light-toned kinds (grass, flowers) are tinted per instance in Godot.
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import vk_lib as vk  # noqa: E402


def canopy_paint(b, verts, center, dark, light, sun="leaf_sun", jitter=0.0, rng=None):
    """Shade a foliage blob from its centre: underside dark, top lit, a touch of sun on the crown."""
    shift = rng.uniform(-jitter, jitter) if rng and jitter else 0.0

    def fn(co):
        up = (co - Vector(center)).normalized().z
        t = max(0.0, min(1.0, up * 0.6 + 0.5 + shift))
        rgb = vk.mix(dark, light, t)
        if up > 0.55:
            rgb = vk.mix(rgb, sun, (up - 0.55) * 0.9)
        return rgb
    return b.paint(verts, fn)


def blob(b, center, radius, squash, dark, light, rng, segments=10, rings=7, sun="leaf_sun"):
    def lumpy(co):
        return co * (1.0 + rng.uniform(-0.09, 0.09))
    verts = b.sphere(radius, center, scale=(1, 1, squash), mat="leaf", segments=segments, rings=rings, shape=lumpy)
    canopy_paint(b, verts, center, dark, light, sun, 0.08, rng)


def trunk(b, height, radius, branches, rng, mat="wood"):
    verts = b.cylinder(radius, height, (0, 0, height / 2), mat=mat, top=radius * 0.62, segments=7)
    b.paint(verts, lambda co: vk.mix("wood_dark", mat, 0.35 + co.z / height * 0.65))
    for angle, rise, length in branches:
        start = Vector((0, 0, height * rise))
        end = start + Vector((math.cos(angle) * length, math.sin(angle) * length, length * 0.7))
        b.segment(start, end, radius * 0.45, radius * 0.22, mat=mat, segments=5)


# ---------------------------------------------------------------- trees

def tree_round():
    """Broad Ghibli-style shade tree: rounded crown of lumpy blobs."""
    rng = random.Random(11)
    b = vk.MeshBuilder("TreeRound", vcol=True)
    trunk(b, 3.0, 0.3, [(0.4, 0.62, 1.3), (2.6, 0.7, 1.2), (4.3, 0.55, 1.1)], rng)
    crown = [((0, 0, 4.1), 1.9, 0.8), ((1.3, 0.3, 3.6), 1.3, 0.85), ((-1.2, 0.5, 3.7), 1.35, 0.85), ((0.2, -1.2, 3.6), 1.25, 0.85),
             ((-0.4, 1.1, 4.4), 1.2, 0.8), ((0.6, 0.4, 5.0), 1.15, 0.78), ((-0.7, -0.6, 4.8), 1.05, 0.8), ((1.1, -0.7, 4.4), 1.0, 0.8)]
    for center, radius, squash in crown:
        blob(b, center, radius, squash, "leaf_dark", "leaf_light", rng)
    return b


def tree_blossom():
    """Flowering peach tree (hoa đào): pink crown over a dark twisting trunk."""
    rng = random.Random(23)
    b = vk.MeshBuilder("TreeBlossom", vcol=True)
    trunk(b, 2.4, 0.22, [(0.9, 0.5, 1.2), (3.0, 0.65, 1.1), (5.0, 0.7, 1.0)], rng, mat="wood_dark")
    crown = [((0, 0, 3.4), 1.45, 0.75), ((1.1, 0.4, 3.1), 1.0, 0.8), ((-1.0, 0.3, 3.2), 1.05, 0.8), ((0.1, -1.0, 3.2), 0.95, 0.8),
             ((-0.3, 0.8, 3.9), 0.9, 0.8), ((0.5, -0.2, 4.2), 0.85, 0.78)]
    for center, radius, squash in crown:
        blob(b, center, radius, squash, "blossom", "blossom_light", rng, sun="petal_white")
    return b


def tree_maple():
    """Autumn maple: vermilion and gold crown (village accent tree)."""
    rng = random.Random(31)
    b = vk.MeshBuilder("TreeMaple", vcol=True)
    trunk(b, 2.7, 0.26, [(0.3, 0.75, 1.0), (2.8, 0.8, 1.0)], rng)
    crown = [((0, 0, 3.7), 1.55, 0.78, "vermilion_dark", "vermilion"), ((1.0, 0.3, 3.4), 1.05, 0.8, "vermilion", "gold"),
             ((-0.9, -0.4, 3.5), 1.1, 0.8, "vermilion_dark", "vermilion"), ((0.2, -0.8, 4.1), 1.0, 0.8, "vermilion", "gold"),
             ((-0.3, 0.7, 4.3), 0.95, 0.8, "vermilion", "gold"), ((0.3, 0.1, 4.8), 0.9, 0.78, "vermilion", "lantern")]
    for center, radius, squash, dark, light in crown:
        blob(b, center, radius, squash, dark, light, rng, sun="lantern")
    return b


def tree_pine():
    """Layered mountain pine with lit upper tiers."""
    b = vk.MeshBuilder("TreePine", vcol=True)
    verts = b.cylinder(0.24, 3.6, (0, 0, 1.8), mat="wood_dark", top=0.13, segments=7)
    b.paint(verts, lambda co: vk.mix("wood_dark", "wood", co.z / 3.6))
    tiers = [(1.8, 2.3, 2.3), (1.45, 2.1, 3.3), (1.1, 1.9, 4.25), (0.72, 1.6, 5.1)]
    for index, (radius, depth, z) in enumerate(tiers):
        lit = 0.25 + index * 0.18
        cone = b.cone(radius, depth, (0, 0, z), mat="leaf", segments=9)
        b.paint(cone, lambda co, z=z, depth=depth, lit=lit: vk.mix("leaf_dark", "leaf", lit + (co.z - z + depth / 2) / depth * 0.5))
        skirt = b.cone(radius * 0.93, depth * 0.3, (0, 0, z - depth * 0.42), (180, 0, 0), mat="leaf", segments=9)
        b.paint(skirt, lambda co: vk.color("leaf_dark"))
    return b


# ---------------------------------------------------------------- bamboo

def bamboo_cluster():
    """Dense grove of 9 stalks with leaf fans near the top (≈1.6k triangles)."""
    rng = random.Random(7)
    b = vk.MeshBuilder("Bamboo", vcol=True)
    for k in range(9):
        angle = k * 2.4
        dist = 0.18 + 0.11 * k
        base = Vector((math.cos(angle) * dist, math.sin(angle) * dist, 0))
        height = rng.uniform(7.0, 10.5)
        lean = Vector((rng.uniform(-0.07, 0.07), rng.uniform(-0.07, 0.07), 1)).normalized()
        tone = rng.choice(["bamboo", "bamboo_light", "bamboo"])
        # One five-sided stalk; dark bands every 1.1 m read as the nodes.
        rings = []
        steps = 6
        for s in range(steps + 1):
            point = base + lean * (height * s / steps)
            radius = 0.058 - 0.016 * s / steps
            rings.append([tuple(point + Vector((math.cos(i * math.tau / 5) * radius, math.sin(i * math.tau / 5) * radius, 0))) for i in range(5)])
        stalk = b.loft(rings, mat=tone, cap_bottom=False, cap_top=False)
        b.paint(stalk, lambda co, tone=tone, height=height: vk.mix("bamboo_dark", tone, 0.3 + co.z / height) if (co.z % 1.1) > 0.12 else vk.color("bamboo_dark"))
        for leaf in range(5):
            spot = base + lean * (height * rng.uniform(0.6, 0.97))
            a = leaf * 1.26 + k
            tip = spot + Vector((math.cos(a) * 1.2, math.sin(a) * 1.2, -0.6))
            mid = spot.lerp(tip, 0.5) + Vector((0, 0, 0.18))
            fan = b.blade([spot, mid, tip], [0.06, 0.45, 0.0], normal=(0, 0, 1), mat="leaf")
            light = rng.random() < 0.5
            b.paint(fan, lambda co, light=light: vk.color("bamboo_light" if light else "leaf"))
    return b


def bamboo_far():
    """Cheap stand-in for bamboo groves beyond the tree distance."""
    b = vk.MeshBuilder("BambooFar", vcol=True)
    for k in range(5):
        a = k * 1.256
        base = (math.cos(a) * 0.4, math.sin(a) * 0.4, 0)
        b.segment(base, (base[0] * 1.6, base[1] * 1.6, 9.0), 0.07, 0.05, mat="bamboo", segments=4, cap=False)
    crown = b.cone(1.6, 4.2, (0, 0, 7.6), mat="leaf", segments=6)
    b.paint(crown, lambda co: vk.mix("leaf_dark", "bamboo_light", (co.z - 5.5) / 4.2))
    return b


# ---------------------------------------------------------------- ground cover

def grass_tuft():
    """Pale blades darkening to the root; Godot tints each tuft with the ground colour."""
    rng = random.Random(3)
    b = vk.MeshBuilder("Grass", vcol=True)
    for k in range(13):
        a = k * 2.39
        r = rng.uniform(0.0, 0.22)
        base = Vector((math.cos(a) * r, math.sin(a) * r, 0))
        bend = Vector((math.cos(a) * 0.16, math.sin(a) * 0.16, 0))
        height = rng.uniform(0.32, 0.62)
        tip = base + bend + Vector((0, 0, height))
        blade = b.blade([base, base + bend * 0.3 + Vector((0, 0, height * 0.55)), tip], [0.075, 0.05, 0.0],
                        normal=(math.cos(a + 1.57), math.sin(a + 1.57), 0), mat="white")
        b.paint(blade, lambda co, height=height: vk.mix(vk.shade("white", 0.72), "white", co.z / height))
    return b


def flower_patch():
    """A handful of five-petal flowers on stems; petals are white so Godot tints them per patch."""
    rng = random.Random(41)
    b = vk.MeshBuilder("Flowers", vcol=True)
    for k in range(6):
        a = k * 1.9
        r = rng.uniform(0.05, 0.32)
        base = Vector((math.cos(a) * r, math.sin(a) * r, 0))
        height = rng.uniform(0.25, 0.45)
        top = base + Vector((rng.uniform(-0.05, 0.05), rng.uniform(-0.05, 0.05), height))
        b.segment(base, top, 0.012, 0.01, mat="leaf", segments=3, cap=False)
        leaf = b.blade([base + Vector((0, 0, 0.03)), base + Vector((0.08, 0.02, 0.12)), base + Vector((0.16, 0.0, 0.1))], [0.02, 0.07, 0.0],
                       normal=(0, 0, 1), mat="leaf")
        b.paint(leaf, lambda co: vk.color("leaf"))
        head = b.fan(tuple(top), 0.075, 5, mat="petal_white", tilt=0.25, rot=k)
        b.paint(head, lambda co, top=top: vk.color("pollen") if (co - top).length < 0.012 else vk.color("petal_white"))
    return b


def fern_clump():
    """Arching fronds for the bamboo forest floor."""
    rng = random.Random(53)
    b = vk.MeshBuilder("Fern", vcol=True)
    for k in range(8):
        a = k * math.tau / 8 + rng.uniform(-0.2, 0.2)
        length = rng.uniform(0.7, 1.05)
        direction = Vector((math.cos(a), math.sin(a), 0))
        points = [direction * (length * t) + Vector((0, 0, math.sin(t * math.pi * 0.85) * length * 0.55)) for t in (0.0, 0.3, 0.6, 0.85, 1.0)]
        frond = b.blade(points, [0.03, 0.2, 0.22, 0.14, 0.0], normal=(0, 0, 1), mat="fern")
        b.paint(frond, lambda co, length=length: vk.mix("fern", "fern_light", min(1.0, Vector((co.x, co.y, 0)).length / length + co.z)))
    return b


def bush_round():
    rng = random.Random(61)
    b = vk.MeshBuilder("Bush", vcol=True)
    for center, radius in [((0, 0, 0.45), 0.6), ((0.45, 0.15, 0.35), 0.45), ((-0.4, 0.2, 0.38), 0.45), ((0.05, -0.4, 0.35), 0.42), ((0.1, 0.25, 0.7), 0.38)]:
        blob(b, center, radius, 0.85, "leaf_dark", "leaf_light", rng, segments=8, rings=6)
    return b


def bush_flower():
    """Hydrangea-like bush with white blooms (village gardens, forest edges)."""
    rng = random.Random(67)
    b = bush_round()
    b.name = "BushFlower"
    for k in range(9):
        a = k * 2.2
        center = Vector((math.cos(a) * rng.uniform(0.2, 0.55), math.sin(a) * rng.uniform(0.2, 0.55), rng.uniform(0.55, 0.95)))
        bloom = b.sphere(0.11, tuple(center), mat="petal_white", segments=5, rings=3)
        b.paint(bloom, lambda co, center=center: vk.mix("blossom_light", "petal_white", (co.z - center.z) * 6 + 0.5))
    return b


def reed_clump():
    rng = random.Random(71)
    b = vk.MeshBuilder("Reeds", vcol=True)
    for k in range(11):
        a = k * 2.39
        base = Vector((math.cos(a) * rng.uniform(0, 0.35), math.sin(a) * rng.uniform(0, 0.35), 0))
        height = rng.uniform(1.0, 1.7)
        tip = base + Vector((rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), height))
        blade = b.blade([base, base.lerp(tip, 0.5), tip], [0.05, 0.035, 0.0], normal=(math.cos(a + 1.57), math.sin(a + 1.57), 0), mat="reed")
        b.paint(blade, lambda co, height=height: vk.mix("leaf_dark", "reed", co.z / height))
        if k % 3 == 0:
            b.cylinder(0.035, 0.2, tuple(tip - Vector((0, 0, 0.12))), mat="reed_head", segments=5)
    return b


def pebbles():
    rng = random.Random(79)
    b = vk.MeshBuilder("Pebbles", vcol=True)
    for k in range(6):
        a = k * 1.1
        r = rng.uniform(0.1, 0.45)
        size = rng.uniform(0.07, 0.16)
        stone = b.sphere(size, (math.cos(a) * r, math.sin(a) * r, size * 0.3), scale=(1.3, 1.0, 0.55), mat="stone", segments=6, rings=4)
        tone = rng.choice(["stone", "stone_light", "stone_dark"])
        b.paint(stone, lambda co, tone=tone: vk.color(tone))
    return b


def rock_moss():
    rng = random.Random(5)
    b = vk.MeshBuilder("Rock", vcol=True)

    def lumpy(co):
        return co * (1.0 + rng.uniform(-0.1, 0.1))
    body = b.sphere(0.8, (0, 0, 0.35), scale=(1.25, 0.95, 0.72), mat="stone", segments=9, rings=6, shape=lumpy)
    b.paint(body, lambda co: vk.mix("stone_dark", "stone_light", co.z / 0.9) if co.z < 0.62 else vk.mix("moss", "leaf_light", (co.z - 0.62) * 3))
    return b


def log_fallen():
    rng = random.Random(83)
    b = vk.MeshBuilder("Log", vcol=True)
    body = b.segment((-1.3, 0, 0.26), (1.3, 0.1, 0.24), 0.26, 0.22, mat="wood", segments=7)
    b.paint(body, lambda co: vk.color("moss") if co.z > 0.42 else vk.mix("wood_dark", "wood", co.z / 0.42))
    b.segment((0.4, 0.1, 0.35), (0.8, 0.5, 0.75), 0.07, 0.03, mat="wood_dark", segments=4)
    for k in range(3):
        cap = b.sphere(0.07, (-0.6 + k * 0.35, -0.2, 0.18), scale=(1, 1, 0.5), mat="cream", segments=6, rings=3)
        b.paint(cap, lambda co: vk.color("cream_dark"))
    return b


def mushroom_cluster():
    rng = random.Random(89)
    b = vk.MeshBuilder("Mushrooms", vcol=True)
    for k in range(4):
        a = k * 1.7
        base = Vector((math.cos(a) * rng.uniform(0.05, 0.25), math.sin(a) * rng.uniform(0.05, 0.25), 0))
        height = rng.uniform(0.12, 0.26)
        b.segment(base, base + Vector((0, 0, height)), 0.025, 0.02, mat="mushroom_spot", segments=5)
        cap = b.sphere(0.07 + height * 0.25, tuple(base + Vector((0, 0, height))), scale=(1, 1, 0.55), mat="mushroom_cap", segments=7, rings=4)
        b.paint(cap, lambda co, top=base.z + height: vk.mix("mushroom_cap", "mushroom_spot", 1.0 if (int(co.x * 60) + int(co.y * 60)) % 5 == 0 and co.z > top else 0.0))
    return b


def karst_peak():
    """Background limestone tower: pale cliffs under a forested cap (Hạ Long / Guilin look)."""
    rng = random.Random(97)
    b = vk.MeshBuilder("Karst", vcol=True)
    rings = []
    heights = [0.0, 0.15, 0.35, 0.55, 0.72, 0.84, 0.93, 1.0]
    widths = [1.0, 0.9, 0.78, 0.7, 0.66, 0.58, 0.42, 0.12]
    count = 16
    for level, (h, w) in enumerate(zip(heights, widths)):
        ring = []
        for i in range(count):
            a = math.tau * i / count
            r = w * rng.uniform(0.85, 1.12)
            ring.append((math.cos(a) * r, math.sin(a) * r, h))
        rings.append(ring)
    verts = b.loft(rings, mat="karst", cap_top=True, cap_bottom=False, sharp_angle=70)

    def paint(co):
        if co.z > 0.62 + 0.08 * math.sin(co.x * 5 + co.y * 3):
            return vk.mix("karst_forest", "karst_forest_light", (co.z - 0.6) * 2.5)
        streak = 0.5 + 0.5 * math.sin(co.x * 9 + co.y * 7)
        return vk.mix("karst_shadow", "karst", min(1.0, co.z * 1.4) * (0.75 + 0.25 * streak))
    b.paint(verts, paint)
    return b


ASSETS = {
    "tree_round": tree_round, "tree_blossom": tree_blossom, "tree_maple": tree_maple, "tree_pine": tree_pine,
    "bamboo_cluster": bamboo_cluster, "bamboo_far": bamboo_far, "grass_tuft": grass_tuft, "flower_patch": flower_patch,
    "fern_clump": fern_clump, "bush_round": bush_round, "bush_flower": bush_flower, "reed_clump": reed_clump,
    "pebbles": pebbles, "rock_moss": rock_moss, "log_fallen": log_fallen, "mushroom_cluster": mushroom_cluster,
    "karst_peak": karst_peak,
}


def main(names, preview):
    out_dir = vk.MODELS / "env"
    out_dir.mkdir(parents=True, exist_ok=True)
    for name in names:
        vk.reset()
        ASSETS[name]().build()
        original_art, original_models = vk.ART, vk.MODELS
        vk.MODELS, vk.ART = out_dir, original_art / "env"
        info = vk.save_and_export(name, extra={"kind": "flora"})
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
