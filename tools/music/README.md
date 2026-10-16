# Living colony arrangement — 190

Four synchronized **85⅓-second, 32-bar, 90-BPM, stereo 44.1-kHz/16-bit PCM** voices. The original D-minor/modal score moves through four eight-bar phrases, varying motifs, register, timing and density. Phrase rests and a sparse return home provide breathing space. Shared circular stereo room/delay carries tails across the score; a 6ms cadence breath brings the file boundary to zero. Equal-power positions keep bass centred and give higher instruments space. One common gain across all subsets retains layer balance; runtime stays at -4dB with three-second real-time fades.

| Voice | Role |
| --- | --- |
| Base | Soft detuned breathing harmony, rounded low pulse, recorded bass drum and three tuned timpani answers |
| Food Exchange | Flowing recorded harp with four phrase shapes and occasional soft glass answers |
| Nursery | Recorded marimba question/answer melody and quiet sustained answers, with eight rest bars |
| Midden | Tactile frame drum, varied rests, eight 2.4kHz-lowpassed shaker accents; no wooden clicks |

The two short stereo returned-information cues are original soft glass synthesis: an upward discovery and a lower falling loss. They retain actual returned-batch eligibility, independent cue volume, no loop, and reload suppression. No hidden threat or live world query enters audio.

The score/script are original project work. Seven recordings by Sam Gossner/Versilian Studios are CC0-1.0 from [VCSL](https://github.com/sgossner/VCSL/tree/sfz); the [publisher's statement](https://versilian-studios.com/vcsl/) permits commercial use. `sample_manifest.json` pins the upstream tree, each URL and SHA-256/Git-blob checksum. Six recordings are used; the historical woodblock stays in the manifest/cache for provenance. No new library/plugin/engine/runtime sampler. NumPy is authoring-only.

```text
python tools/music/fetch_samples.py
python tools/music/compose_colony_music.py
python tools/music/check_score.py --rebuild
```

Fetch reuses matching ignored samples. Compose is deterministic with a fixed authoring-only seed, writes the canonical six assets, eight runtime-gain listening mixes under ignored `builds/music_review/`, and `docs/evidence/card190/music.json`. Historical019/068/092/093 evidence is retained; historical generators cannot overwrite the current assets. The independent PCM check covers exact stereo frames, source hashes, all combinations/headroom, DC, seam, distinct phrases and cue overlap. Do not normalize stems independently. Existing Godot import settings remain; native tests verify actual imported duration/phase.

Four loop PCM payloads total 57.42MiB (about 3.6times the old score). This is deliberate for the current desktop target; no mobile memory/latency or human listening approval is claimed. The game needs neither Python nor a network connection. `tools/music/.gdignore` excludes authoring sources. Listening fatigue/enjoyment and the final balance of voices remain player acceptance, separate from numerical/render/runtime checks.
