"""Rebuild the original low-poly starter kit using Blender in background mode.

blender --background --factory-startup --python tools/blender/build_assets.py
The live Blender session is never touched. Sources: art/*.blend; runtime: assets/models/*.glb.
"""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art"
OUTPUT = ROOT / "assets" / "models"


def material(name, color, glow=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = 0.85
    if glow:
        shader.inputs["Emission Color"].default_value = (*color, 1)
        shader.inputs["Emission Strength"].default_value = glow
    return mat


def finish(name, mat):
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    preview = bpy.context.preferences.filepaths.bl_rna.properties.get("file_preview_type")
    if preview and "NONE" in {item.identifier for item in preview.enum_items}:
        bpy.context.preferences.filepaths.file_preview_type = "NONE"
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0


def export(name):
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / f"{name}.blend"), compress=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT / f"{name}.glb"), export_format="GLB",
        use_selection=False, export_yup=True, export_apply=True,
        export_cameras=False, export_lights=False,
    )
    print(f"ASSET_OK {name}: {(OUTPUT / f'{name}.glb').stat().st_size} bytes")


def tree():
    reset()
    bark = material("Pine bark", (0.20, 0.115, 0.065))
    greens = [material(f"Needles {i}", col) for i, col in enumerate([
        (0.075, 0.23, 0.145), (0.12, 0.31, 0.20), (0.19, 0.39, 0.25)])]
    bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=0.24, radius2=0.15, depth=3.5, location=(0, 0, 1.75))
    finish("Trunk", bark)
    for i, (radius, depth, z) in enumerate([(1.55, 2.5, 2.5), (1.20, 2.25, 3.45), (0.80, 1.9, 4.30)]):
        bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=radius, radius2=0, depth=depth, location=(0, 0, z))
        finish(f"Crown_{i}", greens[i])
    export("tree")


def rock():
    reset()
    stone = material("River stone", (0.34, 0.38, 0.33))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.8, location=(0, 0, 0.4))
    bpy.context.object.scale = (1.3, 0.85, 0.72)
    finish("Rock", stone)
    export("rock")


def beacon():
    reset()
    stone = material("Warm stone", (0.44, 0.43, 0.32))
    metal = material("Oxidized bronze", (0.17, 0.25, 0.19))
    light = material("Amber signal", (1.0, 0.54, 0.12), glow=2.5)
    for radius, depth, z in [(1.15, 0.24, 0.12), (0.8, 0.2, 0.34), (0.32, 1.8, 1.3)]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=radius, depth=depth, location=(0, 0, z))
        finish("Plinth", stone)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.40, location=(0, 0, 2.5))
    finish("Signal", light)
    for x in [-0.5, 0.5]:
        for y in [-0.5, 0.5]:
            bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, 2.5))
            bpy.context.object.scale = (0.08, 0.08, 1.25)
            finish("Frame", metal)
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.94, radius2=0.0, depth=0.6, location=(0, 0, 3.4), rotation=(0, 0, 0.785398))
    finish("Roof", metal)
    export("beacon")


if __name__ == "__main__":
    if not bpy.app.background:
        raise RuntimeError("Run this generator in a separate background Blender process.")
    SOURCE.mkdir(parents=True, exist_ok=True)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    tree()
    rock()
    beacon()
