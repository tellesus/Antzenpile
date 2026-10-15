"""Independent checks of the actual quantized PCM shipped to Godot."""
from hashlib import sha256
import io
import json
from pathlib import Path
import sys
import wave
import numpy as np

REPO = Path(__file__).resolve().parents[2]
EVIDENCE = REPO / "docs/evidence/card190"
NAMES = ["base_loop", "growth_loop", "nursery_loop", "midden_loop"]


def read(name, frames):
    path = REPO / "assets/audio" / (name + ".wav")
    with wave.open(str(path), "rb") as wav:
        assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate(), wav.getnframes()) == (2, 2, 44100, frames), name
        pcm = np.frombuffer(wav.readframes(frames), dtype="<i2").reshape(-1, 2)
    assert not np.any(np.abs(pcm.astype(np.int32)) >= 32767), name
    assert not pcm[0].any() and not pcm[-1].any(), name
    return pcm.astype(np.float64) / 32768, sha256(path.read_bytes()).hexdigest()


def main():
    metrics = json.loads((EVIDENCE / "music.json").read_text())
    tracks = []
    hashes = {}
    for name in NAMES:
        pcm, digest = read(name, 3763200)
        assert digest == metrics["stems"][name]["sha256"], name
        hashes[name] = digest
        assert np.max(np.abs(pcm.mean(axis=0))) < 0.0001, name
        assert np.sqrt(np.mean((pcm[:, 0] - pcm[:, 1]) ** 2)) > 0.001, name
        # Four sections must differ, including when a voice has intentional rests.
        sections = np.split(pcm, 4)
        floor = 0.03 * np.sqrt(np.mean(pcm ** 2))
        assert all(np.sqrt(np.mean((sections[0] - section) ** 2)) > floor for section in sections[1:]), name
        tracks.append(pcm)
    cue_peak = 0.0
    for name, frames in [("returned_alarm", 18522), ("returned_discovery", 12348)]:
        pcm, digest = read(name, frames)
        assert digest == metrics[name]["sha256"]
        hashes[name] = digest
        cue_peak += np.max(np.abs(pcm)) * 10 ** (-15 / 20)
    peaks = []
    for mask in range(8):
        mix = tracks[0].copy()
        for index in range(3):
            if mask & (1 << index): mix += tracks[index + 1]
        mix *= 10 ** (-4 / 20)
        peak = float(np.max(np.abs(mix)))
        assert peak < 0.541 and peak + cue_peak < 0.7
        # Edge neighbourhoods, not just equal boundary samples.
        edge = np.concatenate((mix[-441:], mix[:441]))
        assert np.max(np.abs(np.diff(edge, axis=0))) < 0.02
        assert np.corrcoef(mix.T)[0, 1] > 0.2
        peaks.append(peak)
    result = dict(actual_pcm=True, exact_frames=3763200, stereo=True,
                  subset_peaks=peaks, both_cues_peak_bound=float(cue_peak),
                  worst_combined_bound=max(peaks) + float(cue_peak), sha256=hashes)
    if "--rebuild" in sys.argv:
        import compose_colony_music as score
        rebuilt, _, _ = score.compose()
        for name, track in list(zip(NAMES, rebuilt)) + list(score.cues().items()):
            buffer = io.BytesIO()
            with wave.open(buffer, "wb") as wav:
                wav.setparams((2, 2, 44100, 0, "NONE", "not compressed"))
                wav.writeframes(np.rint(track * 32767).astype("<i2").tobytes())
            assert sha256(buffer.getvalue()).hexdigest() == hashes[name], name
        result["independent_second_render_matches_all_six_assets"] = True
    (EVIDENCE / "pcm_check.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__": main()
