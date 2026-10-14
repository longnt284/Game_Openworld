"""Build rigged, animated humanoids for Vân Khê: Dư Âm Gió.

blender --background --factory-startup --python tools/blender/build_characters.py -- [names...] [--preview]
Writes art/<name>.blend and assets/models/characters/<name>.glb. Background only.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import anim_humanoid as anims  # noqa: E402
import humanoid as hu  # noqa: E402
import vk_lib as vk  # noqa: E402

CHARACTERS = {
    "lam_an": {
        "role": "player", "scale": 1.0, "hair_style": "hero", "outer": "jade", "inner": "cream", "trim": "white", "sash": "vermilion",
        "pants": "cloth_dark", "boots": "leather", "extras": ["tails", "pauldron", "scarf", "sheath"], "brow_tilt": 10,
    },
    "tieu_mac": {
        "role": "npc", "scale": 0.95, "hair_style": "short", "hair": "hair_brown", "outer": "cloth_blue", "inner": "cream", "trim": "cream",
        "sash": "gold", "pants": "cream_dark", "boots": "wood", "extras": ["tails", "hat", "bag"], "tail_length": 0.3, "iris": "iris_amber",
        "brow_tilt": -6, "mouth": 0.022,
    },
    "ba_luc": {
        "role": "npc", "scale": 0.88, "hair_style": "bun", "hair": "hair_white", "brow": "hair_white", "outer": "cloth_brown", "inner": "cream",
        "trim": "cream", "sash": "jade_dark", "skirt": "cloth_brown", "extras": ["skirt", "cane"], "eye_scale": 0.82, "iris": "hair_brown",
        "hunch": 12, "hands": "cane", "lash_tilt": 4,
    },
    "chu_bay": {
        "role": "npc", "scale": 1.04, "width": 1.15, "belly": 1.1, "hair_style": "short", "hair": "hair", "outer": "cloth_dark", "sleeve": "cloth_dark",
        "inner": "cream", "trim": "wood_light", "sash": "wood", "pants": "cloth_brown", "boots": "leather", "bare_forearms": True,
        "extras": ["bandana", "beard", "apron", "hammer"], "beard": "hair", "eye_scale": 0.9, "brow_tilt": 14, "work": True,
    },
    "ba_hanh": {
        "role": "npc", "scale": 0.92, "hair_style": "bun", "hair": "hair_brown", "outer": "wood_light", "inner": "gold", "trim": "cream",
        "sash": "jade", "skirt": "cloth_dark", "extras": ["skirt", "bandana"], "bandana": "cloth_dark", "eye_scale": 0.9, "iris": "hair_brown",
        "hands": "clasped", "brow_tilt": -4,
    },
    "tich_phong": {
        "role": "npc", "scale": 1.04, "hair_style": "long", "hair": "hair_white", "brow": "hair_white", "outer": "white", "inner": "vermilion",
        "trim": "vermilion", "sash": "vermilion_dark", "skirt": "cream", "extras": ["skirt", "scarf"], "scarf": "vermilion", "iris": "spirit",
        "eye_scale": 0.92, "brow_tilt": 4, "hands": "clasped",
    },
    "tan_binh": {
        "role": "bandit", "scale": 1.0, "hair_style": "short", "hair": "hair", "outer": "cloth_dark", "sleeve": "cloth_dark", "inner": "stone_dark",
        "trim": "vermilion_dark", "sash": "vermilion_dark", "tails": "wood_dark", "pants": "stone_dark", "boots": "leather",
        "extras": ["tails", "mask"], "mask": "mask", "mask_mark": "vermilion",
    },
    "truc_tuong": {
        "role": "guardian", "scale": 1.55, "width": 1.25, "belly": 1.15, "hair_style": "none", "skin": "stone_dark", "outer": "bamboo_dark",
        "sleeve": "bamboo_dark", "inner": "cream", "trim": "gold", "sash": "vermilion", "tails": "bamboo", "pants": "cloth_dark", "boots": "wood_dark",
        "bracer": "bamboo_dark", "extras": ["tails", "mask", "armor"], "mask": "mask", "mask_mark": "seal", "eye_glow": "spirit",
        "tail_length": 0.5,
    },
}


def extra_props(b, spec):
    extras = spec.get("extras", [])
    if "cane" in extras:
        b.segment((-0.236, -0.03, 0.83), (-0.25, -0.2, 0.0), 0.014, 0.012, mat="wood", bone="hand.R", segments=6)
        b.sphere(0.022, (-0.236, -0.03, 0.85), mat="wood_dark", bone="hand.R", segments=8, rings=6)
    if "hammer" in extras:
        b.segment((-0.226, -0.01, 0.82), (-0.226, -0.3, 0.6), 0.013, mat="wood", bone="hand.R", segments=6)
        b.box((0.06, 0.06, 0.13), (-0.226, -0.31, 0.6), (35, 0, 0), mat="metal_dark", bone="hand.R", bevel=0.008)


def build(name, preview):
    spec = dict(CHARACTERS[name])
    scale = spec["scale"]
    vk.reset()
    extras = [extra for extra in spec.get("extras", []) if extra not in ("cane", "hammer")]
    builder = hu.build_mesh("Body", dict(spec, extras=extras))
    extra_props(builder, spec)
    body = builder.build()
    body.data.transform(__import__("mathutils").Matrix.Scale(scale, 4))
    rig = hu.create_rig(scale)
    hu.bind(body, rig)
    grip = hu.hand_grip(scale)
    hu.add_socket(rig, "SwordSocket", "hand.R", grip, hu.BLADE_REST, hu.EDGE_REST)
    if "sheath" in spec.get("extras", []):
        mouth, direction = hu.sheath_frame()
        hu.add_socket(rig, "SheathSocket", "hips", (mouth - direction * 0.11) * scale, direction, Vector((0, 0, 1)))
    poser = hu.Poser(rig, scale)
    role = spec["role"]
    if role == "player":
        sets = anims.player_animations()
    elif role == "bandit":
        sets = anims.bandit_animations()
    elif role == "guardian":
        sets = anims.guardian_animations()
    else:
        sets = anims.npc_animations(spec.get("hunch", 0.0), spec.get("hands", "sides"), spec.get("work", False))
    for anim_name, (keys, length, loop) in sets.items():
        hu.add_action(rig, poser, anim_name, keys, length, loop)
    rig.animation_data.action = None
    poser.reset()
    bpy.context.view_layer.update()
    out_dir = vk.MODELS / "characters"
    out_dir.mkdir(parents=True, exist_ok=True)
    original = vk.MODELS
    original_art = vk.ART
    vk.MODELS = out_dir
    vk.ART = original_art / "characters"
    info = vk.save_and_export(name, animations=True, extra={"animations": sorted(sets.keys()), "role": role})
    vk.MODELS = original
    vk.ART = original_art
    vk.write_manifest_entry(info, "characters")
    if preview:
        render_previews(name, rig, scale, sets)


def render_previews(name, rig, scale, sets):
    blade = vk.MeshBuilder("PreviewBlade")
    blade.box((0.03, 0.008, 0.75), (0, 0, 0.47), mat="metal")
    blade.box((0.09, 0.03, 0.02), (0, 0, 0.09), mat="gold")
    blade.cylinder(0.014, 0.18, (0, 0, 0), mat="wood_dark")
    blade_obj = blade.build()
    socket = bpy.data.objects["SwordSocket"]
    blade_obj.parent = socket
    target = (0, 0, 0.85 * scale)
    size = 2.3 * scale
    vk.render_preview(name + "_rest", {"front": (0, 0, size), "side": (90, 0, size), "three_quarter": (35, 8, size), "back": (180, 0, size)},
                      size=(520, 640), target=target)
    vk.render_preview(name + "_face", {"face": (12, 4, 0.42 * scale)}, size=(480, 480), target=(0, 0, 1.58 * scale))
    sheet = []
    for anim_name in sets:
        action = bpy.data.actions[anim_name]
        rig.animation_data.action = action
        end = int(action.frame_end)
        for index, frame in enumerate(sorted({0, end // 3, (2 * end) // 3, end})):
            paths = vk.render_preview(f"{name}_{anim_name}_{index}", {"q": (30, 8, size * 1.15)}, size=(260, 320), target=target, frame=frame)
            sheet.append((anim_name, paths[0]))
    rig.animation_data.action = None
    contact_sheet(name, sheet)


def contact_sheet(name, sheet):
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        print("PIL missing; individual previews kept")
        return
    columns = 8
    rows = (len(sheet) + columns - 1) // columns
    canvas = Image.new("RGB", (260 * columns, 340 * rows), (30, 34, 38))
    draw = ImageDraw.Draw(canvas)
    for index, (label, path) in enumerate(sheet):
        image = Image.open(path)
        x, y = (index % columns) * 260, (index // columns) * 340
        canvas.paste(image, (x, y))
        draw.text((x + 6, y + 322), label, fill=(240, 230, 200))
        Path(path).unlink()
    target = vk.PREVIEW / f"{name}_anim_sheet.png"
    canvas.save(target)
    print("SHEET " + str(target))


if __name__ == "__main__":
    if not bpy.app.background:
        raise RuntimeError("Run this generator in a separate background Blender process.")
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    preview = "--preview" in argv
    names = [arg for arg in argv if not arg.startswith("--")] or list(CHARACTERS)
    for character in names:
        build(character, preview)
