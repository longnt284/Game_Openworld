"""Keyframed animation sets for the chapter-one monsters that share the 20-bone humanoid rig:
archer (bow in the left hand), shield guard (tower shield on the left forearm, spear in the right
hand), bandit mage (staff), memory wraith (floating, no feet on the ground) and stone golem.
Times in seconds; strike keys follow data/anim_timings.json like the player and bandit sets.

Arm poses are (upper arm, forearm[, held weapon]) directions in the hips' yaw frame:
+X is the character's left, -Y forward, +Z up (see humanoid.Poser)."""
from anim_humanoid import death_keys, hit_keys, idle, merge, run_keys, t, walk_keys


def _daze(rest, lean=24.0):
    daze = merge(rest, legs=(-6, 6, 10), drop=0.12, spine=(lean, 0, 10), chest=(10, 0, 0), head=(20, 0, 14))
    daze["armL"] = ((0.3, 0.1, -1), (0.2, -0.2, -1))
    daze["armR"] = ((-0.3, 0.0, -1), (-0.2, -0.3, -1))
    return daze


def _stagger(rest, length=1.5):
    daze = _daze(rest)
    return ([(0.0, rest), (0.15, merge(hit_keys(rest)[1][1])), (0.4, daze), (0.8, merge(daze, spine=(22, 0, -8), head=(16, 0, -12))),
             (1.2, daze), (length, rest)], length, False)


def _alert(rest):
    shout = merge(rest, spine=(-6, 0, 0), chest=(-8, 0, 0), head=(10, 0, 0))
    return ([(0.0, rest), (0.25, shout), (0.6, shout), (0.8, rest)], 0.8, False)


# ---------------------------------------------------------------- archer (bow in the left hand)

def archer_guard(breath=0.0):
    pose = merge(idle(breath), legs=(-12, 14, 8), drop=0.05 + breath * 0.008, spine=(6, 0, 0), chest=(2 + breath, -12, 0), head=(-6, 10, 0))
    pose["armL"] = ((0.3, -0.4, -0.85), (0.12, -0.9, -0.42))
    pose["armR"] = ((-0.25, 0.1, -1), (-0.12, -0.25, -1))
    return pose


def archer_animations():
    rest = archer_guard()
    anims = {"idle": ([(0.0, rest), (1.1, archer_guard(1.0))], 2.2, True)}
    bow_low = lambda s: ((0.3, -0.4 - s * 0.2, -0.85), (0.12, -0.9, -0.42))  # noqa: E731
    walk = walk_keys(None, swing=0.6)
    for _, pose in walk:
        pose["armL"] = bow_low(0.0)
    anims["walk"] = (walk, 0.93, True)
    run = run_keys(None, lean=14)
    for _, pose in run:
        pose["armL"] = ((0.35, -0.3, -0.85), (0.2, -0.95, -0.2))
    anims["run"] = (run, 0.53, True)
    # Shoot: nock, raise the bow arm straight at the target, draw the string to the cheek, loose.
    release = t("archer", "shoot", "hit_start")
    nock = merge(rest, legs=(-16, 20, 10), drop=0.07, spine=(2, 0, 0), chest=(0, -30, 0), head=(-2, 26, 0))
    nock["armL"] = ((0.35, -0.85, -0.3), (0.15, -1.0, -0.1))
    nock["armR"] = ((-0.2, -0.85, -0.3), (0.5, -0.8, 0.05))
    draw = merge(nock, chest=(-2, -42, 0), head=(-4, 36, 0))
    draw["armL"] = ((0.2, -1.0, 0.12), (0.08, -1.0, 0.1))
    draw["armR"] = ((-0.75, 0.55, 0.18), (0.88, -0.45, 0.06))
    loose = merge(draw, chest=(-6, -38, 0))
    loose["armR"] = ((-0.8, 0.5, 0.25), (-0.55, 0.65, 0.4))
    anims["shoot"] = ([(0.0, rest), (0.3, nock), (release - 0.12, draw), (release - 0.02, merge(draw, chest=(-3, -44, 0))), (release + 0.04, loose),
                       (t("archer", "shoot", "recover") - 0.05, loose), (t("archer", "shoot", "length"), rest)], t("archer", "shoot", "length"), False)
    # Bash: a backhand sweep of the bow when a foe gets too close.
    hs, he = t("archer", "bash", "hit_start"), t("archer", "bash", "hit_end")
    wind = merge(rest, legs=(-10, 16, 8), spine=(4, 0, 0), chest=(0, 35, 0), head=(0, -20, 0))
    wind["armL"] = ((0.75, 0.45, -0.3), (0.6, 0.75, 0.0))
    sweep = merge(rest, legs=(-28, 22, 8), drop=0.1, spine=(14, 0, 0), chest=(4, -35, 0), head=(-8, 22, 0))
    sweep["armL"] = ((-0.3, -0.95, 0.0), (-0.75, -0.65, 0.05))
    anims["bash"] = ([(0.0, rest), (hs - 0.12, wind), (hs + 0.04, merge(sweep, chest=(4, -15, 0))), (he, sweep), (0.95, rest)], t("archer", "bash", "length"), False)
    # Hop: a crouch and a spring backwards; the body itself is moved by the game.
    crouch = merge(rest, legs=(-30, -18, 8), drop=0.14, spine=(16, 0, 0))
    air = merge(rest, **{"thigh.L": (-40, 0, -6), "shin.L": (70, 0, 0), "thigh.R": (-20, 0, 6), "shin.R": (55, 0, 0), "spine": (-6, 0, 0), "off": (0, 0, 0.12)})
    air.pop("legs")
    air.pop("drop")
    anims["hop"] = ([(0.0, rest), (0.08, crouch), (0.22, air), (0.42, crouch), (0.55, rest)], 0.55, False)
    anims["hit"] = (hit_keys(rest), 0.35, False)
    anims["stagger"] = _stagger(rest)
    anims["death"] = (death_keys(rest), 1.2, False)
    anims["alert"] = _alert(rest)
    return anims


# ---------------------------------------------------------------- shield guard (tower shield + spear)

def shield_guard(breath=0.0):
    pose = merge(idle(breath), legs=(-18, 18, 10), drop=0.09 + breath * 0.008, spine=(8, 0, 0), chest=(3 + breath, 12, 0), head=(-6, -12, 0))
    # Forearm across the chest so the shield faces forward; spear upright in the right hand.
    pose["armL"] = ((0.3, -0.6, -0.75), (-1.0, -0.15, 0.1))
    pose["armR"] = ((-0.4, -0.3, -0.85), (-0.2, -0.95, 0.15), (0.1, -0.4, 0.91))
    return pose


def shield_animations():
    rest = shield_guard()
    anims = {"idle": ([(0.0, rest), (1.2, shield_guard(1.0))], 2.4, True)}
    walk = walk_keys(lambda s: ((-0.4, -0.3, -0.85), (-0.2, -0.95, 0.15), (0.1, -0.4, 0.91)), swing=0.35, length=1.05)
    for _, pose in walk:
        pose["armL"] = rest["armL"]
    anims["walk"] = (walk, 1.05, True)
    run = run_keys(lambda s: ((-0.4, -0.2, -0.85), (-0.2, -0.95, 0.2), (0.15, -0.5, 0.85)), length=0.62, lean=10)
    for _, pose in run:
        pose["armL"] = rest["armL"]
    anims["run"] = (run, 0.62, True)
    brace = merge(rest, legs=(-30, 26, 14), drop=0.16, spine=(14, 0, 0), chest=(4, 6, 0))
    brace["armL"] = ((0.25, -0.75, -0.6), (-1.0, -0.25, 0.15))
    anims["block"] = ([(0.0, brace), (0.6, merge(brace, drop=0.17))], 1.2, True)
    # Shield bash: draw the shield back, then drive it forward with the whole body.
    hs, he = t("shield", "bash", "hit_start"), t("shield", "bash", "hit_end")
    coil = merge(rest, legs=(-16, 24, 10), drop=0.12, spine=(4, 0, 0), chest=(0, 30, 0))
    coil["armL"] = ((0.55, 0.1, -0.8), (-0.6, -0.5, 0.4))
    drive = merge(rest, legs=(-46, 30, 10), drop=0.18, spine=(20, 0, 0), chest=(6, -10, 0), off=(0, -0.12, 0))
    drive["armL"] = ((0.2, -0.95, -0.3), (-1.0, -0.2, 0.12))
    anims["bash"] = ([(0.0, rest), (hs - 0.18, coil), (hs + 0.02, drive), (he, drive), (t("shield", "bash", "recover"), merge(drive, drop=0.14)),
                      (t("shield", "bash", "length"), rest)], t("shield", "bash", "length"), False)
    # Spear thrust under the shield rim.
    hs, he = t("shield", "thrust", "hit_start"), t("shield", "thrust", "hit_end")
    pull = merge(rest, legs=(-14, 22, 10), drop=0.1, chest=(2, 26, 0))
    pull["armR"] = ((-0.45, 0.55, -0.7), (-0.2, -0.3, 0.2), (0.05, -1.0, 0.05))
    stab = merge(rest, legs=(-48, 30, 10), drop=0.18, spine=(18, 0, 0), chest=(6, -24, 0), off=(0, -0.15, 0))
    stab["armR"] = ((-0.2, -0.95, -0.1), (-0.05, -1.0, 0.0), (0.0, -1.0, 0.02))
    anims["thrust"] = ([(0.0, rest), (0.45, pull), (hs - 0.04, merge(pull, chest=(2, 30, 0))), (hs + 0.04, stab), (he, stab),
                        (t("shield", "thrust", "recover"), stab), (t("shield", "thrust", "length"), rest)], t("shield", "thrust", "length"), False)
    anims["hit"] = (hit_keys(rest, 0.5), 0.35, False)
    # Guard broken: the shield arm flung wide, stumbling back.
    broken = merge(_daze(rest, 18), off=(0, 0.08, 0))
    broken["armL"] = ((0.8, 0.3, -0.4), (0.7, 0.3, 0.3))
    anims["stagger"] = ([(0.0, rest), (0.12, merge(hit_keys(rest)[1][1])), (0.35, broken), (1.2, merge(broken, spine=(16, 0, -6))), (1.7, rest)], 1.7, False)
    anims["death"] = (death_keys(rest), 1.2, False)
    anims["alert"] = _alert(rest)
    return anims


# ---------------------------------------------------------------- bandit mage (staff)

def mage_guard(breath=0.0):
    pose = merge(idle(breath), legs=(-8, 10, 6), drop=0.03, spine=(2 + breath, 0, 0), chest=(1 + breath, 6, 0), head=(-4, -6, 0))
    pose["armR"] = ((-0.35, -0.2, -0.9), (-0.15, -0.75, 0.35), (0.05, -0.2, 0.98))
    pose["armL"] = ((0.3, -0.3, -0.9), (0.25, -0.85, 0.1))
    return pose


def mage_animations():
    rest = mage_guard()
    anims = {"idle": ([(0.0, rest), (1.3, mage_guard(1.0))], 2.6, True)}
    anims["walk"] = (walk_keys(lambda s: ((-0.35, -0.2, -0.9), (-0.15, -0.75, 0.35), (0.05, -0.2, 0.98)), swing=0.4, length=1.0), 1.0, True)
    anims["run"] = (run_keys(lambda s: ((-0.35, 0.1, -0.85), (-0.2, -0.6, 0.4), (0.0, -0.3, 0.95)), length=0.6, lean=10), 0.6, True)
    # Cast: the staff swept up overhead, then levelled at the target as the orb leaves it.
    release = t("mage", "cast", "hit_start")
    gather = merge(rest, legs=(-12, 16, 8), drop=0.06, spine=(-8, 0, 0), chest=(-8, 14, 0), head=(6, -10, 0))
    gather["armR"] = ((-0.3, 0.1, 0.95), (-0.1, 0.3, 0.95), (0.0, 0.35, 0.94))
    gather["armL"] = ((0.6, -0.3, 0.6), (0.4, -0.5, 0.8))
    point = merge(rest, legs=(-30, 22, 8), drop=0.1, spine=(12, 0, 0), chest=(4, -10, 0))
    point["armR"] = ((-0.2, -0.95, 0.15), (-0.05, -1.0, 0.05), (0.0, -1.0, 0.15))
    point["armL"] = ((0.4, 0.3, -0.8), (0.3, 0.2, -0.9))
    anims["cast"] = ([(0.0, rest), (0.45, gather), (release - 0.1, merge(gather, spine=(-12, 0, 0))), (release + 0.02, point),
                      (t("mage", "cast", "recover"), point), (t("mage", "cast", "length"), rest)], t("mage", "cast", "length"), False)
    # Storm: both arms raised to the sky, then the staff butt struck on the ground.
    hs = t("mage", "storm", "hit_start")
    call = merge(rest, legs=(-14, 14, 10), drop=0.04, spine=(-14, 0, 0), chest=(-12, 0, 0), head=(-18, 0, 0))
    call["armR"] = ((-0.4, 0.0, 0.9), (-0.15, 0.0, 1.0), (0.0, 0.0, 1.0))
    call["armL"] = ((0.4, 0.0, 0.9), (0.15, 0.0, 1.0))
    strike = merge(rest, legs=(-34, 26, 12), drop=0.2, spine=(24, 0, 0), chest=(8, 0, 0))
    strike["armR"] = ((-0.25, -0.8, -0.5), (-0.05, -0.6, -0.8), (0.0, -0.2, -0.98))
    strike["armL"] = ((0.3, -0.6, -0.7), (0.1, -0.6, -0.8))
    anims["storm"] = ([(0.0, rest), (0.5, call), (hs - 0.12, merge(call, spine=(-16, 0, 0))), (hs + 0.02, strike), (t("mage", "storm", "recover"), strike),
                       (t("mage", "storm", "length"), rest)], t("mage", "storm", "length"), False)
    # Blink: folds into the robe, vanishes and reforms (the game hides and moves the body).
    fold = merge(rest, legs=(-40, -30, 8), drop=0.3, spine=(30, 0, 0), chest=(14, 0, 0), head=(20, 0, 0))
    fold["armR"] = ((-0.3, -0.6, -0.7), (0.4, -0.8, -0.2), (0.0, -0.3, 0.95))
    fold["armL"] = ((0.3, -0.6, -0.7), (-0.4, -0.8, -0.2))
    anims["blink"] = ([(0.0, rest), (0.18, fold), (0.42, fold), (0.6, rest)], 0.6, False)
    anims["hit"] = (hit_keys(rest), 0.35, False)
    anims["stagger"] = _stagger(rest)
    anims["death"] = (death_keys(rest), 1.2, False)
    anims["alert"] = _alert(rest)
    return anims


# ---------------------------------------------------------------- memory wraith (floating)

def wraith_float(breath=0.0):
    pose = {"thigh.L": (18, 0, -4), "shin.L": (55, 0, 0), "foot.L": (40, 0, 0), "thigh.R": (12, 0, 4), "shin.R": (48, 0, 0), "foot.R": (40, 0, 0),
            "spine": (10 + breath * 2, 0, 0), "chest": (6 + breath * 2, 0, 0), "head": (8 - breath * 2, 0, 0), "off": (0, 0, 0.06 + breath * 0.04),
            "ponytail": (breath * 6, 0, 0), "scarf": (breath * 6, 0, 0)}
    pose["armL"] = ((0.3, -0.45, -0.85), (0.2, -0.75, -0.6))
    pose["armR"] = ((-0.3, -0.45, -0.85), (-0.2, -0.75, -0.6))
    return pose


def wraith_animations():
    rest = wraith_float()
    anims = {"idle": ([(0.0, rest), (1.2, wraith_float(1.0))], 2.4, True)}
    drift = merge(rest, spine=(22, 0, 0), chest=(10, 0, 0), head=(-6, 0, 0), off=(0, 0, 0.1))
    drift["armL"] = ((0.35, 0.5, -0.8), (0.3, 0.7, -0.6))
    drift["armR"] = ((-0.35, 0.5, -0.8), (-0.3, 0.7, -0.6))
    anims["walk"] = ([(0.0, drift), (0.6, merge(drift, off=(0, 0, 0.16), chest=(12, 4, 0))), (1.2, merge(drift, chest=(10, -4, 0)))], 1.8, True)
    rush = merge(drift, spine=(34, 0, 0), head=(-14, 0, 0))
    anims["run"] = ([(0.0, rush), (0.3, merge(rush, off=(0, 0, 0.16))), (0.6, rush)], 0.9, True)
    # Claw: both hands rise and rake down across the target.
    hs, he = t("wraith", "claw", "hit_start"), t("wraith", "claw", "hit_end")
    rise = merge(rest, spine=(-8, 0, 0), chest=(-10, 0, 0), head=(-6, 0, 0), off=(0, 0.05, 0.16))
    rise["armL"] = ((0.6, -0.2, 0.75), (0.3, -0.6, 0.75))
    rise["armR"] = ((-0.6, -0.2, 0.75), (-0.3, -0.6, 0.75))
    rake = merge(rest, spine=(30, 0, 0), chest=(14, 0, 0), head=(-10, 0, 0), off=(0, -0.2, 0.02))
    rake["armL"] = ((-0.3, -0.9, -0.3), (-0.6, -0.6, -0.5))
    rake["armR"] = ((0.3, -0.9, -0.3), (0.6, -0.6, -0.5))
    anims["claw"] = ([(0.0, rest), (hs - 0.14, rise), (hs + 0.04, merge(rake, spine=(20, 0, 0))), (he, rake), (t("wraith", "claw", "length"), rest)],
                     t("wraith", "claw", "length"), False)
    # Scream: arches back, arms flung wide, then the wail bursts out.
    hs = t("wraith", "scream", "hit_start")
    arch = merge(rest, spine=(-20, 0, 0), chest=(-18, 0, 0), head=(-30, 0, 0), off=(0, 0, 0.2))
    arch["armL"] = ((0.95, 0.1, 0.3), (0.9, 0.3, 0.3))
    arch["armR"] = ((-0.95, 0.1, 0.3), (-0.9, 0.3, 0.3))
    wail = merge(rest, spine=(18, 0, 0), chest=(12, 0, 0), head=(16, 0, 0), off=(0, -0.05, 0.1))
    wail["armL"] = ((0.95, -0.3, -0.1), (0.85, -0.5, 0.1))
    wail["armR"] = ((-0.95, -0.3, -0.1), (-0.85, -0.5, 0.1))
    anims["scream"] = ([(0.0, rest), (0.5, arch), (hs - 0.05, merge(arch, head=(-36, 0, 0))), (hs + 0.05, wail), (t("wraith", "scream", "recover"), wail),
                        (t("wraith", "scream", "length"), rest)], t("wraith", "scream", "length"), False)
    curl = merge(rest, spine=(40, 0, 0), chest=(20, 0, 0), head=(20, 0, 0), off=(0, 0, -0.1))
    anims["blink"] = ([(0.0, rest), (0.15, curl), (0.45, curl), (0.6, rest)], 0.6, False)
    recoil = merge(rest, spine=(-16, 0, 6), chest=(-12, 10, 0), head=(-18, 0, 8), off=(0, 0.1, 0.08))
    anims["hit"] = ([(0.0, rest), (0.07, recoil), (0.35, rest)], 0.35, False)
    slump = merge(rest, spine=(36, 0, 12), chest=(16, 0, 0), head=(26, 0, 14), off=(0, 0, -0.12))
    anims["stagger"] = ([(0.0, rest), (0.15, recoil), (0.45, slump), (1.1, merge(slump, spine=(32, 0, -10))), (1.5, rest)], 1.5, False)
    fade = merge(slump, spine=(50, 0, 0), off=(0, 0, -0.5))
    anims["death"] = ([(0.0, rest), (0.12, recoil), (0.6, slump), (1.2, fade)], 1.2, False)
    anims["alert"] = ([(0.0, rest), (0.3, merge(arch, off=(0, 0, 0.12))), (0.8, rest)], 0.8, False)
    return anims


# ---------------------------------------------------------------- stone golem

def golem_stance(breath=0.0):
    pose = merge(idle(breath), legs=(-14, 16, 12), drop=0.08 + breath * 0.01, spine=(10 + breath, 0, 0), chest=(6 + breath * 2, 0, 0), head=(-12, 0, 0))
    pose["armL"] = ((0.45, -0.15, -0.88), (0.3, -0.35, -0.88))
    pose["armR"] = ((-0.45, -0.15, -0.88), (-0.3, -0.35, -0.88))
    return pose


def golem_animations():
    rest = golem_stance()
    anims = {"idle": ([(0.0, rest), (1.6, golem_stance(1.0))], 3.2, True)}
    heavy = lambda s: ((-0.45, -0.15 - s * 0.3, -0.88), (-0.3, -0.35 - s * 0.3, -0.88))  # noqa: E731
    walk = walk_keys(heavy, swing=0.5, length=1.4)
    for index, (_, pose) in enumerate(walk):
        pose["armL"] = ((0.45, -0.15 + (0.3 if index < 2 else -0.3) * 0.5, -0.88), (0.3, -0.35, -0.88))
        pose["spine"] = (12, 0, 0)
        pose["chest"] = (6, 8 if index < 2 else -8, 0)
    anims["walk"] = (walk, 1.4, True)
    run = walk_keys(heavy, swing=0.7, length=1.0)
    for index, (_, pose) in enumerate(run):
        pose["armL"] = ((0.45, -0.1 + (0.35 if index < 2 else -0.35), -0.85), (0.3, -0.4, -0.85))
        pose["spine"] = (18, 0, 0)
    anims["run"] = (run, 1.0, True)
    # Punch: the right fist drawn back past the hip, then hammered forward and down.
    hs, he = t("golem", "punch", "hit_start"), t("golem", "punch", "hit_end")
    draw = merge(rest, legs=(-12, 26, 12), drop=0.1, spine=(4, 0, 0), chest=(0, 40, 0), head=(-6, -24, 0))
    draw["armR"] = ((-0.6, 0.65, -0.3), (-0.2, 0.9, 0.3))
    smash = merge(rest, legs=(-44, 30, 12), drop=0.22, spine=(26, 0, 0), chest=(8, -30, 0), head=(-18, 20, 0), off=(0, -0.12, 0))
    smash["armR"] = ((-0.1, -0.95, -0.25), (0.0, -0.8, -0.6))
    anims["punch"] = ([(0.0, rest), (hs - 0.25, draw), (hs + 0.03, smash), (he, smash), (t("golem", "punch", "recover"), smash),
                       (t("golem", "punch", "length"), rest)], t("golem", "punch", "length"), False)
    # Slam: both fists raised overhead, brought down on the ground.
    hs, he = t("golem", "slam", "hit_start"), t("golem", "slam", "hit_end")
    lift = merge(rest, legs=(-10, 16, 14), drop=0.02, spine=(-14, 0, 0), chest=(-12, 0, 0), head=(-10, 0, 0))
    lift["armL"] = ((0.3, 0.0, 0.95), (0.1, 0.15, 0.98))
    lift["armR"] = ((-0.3, 0.0, 0.95), (-0.1, 0.15, 0.98))
    pound = merge(rest, legs=(-50, -40, 16), drop=0.36, spine=(38, 0, 0), chest=(14, 0, 0), head=(-20, 0, 0))
    pound["armL"] = ((0.25, -0.75, -0.6), (0.1, -0.4, -0.9))
    pound["armR"] = ((-0.25, -0.75, -0.6), (-0.1, -0.4, -0.9))
    anims["slam"] = ([(0.0, rest), (0.7, lift), (hs - 0.12, merge(lift, spine=(-18, 0, 0))), (hs + 0.03, pound), (he, pound),
                      (t("golem", "slam", "recover"), pound), (t("golem", "slam", "length"), rest)], t("golem", "slam", "length"), False)
    # Throw: tears a rock from the ground, heaves it overhead, hurls it.
    release = t("golem", "throw", "hit_start")
    reach = merge(rest, legs=(-46, -36, 14), drop=0.32, spine=(44, 0, 0), chest=(10, 0, 0))
    reach["armR"] = ((-0.3, -0.6, -0.75), (-0.1, -0.3, -0.95))
    reach["armL"] = ((0.3, -0.6, -0.75), (0.1, -0.3, -0.95))
    heave = merge(rest, legs=(-14, 24, 12), drop=0.04, spine=(-16, 0, 0), chest=(-14, 18, 0))
    heave["armR"] = ((-0.35, 0.35, 0.85), (-0.1, 0.55, 0.8))
    heave["armL"] = ((0.35, 0.2, 0.9), (0.0, 0.4, 0.9))
    hurl = merge(rest, legs=(-42, 30, 12), drop=0.18, spine=(24, 0, 0), chest=(6, -24, 0), off=(0, -0.1, 0))
    hurl["armR"] = ((-0.2, -0.95, 0.2), (-0.05, -1.0, -0.1))
    hurl["armL"] = ((0.4, 0.3, -0.85), (0.3, 0.1, -0.9))
    anims["throw"] = ([(0.0, rest), (0.45, reach), (0.8, heave), (release - 0.08, merge(heave, chest=(-16, 30, 0))), (release + 0.04, hurl),
                       (t("golem", "throw", "recover"), hurl), (t("golem", "throw", "length"), rest)], t("golem", "throw", "length"), False)
    # Awaken: from a dormant crouch, rising and roaring.
    dormant = merge(rest, legs=(-70, -60, 16), drop=0.5, spine=(46, 0, 0), chest=(20, 0, 0), head=(30, 0, 0))
    dormant["armL"] = ((0.3, -0.5, -0.8), (0.1, -0.2, -0.97))
    dormant["armR"] = ((-0.3, -0.5, -0.8), (-0.1, -0.2, -0.97))
    roar = merge(rest, legs=(-20, 22, 16), drop=0.06, spine=(-16, 0, 0), chest=(-18, 0, 0), head=(-22, 0, 0))
    roar["armL"] = ((0.85, 0.0, 0.5), (0.7, -0.2, 0.7))
    roar["armR"] = ((-0.85, 0.0, 0.5), (-0.7, -0.2, 0.7))
    anims["awaken"] = ([(0.0, dormant), (0.8, dormant), (1.4, merge(rest, drop=0.2)), (1.8, roar), (2.2, roar), (2.4, rest)], 2.4, False)
    anims["roar"] = ([(0.0, rest), (0.4, merge(rest, spine=(24, 0, 0), drop=0.2)), (0.8, roar), (1.4, roar), (1.8, rest)], 1.8, False)
    anims["hit"] = (hit_keys(rest, 0.4), 0.4, False)
    slump = merge(rest, legs=(-40, 20, 16), drop=0.3, spine=(34, 0, 10), chest=(14, 0, 0), head=(20, 0, 10))
    anims["stagger"] = ([(0.0, rest), (0.2, merge(hit_keys(rest, 0.4)[1][1])), (0.6, slump), (1.6, merge(slump, spine=(30, 0, -8))), (2.0, slump), (2.4, rest)], 2.4, False)
    kneel = merge(rest, legs=(-80, 8, 14), drop=0.46, spine=(30, 0, 6), chest=(16, 0, 0), head=(24, 0, 0))
    topple = merge(kneel, spine=(70, 0, 10), off=(0, -0.4, -0.2))
    anims["death"] = ([(0.0, rest), (0.2, merge(hit_keys(rest, 0.4)[1][1])), (0.8, kneel), (1.5, topple), (1.8, merge(topple, off=(0, -0.5, -0.3)))], 1.8, False)
    anims["alert"] = ([(0.0, rest), (0.4, roar), (1.0, rest)], 1.0, False)
    return anims
