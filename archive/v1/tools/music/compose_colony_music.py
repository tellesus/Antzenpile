"""Original 32-bar/90-BPM stereo colony arrangement; render offline with NumPy.

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
BPM = 90
BEAT = 60 / BPM
BAR = BEAT * 4
DURATION = BAR * 32
FRAMES = round(DURATION * RATE)
STEMS = ["base_loop", "growth_loop", "nursery_loop", "midden_loop"]
# Two-bar harmonic rooms: D-minor/modal colour, suspended rather than urgent.
CHORDS = [
    (38, (53, 57, 60, 64)), (34, (53, 57, 60, 62)),
    (41, (53, 57, 60, 67)), (36, (55, 60, 62, 64)),
    (43, (53, 57, 62, 65)), (38, (53, 57, 60, 64)),
    (34, (53, 57, 60, 65)), (45, (55, 57, 62, 64)),
    (38, (53, 57, 60, 64)), (41, (53, 57, 60, 67)),
    (36, (55, 60, 62, 64)), (43, (53, 57, 62, 65)),
    (34, (53, 57, 60, 62)), (41, (53, 57, 60, 67)),
    (45, (55, 57, 62, 64)), (38, (53, 57, 60, 62)),
]
# A rising question, an answer, an opening-out, a sparse homeward phrase.
MELODY = [
    [(0.8,69),(2.5,72)],[(1.3,74)],[(0.7,69),(2.4,65)],[],
    [(1,67),(2.7,69)],[(1.5,65)],[(0.9,64),(2.6,62)],[],
    [(0.8,69),(2.5,72)],[(1.3,77)],[(0.7,76),(2.4,72)],[],
    [(1,74),(2.7,69)],[(1.5,67)],[(0.9,64),(2.6,62)],[],
    [(0.8,74),(2.5,76)],[(1.3,77)],[(0.7,76),(2.4,72)],[],
    [(1,67),(2.7,72)],[(1.5,69)],[(0.9,65),(2.6,62)],[],
    [(1,65)],[(2,69)],[(1,72),(2.7,69)],[],
    [(1,67)],[(1.8,64)],[(0.8,65),(2.4,62)],[],
]
RUNTIME_GAIN = 10 ** (-4 / 20)


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


def add(track, sound, seconds, gain, pan=0):
    # Equal-power placement, one sample clock, circular note/room tails.
    start = round(seconds * RATE) % len(track)
    stereo = sound[:len(track), None] * np.array([
        np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)]) * gain
    first = min(len(stereo), len(track) - start)
    track[start:start + first] += stereo[:first]
    if first < len(stereo): track[:len(stereo) - first] += stereo[first:]


def pad(note, seconds, bass=False):
    t = np.arange(round(seconds * RATE)) / RATE
    f = hz(note)
    value = np.sin(2 * np.pi * f * t)
    if not bass:
        value = (value * 0.55 + 0.25 * np.sin(2*np.pi*f*1.0009*t + 0.3)
                 + 0.16 * np.sin(2*np.pi*f*0.9991*t) + 0.045 * np.sin(2*np.pi*f*2*t))
        value *= 0.84 + 0.16 * np.sin(2*np.pi*0.23*t + note)
    return value * envelope(len(t), 0.12 if bass else 0.9, 0.6 if bass else 1.6)


def glass(note, seconds):
    t = np.arange(round(seconds * RATE)) / RATE
    f = hz(note)
    value = (np.sin(2*np.pi*f*t)*np.exp(-t*2)
             + 0.12*np.sin(2*np.pi*f*2.002*t)*np.exp(-t*4))
    return value * envelope(len(t), 0.025, 0.4)


def room(track):
    result = track.copy()
    for beats, amount in [(0.375,0.13),(0.75,0.075),(1.375,0.04)]:
        result += np.roll(track[:, ::-1], round(beats*BEAT*RATE), axis=0)*amount
    for seconds, amount in [(0.091,0.09),(0.163,0.06),(0.277,0.035)]:
        result += np.roll(track, round(seconds*RATE), axis=0)*amount
    result -= result.mean(axis=0)
    # A 6ms cadence breath avoids a wrap click and a nonzero start sample.
    return result * envelope(len(result),0.006,0.006)[:,None]


def soften_shaker(source):
    # Symmetric windowed-sinc filter, baked offline; leave low drums untouched.
    taps = np.arange(129) - 64
    kernel = 2 * 2400 / RATE * np.sinc(2 * 2400 / RATE * taps) * np.hanning(129)
    kernel /= kernel.sum()
    return np.convolve(source, kernel, mode="same")


def write_wav(path, track):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as target:
        target.setnchannels(2)
        target.setsampwidth(2)
        target.setframerate(RATE)
        target.writeframes(np.rint(np.clip(track, -1, 1) * 32767).astype("<i2").tobytes())


def compose():
    manifest = json.loads((ROOT / "sample_manifest.json").read_text())
    for row in manifest["samples"]:
        if sha256((ROOT / "samples" / row["file"]).read_bytes()).hexdigest() != row["sha256"]:
            raise ValueError("Source checksum mismatch: " + row["file"])
    samples = {name: read_sample(name + ".wav") for name in
               ["bass_drum", "harp_c4", "marimba_c4", "timpani", "frame_drum", "shaker"]}
    samples["shaker"] = soften_shaker(samples["shaker"])
    tracks = [np.zeros((FRAMES,2)) for _ in STEMS]
    base, food, nursery, midden = tracks
    rng = np.random.default_rng(190)
    counts = dict(harp=0, melody=0, frame_drum=0, shaker=0, woodblock=0)
    for bar in range(32):
        at = bar * BAR
        root, chord = CHORDS[bar // 2]
        section = bar // 8
        intensity = [0.86,0.96,1.0,0.78][section]
        if bar % 2 == 0:
            for index,note in enumerate(chord):
                add(base,pad(note-12,BAR*2+1.6),at,0.023*intensity,[-0.5,0.35,-0.25,0.55][index])
        add(base,pad(root-12,BAR+0.5,True),at+0.025,0.045)
        add(base,pitched(samples["bass_drum"],60,60,1.8),at+0.06,0.075*intensity)
        if bar % 4 in [0,2]: add(base,pad(root,BEAT*0.9,True),at+BEAT*2.55,0.024)
        if bar in [7,15,23]:
            add(base,pitched(samples["timpani"],44,root+12,2.4,83),at+BEAT*2.75,0.05,-0.12)
        pattern = ([0,2,1,3],[2,1,3],[0,1,2,3,2],[1,3])[section]
        if bar % 4 != 3:
            for index,degree in enumerate(pattern):
                note = chord[degree] + (12 if section == 2 and index % 2 else 0)
                when = at+BEAT*(0.32+index*(3.1/len(pattern)))+rng.uniform(-0.012,0.012)
                gain = 0.11*intensity*(1-index*0.09)
                pan = -0.4+0.8*(index%3)/2
                add(food,pitched(samples["harp_c4"],60,note,3.2),when,gain,pan)
                if index == 0 and bar % 4 == 0:
                    add(food,glass(note+12,2.6),when+BEAT*1.5,0.016,-pan)
                counts["harp"] += 1
        for index,(beat,note) in enumerate(MELODY[bar]):
            when = at+BEAT*beat+rng.uniform(-0.008,0.008)
            add(nursery,pitched(samples["marimba_c4"],60,note,3),when,
                0.11*intensity*(1-index*0.18),0.22 if index == 0 else -0.25)
            if bar % 4 == 1: add(nursery,pad(note-12,BAR+1),when+BEAT*0.25,0.018,-0.35)
            counts["melody"] += 1
        if bar % 8 != 7:
            for beat,gain,pan in [(1.15,0.04,-0.25),(3.05,0.027,0.3)]:
                if section == 3 and beat > 2: continue
                add(midden,pitched(samples["frame_drum"],60,58,0.9),at+BEAT*beat,gain*intensity,pan)
                counts["frame_drum"] += 1
        if bar in [2,5,10,13,18,21,26,29]:
            add(midden,pitched(samples["shaker"],60,59,0.23),at+BEAT*[2.7,3.3,1.7,2.4][bar%4],0.008,0.35)
            counts["shaker"] += 1
    tracks = [room(track) for track in tracks]
    # Calibrate once across all subsets, never normalize voices independently.
    peak = max(np.max(np.abs(tracks[0]+sum((tracks[i+1] for i in range(3)
               if mask & (1<<i)),np.zeros_like(tracks[0])))) for mask in range(8))
    gain = 0.54/(peak*RUNTIME_GAIN)
    return [track*gain for track in tracks],gain,counts


def cues():
    result = {}
    for name,seconds,notes in [("returned_discovery",0.28,[(0,74),(0.085,81)]),
                               ("returned_alarm",0.42,[(0,62),(0.13,57)])]:
        track = np.zeros((round(seconds*RATE),2))
        for at,note in notes:
            sound = glass(note,seconds-at)*envelope(round((seconds-at)*RATE),0.018,0.1)
            add(track,sound,at,0.3,-0.08 if at == 0 else 0.08)
        result[name] = track*envelope(len(track),0.008,0.025)[:,None]
    return result


def metrics(track):
    return dict(peak=float(np.max(np.abs(track))),rms=float(np.sqrt(np.mean(track**2))),
        dc=list(map(float,track.mean(axis=0))),
        boundary_delta=float(np.max(np.abs(track[0]-track[-1]))),
        stereo_correlation=float(np.corrcoef(track.T)[0,1]),
        side_rms=float(np.sqrt(np.mean(((track[:,0]-track[:,1])/2)**2))))


def main():
    tracks,gain,counts = compose()
    evidence = dict(bpm=BPM,bars=32,duration_seconds=DURATION,sample_rate=RATE,
        frames=FRAMES,channels=2,pcm_bits=16,mix_gain=gain,events=counts,
        shaker_lowpass_hz=2400,stems={},combinations=[])
    for name,track in zip(STEMS,tracks):
        assert np.isfinite(track).all() and np.max(np.abs(track)) < 0.9,name
        path = REPO / "assets/audio" / (name+".wav")
        write_wav(path,track)
        row = metrics(track)
        assert row["boundary_delta"] < 0.001 and row["side_rms"] > 0.0005,name
        row["sha256"] = sha256(path.read_bytes()).hexdigest()
        row["phrase_rms"] = [float(np.sqrt(np.mean(part**2))) for part in np.split(track,4)]
        assert len(set(round(x,5) for x in row["phrase_rms"])) == 4,name
        evidence["stems"][name] = row
    for mask in range(8):
        mix = tracks[0].copy()
        names = ["base"]
        for index in range(3):
            if mask & (1<<index):
                mix += tracks[index+1]
                names.append(["food","nursery","midden"][index])
        mix *= RUNTIME_GAIN
        row = dict(layers=names,**metrics(mix))
        assert row["peak"] < 0.541 and row["boundary_delta"] < 0.001
        assert row["stereo_correlation"] > 0.2 and max(abs(x) for x in row["dc"]) < 0.0001
        evidence["combinations"].append(row)
        write_wav(REPO / "builds/music_review" / ("_".join(names)+".wav"),mix)
    for name,track in cues().items():
        path = REPO / "assets/audio" / (name+".wav")
        write_wav(path,track)
        evidence[name] = dict(seconds=len(track)/RATE,sha256=sha256(path.read_bytes()).hexdigest(),**metrics(track))
    target = REPO / "docs/evidence/card190"
    target.mkdir(parents=True,exist_ok=True)
    (target / "music.json").write_text(json.dumps(evidence,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(evidence,indent=2))


if __name__ == "__main__": main()
