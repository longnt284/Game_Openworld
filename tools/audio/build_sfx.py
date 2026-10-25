"""Build sound effects and ambience loops.

python3 tools/audio/build_sfx.py <kenney_dir>   (or --elemental / --weather / --monsters to rebuild only those clips)
- Synthesises whooshes, wind skills, impacts, creature sounds and ambience loops with numpy/scipy
  (original work for this project).
- Copies selected CC0 clips from Kenney's "RPG Audio", "Impact Sounds" and "Interface Sounds" packs
  (download from kenney.nl, unzip into <kenney_dir>/kenney_<pack>/).
"""
import shutil
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parents[2]
SFX = ROOT / "assets" / "audio" / "sfx"
AMBIENCE = ROOT / "assets" / "audio" / "ambience"
RATE = 44100
RNG = np.random.default_rng(284)

KENNEY = {
    "impact-sounds": {
        "step_grass_{i}": "footstep_grass_00{i}.ogg", "step_wood_{i}": "footstep_wood_00{i}.ogg", "step_stone_{i}": "footstep_concrete_00{i}.ogg",
        "step_leaves_{i}": "footstep_snow_00{i}.ogg", "hit_flesh_{i}": "impactPunch_medium_00{i}.ogg", "block_{i}": "impactMetal_medium_00{i}.ogg",
        "boar_hit_{i}": "impactSoft_heavy_00{i}.ogg", "hit_heavy_{i}": "impactPunch_heavy_00{i}.ogg",
    },
    "rpg-audio": {"step_dirt_{i}": "footstep0{i}.ogg"},
}
KENNEY_SINGLE = {
    "parry": ("impact-sounds", "impactBell_heavy_001.ogg"), "parry_metal": ("impact-sounds", "impactMetal_heavy_002.ogg"),
    "chest_open": ("rpg-audio", "doorOpen_1.ogg"), "coins": ("rpg-audio", "handleCoins.ogg"), "pickup": ("rpg-audio", "beltHandle1.ogg"),
    "book": ("rpg-audio", "bookFlip2.ogg"), "sword_draw": ("rpg-audio", "drawKnife1.ogg"), "cloth": ("rpg-audio", "cloth2.ogg"),
    "wood_knock": ("impact-sounds", "impactWood_heavy_001.ogg"), "plank": ("impact-sounds", "impactPlank_medium_002.ogg"),
    "ui_click": ("interface-sounds", "click_002.ogg"), "ui_select": ("interface-sounds", "select_002.ogg"),
    "ui_open": ("interface-sounds", "open_001.ogg"), "ui_close": ("interface-sounds", "close_001.ogg"),
    "ui_confirm": ("interface-sounds", "confirmation_002.ogg"), "ui_error": ("interface-sounds", "error_004.ogg"),
}


def write(path, data, mono=True):
    path.parent.mkdir(parents=True, exist_ok=True)
    data = np.asarray(data, dtype=np.float32)
    peak = np.max(np.abs(data)) + 1e-9
    data = data / peak * 0.85
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "out.wav"
        with wave.open(str(wav), "wb") as handle:
            handle.setnchannels(1 if mono else 2)
            handle.setsampwidth(2)
            handle.setframerate(RATE)
            handle.writeframes((np.clip(data, -1, 1) * 32767).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "5", str(path)], check=True)
    print("SFX_OK", path.relative_to(ROOT))


def t(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def env(length, attack=0.01, release=0.2, curve=2.0):
    n = int(length * RATE)
    e = np.ones(n)
    a = max(1, int(attack * RATE))
    r = max(1, int(release * RATE))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r) ** curve
    return e


def swept_noise(length, f_start, f_end, width=0.35, color=0.0):
    """White noise shaped by a moving gaussian band (log-frequency sweep)."""
    n = int(length * RATE)
    noise = RNG.standard_normal(n)
    f, times, z = signal.stft(noise, RATE, nperseg=1024)
    centers = np.exp(np.linspace(np.log(f_start), np.log(f_end), z.shape[1]))
    for k, center in enumerate(centers):
        band = np.exp(-0.5 * (np.log((f + 1) / center) / width) ** 2)
        z[:, k] *= band * (1.0 + color * (center / (f + 50.0)))
    _, out = signal.istft(z, RATE, nperseg=1024)
    return out[:n]


def lowpass(x, cutoff, order=4):
    return signal.sosfilt(signal.butter(order, cutoff, "low", fs=RATE, output="sos"), x)


def bandpass(x, low, high, order=3):
    return signal.sosfilt(signal.butter(order, [low, high], "band", fs=RATE, output="sos"), x)


def sine(freq, length, phase=0.0):
    return np.sin(2 * np.pi * np.cumsum(np.broadcast_to(freq, int(length * RATE)) / RATE) + phase)


# ---------------------------------------------------------------- effects

def whoosh(length, f0, f1, width=0.3):
    return swept_noise(length, f0, f1, width) * env(length, length * 0.35, length * 0.55)


def effects():
    for i, (f0, f1) in enumerate(((500, 2600), (700, 3200), (420, 2200))):
        write(SFX / f"swing_{i}.ogg", whoosh(0.28, f0, f1) + 0.15 * whoosh(0.28, f1 * 1.5, f0 * 2))
    write(SFX / "swing_heavy.ogg", whoosh(0.55, 260, 2400, 0.4) + 0.4 * lowpass(RNG.standard_normal(int(0.55 * RATE)), 300) * env(0.55, 0.15, 0.3))
    gust = swept_noise(0.7, 300, 3800, 0.25) * env(0.7, 0.05, 0.5)
    ring = sine(np.linspace(900, 1500, int(0.7 * RATE)), 0.7) * env(0.7, 0.02, 0.6) * 0.12
    write(SFX / "wind_slash.ogg", gust + ring)
    spin = np.zeros(int(1.3 * RATE))
    for k in range(5):
        start = int(k * 0.2 * RATE)
        burst = whoosh(0.35, 400 + k * 60, 2600 + k * 200)
        spin[start:start + len(burst)] += burst * (0.7 + 0.1 * k)
    write(SFX / "wind_cyclone.ogg", spin + 0.3 * swept_noise(1.3, 200, 900, 0.5) * env(1.3, 0.2, 0.6))
    write(SFX / "dodge.ogg", whoosh(0.32, 900, 400, 0.45) * 0.8)
    write(SFX / "jump.ogg", whoosh(0.2, 600, 1400, 0.4) * 0.6)
    write(SFX / "leap.ogg", swept_noise(0.6, 250, 2200, 0.3) * env(0.6, 0.02, 0.45) + 0.1 * sine(np.linspace(600, 1200, int(0.6 * RATE)), 0.6) * env(0.6, 0.01, 0.5))
    thump = lowpass(RNG.standard_normal(int(0.25 * RATE)), 260) * env(0.25, 0.002, 0.22) + 0.6 * sine(np.linspace(90, 45, int(0.25 * RATE)), 0.25) * env(0.25, 0.002, 0.2)
    write(SFX / "land.ogg", thump)
    write(SFX / "glint.ogg", (sine(2400, 0.5) + 0.5 * sine(3610, 0.5)) * env(0.5, 0.003, 0.48, 3.0) * 0.6)
    write(SFX / "danger.ogg", (sine(620, 0.6) * 0.6 + sine(930, 0.6) * 0.4) * env(0.6, 0.005, 0.5, 2.0) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 14 * t(0.6)))))
    boom_len = 1.4
    boom = 0.9 * sine(np.linspace(70, 32, int(boom_len * RATE)), boom_len) * env(boom_len, 0.003, 1.3) + 0.6 * lowpass(RNG.standard_normal(int(boom_len * RATE)), 500) * env(boom_len, 0.003, 1.0, 3.0)
    write(SFX / "ground_slam.ogg", boom)
    write(SFX / "glaive_sweep.ogg", whoosh(0.8, 180, 1500, 0.45) + 0.4 * lowpass(RNG.standard_normal(int(0.8 * RATE)), 200) * env(0.8, 0.3, 0.4))
    slam = np.pad(boom[: int(0.9 * RATE)], (int(0.25 * RATE), 0))[: int(0.9 * RATE)]
    slam[: int(0.35 * RATE)] += whoosh(0.35, 300, 1600, 0.4) * 0.6
    write(SFX / "glaive_slam.ogg", slam)
    write(SFX / "sabre_swing.ogg", whoosh(0.32, 380, 2000, 0.35))
    growl_len = 0.7
    growl_base = 110 + 25 * np.sin(2 * np.pi * 7 * t(growl_len))
    growl = (signal.sawtooth(2 * np.pi * np.cumsum(growl_base) / RATE) * 0.5 + bandpass(RNG.standard_normal(int(growl_len * RATE)), 150, 900)) * env(growl_len, 0.05, 0.4)
    write(SFX / "boar_grunt.ogg", lowpass(growl, 1400))
    charge = bandpass(RNG.standard_normal(int(1.0 * RATE)), 60, 400) * env(1.0, 0.1, 0.4) * (0.7 + 0.3 * np.sin(2 * np.pi * 9 * t(1.0)))
    write(SFX / "boar_charge.ogg", charge)
    roar_len = 1.8
    roar_freq = 70 + 30 * np.sin(2 * np.pi * 3 * t(roar_len)) + np.linspace(0, 40, int(roar_len * RATE))
    roar = (signal.sawtooth(2 * np.pi * np.cumsum(roar_freq) / RATE) * 0.6 + bandpass(RNG.standard_normal(int(roar_len * RATE)), 100, 1600) * 0.7) * env(roar_len, 0.2, 0.8)
    write(SFX / "roar.ogg", lowpass(roar, 2200) + 0.4 * swept_noise(roar_len, 300, 2400, 0.4) * env(roar_len, 0.4, 1.0))
    write(SFX / "enemy_down.ogg", thump * 0.8 + 0.3 * whoosh(0.25, 800, 300))
    shimmer = np.zeros(int(1.4 * RATE))
    for k, freq in enumerate((880, 1174, 1318, 1760)):
        start = int(k * 0.08 * RATE)
        tone = sine(freq, 1.0) * env(1.0, 0.01, 0.9, 3.0) * 0.3
        shimmer[start:start + len(tone)] += tone
    write(SFX / "heal.ogg", shimmer + 0.2 * swept_noise(1.4, 2000, 6000, 0.3) * env(1.4, 0.2, 0.8))
    write(SFX / "splash.ogg", bandpass(RNG.standard_normal(int(0.8 * RATE)), 400, 5000) * env(0.8, 0.005, 0.7, 3.0))
    whisper = bandpass(RNG.standard_normal(int(2.4 * RATE)), 600, 3200) * env(2.4, 0.6, 1.2) * (0.5 + 0.5 * np.sin(2 * np.pi * 2.5 * t(2.4)) ** 2)
    write(SFX / "echo_whisper.ogg", whisper * 0.6 + 0.25 * (sine(587, 2.4) + sine(880, 2.4)) * env(2.4, 0.5, 1.5))
    write(SFX / "barrier.ogg", swept_noise(1.0, 200, 1200, 0.5) * env(1.0, 0.3, 0.6) + 0.3 * sine(220, 1.0) * env(1.0, 0.3, 0.6))
    write(SFX / "seal_hum.ogg", (sine(110, 1.5) * 0.4 + sine(165, 1.5) * 0.3) * env(1.5, 0.4, 0.8) * (0.8 + 0.2 * np.sin(2 * np.pi * 4 * t(1.5))))


def elemental():
    """Sounds for the four elemental styles and the ultimate release (own RNG, so the clips above stay stable)."""
    global RNG
    saved, RNG = RNG, np.random.default_rng(2840)
    # Water: a wet swish over a bubbling low band; swirl spins it into a draining vortex.
    wash = bandpass(RNG.standard_normal(int(0.6 * RATE)), 250, 2400) * env(0.6, 0.03, 0.5) * (0.7 + 0.3 * np.sin(2 * np.pi * 23 * t(0.6)))
    write(SFX / "water_slash.ogg", whoosh(0.6, 400, 1800, 0.35) * 0.8 + wash * 0.6)
    swirl_len = 1.4
    gurgle = bandpass(RNG.standard_normal(int(swirl_len * RATE)), 120, 900) * (0.6 + 0.4 * np.sin(2 * np.pi * np.linspace(3, 11, int(swirl_len * RATE)) * t(swirl_len)))
    write(SFX / "water_swirl.ogg", (gurgle + 0.5 * swept_noise(swirl_len, 1600, 300, 0.4)) * env(swirl_len, 0.2, 0.7))
    # Thunder: a crackling zip for the dash, a branching snap-and-rumble for the chain.
    crackle = RNG.standard_normal(int(0.45 * RATE)) * (RNG.random(int(0.45 * RATE)) > 0.93)
    write(SFX / "thunder_dash.ogg", whoosh(0.45, 1200, 4800, 0.3) * 0.7 + bandpass(crackle, 1500, 9000) * env(0.45, 0.005, 0.4) * 1.4)
    chain_len = 1.1
    snaps = np.zeros(int(chain_len * RATE))
    for k in range(4):
        start = int(k * 0.12 * RATE)
        snap = bandpass(RNG.standard_normal(int(0.09 * RATE)), 2000, 10000) * env(0.09, 0.001, 0.08, 3.0)
        snaps[start:start + len(snap)] += snap * (1.0 - 0.15 * k)
    rumble = lowpass(RNG.standard_normal(int(chain_len * RATE)), 180) * env(chain_len, 0.05, 0.9, 2.5)
    write(SFX / "thunder_chain.ogg", snaps + rumble * 0.8)
    # Flame: a roaring ignition with crackle.
    burst_len = 0.9
    roar = lowpass(RNG.standard_normal(int(burst_len * RATE)), 900) * env(burst_len, 0.02, 0.7)
    pops = bandpass(RNG.standard_normal(int(burst_len * RATE)) * (RNG.random(int(burst_len * RATE)) > 0.97), 900, 5000)
    write(SFX / "flame_burst.ogg", roar + 0.6 * swept_noise(burst_len, 300, 1400, 0.45) * env(burst_len, 0.01, 0.7) + pops * env(burst_len, 0.01, 0.8))
    # Frost: a glassy chime over cold hiss; shatter is a burst of high tinkles.
    chime = sum(sine(f, 0.8) * env(0.8, 0.002, 0.75, 3.0) * g for f, g in ((2093, 0.5), (3136, 0.3), (4186, 0.2)))
    write(SFX / "frost_cast.ogg", chime + 0.4 * swept_noise(0.8, 3000, 7000, 0.3) * env(0.8, 0.05, 0.6))
    shatter = np.zeros(int(1.0 * RATE))
    for _ in range(24):
        start = RNG.integers(0, int(0.35 * RATE))
        ping = sine(RNG.uniform(2500, 7000), 0.25) * env(0.25, 0.001, 0.24, 4.0) * RNG.uniform(0.2, 0.5)
        shatter[start:start + len(ping)] += ping
    crash = bandpass(RNG.standard_normal(int(1.0 * RATE)), 1500, 9000) * env(1.0, 0.001, 0.6, 4.0)
    write(SFX / "frost_shatter.ogg", shatter + crash * 0.7)
    # Ultimate release: rising charge into a deep boom and a bright tail.
    rise_len, boom_len = 0.6, 1.6
    rise = swept_noise(rise_len, 200, 3000, 0.3) * np.linspace(0.1, 1.0, int(rise_len * RATE)) ** 2
    boom = 0.9 * sine(np.linspace(80, 30, int(boom_len * RATE)), boom_len) * env(boom_len, 0.002, 1.5) + 0.7 * lowpass(RNG.standard_normal(int(boom_len * RATE)), 700) * env(boom_len, 0.002, 1.2, 3.0)
    tail = (sine(1318, boom_len) * 0.15 + sine(1975, boom_len) * 0.1) * env(boom_len, 0.01, 1.4, 2.0)
    write(SFX / "ult_release.ogg", np.concatenate([rise, boom + tail]))
    RNG = saved


# ---------------------------------------------------------------- ambience

def loopable(x, fade=1.5):
    """Crossfade the tail into the head so the clip loops without a click."""
    n = int(fade * RATE)
    head, body, tail = x[:n], x[n:-n], x[-n:]
    ramp = np.linspace(0, 1, n)
    return np.concatenate([tail * (1 - ramp) + head * ramp, body])


def wind_bed(length, low=120, high=900, gust_rate=0.08):
    n = int(length * RATE)
    noise = RNG.standard_normal(n)
    base = bandpass(noise, low, high, 2)
    lfo = 0.55 + 0.45 * np.sin(2 * np.pi * gust_rate * t(length) + 1.3) * np.sin(2 * np.pi * gust_rate * 0.37 * t(length))
    whistle = swept_noise(length, 500, 700, 0.15) * (0.3 + 0.3 * np.sin(2 * np.pi * 0.05 * t(length)))
    return base * lfo + whistle * 0.25


def bird(freq, length=0.18):
    sweep = freq * (1 + 0.25 * np.sin(2 * np.pi * 18 * t(length)))
    return sine(sweep, length) * env(length, 0.01, 0.12) * 0.25


def scatter(bed, maker, count, gain):
    for _ in range(count):
        clip = maker()
        start = RNG.integers(0, len(bed) - len(clip))
        bed[start:start + len(clip)] += clip * gain
    return bed


def ambience():
    length = 32.0
    wind = wind_bed(length)
    write(AMBIENCE / "wind.ogg", loopable(wind))
    forest = wind_bed(length, 200, 1600, 0.12) * 0.6
    forest = scatter(forest, lambda: np.concatenate([bird(RNG.uniform(2400, 4200)) for _ in range(RNG.integers(2, 5))]), 14, 0.5)
    forest = scatter(forest, lambda: bandpass(RNG.standard_normal(int(0.05 * RATE)), 300, 1200) * env(0.05, 0.002, 0.04), 30, 0.6)
    write(AMBIENCE / "forest.ogg", loopable(forest))
    n = int(24 * RATE)
    river = bandpass(RNG.standard_normal(n), 300, 6000, 2) * 0.6 + bandpass(RNG.standard_normal(n), 80, 500, 2) * 0.5
    river *= 0.8 + 0.2 * np.sin(2 * np.pi * 0.3 * t(24)) * np.sin(2 * np.pi * 1.7 * t(24))
    river = scatter(river, lambda: bandpass(RNG.standard_normal(int(0.08 * RATE)), 800, 3000) * env(0.08, 0.01, 0.06), 60, 0.5)
    write(AMBIENCE / "river.ogg", loopable(river))
    village = wind_bed(length, 150, 1000, 0.06) * 0.35
    formants = [(700, 1200), (400, 2200), (600, 1000), (300, 2600)]

    def chatter():
        syllables = []
        for _ in range(RNG.integers(3, 8)):
            low, high = formants[RNG.integers(0, len(formants))]
            dur = RNG.uniform(0.08, 0.2)
            pitch = RNG.uniform(140, 240)
            voiced = signal.sawtooth(2 * np.pi * pitch * t(dur)) * 0.4 + RNG.standard_normal(int(dur * RATE)) * 0.1
            syllables.append(bandpass(voiced, low * 0.7, high * 1.2) * env(dur, 0.02, 0.06))
            syllables.append(np.zeros(int(RNG.uniform(0.03, 0.12) * RATE)))
        return lowpass(np.concatenate(syllables), 2400)
    village = scatter(village, chatter, 70, 0.22)
    village = scatter(village, lambda: bird(RNG.uniform(2800, 3800)), 8, 0.35)
    village = scatter(village, lambda: bandpass(RNG.standard_normal(int(0.04 * RATE)), 500, 2000) * env(0.04, 0.001, 0.03), 18, 0.5)
    write(AMBIENCE / "village.ogg", loopable(village))


def weather():
    """Rain, storm wind, night insects and thunder (own RNG, so every clip above stays byte-identical)."""
    global RNG
    saved, RNG = RNG, np.random.default_rng(2841)
    length = 28.0
    n = int(length * RATE)

    def drops(count, low, high, gain):
        bed = np.zeros(n)
        return scatter(bed, lambda: bandpass(RNG.standard_normal(int(0.012 * RATE)), low, high) * env(0.012, 0.0005, 0.011, 3.0), count, gain)

    # Light rain: a soft high hiss with patters of drops on leaves and roofs.
    hiss = bandpass(RNG.standard_normal(n), 1800, 9000, 2) * 0.35
    hiss *= 0.85 + 0.15 * np.sin(2 * np.pi * 0.11 * t(length)) * np.sin(2 * np.pi * 0.37 * t(length))
    write(AMBIENCE / "rain_light.ogg", loopable(hiss + drops(900, 2000, 7000, 0.5) + drops(260, 600, 2400, 0.35)))
    # Heavy rain: a dense roar in the low mids under the hiss, drops everywhere.
    roar = bandpass(RNG.standard_normal(n), 250, 1800, 2) * 0.6 + bandpass(RNG.standard_normal(n), 1500, 8000, 2) * 0.45
    roar *= 0.8 + 0.2 * np.sin(2 * np.pi * 0.07 * t(length) + 0.6)
    write(AMBIENCE / "rain_heavy.ogg", loopable(roar + drops(2600, 1500, 7000, 0.45) + drops(700, 400, 1800, 0.35)))
    # Storm wind: fast gusts that howl and drop away.
    gale = wind_bed(length, 90, 1400, 0.22) * 0.8
    howl = swept_noise(length, 380, 900, 0.12) * (0.25 + 0.25 * np.sin(2 * np.pi * 0.09 * t(length)) ** 2)
    write(AMBIENCE / "storm_wind.ogg", loopable(gale + howl))
    # Night: crickets chirping in trains at their own pitches and rates over a faint breeze.
    night = wind_bed(length, 120, 600, 0.04) * 0.12

    def cricket():
        pitch = RNG.uniform(3800, 5200)
        pulses = []
        for _ in range(RNG.integers(3, 7)):
            pulses.append(sine(pitch, 0.018) * env(0.018, 0.002, 0.01) * 0.6)
            pulses.append(np.zeros(int(0.022 * RATE)))
        return np.concatenate(pulses)
    night = scatter(night, cricket, 420, 0.35)
    night = scatter(night, lambda: bird(RNG.uniform(900, 1300), 0.3) * 0.5, 4, 0.3)
    write(AMBIENCE / "night_insects.ogg", loopable(night))
    # Thunder: a crack (near) into a rolling low rumble; four lengths and strengths.
    for index, (length_s, crack) in enumerate(((3.2, 0.9), (4.5, 0.5), (5.5, 0.2), (2.6, 1.0))):
        m = int(length_s * RATE)
        rumble = lowpass(RNG.standard_normal(m), 160, 2) * env(length_s, 0.08, length_s * 0.8, 1.6)
        rolls = 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * RNG.uniform(0.7, 1.4) * t(length_s) + RNG.uniform(0, 3)))
        boom = 0.5 * sine(np.linspace(55, 28, m), length_s) * env(length_s, 0.01, length_s * 0.7, 2.0)
        snap = bandpass(RNG.standard_normal(m), 700, 6000) * env(length_s, 0.001, 0.35, 4.0) * crack
        write(SFX / f"thunder_{index}.ogg", rumble * rolls + boom + snap)
    RNG = saved


def monsters():
    """Chapter-one monsters and the earth style (own RNG, so every clip above stays byte-identical)."""
    global RNG
    saved, RNG = RNG, np.random.default_rng(2842)
    # Bow: the creak of a drawn bow, then the string's twang.
    creak = bandpass(RNG.standard_normal(int(0.5 * RATE)), 300, 1400) * env(0.5, 0.3, 0.15) * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t(0.5)))
    twang = (sine(np.linspace(190, 160, int(0.4 * RATE)), 0.4) + 0.4 * sine(np.linspace(380, 330, int(0.4 * RATE)), 0.4)) * env(0.4, 0.002, 0.38, 3.0)
    write(SFX / "bow_draw.ogg", np.concatenate([creak * 0.5, twang + whoosh(0.4, 1800, 600, 0.3) * 0.4]))
    write(SFX / "arrow_hit.ogg", lowpass(RNG.standard_normal(int(0.2 * RATE)), 1800) * env(0.2, 0.001, 0.18, 3.0) + 0.3 * sine(np.linspace(900, 300, int(0.2 * RATE)), 0.2) * env(0.2, 0.001, 0.15))
    # Wolves: a low snarl, a snapping bite and a long howl that rises and falls.
    snarl_len = 0.6
    snarl_f = 140 + 30 * np.sin(2 * np.pi * 18 * t(snarl_len))
    snarl = (signal.sawtooth(2 * np.pi * np.cumsum(snarl_f) / RATE) * 0.4 + bandpass(RNG.standard_normal(int(snarl_len * RATE)), 200, 1600)) * env(snarl_len, 0.04, 0.3)
    write(SFX / "wolf_snarl.ogg", lowpass(snarl, 2000))
    bite = bandpass(RNG.standard_normal(int(0.16 * RATE)), 800, 5000) * env(0.16, 0.001, 0.14, 4.0)
    write(SFX / "wolf_bite.ogg", np.concatenate([bite, np.zeros(int(0.04 * RATE)), bite * 0.6]))
    howl_len = 2.6
    howl_f = np.interp(t(howl_len), [0, 0.4, 1.6, 2.6], [420, 640, 600, 380]) + 8 * np.sin(2 * np.pi * 5 * t(howl_len))
    howl = (sine(howl_f, howl_len) + 0.25 * sine(howl_f * 2, howl_len) + 0.15 * bandpass(RNG.standard_normal(int(howl_len * RATE)), 500, 2500)) * env(howl_len, 0.3, 1.2)
    write(SFX / "wolf_howl.ogg", howl * 0.8)
    # Wraith: a breathy wail between two pitches with a hollow whisper under it.
    wail_len = 1.6
    wail_f = np.interp(t(wail_len), [0, 0.6, 1.6], [520, 780, 460])
    wail = (sine(wail_f, wail_len) * 0.5 + sine(wail_f * 1.5, wail_len) * 0.2) * (0.6 + 0.4 * np.sin(2 * np.pi * 6 * t(wail_len)))
    wail = wail * env(wail_len, 0.25, 0.8) + bandpass(RNG.standard_normal(int(wail_len * RATE)), 900, 4200) * env(wail_len, 0.4, 0.9) * 0.4
    write(SFX / "ghost_wail.ogg", wail)
    # Golem: grinding stone, and a boulder shattering.
    grind_len = 0.9
    grind = bandpass(RNG.standard_normal(int(grind_len * RATE)), 70, 600) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 11 * t(grind_len)))) * env(grind_len, 0.1, 0.4)
    write(SFX / "golem_grind.ogg", grind + 0.3 * sine(np.linspace(55, 40, int(grind_len * RATE)), grind_len) * env(grind_len, 0.1, 0.5))
    crash_len = 1.1
    crash = lowpass(RNG.standard_normal(int(crash_len * RATE)), 900) * env(crash_len, 0.002, 1.0, 2.5)
    for _ in range(14):
        start = int(RNG.uniform(0.02, 0.7) * RATE)
        chip = bandpass(RNG.standard_normal(int(0.05 * RATE)), 1200, 6000) * env(0.05, 0.001, 0.045, 3.0) * RNG.uniform(0.2, 0.5)
        crash[start:start + len(chip)] += chip
    write(SFX / "rock_crash.ogg", crash + 0.6 * sine(np.linspace(80, 38, int(crash_len * RATE)), crash_len) * env(crash_len, 0.002, 0.9))
    # Earth style: pillars punching up out of the ground.
    write(SFX / "earth_spike.ogg", 0.8 * sine(np.linspace(110, 50, int(0.5 * RATE)), 0.5) * env(0.5, 0.002, 0.45) + lowpass(RNG.standard_normal(int(0.5 * RATE)), 1400) * env(0.5, 0.002, 0.4, 3.0))
    RNG = saved


def copy_kenney(base):
    for pack, mapping in KENNEY.items():
        for target, source in mapping.items():
            for i in range(5 if "step" in target else 3):
                src = base / f"kenney_{pack}" / "Audio" / source.format(i=i)
                if not src.exists():
                    matches = list((base / f"kenney_{pack}").rglob(source.format(i=i)))
                    src = matches[0] if matches else None
                if src:
                    shutil.copy(src, SFX / (target.format(i=i) + ".ogg"))
    for target, (pack, source) in KENNEY_SINGLE.items():
        matches = list((base / f"kenney_{pack}").rglob(source))
        if matches:
            shutil.copy(matches[0], SFX / f"{target}.ogg")
        else:
            print("MISSING", pack, source)
    print("KENNEY_OK")


if __name__ == "__main__":
    SFX.mkdir(parents=True, exist_ok=True)
    AMBIENCE.mkdir(parents=True, exist_ok=True)
    if sys.argv[1:] == ["--elemental"]:
        elemental()
        sys.exit()
    if sys.argv[1:] == ["--weather"]:
        weather()
        sys.exit()
    if sys.argv[1:] == ["--monsters"]:
        monsters()
        sys.exit()
    if len(sys.argv) > 1:
        copy_kenney(Path(sys.argv[1]))
    effects()
    ambience()
    elemental()
    weather()
    monsters()
