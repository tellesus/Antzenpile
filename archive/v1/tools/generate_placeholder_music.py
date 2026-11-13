"""Historical task-019 prototype; not the current soundtrack authoring command.

Current four-layer music: tools/music/compose_colony_music.py.
"""

from math import pi, sin
from pathlib import Path
from struct import pack
import wave


RATE = 22_050
DURATION = 8
FRAMES = RATE * DURATION
OUT = Path(__file__).resolve().parents[1] / "builds" / "historical_music_019"


def render(name: str, tones: tuple[tuple[int, float], ...]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        samples = bytearray()
        for index in range(FRAMES):
            time = index / RATE
            # All frequencies and the slow pulse complete whole cycles in 8 s.
            pulse = 0.62 + 0.38 * sin(2 * pi * 0.25 * time - pi / 2)
            value = sum(weight * sin(2 * pi * frequency * time) for frequency, weight in tones)
            samples.extend(pack("<h", round(32767 * pulse * value)))
        wav.writeframes(samples)


if __name__ == "__main__":
    render("base_loop.wav", ((55, 0.052), (110, 0.037), (165, 0.021)))
    render("growth_loop.wav", ((220, 0.027), (330, 0.017), (440, 0.009)))
