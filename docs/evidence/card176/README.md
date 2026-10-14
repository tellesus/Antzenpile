# Card 176 — Actual Godot trail validation

Final Windows result: **11,003 regression checks, zero failures**, plus 126 affected checks, clean import/Main, 12 native captures and completed frame-loop measurements. The original Linux record below is preserved; the recovery section gives current results and timing limitations.

Work started from PR #2 head `170cd6ee40b6f1ea508759153f4045c0b9324619` on `visual/neon-trails-ux-direction-20261014`.

## Recovered Linux evidence and limits

Godot **4.7.2.stable.official.ed1daf0bf**, Linux x86_64, OpenGL Compatibility, Mesa 25.2.8 **llvmpipe software renderer** through a virtual X display. V-sync is unsupported in this renderer. These are actual engine captures, not concept art; no Windows/RX 6650 XT performance claim is made. The original six concept images were not available in this workspace; visual assessment follows the player's written direction.

The probe explicitly sets both the window and logical layout size and checks the captured pixel dimensions. This exercises 1920×1080, 1280×720 and compact 900×600 layouts directly, without stretching or letterboxing them. Ordinary project window scaling is unchanged. Calling only `DisplayServer.window_set_size` in the first attempt left the capture at 1280×720, so those mislabeled captures were discarded.

## Visual findings and correction

The first runtime capture showed broad, hard-edged colored strips, particularly rectangular caps on the weak cyan fragments. The new 128×64 cached analytical light mask feathers the sides and both ends. Wide uniform polylines now use that mask; the original texture and narrow readable cores remain. Strong and weak scent, familiarity-only ghosts, route geometry and representative ant limits keep their previous semantics. No simulation or gameplay files changed.

The clouds, home material and visible menus still reflect the existing art/UI implementation. This correction does not complete the concept-art target: clouds need richer internal motion, ants need stronger silhouettes, and the persistent top-row controls and crowded contexts still require their planned UI pass. The existing representative motion is not yet normalized by curve length.

## Captures

- [Before, 1280×720](before_1280.png): original PR #2 flat aura bands.
- [Corrected, 1280×720](mixed_1280.png): identical detached fixture and decorative time.
- [Corrected, 1920×1080](mixed_1920.png): six visible routes; strong, weak, ghost and reported-empty variants.
- [Compact selected source, 900×600](selected_900.png): actual mouse/touch selection; panel remains within the viewport.
- [Real returned alarm, 1920×1080](returned_alarm_1920.png): seed 3043, an ordinary paid scout, established aphid route and actual returned loss. The unknown cause remains unidentified. This scene is not a fabricated combat result.
- [Inward baseline, 1920×1080](inward_1920.png): untouched starting colony, captured as a shared-art smoke check.

All mixed-route pictures use explicitly detached presentation test data; they do not assert that the starter colony has discovered six resources. The fresh empty scene and actual returned-alarm scene use normal approved game snapshots. Additional rain, empty, rear-facing and decorative-motion captures are reproduced by the probe.

## Reproduce

From the repository root with the pinned engine:

```powershell
& $env:GODOT_EXE --headless --path . --import
& $env:GODOT_EXE --headless --path . --script res://tests/run_tests.gd
& $env:GODOT_EXE --headless --path . --quit-after 120
& $env:GODOT_EXE --path . --script res://tests/probe_neon_trails.gd
```

The graphical probe writes `.godot/card176/*.png`, reports actual image sizes and exits nonzero if mouse/touch selection, empty/rear-facing visibility, pause, immutable snapshots or actual returned-alarm setup fail. It does not save over the player's run or preferences. It requires a graphical display; headless mode is explicitly rejected.

## Original verification record (superseded by recovery below)

Final suite result pending. Import and Main headless smoke pass. Initial affected checks: **126 checks, zero failures**. Final graphical probe: **12 correctly sized captures**, mouse/touch selection at all three sizes, empty/rear-facing suppression, paused visual clock, unchanged detached-run snapshot, and actual returned alarm pass. No script/render errors or ObjectDB leak warnings in the final probe; only unsupported V-sync is reported by llvmpipe.

Windows 1080p median/1% low frame-time measurement on the RX 6650 XT, visual player acceptance, and broader UI/cloud work remain pending. Keep PR #2 draft.


## Recovery and final Windows verification — 2026-10-14

The original Work execution (`01a138e8-bc0b-74ce-a4fa-af4d336620c3`, backing
“Work · Antzenpile Graphic Rework Chat”) staged the correction but never created a
commit or moved the PR branch. Its final regression command eventually returned
exit 0 after 575.402 seconds. The complete old test log was not retained in the
accessible history, so it is not used as the final regression evidence here.
All source patches, the capture probe and six runtime PNGs above were recovered;
their Git blob hashes match the old staged-file manifest. The two old generated
script UID files were regenerated. The original six concept-art assets were not
exposed by the recoverable Work history.

The initial Windows import/test attempt reached protected Godot profile paths.
Final gates redirect APPDATA/LOCALAPPDATA and logs to an isolated workspace profile.
No player slot or audio preferences were overwritten. An intermittent capture
shutdown warning was traced with verbose diagnostics to stopped audio streams.
The probes drain four frames and wait 0.25 seconds after freeing the test scene,
allowing the audio mixing thread to release them. The final capture and performance
runs have clean stderr. No audio implementation changes were needed.

Final engine: **4.7.2-stable (official)**, **Windows**, **AMD Radeon RX 6650 XT**, OpenGL
Compatibility. CPU: **AMD Ryzen 7 7800X3D 8-Core Processor**. Driver reported by the renderer:
OpenGL 3.3.0 Core Profile Context 26.8.1.260806.

- Import: exit 0, clean stderr.
- Affected sensory/outward/scout-caption suites: **126 checks, zero failures**.
- Full regression: **11003 checks, zero failures**; regression exit: 0; elapsed: 475.19s.
- Main headless smoke: 120 frames, exit 0, clean stderr.
- Native capture probe: **12** captures at the asserted 1920×1080, 1280×720 and
  900×600 sizes. Mouse/touch selection, empty/rear suppression, pause and immutable
  snapshots pass. Actual returned-loss scene passes and visually retains
  “Unidentified threat.” Touch events are synthetic, not physical touch-device validation.

Fresh native captures: [six trails](windows_mixed_1920.png),
[compact selection](windows_selected_900.png),
[returned alarm](windows_returned_alarm_1920.png).
The original Linux PNGs remain unchanged for provenance.

### Native 1080p frame-loop measurements

Run `tests/probe_neon_performance.gd` graphically with the pinned engine and
`--audio-driver Dummy`. Two 60-second samples use the same detached six-route
fixture, a paused simulation and live decorative animation, two seconds of warmup,
V-sync disabled, and an unchanged run snapshot. The control sets only the soft
trail halo mask transparent: draw submissions, cores, textured filaments and ant
halos remain. It is a visual control, not a benchmark of eliminating those draws.

| Soft trail halos | Median FPS | Median ms | P99 ms | 1% low FPS | Worst ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| On | 211.86 | 4.72 | 6.01 | 106.23 | 199.72 |
| Transparent control | 213.22 | 4.69 | 5.72 | 148.05 | 15.28 |

1% low FPS is 1000 divided by the mean of the slowest 1% of frame intervals;
P99 is the 99th percentile interval. These are engine frame-loop intervals from
the hidden automated window, not GPU timer queries or a visible packaged-game
playtest. The worst interval records isolated stalls as well as ordinary frames;
high median FPS does not establish stutter-free play. No regression process ran
during these samples. Raw samples and
environment are recorded in [windows_performance.json](windows_performance.json).

The initial 60-second pair is also preserved in
[initial_windows_performance.json](initial_windows_performance.json). Its halo-on
sample had median 213.45 FPS, 1% low 113.13 FPS and worst 200.98 ms; its transparent
control had median 214.68 FPS, 1% low 18.89 FPS and a 5474.52 ms stall. The cause of those
isolated frame-loop interruptions was not established. The pair was repeated
after correcting the harness's audio shutdown wait; this does not establish an
audio cause for the stalls or erase the initial measurements.
The repeat's halo-on sample overlapped a 9.52-second editor reimport in the same
workspace. Its timing therefore includes that background workload; it is not an
isolated GPU benchmark. Both pairs are observations of this automated desktop
fixture, and final visible-game performance acceptance remains pending.

All final gate logs and elapsed times are adjacent `windows_*.log` and
`windows_*_result.txt` files. Final player approval and a visible packaged-game
playtest remain pending. Keep PR #2 draft. The richer cloud/ant art, broader UI
cleanup, music and arc-length-normalized trail traffic are subsequent work.
