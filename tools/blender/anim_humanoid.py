"""Keyframed humanoid animation sets. Times in seconds; strike keys follow data/anim_timings.json."""
import json
import math

import vk_lib as vk

TIMINGS = json.loads((vk.DATA / "anim_timings.json").read_text(encoding="utf-8"))


def t(owner, name, key):
    return TIMINGS[owner][name][key]


def merge(base, **changes):
    pose = dict(base)
    pose.update(changes)
    return pose


def sway(phase, amount):
    return math.sin(phase * math.tau) * amount


# ---------------------------------------------------------------- shared

def idle(breath=0.0, hunch=0.0):
    return {
        "legs": (-6, 8, 5), "drop": 0.03 + breath * 0.008,
        "spine": (2 + breath + hunch, 0, 0), "chest": (1 + breath * 1.5 + hunch * 0.5, 8, 0), "head": (-2 - hunch * 0.6, -8, 0),
        "armL": ((0.22, 0.05, -1), (0.12, -0.35, -1)),
        "armR": ((-0.32, -0.12, -1), (-0.15, -0.75, -0.65), (-0.3, -0.75, -0.55)),
        "ponytail": (breath * 3, 0, 0), "scarf": (breath * 4, 0, 2),
    }


def walk_keys(arm_r, swing=1.0, hunch=0.0, length=0.93):
    keys = []
    for i, phase in enumerate((0.0, 0.25, 0.5, 0.75)):
        mirror = 1 if i < 2 else -1
        contact = i % 2 == 0
        if contact:
            legs = {"thigh.L": (-24 * mirror, 0, -3), "shin.L": (6 if mirror > 0 else 14, 0, 0), "foot.L": (-12 if mirror > 0 else 6, 0, 0),
                    "thigh.R": (24 * mirror, 0, 3), "shin.R": (14 if mirror > 0 else 6, 0, 0), "foot.R": (6 if mirror > 0 else -12, 0, 0)}
            height = -0.025
        else:
            front = "R" if mirror > 0 else "L"
            back = "L" if mirror > 0 else "R"
            legs = {"thigh." + front: (-8, 0, 3 if front == "R" else -3), "shin." + front: (42, 0, 0), "foot." + front: (4, 0, 0),
                    "thigh." + back: (4, 0, -3 if back == "L" else 3), "shin." + back: (5, 0, 0), "foot." + back: (-9, 0, 0)}
            height = 0.012
        pose = {"off": (0, 0, height), "hips": (0, -5 * mirror if contact else 0, 0), "spine": (4 + hunch, 0, 0),
                "chest": (0 + hunch * 0.5, 7 * mirror if contact else 0, 0), "head": (-3 - hunch * 0.6, -4 * mirror if contact else 0, 0),
                "ponytail": (6 if contact else 2, 0, 3 * mirror), "scarf": (8 if contact else 4, 0, 3 * mirror)}
        pose.update(legs)
        arm_swing = (0.3 * mirror if contact else 0.0) * swing
        pose["armL"] = ((0.2, arm_swing, -1), (0.12, arm_swing - 0.35 - (0.25 if arm_swing < 0 else 0), -1))
        if arm_r is None:
            pose["armR"] = ((-0.2, -arm_swing, -1), (-0.12, -arm_swing - 0.35 - (0.25 if -arm_swing < 0 else 0), -1))
        else:
            pose["armR"] = arm_r(arm_swing)
        keys.append((phase * length, pose))
    return keys


def run_keys(arm_r, length=0.53, lean=12):
    keys = []
    for i, phase in enumerate((0.0, 0.25, 0.5, 0.75)):
        mirror = 1 if i < 2 else -1
        contact = i % 2 == 0
        f, b = ("L", "R") if mirror > 0 else ("R", "L")
        sf = -1 if f == "L" else 1
        if contact:
            legs = {"thigh." + f: (-38, 0, 3 * sf), "shin." + f: (22, 0, 0), "foot." + f: (-6, 0, 0),
                    "thigh." + b: (28, 0, -3 * sf), "shin." + b: (58, 0, 0), "foot." + b: (24, 0, 0)}
            height = -0.035
        else:
            legs = {"thigh." + b: (-50, 0, -3 * sf), "shin." + b: (98, 0, 0), "foot." + b: (10, 0, 0),
                    "thigh." + f: (22, 0, 3 * sf), "shin." + f: (28, 0, 0), "foot." + f: (25, 0, 0)}
            height = 0.045
        pose = {"off": (0, 0, height), "hips": (0, -8 * mirror if contact else 0, 0), "spine": (lean, 0, 0),
                "chest": (4, 10 * mirror if contact else 0, 0), "head": (-lean + 2, -6 * mirror if contact else 0, 0),
                "ponytail": (28 if contact else 18, 0, 6 * mirror), "scarf": (35 if contact else 25, 0, 8 * mirror)}
        pose.update(legs)
        pump = 0.55 * mirror if contact else 0.0
        pose["armL"] = ((0.2, pump, -0.8), (0.12, pump - 0.9, 0.15 if pump < 0 else -0.6))
        pose["armR"] = arm_r(pump) if arm_r else ((-0.2, -pump, -0.8), (-0.12, -pump - 0.9, 0.15 if -pump < 0 else -0.6))
        keys.append((phase * length, pose))
    return keys


def jump_keys(rest):
    crouch = merge(rest, legs=(-32, -20, 6), drop=0.12, spine=(16, 0, 0), chest=(6, 4, 0), head=(-10, -4, 0))
    push = merge(rest, legs=(-6, 4, 4), drop=0.0, spine=(4, 0, 0), off=(0, 0, 0.04))
    tuck = merge(rest, **{"thigh.L": (-55, 0, -5), "shin.L": (75, 0, 0), "foot.L": (15, 0, 0), "thigh.R": (-15, 0, 5),
                          "shin.R": (45, 0, 0), "foot.R": (20, 0, 0), "spine": (6, 0, 0), "ponytail": (-20, 0, 0), "scarf": (-25, 0, 0)})
    tuck.pop("legs", None)
    return [(0.0, crouch), (0.13, push), (0.3, tuck)]


def fall_keys(rest, arm_r):
    keys = []
    for i, phase in enumerate((0.0, 0.5)):
        s = 1 if i == 0 else -1
        pose = merge(rest, **{"thigh.L": (-32 + 4 * s, 0, -5), "shin.L": (52, 0, 0), "foot.L": (18, 0, 0), "thigh.R": (-8 - 4 * s, 0, 5),
                              "shin.R": (34, 0, 0), "foot.R": (22, 0, 0), "spine": (4, 0, 0), "chest": (-2, 0, 0),
                              "ponytail": (-35 + 6 * s, 0, 4 * s), "scarf": (-40 + 8 * s, 0, 6 * s)})
        pose.pop("legs", None)
        pose["armL"] = ((0.8, 0.1, 0.25 + 0.05 * s), (0.85, -0.2, 0.4))
        pose["armR"] = arm_r(s)
        keys.append((phase * 0.66, pose))
    return keys


def land_keys(rest):
    deep = merge(rest, legs=(-48, -30, 8), drop=0.2, spine=(20, 0, 0), chest=(8, 6, 0), head=(-14, -4, 0), ponytail=(18, 0, 0), scarf=(20, 0, 0))
    return [(0.0, deep), (0.12, merge(deep, drop=0.16)), (0.33, rest)]


def hit_keys(rest, scale=1.0):
    recoil = merge(rest, spine=(-14 * scale, 0, 4), chest=(-10 * scale, 12, 0), head=(-16 * scale, -6, 6), off=(0, 0.07 * scale, 0),
                   legs=(-14, 14, 6), drop=0.05, ponytail=(-25, 0, 0), scarf=(-25, 0, 0))
    recoil["armL"] = ((0.6, 0.2, -0.75), (0.7, -0.2, -0.4))
    return [(0.0, rest), (0.06, recoil), (0.18, merge(recoil, spine=(-6, 0, 2), off=(0, 0.05 * scale, 0))), (0.35, rest)]


def death_keys(rest):
    hit = hit_keys(rest)[1][1]
    kneel = merge(rest, legs=(-75, 10, 8), drop=0.36, spine=(26, 0, 6), chest=(16, 10, 0), head=(18, 0, 10), ponytail=(10, 0, 0))
    kneel["armL"] = ((0.3, -0.2, -1), (0.2, -0.3, -1))
    down = {"hips": (0, 0, 84), "spine": (12, 0, 8), "chest": (6, 0, 0), "head": (10, 0, 10),
            "thigh.L": (-40, 0, -5), "shin.L": (60, 0, 0), "thigh.R": (-10, 0, 5), "shin.R": (25, 0, 0),
            "upper_arm.L": (-50, 0, -20), "forearm.L": (-30, 0, 0), "upper_arm.R": (-20, 0, 30), "forearm.R": (-20, 0, 0),
            "ponytail": (20, 0, 20), "scarf": (30, 0, 30)}
    down["off"] = (-0.5, 0.05, -0.8)
    return [(0.0, rest), (0.12, hit), (0.45, kneel), (0.8, merge(down, off=(-0.44, 0.05, -0.72), hips=(0, 0, 76))), (1.2, down)]


# ---------------------------------------------------------------- player (sword)

def sword_low(swing):
    return ((-0.3, -0.2 - swing * 0.5, -1), (-0.18, -0.7 - swing * 0.3, -0.65), (-0.32, -0.7, -0.6))


def sword_trail(swing):
    return ((-0.35, 0.35 + swing * 0.2, -0.85), (-0.25, 0.6, -0.75), (-0.2, 0.78, -0.45))


def player_animations():
    rest = idle()
    anims = {}
    anims["idle"] = ([(0.0, idle(0.0)), (1.0, idle(1.0))], 2.0, True)
    anims["walk"] = (walk_keys(sword_low), 0.93, True)
    anims["run"] = (run_keys(sword_trail), 0.53, True)
    anims["jump"] = (jump_keys(rest), 0.3, False)
    anims["fall"] = (fall_keys(rest, lambda s: ((-0.75, 0.2, 0.3), (-0.7, 0.55, 0.3), (-0.2, 0.9, 0.2))), 0.66, True)
    anims["land"] = (land_keys(rest), 0.33, False)

    dash = merge(rest, legs=(-48, 34, 6), drop=0.17, spine=(24, 0, 0), chest=(12, 0, 0), head=(-22, 0, 0), ponytail=(45, 0, 0), scarf=(55, 0, 0))
    dash["armL"] = ((0.35, 0.8, -0.45), (0.3, 0.9, -0.2))
    dash["armR"] = ((-0.3, 0.8, -0.5), (-0.2, 0.9, -0.3), (-0.1, 0.95, -0.25))
    anims["dodge"] = ([(0.0, rest), (0.08, dash), (0.3, merge(dash, drop=0.15)), (0.5, rest)], 0.5, False)

    # attack_1: horizontal cut right -> left
    hs, he = t("player", "attack_1", "hit_start"), t("player", "attack_1", "hit_end")
    wind = merge(rest, legs=(-26, 18, 6), drop=0.08, spine=(6, -12, 0), chest=(4, -32, 0), head=(-4, 30, 0))
    wind["armR"] = ((-0.9, 0.35, -0.2), (-0.7, 0.7, 0.0), (-0.3, 0.92, 0.15))
    wind["armL"] = ((0.45, -0.6, -0.6), (-0.2, -0.95, -0.25))
    mid = merge(wind, spine=(8, 0, 0), chest=(6, 0, 0), head=(-4, 0, 0))
    mid["armR"] = ((-0.75, -0.6, -0.15), (-0.45, -0.9, 0.0), (-0.12, -1, 0.04))
    follow = merge(wind, spine=(8, 14, 0), chest=(6, 38, 0), head=(-6, -30, 0), drop=0.1)
    follow["armR"] = ((0.1, -0.95, -0.22), (0.8, -0.55, -0.05), (0.95, 0.25, -0.05))
    follow["armL"] = ((0.6, 0.6, -0.5), (0.55, 0.75, -0.3))
    settle = merge(follow, chest=(4, 24, 0), head=(-4, -18, 0), drop=0.07)
    settle["armR"] = ((0.15, -0.6, -0.75), (0.5, -0.6, -0.5), (0.6, -0.3, -0.7))
    anims["attack_1"] = ([(0.0, rest), (hs - 0.06, wind), (hs, mid), (he, follow), (0.42, settle), (0.56, settle)], 0.56, False)

    # attack_2: rising backhand left -> right
    hs, he = t("player", "attack_2", "hit_start"), t("player", "attack_2", "hit_end")
    wind = merge(rest, legs=(-20, 16, 6), drop=0.1, spine=(10, 12, 0), chest=(6, 34, 0), head=(-6, -30, 0))
    wind["armR"] = ((0.3, -0.6, -0.7), (0.8, -0.2, -0.5), (0.72, 0.38, -0.55))
    wind["armL"] = ((0.5, 0.5, -0.6), (0.5, 0.7, -0.4))
    mid = merge(wind, spine=(6, 0, 0), chest=(2, 0, 0), head=(-2, 0, 0))
    mid["armR"] = ((-0.2, -0.95, -0.3), (-0.2, -0.95, 0.1), (-0.1, -0.9, 0.42))
    follow = merge(wind, legs=(16, -26, 6), spine=(0, -14, 0), chest=(-4, -36, 0), head=(2, 32, 0), drop=0.08)
    follow["armR"] = ((-0.85, -0.3, 0.3), (-0.8, 0.2, 0.55), (-0.5, 0.45, 0.75))
    follow["armL"] = ((0.4, -0.7, -0.5), (0.0, -0.95, -0.2))
    settle = merge(follow, chest=(0, -22, 0), head=(0, 18, 0))
    settle["armR"] = ((-0.6, -0.4, -0.65), (-0.5, -0.6, -0.4), (-0.4, -0.7, -0.5))
    anims["attack_2"] = ([(0.0, rest), (hs - 0.06, wind), (hs, mid), (he, follow), (0.42, settle), (0.56, settle)], 0.56, False)

    # attack_3: two-handed leaping overhead cleave
    hs, he = t("player", "attack_3", "hit_start"), t("player", "attack_3", "hit_end")
    raise_pose = merge(rest, legs=(-14, 10, 5), drop=0.02, spine=(-10, 0, 0), chest=(-8, 6, 0), head=(6, -6, 0), off=(0, 0, 0.03), ponytail=(-15, 0, 0))
    raise_pose["armR"] = ((-0.2, 0.15, 1.0), (-0.1, 0.6, 0.8), (0.0, 0.92, -0.3))
    raise_pose["armL"] = ((0.15, -0.15, 0.95), (-0.45, 0.25, 0.86))
    leap = merge(raise_pose, off=(0, -0.05, 0.12), **{"thigh.L": (-55, 0, -4), "shin.L": (75, 0, 0), "thigh.R": (18, 0, 4), "shin.R": (45, 0, 0)})
    leap.pop("legs")
    leap.pop("drop")
    strike = merge(rest, legs=(-40, 26, 6), drop=0.12, spine=(18, 0, 0), chest=(8, 4, 0), head=(-12, -4, 0), off=(0, -0.06, 0))
    strike["armR"] = ((-0.15, -0.8, 0.3), (-0.05, -1, -0.05), (0, -1, 0.1))
    strike["armL"] = ((0.15, -0.85, 0.25), (-0.4, -0.9, -0.05))
    impact = merge(strike, legs=(-58, 40, 7), drop=0.22, spine=(30, 0, 0), chest=(10, 4, 0), head=(-20, -4, 0), off=(0, -0.08, 0), ponytail=(35, 0, 0), scarf=(30, 0, 0))
    impact["armR"] = ((-0.1, -0.7, -0.7), (0.0, -0.5, -0.86), (0.0, -0.42, -0.9))
    impact["armL"] = ((0.15, -0.75, -0.6), (-0.35, -0.55, -0.75))
    anims["attack_3"] = ([(0.0, rest), (0.16, raise_pose), (hs - 0.07, leap), (hs, strike), (he, impact), (0.66, impact), (0.86, rest)], 0.86, False)

    # heavy: charged spinning slash
    hs, he = t("player", "heavy", "hit_start"), t("player", "heavy", "hit_end")
    charge = merge(rest, legs=(-34, 28, 8), drop=0.14, spine=(10, -16, 0), chest=(6, -45, 0), head=(-8, 40, 0))
    charge["armR"] = ((-0.8, 0.45, -0.45), (-0.5, 0.82, -0.3), (-0.2, 0.86, -0.5))
    charge["armL"] = ((0.4, -0.9, 0.0), (0.3, -0.95, 0.1))
    keys = [(0.0, rest), (0.18, charge), (0.36, merge(charge, drop=0.16, chest=(6, -50, 0)))]
    spin_start = hs - 0.06
    steps = 6
    for i in range(steps + 1):
        u = i / steps
        # Low, forward-leaning spin: sword arm sweeps out front-right, off hand tucked to the chest.
        pose = merge(rest, legs=(-32, 24, 10), drop=0.13, spine=(14, 0, 0), chest=(6, -12, 0), head=(-10, 12, 0), hips=(0, -30 + 360 * u, 0),
                     off=(0, 0, 0.04 * math.sin(u * math.pi)), ponytail=(40, 0, 30), scarf=(45, 0, 35))
        pose["armR"] = ((-0.82, -0.42, -0.25), (-0.72, -0.68, -0.08), (-0.45, -0.88, 0.05))
        pose["armL"] = ((0.3, -0.45, -0.84), (-0.45, -0.82, 0.25))
        keys.append((spin_start + (he - spin_start) * u, pose))
    finish = merge(rest, legs=(-36, 24, 8), drop=0.15, spine=(16, 6, 0), chest=(8, 20, 0), head=(-10, -16, 0))
    finish["armR"] = ((-0.9, -0.3, -0.25), (-0.85, -0.45, -0.1), (-0.5, -0.85, -0.15))
    keys += [(0.86, finish), (1.1, rest)]
    anims["heavy"] = (keys, 1.1, False)

    # skill_gust (Phong Trảm): rising diagonal releasing a wind blade
    hs, he = t("player", "skill_gust", "hit_start"), t("player", "skill_gust", "hit_end")
    low = merge(rest, legs=(-30, 22, 7), drop=0.12, spine=(12, 10, 0), chest=(6, 32, 0), head=(-8, -28, 0))
    low["armR"] = ((0.2, -0.5, -0.85), (0.6, -0.4, -0.7), (0.62, 0.2, -0.76))
    low["armL"] = ((0.6, 0.6, -0.5), (0.5, 0.75, -0.4))
    mid = merge(low, spine=(6, 0, 0), chest=(2, 0, 0), head=(-2, 0, 0), drop=0.06)
    mid["armR"] = ((-0.3, -0.9, -0.2), (-0.2, -0.95, 0.2), (-0.1, -0.9, 0.42))
    high = merge(low, legs=(-22, 18, 6), drop=0.02, spine=(-6, -10, 0), chest=(-6, -30, 0), head=(4, 26, 0), ponytail=(-20, 0, 10), scarf=(-25, 0, 15))
    high["armR"] = ((-0.6, -0.3, 0.75), (-0.5, 0.0, 0.86), (-0.45, 0.3, 0.84))
    high["armL"] = ((0.2, -0.95, 0.1), (0.1, -1, 0.1))
    anims["skill_gust"] = ([(0.0, rest), (hs - 0.1, low), (hs, mid), (he, high), (0.6, high), (0.8, rest)], 0.8, False)

    # skill_cyclone (Toàn Phong): leap with two airborne spins
    hs, he = t("player", "skill_cyclone", "hit_start"), t("player", "skill_cyclone", "hit_end")
    crouch = merge(rest, legs=(-40, -26, 10), drop=0.18, spine=(18, 0, 0), chest=(10, -20, 0), head=(-14, 16, 0))
    crouch["armR"] = ((-0.3, -0.3, -0.9), (0.4, -0.6, -0.7), (0.7, 0.1, -0.7))
    crouch["armL"] = ((0.3, -0.3, -0.9), (-0.3, -0.6, -0.7))
    keys = [(0.0, rest), (0.22, crouch)]
    steps = 12
    for i in range(steps + 1):
        u = i / steps
        lift = math.sin(min(1.0, u * 1.3) * math.pi * 0.5) * (1.0 - max(0.0, u - 0.75) * 4.0)
        pose = {"hips": (0, 720 * u, 0), "off": (0, 0, 0.3 * lift), "spine": (4, 0, 0), "head": (-4, 0, 0),
                "thigh.L": (-40, 0, -8), "shin.L": (70, 0, 0), "thigh.R": (-10, 0, 8), "shin.R": (40, 0, 0), "foot.L": (20, 0, 0), "foot.R": (20, 0, 0),
                "ponytail": (40, 0, 35), "scarf": (45, 0, 40)}
        pose["armR"] = ((-1, 0, 0.05), (-1, -0.12, 0.08), (-0.3, -0.95, 0.05))
        pose["armL"] = ((0.95, 0.1, 0.1), (0.95, 0.15, 0.2))
        keys.append((hs + (he - hs) * u, pose))
    land = merge(rest, legs=(-46, 30, 10), drop=0.2, spine=(20, 0, 0), chest=(8, 10, 0), head=(-14, -8, 0))
    land["armR"] = ((-0.8, -0.4, -0.4), (-0.7, -0.6, -0.2), (-0.4, -0.9, -0.1))
    keys += [(1.08, land), (1.3, rest)]
    anims["skill_cyclone"] = (keys, 1.3, False)

    # dash_slash (elemental dashing forms): low lunge, sword drawn back, then a long cut across the path
    hs, he = t("player", "dash_slash", "hit_start"), t("player", "dash_slash", "hit_end")
    lunge = merge(rest, legs=(-52, 36, 6), drop=0.2, spine=(28, 14, 0), chest=(10, 30, 0), head=(-26, -24, 0), ponytail=(55, 0, 10), scarf=(65, 0, 15))
    lunge["armR"] = ((0.55, 0.5, -0.65), (0.85, 0.35, -0.4), (0.9, -0.2, -0.35))
    lunge["armL"] = ((0.4, -0.7, -0.55), (0.1, -0.95, -0.25))
    cut = merge(lunge, spine=(26, -16, 0), chest=(8, -36, 0), head=(-24, 26, 0), drop=0.18)
    cut["armR"] = ((-0.9, -0.35, -0.2), (-0.7, -0.7, -0.05), (-0.35, -0.94, 0.05))
    cut["armL"] = ((0.75, 0.4, -0.5), (0.6, 0.7, -0.3))
    recover = merge(cut, legs=(-30, 22, 6), drop=0.1, spine=(12, -8, 0), chest=(4, -18, 0), head=(-8, 12, 0))
    anims["dash_slash"] = ([(0.0, rest), (hs - 0.04, lunge), (hs + (he - hs) * 0.35, merge(lunge, drop=0.21)), (he, cut), (0.5, recover), (0.62, rest)], 0.62, False)

    # ultimate: gather, leap with the blade overhead, crash down into the ground
    hs, he = t("player", "ultimate", "hit_start"), t("player", "ultimate", "hit_end")
    gather = merge(rest, legs=(-48, 34, 10), drop=0.22, spine=(22, 0, 0), chest=(10, -24, 0), head=(-18, 20, 0))
    gather["armR"] = ((-0.6, 0.6, -0.5), (-0.3, 0.9, -0.3), (0.1, 0.9, -0.45))
    gather["armL"] = ((0.5, -0.6, -0.6), (0.2, -0.9, -0.4))
    rise = merge(rest, spine=(-14, 0, 0), chest=(-10, 0, 0), head=(10, 0, 0), off=(0, 0, 0.55), ponytail=(-35, 0, 0), scarf=(-40, 0, 0),
                 **{"thigh.L": (-70, 0, -6), "shin.L": (95, 0, 0), "thigh.R": (-20, 0, 6), "shin.R": (60, 0, 0)})
    rise["armR"] = ((-0.15, 0.1, 1.0), (-0.05, 0.4, 0.9), (0.0, 0.85, 0.5))
    rise["armL"] = ((0.15, -0.1, 1.0), (-0.35, 0.3, 0.88))
    apex = merge(rise, off=(0, 0, 0.8), spine=(-20, 0, 0))
    slam = merge(rest, legs=(-62, 44, 9), drop=0.26, spine=(34, 0, 0), chest=(12, 2, 0), head=(-24, 0, 0), off=(0, -0.05, 0), ponytail=(45, 0, 0), scarf=(40, 0, 0))
    slam["armR"] = ((-0.1, -0.75, -0.65), (0.0, -0.55, -0.84), (0.0, -0.45, -0.89))
    slam["armL"] = ((0.15, -0.75, -0.6), (-0.3, -0.6, -0.74))
    anims["ultimate"] = ([(0.0, rest), (0.3, gather), (0.55, rise), (hs - 0.18, apex), (hs, slam), (he, merge(slam, drop=0.28)), (1.55, slam), (1.9, rest)], 1.9, False)

    guard = merge(rest, legs=(-16, 18, 7), drop=0.08, spine=(6, 0, 0), chest=(2, 12, 0), head=(-4, -10, 0))
    guard["armR"] = ((-0.4, -0.65, -0.45), (0.35, -0.9, 0.3), (0.95, -0.15, 0.3))
    guard["armL"] = ((0.3, -0.6, -0.55), (0.0, -0.9, 0.42))
    recoil = merge(guard, off=(0, 0.04, 0), spine=(2, 0, 0))
    anims["parry"] = ([(0.0, rest), (0.06, guard), (0.2, guard), (0.3, recoil), (0.45, rest)], 0.45, False)
    anims["block"] = ([(0.0, guard), (0.5, merge(guard, drop=0.09))], 1.0, True)
    anims["hit"] = (hit_keys(rest), 0.35, False)
    anims["death"] = (death_keys(rest), 1.2, False)

    keys = []
    for i, phase in enumerate((0.0, 0.5)):
        s = 1 if i == 0 else -1
        pose = {"hips": (32, 0, 0), "spine": (6, 0, 0), "chest": (-4, 0, 0), "head": (-30, 0, 0),
                "thigh.L": (12, 0, -3), "shin.L": (26, 0, 0), "foot.L": (25, 0, 0), "thigh.R": (24 + 3 * s, 0, 3), "shin.R": (12, 0, 0), "foot.R": (30, 0, 0),
                "ponytail": (55 + 10 * s, 0, 10 * s), "scarf": (65 + 12 * s, 0, 14 * s), "off": (0, 0, 0.02 * s)}
        pose["armL"] = ((0.85, 0.45, 0.15 + 0.05 * s), (0.8, 0.6, 0.05))
        pose["armR"] = ((-0.85, 0.45, 0.15 - 0.05 * s), (-0.8, 0.6, 0.05), (-0.2, 0.96, -0.1))
        keys.append((phase * 0.8, pose))
    anims["glide"] = (keys, 0.8, True)

    keys = []
    for i in range(7):
        u = i / 6
        pose = {"hips": (360 * u, 0, 0), "off": (0, 0, 0.18 * math.sin(u * math.pi)), "spine": (20, 0, 0), "head": (-10, 0, 0),
                "thigh.L": (-80, 0, -5), "shin.L": (110, 0, 0), "thigh.R": (-70, 0, 5), "shin.R": (100, 0, 0), "ponytail": (20, 0, 0), "scarf": (30, 0, 0)}
        pose.update({"upper_arm.L": (-40, 0, -12), "forearm.L": (-70, 0, 0), "upper_arm.R": (-40, 0, 12), "forearm.R": (-70, 0, 0)})
        keys.append((0.5 * u, pose))
    anims["air_leap"] = (keys, 0.5, False)

    reach = merge(rest, legs=(-12, 10, 6), drop=0.05, spine=(14, 0, 0), chest=(4, -8, 0), head=(-6, 6, 0))
    reach["armL"] = ((0.15, -0.85, -0.45), (0.05, -1, -0.1))
    anims["interact"] = ([(0.0, rest), (0.2, reach), (0.38, reach), (0.6, rest)], 0.6, False)
    return anims


# ---------------------------------------------------------------- villagers

def npc_idle(breath, hunch=0.0, hands="sides"):
    pose = idle(breath, hunch)
    pose["armR"] = ((-0.2, 0.0, -1), (-0.12, -0.3, -1))
    if hands == "clasped":
        pose["armL"] = ((0.15, -0.35, -1), (-0.6, -0.75, -0.2))
        pose["armR"] = ((-0.15, -0.35, -1), (0.6, -0.75, -0.2))
    elif hands == "cane":
        pose["armR"] = ((-0.2, -0.45, -1), (-0.05, -0.7, -0.75))
    return pose


def npc_animations(hunch=0.0, hands="sides", work=False):
    rest = npc_idle(0.0, hunch, hands)
    anims = {}
    anims["idle"] = ([(0.0, rest), (1.2, npc_idle(1.0, hunch, hands))], 2.4, True)
    arm_r = (lambda s: ((-0.2, -0.45, -1), (-0.05, -0.7, -0.75))) if hands == "cane" else None
    anims["walk"] = (walk_keys(arm_r, swing=0.8 if hunch else 1.0, hunch=hunch, length=1.0 if hunch else 0.93), 1.0 if hunch else 0.93, True)
    talk_a = merge(rest, chest=(2 + hunch * 0.5, 4, 0), head=(-4 - hunch * 0.6, -4, 3))
    talk_a["armL"] = ((0.35, -0.6, -0.7), (0.3, -0.95, 0.0))
    talk_b = merge(rest, chest=(3 + hunch * 0.5, -6, 0), head=(2 - hunch * 0.6, 6, -3))
    if hands != "cane":
        talk_b["armR"] = ((-0.35, -0.55, -0.75), (-0.4, -0.9, 0.1))
    anims["talk"] = ([(0.0, rest), (0.6, talk_a), (1.4, talk_b), (2.2, merge(talk_a, head=(0, 0, 0)))], 2.8, True)
    wave = merge(rest, head=(-6, 0, 4))
    wave["armL"] = ((0.75, -0.2, 0.62), (0.4, -0.2, 0.9))
    wave2 = merge(wave)
    wave2["armL"] = ((0.75, -0.2, 0.62), (0.8, -0.2, 0.55))
    anims["wave"] = ([(0.0, rest), (0.3, wave), (0.55, wave2), (0.8, wave), (1.05, wave2), (1.4, rest)], 1.4, False)
    if work:
        up = merge(rest, legs=(-14, 12, 8), drop=0.08, spine=(14, 0, 0), chest=(4, 10, 0))
        up["armR"] = ((-0.35, -0.3, 0.85), (-0.2, 0.3, 0.9))
        up["armL"] = ((0.2, -0.7, -0.6), (-0.2, -0.95, -0.1))
        down = merge(up, spine=(24, 0, 0))
        down["armR"] = ((-0.2, -0.8, -0.5), (-0.1, -0.7, -0.75))
        anims["work"] = ([(0.0, up), (0.35, down), (0.5, down), (1.0, up)], 1.0, True)
    return anims


# ---------------------------------------------------------------- bandit (sabre)

def bandit_guard(breath=0.0):
    pose = merge(idle(breath), legs=(-18, 16, 8), drop=0.07 + breath * 0.008, spine=(8, 0, 0), chest=(2 + breath, 18, 0), head=(-8, -16, 0))
    pose["armR"] = ((-0.35, -0.6, -0.65), (-0.1, -0.9, 0.25), (-0.1, -0.6, 0.8))
    pose["armL"] = ((0.35, -0.5, -0.7), (0.1, -0.9, -0.1))
    return pose


def bandit_animations():
    rest = bandit_guard()
    anims = {}
    anims["idle"] = ([(0.0, rest), (1.0, bandit_guard(1.0))], 2.0, True)
    anims["walk"] = (walk_keys(lambda s: ((-0.3, -0.4 - s * 0.3, -0.85), (-0.1, -0.9, 0.2), (-0.1, -0.6, 0.8))), 0.93, True)
    anims["run"] = (run_keys(lambda s: ((-0.35, 0.3 + s * 0.2, -0.85), (-0.25, 0.6, -0.75), (-0.2, 0.75, -0.5)), lean=16), 0.53, True)
    hs, he = t("bandit", "attack", "hit_start"), t("bandit", "attack", "hit_end")
    raise_pose = merge(rest, legs=(-10, 20, 8), drop=0.04, spine=(-8, -8, 0), chest=(-8, -20, 0), head=(6, 16, 0))
    raise_pose["armR"] = ((-0.35, 0.2, 0.9), (-0.2, 0.7, 0.68), (0.0, 0.85, -0.5))
    raise_pose["armL"] = ((0.5, -0.6, -0.3), (0.2, -0.95, 0.0))
    hold = merge(raise_pose, spine=(-10, -10, 0), off=(0, 0.03, 0))
    chop = merge(rest, legs=(-44, 30, 8), drop=0.17, spine=(26, 6, 0), chest=(10, 10, 0), head=(-18, -8, 0), off=(0, -0.08, 0))
    chop["armR"] = ((-0.25, -0.8, -0.5), (-0.1, -0.6, -0.8), (0.0, -0.55, -0.83))
    chop["armL"] = ((0.6, 0.5, -0.5), (0.5, 0.7, -0.3))
    anims["attack"] = ([(0.0, rest), (0.4, raise_pose), (hs - 0.04, hold), (hs + 0.05, merge(chop, drop=0.1)), (he, chop), (1.0, chop), (1.3, rest)], 1.3, False)
    anims["hit"] = (hit_keys(rest), 0.35, False)
    daze = merge(rest, legs=(-6, 6, 10), drop=0.12, spine=(24, 0, 10), chest=(10, 0, 0), head=(20, 0, 14))
    daze["armR"] = ((-0.3, 0.0, -1), (-0.2, -0.3, -1), (-0.3, -0.3, -0.9))
    daze["armL"] = ((0.3, 0.1, -1), (0.2, -0.2, -1))
    daze2 = merge(daze, spine=(22, 0, -8), head=(16, 0, -12), chest=(8, 6, 0))
    anims["stagger"] = ([(0.0, rest), (0.15, merge(hit_keys(rest)[1][1])), (0.4, daze), (0.8, daze2), (1.2, daze), (1.5, rest)], 1.5, False)
    anims["death"] = (death_keys(rest), 1.2, False)
    shout = merge(rest, spine=(-6, 0, 0), chest=(-8, 0, 0), head=(10, 0, 0))
    shout["armL"] = ((0.4, -0.85, 0.2), (0.2, -1, 0.15))
    anims["alert"] = ([(0.0, rest), (0.25, shout), (0.6, shout), (0.8, rest)], 0.8, False)
    return anims


# ---------------------------------------------------------------- guardian (glaive)

def guardian_guard(breath=0.0):
    pose = merge(idle(breath), legs=(-16, 18, 12), drop=0.1 + breath * 0.01, spine=(6 + breath, 0, 0), chest=(2, 20, 0), head=(-6, -18, 0))
    pose["armR"] = ((-0.4, -0.3, -0.85), (-0.2, -0.95, 0.15), (0.15, -0.35, 0.92))
    pose["armL"] = ((0.3, -0.6, -0.7), (-0.35, -0.85, 0.3))
    return pose


def guardian_animations():
    rest = guardian_guard()
    anims = {}
    anims["idle"] = ([(0.0, rest), (1.3, guardian_guard(1.0))], 2.6, True)
    anims["walk"] = (walk_keys(lambda s: ((-0.4, -0.3, -0.85), (-0.2, -0.95, 0.15), (0.15, -0.35, 0.92)), swing=0.5, length=1.2), 1.2, True)
    hs, he = t("guardian", "attack", "hit_start"), t("guardian", "attack", "hit_end")
    lift = merge(rest, legs=(-8, 20, 10), drop=0.04, spine=(-12, 0, 0), chest=(-10, 6, 0), head=(8, -6, 0))
    lift["armR"] = ((-0.25, 0.1, 0.95), (-0.15, 0.55, 0.82), (0.0, 0.8, -0.6))
    lift["armL"] = ((0.15, 0.0, 0.98), (-0.3, 0.4, 0.86))
    slam = merge(rest, legs=(-46, 32, 10), drop=0.2, spine=(30, 0, 0), chest=(10, 4, 0), head=(-20, -4, 0), off=(0, -0.1, 0))
    slam["armR"] = ((-0.2, -0.85, -0.45), (-0.05, -0.75, -0.66), (0.0, -0.5, -0.86))
    slam["armL"] = ((0.2, -0.85, -0.45), (-0.3, -0.75, -0.6))
    anims["attack"] = ([(0.0, rest), (0.55, lift), (hs - 0.06, merge(lift, spine=(-14, 0, 0))), (hs + 0.06, merge(slam, drop=0.12)), (he, slam), (1.35, slam), (1.6, rest)], 1.6, False)

    hs, he = t("guardian", "sweep", "hit_start"), t("guardian", "sweep", "hit_end")
    coil = merge(rest, legs=(-30, 26, 12), drop=0.16, spine=(10, -20, 0), chest=(6, -50, 0), head=(-6, 40, 0))
    coil["armR"] = ((-0.85, 0.4, -0.3), (-0.6, 0.8, -0.1), (-0.2, 0.95, 0.1))
    coil["armL"] = ((-0.1, 0.4, -0.9), (-0.5, 0.75, -0.4))
    keys = [(0.0, rest), (0.7, coil), (hs - 0.1, merge(coil, chest=(6, -56, 0)))]
    for i in range(6):
        u = i / 5
        pose = merge(rest, legs=(-24, 20, 12), drop=0.12, spine=(8, 0, 0), chest=(2, 0, 0), head=(-4, 0, 0), hips=(0, -40 + 300 * u, 0))
        pose["armR"] = ((-1, -0.05, 0.0), (-1, -0.15, 0.05), (-0.25, -0.97, 0.05))
        pose["armL"] = ((-0.2, -0.9, -0.2), (-0.8, -0.6, 0.0))
        keys.append((hs + (he - hs) * u, pose))
    keys += [(1.75, merge(rest, drop=0.14, chest=(4, 30, 0), hips=(0, 260, 0))), (2.0, merge(rest, hips=(0, 360, 0)))]
    anims["sweep"] = (keys, 2.0, False)

    hs, he = t("guardian", "slam", "hit_start"), t("guardian", "slam", "hit_end")
    squat = merge(rest, legs=(-46, -36, 14), drop=0.26, spine=(24, 0, 0), chest=(10, 0, 0), head=(-16, 0, 0))
    squat["armR"] = ((-0.4, -0.2, -0.9), (0.2, -0.8, -0.55), (0.3, -0.2, 0.93))
    squat["armL"] = ((0.4, -0.2, -0.9), (-0.2, -0.8, -0.55))
    air = merge(lift, off=(0, -0.2, 0.9), **{"thigh.L": (-60, 0, -8), "shin.L": (80, 0, 0), "thigh.R": (-30, 0, 8), "shin.R": (60, 0, 0)})
    air.pop("legs")
    air.pop("drop")
    land = merge(slam, legs=(-56, 40, 14), drop=0.32, off=(0, -0.3, 0))
    anims["slam"] = ([(0.0, rest), (0.6, squat), (0.95, air), (hs - 0.05, merge(air, off=(0, -0.3, 0.5))), (hs + 0.02, land), (he, land), (1.9, land), (2.2, rest)], 2.2, False)
    anims["hit"] = (hit_keys(rest, 0.6), 0.35, False)
    daze = merge(rest, legs=(-30, 20, 14), drop=0.3, spine=(34, 0, 10), chest=(14, 0, 0), head=(24, 0, 14))
    daze["armR"] = ((-0.35, -0.2, -1), (-0.2, -0.6, -0.8), (0.2, -0.6, -0.7))
    daze["armL"] = ((0.4, -0.3, -0.9), (0.3, -0.4, -0.85))
    anims["stagger"] = ([(0.0, rest), (0.2, merge(hit_keys(rest, 0.6)[1][1])), (0.5, daze), (1.4, merge(daze, spine=(30, 0, -8))), (2.0, daze), (2.4, rest)], 2.4, False)
    anims["death"] = (death_keys(rest), 1.2, False)
    roar = merge(rest, legs=(-24, 22, 14), drop=0.12, spine=(-16, 0, 0), chest=(-14, 0, 0), head=(-12, 0, 0))
    roar["armR"] = ((-0.8, 0.1, 0.55), (-0.6, 0.0, 0.8), (-0.1, 0.0, 1.0))
    roar["armL"] = ((0.85, 0.1, 0.5), (0.7, -0.1, 0.7))
    anims["roar"] = ([(0.0, rest), (0.4, merge(rest, spine=(20, 0, 0), drop=0.18)), (0.7, roar), (1.2, merge(roar, chest=(-16, 6, 0))), (1.6, rest)], 1.6, False)
    return anims
