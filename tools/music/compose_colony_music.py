"""Original 16-bar/80-BPM chamber arrangement; render offline with NumPy.

Run fetch_samples.py once, then this script. Sources/seed/score are fixed.
Godot plays only four finished WAVs; no sampler, NumPy or network at runtime.
"""
from hashlib import sha256
import json
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]
RATE = 44100
BPM = 80
BEAT = 60 / BPM
BAR = BEAT * 4
DURATION = BAR * 16
FRAMES = round(DURATION * RATE)
STEMS = ["base_loop", "growth_loop", "nursery_loop", "midden_loop"]
# A-minor/C-major family: four spacious phrases, with a gentle return to home.
CHORDS = [
    (45, (57, 60, 64, 67)), (41, (57, 60, 64, 65)),
    (48, (55, 60, 62, 64)), (43, (55, 57, 62, 67)),
    (45, (57, 60, 64, 67)), (41, (57, 60, 64, 65)),
    (48, (55, 60, 64, 67)), (43, (55, 59, 62, 67)),
    (38, (57, 60, 62, 65)), (41, (57, 60, 64, 65)),
    (45, (57, 60, 64, 67)), (40, (55, 59, 62, 64)),
    (41, (57, 60, 64, 65)), (48, (55, 60, 62, 64)),
    (43, (55, 57, 62, 67)), (45, (57, 60, 64, 69)),
]


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def read_sample(name):
    with wave.open(str(ROOT / "samples" / name), "rb") as source:
        data = source.readframes(source.getnframes())
        width, channels, rate = source.getsampwidth(), source.getnchannels(), source.getframerate()
    if width == 3:
        raw = np.frombuffer(data, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        values = raw[:, 0] | raw[:, 1] << 8 | raw[:, 2] << 16
        values = (values ^ 0x800000) - 0x800000
        values = values.astype(np.float64) / 8388608
    elif width == 2:
        values = np.frombuffer(data, dtype="<i2").astype(np.float64) / 32768
    else:
        raise ValueError("Unsupported source PCM format")
    values = values.reshape(-1, channels).mean(axis=1)
    values -= values.mean()
    peak = np.max(np.abs(values))
    # Remove recording lead-in while retaining the soft attack, not the peak.
    onset = np.flatnonzero(np.abs(values) > peak * 0.015)[0]
    values = values[max(0, onset - round(rate * 0.004)):]
    if rate != RATE:
        values = np.interp(np.arange(0, len(values), rate / RATE), np.arange(len(values)), values)
    return values / max(peak, 1e-9)


def envelope(size, attack, release):
    gain = np.ones(size)
    a, r = min(size, round(attack * RATE)), min(size, round(release * RATE))
    if a: gain[:a] *= np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    if r: gain[-r:] *= np.cos(np.linspace(0, np.pi / 2, r)) ** 2
    return gain


def pitched(source, root, note, seconds, cents=0):
    step = 2 ** ((note - root + cents / 100) / 12)
    positions = np.arange(min(round(seconds * RATE), int(len(source) / step))) * step
    tone = np.interp(positions, np.arange(len(source)), source)
    return tone * envelope(len(tone), 0.008, 0.35)


def add(track, sound, seconds, gain):
    # Circular overlap-add preserves all decay/reverb across the loop boundary.
    start = round(seconds * RATE) % FRAMES
    sound = sound[:FRAMES] * gain
    first = min(len(sound), FRAMES - start)
    track[start:start + first] += sound[:first]
    if first < len(sound): track[:len(sound) - first] += sound[first:]


def pad(note, seconds, bass=False):
    t = np.arange(round(seconds * RATE)) / RATE
    vibrato = 0.0005 * np.sin(2 * np.pi * 0.17 * t)
    phase = 2 * np.pi * hz(note) * (t + vibrato)
    value = np.sin(phase) + 0.12 * np.sin(phase * 2) + 0.025 * np.sin(phase * 3)
    return value * envelope(len(t), 0.28 if bass else 0.8, 1.1)


def room(track):
    # Same modest room for all voices, baked; no runtime reverb node.
    result = track.copy()
    for seconds, amount in [(0.113, 0.10), (0.239, 0.075), (0.397, 0.045)]:
        result += np.roll(track, round(seconds * RATE)) * amount
    return result


def write_wav(path, track):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as target:
        target.setnchannels(1)
        target.setsampwidth(2)
        target.setframerate(RATE)
        target.writeframes(np.rint(np.clip(track, -1, 1) * 32767).astype("<i2").tobytes())


def compose():
    manifest = json.loads((ROOT / "sample_manifest.json").read_text())
    for row in manifest["samples"]:
        if sha256((ROOT / "samples" / row["file"]).read_bytes()).hexdigest() != row["sha256"]:
            raise ValueError("Source checksum mismatch: " + row["file"])
    samples = {name: read_sample(name + ".wav") for name in
               ["bass_drum", "harp_c4", "marimba_c4", "timpani", "frame_drum", "woodblock", "shaker"]}
    tracks = [np.zeros(FRAMES) for _ in STEMS]
    base, food, nursery, midden = tracks
    for bar, (root, chord) in enumerate(CHORDS):
        at = bar * BAR
        intensity = [0.90, 0.80, 0.94, 0.76][bar % 4]
        for note in chord:
            add(base, pad(note - 12, BAR + 1.1), at, 0.012 * intensity)
        add(base, pad(root - 12, BAR + 0.6, True), at + 0.03, 0.036)
        add(base, samples["bass_drum"][:RATE * 2] * envelope(min(len(samples["bass_drum"]), RATE * 2), 0.004, 0.6), at + 0.1, 0.10 * intensity)
        if bar % 4 in [0, 2]:
            add(base, samples["bass_drum"][:RATE] * envelope(min(len(samples["bass_drum"]), RATE), 0.004, 0.3), at + BEAT * 2.55, 0.045)
        # Soft timpani answers only a few phrases, tuned from the upstream SFZ
        # keycenter=44/tune=83 recording; no martial roll or constant boom.
        if bar in [3, 7, 11, 15]:
            add(base, pitched(samples["timpani"], 44, root if root >= 41 else root + 12, 2.4, 83), at + BEAT * 2.8, 0.074)
        pattern = [0, 2, 1, 3] if bar % 2 == 0 else [0, 1, 3]
        for index, degree in enumerate(pattern):
            add(food, pitched(samples["harp_c4"], 60, chord[degree], 3.1),
                at + BEAT * (0.35 + index * 0.8) + (0.012 if index % 2 else 0),
                (0.070 - index * 0.009) * intensity)
        # Rest bars and two-note answers give the melody room to breathe.
        if bar not in [3, 7, 11, 15]:
            order = [2, 1] if bar % 4 < 2 else [3, 2]
            for index, degree in enumerate(order):
                note = chord[degree] + (12 if bar in [6, 10, 13] else 0)
                add(nursery, pitched(samples["marimba_c4"], 60, note, 2.7),
                    at + BEAT * (0.75 + index * 1.6), 0.085 if index == 0 else 0.060)
        for beat, gain in [(1.05, 0.040), (3.1, 0.027)]:
            add(midden, pitched(samples["frame_drum"], 60, 60, 0.9), at + BEAT * beat, gain * intensity)
        if bar % 4 != 3:
            add(midden, pitched(samples["woodblock"], 60, 58 + bar % 3, 0.7), at + BEAT * 2.5, 0.020)
        for beat in [0.5, 1.5, 2.5, 3.5]:
            add(midden, pitched(samples["shaker"], 60, 60, 0.20), at + BEAT * beat, 0.016 * intensity)
    tracks = [room(track) for track in tracks]
    # One common gain preserves every combination's intended balance/headroom.
    combined = sum(tracks)
    gain = 0.32 / max(np.max(np.abs(combined)), 1e-9)
    return [track * gain for track in tracks]


def main():
    tracks = compose()
    for name, track in zip(STEMS, tracks):
        write_wav(REPO / "assets/audio" / (name + ".wav"), track)
    evidence = {"bpm": BPM, "bars": 16, "duration_seconds": DURATION,
                "sample_rate": RATE, "frames": FRAMES, "channels": 1, "combinations": []}
    previews = REPO / "builds/music_review"
    for mask in range(8):
        mix = tracks[0].copy()
        names = ["base"]
        for index in range(3):
            if mask & (1 << index):
                mix += tracks[index + 1]
                names.append(["food", "nursery", "midden"][index])
        # Mirrors the existing -4 dB runtime mix; no per-file normalization.
        mix *= 10 ** (-4 / 20)
        write_wav(previews / ("_".join(names) + ".wav"), mix)
        evidence["combinations"].append({"layers": names, "peak": float(np.max(np.abs(mix))),
            "rms": float(np.sqrt(np.mean(mix ** 2))), "boundary_delta": float(abs(mix[0] - mix[-1]))})
    for name, track in zip(STEMS, tracks):
        assert np.isfinite(track).all() and np.max(np.abs(track)) < 0.6, name
        assert abs(track[0] - track[-1]) < 0.003, name
    assert all(row["peak"] < 0.6 and row["boundary_delta"] < 0.003 for row in evidence["combinations"])
    (REPO / "docs/evidence/card092_music.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps(evidence, indent=2))


if __name__ == "__main__":
    main()
