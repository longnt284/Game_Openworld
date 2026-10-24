"""Reproducible art upgrade. Default is the bounded prototype; --all builds the kit."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import bpy
import build_characters as characters
import build_props as props
import build_flora as flora
import vk_lib as vk

if __name__=='__main__':
    if not bpy.app.background:
        raise RuntimeError('Run in a separate background Blender process to preserve the open scene.')
    all_assets='--all' in sys.argv
    vk.DEFAULT_VCOL=False
    for name in characters.CHARACTERS if all_assets else ['lam_an']:
        characters.build(name,False)
    vk.DEFAULT_VCOL=True
    props.main(list(props.ASSETS) if all_assets else ['house_small','well','market_stall','lantern_post'],False)
    flora.main(list(flora.ASSETS) if all_assets else ['tree_maple','bamboo_cluster'],False)
    if all_assets:
        import build_weapons as weapons
        import build_creatures as creatures
        vk.DEFAULT_VCOL=False
        weapons.main(False)
        # Creature generator has its own entry point and animation contract.
        import runpy
        runpy.run_path(str(Path(__file__).with_name('build_creatures.py')),run_name='__main__')
