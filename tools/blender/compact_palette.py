"""Keep recolour channels, bake remaining palette into linear vertex colours."""
import bpy
import json
from pathlib import Path


def compact(obj, name):
    mesh = obj.data
    root=Path(__file__).resolve().parents[2]
    keep = {'VK_robe','VK_robe_trim','VK_sash','VK_ribbon','VK_scarf_white'} if name=='lam_an' else set()
    # NPC variants are a runtime contract too: retain every referenced channel.
    entities=json.loads((root/'data/world/entities.json').read_text(encoding='utf-8'))
    def collect(value):
        if isinstance(value,dict):
            if value.get('npc')==name:
                keep.update(value.get('tint',{}))
            for item in value.values():
                collect(item)
        elif isinstance(value,list):
            for item in value:
                collect(item)
    collect(entities)
    old = list(mesh.materials)
    # Preserve emissive channels as independent surfaces as well.
    def emissive(mat):
        bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        return bsdf.inputs['Emission Strength'].default_value > 0
    kept=[m for m in old if m.name in keep or emissive(m)]
    palette=bpy.data.materials.new('VK_avatar_palette')
    palette.use_nodes=True
    bsdf=next(n for n in palette.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value=(1,1,1,1)
    bsdf.inputs['Roughness'].default_value=0.72
    colors=palette.node_tree.nodes.new('ShaderNodeVertexColor')
    colors.layer_name='Color'
    palette.node_tree.links.new(colors.outputs['Color'],bsdf.inputs['Base Color'])
    layer=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    mesh.color_attributes.active_color=layer
    indices=[]
    for face in mesh.polygons:
        mat=old[face.material_index]
        tint=(1,1,1,1) if mat in kept else tuple(next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'].default_value)
        for li in face.loop_indices:
            layer.data[li].color=tint
        indices.append(kept.index(mat) if mat in kept else len(kept))
    mesh.materials.clear()
    for mat in kept+[palette]:
        mesh.materials.append(mat)
    for face,index in zip(mesh.polygons,indices):
        face.material_index=index
