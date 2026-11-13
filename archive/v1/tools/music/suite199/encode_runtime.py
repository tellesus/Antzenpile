"""Python + Blender/Audaspace: accepted199 arrangement made cyclic for200.

Run after render_suite.py. No introduction/outro envelope in the loop asset;
the player applies only a one-time start fade. All section gain is preserved.
"""
from pathlib import Path
import hashlib
import json
import sys
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
if '--encode' in sys.argv:
    import aud
    source = ROOT / 'builds/music_suite199/WarmCurrent_Cyclic.wav'
    target = ROOT / 'assets/audio/warm_current.ogg'
    aud.Sound.file(str(source)).write(str(target), 44100, 2, aud.FORMAT_S16,
                                   aud.CONTAINER_OGG, aud.CODEC_VORBIS, 192000, 16384)
    np.save(ROOT/'builds/music_suite199/runtime_decoded.npy', np.asarray(aud.Sound.file(str(target)).data()))
    raise SystemExit(0)

import subprocess
sys.path.insert(0, str(ROOT / 'tools/music/pilot197'))
import render_pilot as meter


def read_pcm(path):
    with wave.open(str(path), 'rb') as source:
        assert source.getframerate() == 44100 and source.getnchannels() == 2
        return np.frombuffer(source.readframes(source.getnframes()), '<i2').reshape(-1, 2).astype(float) / 32768


def main():
    sections = {name: read_pcm(ROOT / 'builds/music_suite199/sections' / name / 'full.wav')
                for name in ['Air', 'Warm', 'Current', 'Breath']}
    sequence = ['Air', 'Warm', 'Current', 'Breath', 'Warm']
    frames = 2352000
    fade_frames = 294000
    fade = np.sin(np.linspace(0, np.pi / 2, fade_frames)) ** 2
    pieces = []
    for index, name in enumerate(sequence):
        part = sections[name].copy()
        assert len(part) == frames
        previous = sections[sequence[index - 1]]
        part[:fade_frames] = previous[:fade_frames] * (1 - fade[:, None]) + part[:fade_frames] * fade[:, None]
        pieces.append(part)
    track = np.concatenate(pieces)
    # The listened-to demonstration differs only at the initial cyclic blend
    # and its audition-only opening/ending envelopes (and PCM rounding).
    demo = read_pcm(ROOT / 'builds/music_suite199/WarmCurrent_Layered.wav')
    middle_error = float(np.max(abs(demo[fade_frames:-220500] - track[fade_frames:-220500])))
    assert middle_error < 0.0002
    target = ROOT / 'assets/audio/warm_current.ogg'
    local = ROOT / 'builds/music_suite199/WarmCurrent_Cyclic.wav'
    meter.write(local, track)
    subprocess.run([r'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe',
                    '-b', '--python', str(Path(__file__).resolve()), '--', '--encode'], check=True)
    decoded = np.load(ROOT/'builds/music_suite199/runtime_decoded.npy')
    assert len(decoded) == frames * 5
    seam = float(np.max(abs(decoded[0] - decoded[-1])))
    slopes = np.concatenate([np.diff(decoded[-4410:], axis=0), np.diff(decoded[:4410], axis=0)])
    limit = float(np.quantile(abs(slopes), .99)) * 1.5 + .0001
    assert seam < limit and seam < .01
    boundaries = []
    for index in range(1, 5):
        at = index * frames
        step = float(np.max(abs(decoded[at] - decoded[at - 1])))
        nearby = np.diff(decoded[at - 4410:at + 4410], axis=0)
        boundary_limit = float(np.quantile(abs(nearby), .99)) * 1.5 + .0001
        assert step < boundary_limit and step < .01
        boundaries.append({'seconds': at / 44100, 'step': step, 'nearby_slope_limit': boundary_limit})
    # Vorbis can smear a few transform windows around the silence edges.
    rest = decoded[round(200.2 * 44100):round(213.1 * 44100)]
    assert np.max(abs(rest)) < 0.00001
    assert np.max(abs(decoded)) < .4
    decoded_lufs = meter.loudness(decoded)
    assert abs(decoded_lufs - meter.loudness(track)) < .5
    report = {'sequence': sequence, 'bpm': 72, 'sample_rate': 44100, 'frames': len(decoded),
              'seconds': len(decoded)/44100, 'blend_seconds': fade_frames/44100,
              'blend': 'complementary sin-squared / cos-squared, phase-aligned',
              'source_demo_middle_max_error': middle_error, 'decoded_lufs_estimate': decoded_lufs,
              'pcm_lufs_estimate': meter.loudness(track), 'decoded_peak': float(np.max(abs(decoded))),
              'decoded_wrap_step': seam, 'nearby_slope_limit': limit,
              'decoded_section_boundaries': boundaries,
              'rest_interior_peak': float(np.max(abs(rest))), 'bytes': target.stat().st_size,
              'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
              'sources': {name: hashlib.sha256((ROOT/'builds/music_suite199/sections'/name/'full.wav').read_bytes()).hexdigest() for name in sections},
              'scope': 'authored cyclic arrangement; no gameplay-reactive scheduler; estimated meter'}
    (ROOT/'docs/evidence/card200/production.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()
