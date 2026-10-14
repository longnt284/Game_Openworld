"""Compose and render the Vân Khê soundtrack (theme + area/combat/boss variants and stingers).

python3 tools/audio/compose_music.py
Requires: mido, numpy, fluidsynth CLI with the FluidR3_GM soundfont (MIT licence), ffmpeg.
The theme is written by hand in D minor pentatonic (sáo/đàn feel); arrangements are
generated from it. Loops are rendered twice and the second pass is kept so reverb
tails wrap seamlessly.
"""
import random
import subprocess
import tempfile
import wave
from pathlib import Path

import mido
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "audio" / "music"
STINGERS = ROOT / "assets" / "audio" / "sfx"
SOUNDFONT = Path("/usr/share/sounds/sf2/FluidR3_GM.sf2")
PPQ = 480
RATE = 44100

P = {"D3": 50, "E3": 52, "F3": 53, "G3": 55, "A3": 57, "Bb3": 58, "C4": 60, "D4": 62, "Eb4": 63, "E4": 64, "F4": 65, "G4": 67, "A4": 69,
     "Bb4": 70, "C5": 72, "D5": 74, "Eb5": 75, "E5": 76, "F5": 77, "G5": 79, "A5": 81, "C6": 84, "D6": 86, "A2": 45, "C3": 48, "D2": 38,
     "F2": 41, "G2": 43, "C2": 36, "Bb2": 46, "A1": 33, "D1": 26}

# Main theme: 16 bars of 4/4, (note, beats).
THEME = [
    [("A4", 2), ("G4", 1), ("F4", 1)], [("D4", 1.5), ("F4", 0.5), ("G4", 2)], [("A4", 1), ("C5", 1), ("D5", 1), ("C5", 1)], [("A4", 4)],
    [("D5", 2), ("C5", 1), ("A4", 1)], [("G4", 1.5), ("A4", 0.5), ("C5", 2)], [("A4", 1), ("G4", 1), ("F4", 1), ("G4", 1)], [("D4", 4)],
    [("F5", 2), ("D5", 1), ("C5", 1)], [("D5", 1.5), ("C5", 0.5), ("A4", 2)], [("G4", 1), ("A4", 1), ("C5", 1), ("A4", 1)], [("G4", 3), ("F4", 1)],
    [("D4", 1), ("F4", 1), ("G4", 1), ("A4", 1)], [("C5", 2), ("A4", 2)], [("G4", 1), ("F4", 1), ("G4", 2)], [("D4", 4)],
]
CHORDS = ["D", "D", "F", "D", "C", "F", "C", "D", "F", "D", "C", "C", "D", "F", "C", "D"]
CHORD_TONES = {"D": ["D3", "A3", "D4", "F4"], "F": ["F3", "C4", "F4", "A4"], "C": ["C3", "G3", "C4", "E4"], "G": ["G2", "D3", "G3", "Bb3"],
               "Bb": ["Bb2", "F3", "Bb3", "D4"], "Eb": ["Eb4", "Bb3", "G3", "Eb4"]}
BASS = {"D": "D2", "F": "F2", "C": "C2", "G": "G2", "Bb": "Bb2", "Eb": "Bb2"}


class Song:
    def __init__(self, tempo):
        self.tempo = tempo
        self.events = []
        self.programs = {}
        self.rng = random.Random(284)

    def program(self, channel, program, volume=100, pan=64, reverb=60):
        self.programs[channel] = (program, volume, pan, reverb)

    def note(self, beat, length, pitch, velocity, channel, jitter=0.0):
        if isinstance(pitch, str):
            pitch = P[pitch]
        offset = self.rng.uniform(-jitter, jitter)
        start = max(0, int((beat + offset) * PPQ))
        end = start + max(30, int(length * PPQ * 0.97))
        velocity = max(1, min(127, int(velocity + self.rng.uniform(-5, 5))))
        self.events.append((start, 1, mido.Message("note_on", note=pitch, velocity=velocity, channel=channel)))
        self.events.append((end, 0, mido.Message("note_off", note=pitch, velocity=0, channel=channel)))

    def write(self, path):
        midi = mido.MidiFile(ticks_per_beat=PPQ)
        track = mido.MidiTrack()
        midi.tracks.append(track)
        track.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(self.tempo), time=0))
        for channel, (program, volume, pan, reverb) in self.programs.items():
            track.append(mido.Message("program_change", program=program, channel=channel, time=0))
            track.append(mido.Message("control_change", control=7, value=volume, channel=channel, time=0))
            track.append(mido.Message("control_change", control=10, value=pan, channel=channel, time=0))
            track.append(mido.Message("control_change", control=91, value=reverb, channel=channel, time=0))
        now = 0
        for tick, _order, message in sorted(self.events, key=lambda e: (e[0], e[1])):
            track.append(message.copy(time=tick - now))
            now = tick
        midi.save(path)

    def seconds(self, beats):
        return beats * 60.0 / self.tempo


def melody(song, start_bar, channel, velocity, transpose=0, stretch=1.0, jitter=0.02, bars=THEME):
    beat = start_bar * 4
    for bar in bars:
        for name, length in bar:
            song.note(beat, length * stretch, P[name] + transpose, velocity, channel, jitter)
            beat += length * stretch


def pad(song, start_bar, channel, velocity, chords=CHORDS, octave=0, bar_beats=4):
    for index, chord in enumerate(chords):
        for name in CHORD_TONES[chord][:3]:
            song.note((start_bar + index) * bar_beats, bar_beats, P[name] + octave, velocity, channel)


def arpeggio(song, start_bar, channel, velocity, chords=CHORDS, pattern=(0, 1, 2, 3, 2, 1, 2, 1), step=0.5, octave=0):
    for index, chord in enumerate(chords):
        tones = [P[n] + octave for n in CHORD_TONES[chord]] + [P[CHORD_TONES[chord][2]] + 12 + octave]
        for k, slot in enumerate(pattern):
            song.note((start_bar + index) * 4 + k * step, step * 1.6, tones[slot % len(tones)], velocity - (6 if k % 2 else 0), channel, 0.01)


def bass(song, start_bar, channel, velocity, chords=CHORDS, beats=(0, 2.5)):
    for index, chord in enumerate(chords):
        for b in beats:
            song.note((start_bar + index) * 4 + b, 1.2, BASS[chord], velocity, channel)


def render(song, name, loop_beats=None, gain=0.55, target_db=-15.0, folder=OUT):
    folder.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        mid = Path(tmp) / f"{name}.mid"
        wav = Path(tmp) / f"{name}.wav"
        song.write(mid)
        subprocess.run(["fluidsynth", "-ni", "-g", str(gain), "-r", str(RATE), "-F", str(wav), str(SOUNDFONT), str(mid)], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        with wave.open(str(wav)) as handle:
            frames = handle.readframes(handle.getnframes())
            data = np.frombuffer(frames, dtype=np.int16).reshape(-1, 2).astype(np.float32) / 32768.0
        if loop_beats:
            length = int(round(song.seconds(loop_beats) * RATE))
            data = data[length:2 * length]
        else:
            data = data[: int(np.max(np.nonzero(np.max(np.abs(data), axis=1) > 1e-4)) + RATE * 0.2)]
            fade = min(len(data), int(RATE * 0.25))
            data[-fade:] *= np.linspace(1.0, 0.0, fade)[:, None]
        rms = np.sqrt(np.mean(data ** 2)) + 1e-9
        data *= min(10 ** (target_db / 20.0) / rms, 0.89 / (np.max(np.abs(data)) + 1e-9))
        out_wav = Path(tmp) / "final.wav"
        with wave.open(str(out_wav), "wb") as handle:
            handle.setnchannels(2)
            handle.setsampwidth(2)
            handle.setframerate(RATE)
            handle.writeframes((np.clip(data, -1, 1) * 32767).astype(np.int16).tobytes())
        target = folder / f"{name}.ogg"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(out_wav), "-c:a", "libvorbis", "-q:a", "5", str(target)], check=True)
        print(f"MUSIC_OK {name}: {len(data) / RATE:.1f}s -> {target.relative_to(ROOT)}")


def twice(build, tempo, bars):
    """Builds the arrangement twice in a row (plus a tail) for seamless loop extraction."""
    song = Song(tempo)
    build(song, 0)
    build(song, bars)
    song.note(bars * 2 * 4, 4, "D3", 1, 15)
    song.note(bars * 2 * 4 + 6, 0.5, "D3", 1, 15)
    return song


# ---------------------------------------------------------------- pieces

def village():
    def build(song, bar):
        song.program(0, 73, 96, 70, 70)    # flute (sáo)
        song.program(1, 107, 88, 50, 60)   # koto (đàn tranh)
        song.program(2, 49, 70, 64, 90)    # slow strings
        song.program(3, 45, 80, 70, 40)    # pizzicato bass
        song.program(4, 115, 50, 80, 50)   # woodblock
        song.program(5, 15, 78, 40, 60)    # dulcimer (tam thập lục)
        if bar == 0:
            melody(song, bar, 0, 82)
        else:
            melody(song, bar, 5, 84)
            melody(song, bar, 0, 60, transpose=12)
        arpeggio(song, bar, 1, 62)
        pad(song, bar, 2, 44)
        bass(song, bar, 3, 70)
        for k in range(16):
            for beat in (1, 3):
                song.note((bar + k) * 4 + beat, 0.2, "D5", 38 if beat == 1 else 30, 4)
    return twice(build, 92, 16), 64 * 1


def explore():
    def build(song, bar):
        song.program(0, 77, 100, 64, 90)   # shakuhachi
        song.program(1, 46, 76, 40, 70)    # harp
        song.program(2, 49, 76, 64, 100)   # slow strings
        song.program(3, 8, 50, 90, 100)    # celesta sparkles
        song.program(4, 42, 64, 50, 70)    # cello drone
        melody(song, bar, 0, 74 if bar == 0 else 68, transpose=0 if bar == 0 else 12, jitter=0.05)
        arpeggio(song, bar, 1, 52, pattern=(0, 2, 1, 3), step=1.0)
        pad(song, bar, 2, 46)
        for k in range(16):
            song.note((bar + k) * 4, 4, BASS[CHORDS[k]], 46, 4)
            if k % 2 == 1:
                tones = ["D5", "F5", "A5", "C6", "G5"]
                song.note((bar + k) * 4 + 2.5, 1.0, tones[(k * 3) % len(tones)], 34, 3)
    return twice(build, 72, 16), 64


def bamboo():
    def build(song, bar):
        song.program(0, 75, 92, 60, 85)    # pan flute
        song.program(1, 107, 70, 45, 60)   # koto
        song.program(2, 48, 60, 64, 95)    # strings
        song.program(3, 12, 54, 85, 60)    # marimba (bamboo knocks)
        song.program(4, 77, 70, 75, 100)   # shakuhachi echo
        melody(song, bar, 0, 72, jitter=0.03)
        if bar > 0:
            melody(song, bar + 0.5, 4, 40, transpose=-12, jitter=0.04)
        arpeggio(song, bar, 1, 48, pattern=(0, 1, 2, 1), step=1.0)
        pad(song, bar, 2, 40)
        for k in range(16):
            for beat, pitch in ((0.5, "A4"), (1.5, "D5"), (3.0, "G4")):
                if (k + int(beat)) % 3 != 2:
                    song.note((bar + k) * 4 + beat, 0.3, pitch, 34, 3)
    return twice(build, 76, 16), 64


def temple():
    def build(song, bar):
        song.program(0, 77, 92, 64, 110)   # shakuhachi
        song.program(1, 14, 70, 50, 110)   # tubular bells
        song.program(2, 49, 80, 64, 110)   # strings
        song.program(3, 43, 70, 64, 90)    # contrabass
        melody(song, bar, 0, 66, stretch=1.0, jitter=0.06, bars=THEME[8:16] + THEME[0:8])
        pad(song, bar, 2, 48, octave=-12)
        for k in range(16):
            song.note((bar + k) * 4, 4, "D2", 52, 3)
            if k % 4 == 0:
                song.note((bar + k) * 4, 6, "D4", 58, 1)
                song.note((bar + k) * 4 + 0.02, 6, "A3", 40, 1)
    return twice(build, 60, 16), 64


def combat():
    def build(song, bar):
        song.program(0, 48, 96, 64, 50)    # strings (theme fragments)
        song.program(1, 106, 92, 40, 40)   # shamisen ostinato
        song.program(2, 116, 110, 64, 40)  # taiko
        song.program(3, 43, 92, 64, 30)    # contrabass
        song.program(4, 115, 70, 90, 40)   # woodblock
        song.program(5, 73, 84, 80, 60)    # flute accents
        chords = ["D", "D", "C", "D", "F", "C", "D", "D", "D", "D", "Bb", "C", "D", "F", "C", "D"]
        riff = ["D4", "D4", "A4", "D4", "C5", "D4", "A4", "G4"]
        for k, chord in enumerate(chords):
            shift = {"D": 0, "C": -2, "F": 3, "Bb": -4}[chord]
            for i, name in enumerate(riff):
                song.note((bar + k) * 4 + i * 0.5, 0.4, P[name] + shift, 84 if i % 4 == 0 else 66, 1)
            for i in range(8):
                song.note((bar + k) * 4 + i * 0.5, 0.45, BASS[chord] if chord in BASS else "D2", 80 if i % 2 == 0 else 60, 3)
            for beat, velocity in ((0, 120), (0.75, 70), (1.5, 96), (2, 108), (2.75, 70), (3, 100), (3.5, 86)):
                song.note((bar + k) * 4 + beat, 0.4, "D2" if beat in (0, 2) else "G2", velocity, 2)
            if k % 4 == 3:
                for i in range(4):
                    song.note((bar + k) * 4 + 3 + i * 0.25, 0.2, "A4", 70 + i * 8, 4)
        for k in range(0, 16, 2):
            phrase = THEME[(k + (8 if bar else 0)) % 16]
            beat = (bar + k) * 4
            for name, length in phrase:
                song.note(beat, length * 0.5, P[name] + 12, 76, 0)
                beat += length * 0.5
        for k in (6, 14):
            song.note((bar + k) * 4 + 2, 2, "D6", 70, 5)
    return twice(build, 138, 16), 64


def boss():
    def build(song, bar):
        song.program(0, 48, 100, 64, 60)   # strings
        song.program(1, 106, 90, 40, 40)   # shamisen
        song.program(2, 116, 120, 64, 50)  # taiko
        song.program(3, 43, 100, 64, 40)   # contrabass
        song.program(4, 47, 96, 64, 70)    # timpani
        song.program(5, 77, 92, 80, 80)    # shakuhachi cries
        song.program(6, 55, 70, 64, 70)    # orchestra hit
        chords = ["D", "Eb", "D", "C", "D", "Eb", "Bb", "C", "D", "Eb", "D", "C", "Bb", "C", "Eb", "D"]
        riff = ["D4", "Eb4", "D4", "A4", "D4", "C5", "Bb4", "A4"]
        for k, chord in enumerate(chords):
            shift = {"D": 0, "Eb": 1, "C": -2, "Bb": -4}[chord]
            for i, name in enumerate(riff):
                song.note((bar + k) * 4 + i * 0.5, 0.4, P[name] + shift, 88 if i % 4 == 0 else 68, 1)
                song.note((bar + k) * 4 + i * 0.5, 0.45, P["D2"] + shift, 84 if i % 2 == 0 else 62, 3)
            for beat, velocity in ((0, 124), (0.5, 80), (1, 100), (1.75, 80), (2, 118), (2.5, 90), (3, 104), (3.25, 76), (3.5, 96), (3.75, 88)):
                song.note((bar + k) * 4 + beat, 0.3, "D2" if beat in (0, 2) else "A2", velocity, 2)
            if k % 4 == 0:
                song.note((bar + k) * 4, 1.0, "D4", 90, 6)
                for i in range(8):
                    song.note((bar + k) * 4 + 2 + i * 0.25, 0.25, "D3", 60 + i * 6, 4)
        for k in range(0, 16, 4):
            beat = (bar + k) * 4
            for name, length in THEME[(k // 4 * 4 + 8) % 16] + THEME[(k // 4 * 4 + 9) % 16]:
                song.note(beat, length, P[name] + 12, 84, 5, 0.01)
                song.note(beat, length, P[name] - 12, 70, 0)
                beat += length
    return twice(build, 150, 16), 64


def title():
    def build(song, bar):
        song.program(0, 73, 92, 64, 100)   # flute
        song.program(1, 15, 84, 44, 90)    # dulcimer
        song.program(2, 49, 84, 64, 110)   # strings
        song.program(3, 107, 64, 84, 90)   # koto
        song.program(4, 42, 70, 50, 90)    # cello
        if bar == 0:
            melody(song, bar, 1, 74, jitter=0.03)
        else:
            melody(song, bar, 0, 78, jitter=0.04)
            melody(song, bar, 4, 50, transpose=-12)
        pad(song, bar, 2, 52)
        arpeggio(song, bar, 3, 42, pattern=(0, 1, 2, 3, 4, 3), step=4.0 / 6.0)
    return twice(build, 60, 16), 64


# ---------------------------------------------------------------- stingers

def stinger(name, notes, tempo=90, programs=None):
    song = Song(tempo)
    for channel, settings in (programs or {}).items():
        song.program(channel, *settings)
    for beat, length, pitch, velocity, channel in notes:
        song.note(beat, length, pitch, velocity, channel)
    render(song, name, None, target_db=-14.0, folder=STINGERS)


def stingers():
    koto_flute = {0: (107, 100, 64, 80), 1: (73, 96, 64, 90), 2: (49, 70, 64, 100)}
    stinger("quest_complete", [(i * 0.25, 1.5, p, 80, 0) for i, p in enumerate(["D4", "F4", "G4", "A4", "C5", "D5"])] +
            [(1.5, 2.5, "A5", 84, 1), (1.5, 3, "D4", 60, 2), (1.5, 3, "A4", 54, 2)], 96, koto_flute)
    stinger("discovery", [(0, 1, "A4", 74, 1), (1, 0.5, "C5", 74, 1), (1.5, 0.5, "D5", 74, 1), (2, 2.5, "A5", 80, 1), (0, 4, "D4", 50, 2), (0, 4, "A4", 44, 2)], 84, koto_flute)
    stinger("level_up", [(i * 0.18, 1.2, p, 86, 0) for i, p in enumerate(["D5", "F5", "G5", "A5", "C6", "D6"])], 100, {0: (8, 110, 64, 90)})
    stinger("victory", [(0, 0.5, "D2", 120, 0), (0.75, 0.5, "D2", 100, 0), (1.5, 3, "D4", 80, 1), (1.5, 3, "A4", 74, 1), (1.5, 3, "F4", 70, 1),
                        (1.5, 1, "A5", 90, 2), (2.5, 0.5, "C6", 90, 2), (3, 3, "D6", 96, 2)], 100, {0: (116, 120, 64, 50), 1: (48, 100, 64, 90), 2: (73, 100, 64, 90)})
    stinger("death", [(0, 3, "D3", 80, 0), (0, 3, "A3", 70, 0), (1, 3, "Bb2", 70, 0), (2, 4, "A2", 70, 0), (0, 2, "D5", 60, 1), (2, 3, "A4", 56, 1)], 60,
            {0: (49, 100, 64, 100), 1: (77, 90, 64, 100)})
    stinger("shrine_bell", [(0, 6, "D4", 96, 0), (0.02, 6, "A3", 70, 0), (0.5, 3, "D6", 50, 1), (1.0, 3, "A5", 44, 1)], 70, {0: (14, 110, 64, 110), 1: (8, 100, 64, 110)})
    stinger("temple_bell", [(0, 10, "D2", 120, 0), (0.01, 10, "D3", 90, 0), (0.02, 8, "A3", 60, 0)], 50, {0: (14, 127, 64, 127)})
    stinger("chime_1", [(0, 3, "D5", 100, 0), (0.05, 3, "A5", 60, 0)], 80, {0: (108, 120, 64, 100)})
    stinger("chime_2", [(0, 3, "A4", 96, 0), (0.05, 3, "E5", 50, 0)], 80, {0: (14, 120, 64, 100)})
    stinger("chime_3", [(0, 3, "F5", 100, 0), (0.05, 3, "C6", 60, 0)], 80, {0: (10, 120, 64, 100)})
    stinger("chime_solved", [(i * 0.2, 2, p, 90, 0) for i, p in enumerate(["D5", "A4", "F5", "D6"])] + [(0.9, 4, "D4", 70, 1)], 80, {0: (10, 110, 64, 110), 1: (14, 100, 64, 110)})
    stinger("flute_call", [(0, 1, "D5", 70, 0), (1, 0.5, "C5", 68, 0), (1.5, 0.5, "A4", 66, 0), (2, 1, "G4", 66, 0), (3, 2, "A4", 70, 0)], 80, {0: (73, 110, 64, 120)})


if __name__ == "__main__":
    for builder, name in ((village, "village"), (explore, "explore"), (bamboo, "bamboo"), (temple, "temple"), (combat, "combat"), (boss, "boss"), (title, "title")):
        song, loop_beats = builder()
        render(song, name, loop_beats)
    stingers()
