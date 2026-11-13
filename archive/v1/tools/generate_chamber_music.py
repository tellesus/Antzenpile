"""Historical task-068 prototype; Python standard library only.

Current four-layer music: tools/music/compose_colony_music.py.

Four two-second nursery phrases and a sparse half-second wooden rhythm share
the existing eight-second A/E arrangement. No composition happens at runtime.
"""
from math import exp, pi, sin
from pathlib import Path
from struct import pack
import wave

RATE = 22050
FRAMES = RATE * 8
OUT = Path(__file__).resolve().parents[1] / "builds" / "historical_music_068"


def nursery(time):
    note = (440, 660, 550, 660)[int(time // 2)]
    local = time % 2
    envelope = min(1.0, local / 0.06, (2 - local) / 0.3)
    return envelope * (0.025 * sin(2 * pi * note * local)
                       + 0.006 * sin(4 * pi * note * local))


def midden(time):
    beat = int(time // 0.5)
    local = time % 0.5
    amplitude = (0.035, 0.009, 0.015, 0.009)[beat % 4]
    envelope = min(1.0, local / 0.006, (0.5 - local) / 0.05) * exp(-local * 26)
    return amplitude * envelope * (sin(2 * pi * 82.5 * local)
                                    + 0.3 * sin(2 * pi * 330 * local))


def render(name, voice):
    samples = b"".join(pack("<h", round(32767 * voice(index / RATE)))
                       for index in range(FRAMES))
    with wave.open(str(OUT / name), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(samples)


if __name__ == "__main__":
    render("nursery_loop.wav", nursery)
    render("midden_loop.wav", midden)
