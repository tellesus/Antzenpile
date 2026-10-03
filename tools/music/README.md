# Original warm colony arrangement — 092

Four synchronized **48-second, 16-bar, 80-BPM, 44.1-kHz mono/16-bit PCM** layers. Original score: A-minor/C-major family with four varied phrases, a quiet return home, melody rest bars and sparse tuned timpani answers. Shared gentle room reflections and note/recording decay are baked circularly across the boundary. One common gain preserves layer balance; the runtime keeps its existing -4 dB gain and three-second state fades.

| Layer | Contents |
| --- | --- |
| Base | Warm low harmony/bass, soft recorded bass drum and occasional tuned timpani |
| Food Exchange | Recorded folk-harp arpeggios with alternating shapes/velocity |
| Nursery | Recorded soft marimba, two-note answers and phrase-end rests |
| Midden | Muted frame drum, sparse wooden clicks and quiet shaker detail |

The score/authoring script is original project work. Seven source recordings are by Sam Gossner / Versilian Studios, **CC0-1.0**, from [VCSL](https://github.com/sgossner/VCSL/tree/sfz); the [publisher's license statement](https://versilian-studios.com/vcsl/) permits commercial use. `sample_manifest.json` pins the upstream tree, each exact raw URL and SHA-256/Git-blob checksum. No paid instrument/plugin or runtime sampler. Attribution is retained for provenance even though CC0 does not require it.

Rebuild with the existing Python environment containing NumPy (authoring only):

```text
python tools/music/fetch_samples.py
python tools/music/compose_colony_music.py
```

The first command downloads only seven verified WAVs to ignored `tools/music/samples/`; subsequent runs reuse matching local files. The second runs offline, validates source hashes and renders the four checked-in `assets/audio/*_loop.wav` files. It writes eight actual runtime-gain review combinations to ignored `builds/music_review/` and numerical evidence to `docs/evidence/card092_music.json`. No Godot/gameplay or network dependency is introduced. `tools/music/.gdignore` prevents Godot importing authoring sources.

Historical 019/068 generators now write to their own ignored historical output folders so they cannot overwrite this soundtrack accidentally. All current mixes share harmony, exact frame counts and a common gain. This is a first pleasant-music pass, not a claim of human listening approval or Android audio validation. Loss/discovery cues are unchanged. Uncompressed PCM payload is about 16.15 MiB for all four stems; streaming/compression can be evaluated later rather than assuming mobile memory is free.
