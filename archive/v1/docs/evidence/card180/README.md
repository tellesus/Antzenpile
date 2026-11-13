# Card 180 — native visual revision evidence

Godot **4.7.2-stable (official)**, Windows, **gl_compatibility**, **AMD Radeon RX 6650 XT**. Ryzen 7 7800X3D, 64 GB RAM, 1080p/240 Hz SDR display. No engine/renderer upgrade.

- Final full headless suite: **11,048 checks, zero failures**. regression: exit=0; error_detected=False; seconds=474.91
- Affected menu/save/input/guide/art/cloud suites: **440 checks, zero failures**.
- Pinned import and Main 120-frame smoke pass without errors.
- Native probe: 23 full captures across 1920×1080, 1280×720 and 900×600, plus an unscaled 240×240 spider detail. Nine representative originals are committed here; remaining generated captures live under `.godot/card180`.
- Early, selected, developed and strained colony fixtures, compact contexts and Escape menus are captured. Developed/strained scenes are detached approved-summary art fixtures, not claimed complete player runs.
- An actual paid survey keeps captured spider identity private until its physical return. Actual returned spider and Garden beetle captures pass. Swapped species and old-memory variants are detached fixtures. The normal view never reads hidden predator state.
- Inspection/menu/capture snapshots remain identical, including RNG; exact paused rendered pixels are stable after attention settles. Existing automated mouse/touch selection checks and new menu Save/Load callbacks pass. Physical touchscreen and human usability remain separate.
- Motion previews encode 60 native 1280×720 frames per screen at 15 fps, four seconds each. They step only presentation time against a frozen actual run; they are not performance measurements.
- An initial full run found seven assertions for removed utility launchers and old unscaled targets. Those checks now exercise mouse/touch save/load through the shared menu, Help through Escape, and viewport-scaled organ edges. The raw failed log is retained as `regression-obsolete-controls.log`; the final full log is the acceptance gate above.

## Native frame-loop timing

| Screen | Median FPS | p99 ms | 1% low FPS | Worst ms |
| --- | ---: | ---: | ---: | ---: |
| OUTWARD | 277.85 | 5.588 | 98.92 | 86.278 |
| INWARD | 382.26 | 3.189 | 291.51 | 10.766 |

Two 60-second samples, two-second warmup each, 1920×1080, VSync disabled, Dummy audio. OUTWARD uses the detached six-trail fixture; INWARD uses a developed/strained known-summary fixture with capped workers/brood. Decoration is live; the actual simulation is paused. No other regression/import process runs during timing. These are native editor process-frame intervals, not isolated GPU timings, active simulation budgets or release acceptance. Report medians and outliers together; do not infer a quality-setting speedup or universal 60/120 FPS guarantee.

## Reproduce and scope

Use pinned Godot graphically with `--audio-driver Dummy --script res://tests/probe_sensorium_revision.gd`. Add `-- --movie` for the preview frames. Timing uses `tests/probe_sensorium_performance.gd`, default 60 seconds per screen. Tests use isolated authoring profiles and `.godot` slots, not player settings or saves.

Production materials and exact imagegen prompts: [asset provenance](../../../assets/graphics/sensorium/README.md). Shared UI and Escape menu delegate to existing semantic owners. Simulation, save schema, economy, knowledge, representative caps and audio content are unchanged. Further ant art/animation, dispatch clarity, more supported forms, arc-length trail movement and music remain future work. The specific player save report178 is not closed by generic round-trip tests.

Published/package evidence follows. Evidence SHA256 manifests describe normalized Git blob bytes, rather than checkout line endings.

## Published main and Windows package

Runtime revision [79f482b](https://github.com/tellesus/Antzenpile/commit/79f482bbf7505e17d4e70175ddb9e4ed97fa6d21) is on main and in both checkouts. No new PR or topic branch was created. All 109 preserved primary local files retain their byte hashes.

Fresh Windows x86_64 package audits **638 resources**. Isolated committed-runtime import/export/inventory/extraction, actual extracted release Main and packed save/resume/settings/review pass. Native material, INWARD and menu captures pass under the pinned editor with the unchanged exported PCK, using external tools/package probes excluded from the game. Those authoring probes do not imply release-template input/audio/feel, physical touch or clean-machine acceptance. The probes avoid Root's editor-only debug lifecycle while consuming its approved summaries.

[Build metadata](windows_build.json), [builder log](windows_package.log), [native cloud log](windows_packed-clouds.log), [native inward/menu log](windows_packed-sensorium.log). ZIP SHA256 `78d8ec1c38f4cf1b68e051c0ab2386b477981003cff71925d3979f2177af3dad`. `builds/windows-beta-latest.json` is the current local launch pointer; named old packages remain historical.

The actual release executable also completed native Main startup for180 frames with Dummy audio, exit0 and no engine errors. Forced `--quit-after` shutdown reports eight AudioStreamWAV/Playback instances; verbose comparison with the previous179 executable reproduces the identical four streams/four playbacks. This pre-existing audio-shutdown warning remains open, separate from visual revision acceptance. [Previous](windows_exit-previous179.log), [current](windows_exit-current180.log). Release builds suppress the development `[RUN]` line; the corrected startup assertion checks process status and native renderer initialization instead.
