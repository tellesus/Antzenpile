"""Author a short original high, delicate discovery cue; no runtime synthesis."""
from math import exp, pi, sin
from pathlib import Path
from struct import pack
import wave

RATE = 22050
DURATION = 0.26
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'audio' / 'returned_discovery.wav'
with wave.open(str(OUT), 'wb') as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2)
    wav.setframerate(RATE)
    samples = bytearray()
    for index in range(round(RATE * DURATION)):
        time = index / RATE
        envelope = min(1.0, time / 0.008, (DURATION-time) / 0.015) * exp(-time*14)
        value = envelope * (0.16*sin(2*pi*1100*time) + 0.065*sin(2*pi*1650*time))
        samples.extend(pack('<h',round(32767*value)))
    wav.writeframes(samples)
