# C-based listening revisions —198

Player feedback:197 A's plucks are intrusive/jarring, B has promise but lacks cohesion, and C is strongest but its repeated three-note hits become tiring. The source contains a recurring three-tone pluck spread over210ms, a plausible match to that complaint. These revisions remove that figure and the rolled chord-key attacks, rather than only reducing their gain. Percussion is reduced to two soft events per active bar to avoid another recurring three-hit figure.

Both follow C's24-bar72BPM harmony,86-second duration and long sparse interval. **C1/Quiet Sky** uses the slow bed and a few softened individual piano notes. The soft sample instrument receives one uniform calibration gain so it remains audible after the previously dominant synthetic plucks disappear; relative note levels are preserved. **C2/Warm Current** takes B's key color into C's structure, with a slower/simpler key envelope and a coherent lower-register phrase. Both have ten widely spaced foreground entrances, no plucked string events and no grouped foreground chords. Neither is a claim of musical acceptance or runtime delivery.

The isolated authoring script imports197's source reading, room, filtering, metering and PCM helpers. It preserves197's compositions, files and source recipes. Same eight CC0 Kawai recordings from the pinned [197 source manifest](../pilot197/sources.json), same existing Python/NumPy/SciPy and Blender/Audaspace encoding. No new download, package, optional tool or paid service. These are not Surge renders. [Source licensing and metering limits](../pilot197/README.md).

From the repository root, using the established executable paths:

```powershell
python tools/music/pilot197/fetch_piano.py
python tools/music/pilot198/render_revision.py
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b --factory-startup --python tools/music/pilot198/encode_reviews.py
python tools/music/pilot198/check_revision.py
```

Lossless previews, four separate role WAVs, explicit score events, three-pass4:23 repetition copies and readback data live under ignored `builds/music_pilot198/C1_QuietSky` and `C2_WarmCurrent`. Short160kbps MP3s and final technical evidence are committed under `docs/evidence/card198`. Files have endings; they are not seamless runtime loops.

Checks reuse197's actual file gates: stereo/finite PCM, matching loudness and durations, endpoints/headroom, part reconstruction, identical repeated passes and decoded MP3 level comparison. Additional event inspection checks no plucks or closely grouped foreground attacks, and no percussion entrances in the40–60second breath. These are preparation checks; they do not establish fatigue, taste, naturalness or in-game behavior. Runtime/import/headless-suite/package gates are not relevant to these offline artifacts.
