"""Generate the original soft returned-loss cue; standard library only."""
import math
import struct
import wave
from pathlib import Path

rate = 22050
duration = 0.42
target = Path(__file__).resolve().parents[1] / "assets/audio/returned_alarm.wav"
frames = bytearray()
for index in range(round(rate * duration)):
    time = index / rate
    envelope = math.sin(math.pi * time / duration) ** 2
    sample = envelope * (0.17 * math.sin(2 * math.pi * 330 * time)
                         + 0.10 * math.sin(2 * math.pi * 392 * time))
    frames.extend(struct.pack("<h", round(sample * 32767)))
with wave.open(str(target), "wb") as output:
    output.setparams((1, 2, rate, 0, "NONE", "not compressed"))
    output.writeframes(frames)
print(f"Generated {target.name}: {duration:.2f}s original mono cue")
