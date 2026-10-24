"""Original block avatar kit, preserving the existing 20-bone combat interface."""
import math
from mathutils import Vector
import vk_lib as vk


def build_mesh(name, spec):
    import humanoid as hu
    b = vk.MeshBuilder(name, vcol=False)
    skin = spec.get('skin', 'skin')
    outer = spec.get('outer', 'jade')
    trim = spec.get('trim', 'cream')
    pants = spec.get('pants', 'cloth_dark')
    boots = spec.get('boots', 'leather')
    def box(size, pos, mat, bone, rot=(0, 0, 0), bevel=0.012):
        return b.box(size, pos, rot, mat=mat, bone=bone, bevel=bevel, segments=2)

    # Flat face with a soft jaw bevel; 1.8 m silhouette / 0.31 m head ≈ 5.8 heads.
    box((0.29, 0.25, 0.31), (0, -0.005, 1.59), skin, 'head', bevel=0.035)
    box((0.10, 0.10, 0.11), (0, 0, 1.42), skin, 'neck')
    for side in (-1, 1):
        x = side * 0.061
        box((0.047, 0.009, 0.042), (x, -0.133, 1.586), 'white', 'head', bevel=0.009)
        box((0.026, 0.009, 0.037), (x-side*0.003, -0.14, 1.585), spec.get('iris','iris_amber'), 'head', bevel=0.007)
        box((0.011, 0.007, 0.028), (x-side*0.004, -0.146, 1.584), 'ink', 'head', bevel=0.003)
        box((0.008, 0.005, 0.009), (x-0.006, -0.151, 1.596), 'white', 'head', bevel=0.002)
        box((0.051, 0.012, 0.009), (x, -0.139, 1.61), 'hair', 'head', (0, side*8, 0), 0.002)
        box((0.052, 0.01, 0.009), (x, -0.13, 1.637), spec.get('brow', 'hair'), 'head', (0, side*10, 0), 0.002)
        box((0.035, 0.056, 0.065), (side*0.146, 0, 1.57), skin, 'head')
    b.strip([(-0.025,-0.133,1.509),(0,-0.135,1.505),(0.026,-0.132,1.514)],0.004,mat='vermilion_dark',bone='head',thickness=0.002)

    # Reuse authored hair clumps, enlarging only hair around the head centre.
    old = set(b.bm.verts)
    {'hero':hu.hair_hero,'short':hu.hair_short,'bun':hu.hair_bun,'long':hu.hair_long,'none':lambda *_:None}[spec.get('hair_style','hero')](b,spec)
    for v in set(b.bm.verts)-old:
        v.co = Vector((v.co.x*1.36, v.co.y*1.22, 1.59+(v.co.z-1.59)*1.12))
    if spec.get('hair_style','hero') != 'none':
        box((0.305,0.272,0.115),(0,0.006,1.713),spec.get('hair','hair'),'head',bevel=0.035)
        # Broad swept locks conceal the cap edge without covering the eyes.
        for side in (-1,1):
            hu.lock(b,(side*0.03,-0.10,1.79),(side*0.09,-0.155,1.70),(side*0.13,-0.15,1.625),0.052,spec.get('hair','hair'))

    box((0.30,0.235,0.29),(0,0,1.265),outer,'chest',bevel=0.025)
    box((0.28,0.22,0.17),(0,0,1.07),outer,{'spine':0.6,'hips':0.4},bevel=0.018)
    box((0.14,0.02,0.28),(0,-0.124,1.245),spec.get('inner','cream'),'chest',bevel=0.004)
    for side in (-1,1):
        b.strip([(side*0.105,-0.13,1.395),(side*0.045,-0.139,1.28),(-side*0.025,-0.137,1.13)],0.034,mat=trim,bone='chest',thickness=0.006)
    box((0.314,0.254,0.078),(0,0,1.032),spec.get('sash','vermilion') or outer,'hips')
    box((0.04,0.026,0.06),(0.09,-0.139,1.031),'gold','hips',bevel=0.006)
    for side in (-1,1):
        s = 'L' if side>0 else 'R'
        box((0.17,0.22,0.30),(side*0.207,0,1.22),spec.get('sleeve',outer),'upper_arm.'+s,bevel=0.018)
        box((0.175,0.223,0.035),(side*0.218,0,1.078),trim,'upper_arm.'+s,bevel=0.006)
        box((0.115,0.145,0.205),(side*0.222,0,0.951),skin if spec.get('bare_forearms') else spec.get('bracer','leather'),'forearm.'+s)
        for z in (0.86,1.035):
            box((0.12,0.15,0.022),(side*0.223,0,z),'gold','forearm.'+s,bevel=0.004)
        box((0.105,0.115,0.10),(side*0.226,-0.004,0.795),skin,'hand.'+s)
        box((0.034,0.045,0.06),(side*0.184,-0.048,0.807),skin,'hand.'+s,bevel=0.009)
        box((0.166,0.205,0.40),(side*0.093,0,0.726),pants,'thigh.'+s,bevel=0.02)
        box((0.14,0.175,0.12),(side*0.096,0,0.49),pants,{'thigh.'+s:0.45,'shin.'+s:0.55})
        box((0.15,0.19,0.32),(side*0.10,0,0.267),boots,'shin.'+s,bevel=0.015)
        box((0.16,0.265,0.105),(side*0.10,-0.04,0.06),boots,'foot.'+s,bevel=0.022)
        box((0.164,0.27,0.02),(side*0.10,-0.04,0.014),'wood_dark','foot.'+s,bevel=0.004)
        box((0.156,0.196,0.025),(side*0.10,0,0.402),spec.get('boot_rings','cream_dark'),'shin.'+s,bevel=0.004)
        if 'tails' in spec.get('extras',[]):
            # Solid skirt panels follow each thigh, avoiding a cloth sheet between legs.
            for back in (-1,1):
                box((0.168,0.032,0.34),(side*0.105,back*0.124,0.827),spec.get('tails',outer),'thigh.'+s,(back*5,side*5,0),0.007)
                box((0.169,0.036,0.025),(side*0.12,back*0.139,0.666),trim,'thigh.'+s,bevel=0.004)
    extras = {'hat':hu.hat_conical,'bandana':hu.bandana,'mask':hu.mask_face,'beard':hu.beard,'pauldron':hu.pauldron,'scarf':hu.scarf,'sheath':hu.sheath,'bag':hu.bag,'apron':hu.apron,'armor':hu.guardian_armor,'skirt':hu.skirt}
    for extra in spec.get('extras',[]):
        if extra in extras:
            if extra == 'mask':
                box((0.27,0.035,0.22),(0,-0.145,1.575),spec.get('mask','mask'),'head',bevel=0.025)
                for side in (-1,1):
                    box((0.055,0.012,0.019),(side*0.063,-0.169,1.609),spec.get('eye_glow','ink'),'head',(0,side*12,0),0.004)
                box((0.022,0.009,0.048),(0,-0.169,1.558),'spirit' if spec.get('role')=='guardian' else 'vermilion','head',(0,30,0),0.003)
            elif extra == 'armor':
                for row in range(3):
                    for col in range(5):
                        box((0.061,0.035,0.08),((col-2)*0.064,-0.134,1.32-row*0.09),'bamboo_dark','chest',bevel=0.004)
                    box((0.33,0.04,0.009),(0,-0.14,1.277-row*0.09),'gold','chest',bevel=0.002)
                for side in (-1,1):
                    bone='upper_arm.'+('L' if side>0 else 'R')
                    for row in range(3):
                        box((0.22,0.25,0.055),(side*(0.205+row*0.014),0,1.40-row*0.055),'bamboo_dark',bone,(0,side*12,0),0.01)
                        box((0.225,0.255,0.012),(side*(0.205+row*0.014),0,1.375-row*0.055),'gold',bone,(0,side*12,0),0.004)
                b.cone(0.34,0.18,(0,0,1.80),mat='bamboo_dark',bone='head',segments=12,smooth=False)
                b.torus(0.336,0.007,(0,0,1.712),mat='gold',bone='head',segments=12,ring=4)
            else:
                extras[extra](b,dict(spec,long_scarf=False))
    return b
