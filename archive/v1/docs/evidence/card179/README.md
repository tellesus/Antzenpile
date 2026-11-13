# Card179 — native living-chemistry evidence

Godot **4.7.2-stable (official)**, Windows, **gl_compatibility**, **AMD Radeon RX 6650 XT**.
Workstation: Ryzen7 7800X3D, 64GB RAM; 1080p/240Hz SDR monitor. No renderer/engine upgrade or new dependency.

- Full headless suite: **11,026 checks, zero failures**. `regression: exit=0; error_detected=False; seconds=476.59`
- Focused cloud/art/outward/stationary-witness/roaming-witness/caption suites: **542 checks, zero failures**.
- Pinned import and Main120-frame smoke pass without script/resource/shader errors.
- Native capture probe:14 full captures at1920×1080,1280×720,900×600, plus one unscaled240×240 detail. Each full image asserts its requested resolution. All14 originals stay in `.godot/card179`; the seven useful inspection images are committed here.
- Controlled native mouse/touch selection, unchanged run/RNG snapshots, empty/rear retirement and exact paused rendered-pixel comparison pass. Physical touchscreen and human usability acceptance remain separate.
- Actual paid Backyard survey: captured spider identity stays private while the party returns, then supplies a dated wispy memory on actual delivery. The actual Garden Edge paid-survey path supplies a beetle memory. The stale and swapped-profile images are explicitly detached artwork fixtures, not extra simulated discoveries.
- Animated preview:60 native1280×720 frames at15fps, visual time11–15s, controlled six-trail fixture; unchanged actual run. The user-facing GIF is an encoded preview, not a performance measurement.

## Frame-loop timing

Two60-second1080p samples,2-second warmup, VSync off, Dummy audio. Six detached trails/five nonempty clouds, live decoration, actual simulation paused. Control hides only cloud material quads while retaining per-node configuration, trails, ants, text and motes. It measures their incremental submission/render cost; it is not the old renderer or a gameplay quality setting.

| Sample | Median FPS | p99 ms | 1% low FPS | Worst ms |
| --- | ---: | ---: | ---: | ---: |
| Clouds on | 293.86 | 5.081 | 81.24 | 102.937 |
| Cloud quads hidden | 215.52 | 5.377 | 156.05 | 115.430 |

These are wall-clock process-frame intervals from an automated native window, not isolated GPU timers or guaranteed active-gameplay/clean-machine performance. No simultaneous Godot regression/import ran during these samples. Both raw results, outliers and configuration are retained. Mature-network,1×–64× live simulation, player audio/feel and final release acceptance remain open.

The control's lower median but higher 1% low demonstrates sample/driver/scheduler variability. Do not interpret this pair as proof that adding clouds improves performance, or subtract the medians as an isolated GPU cost. Both cases contain a >100ms outlier; final stutter acceptance remains open.

## Inspect and reproduce

- `clouds_1920.png`: detached six-trail fixture, matching the earlier [trail baseline](../card176/windows_mixed_1920.png).
- `selected_900.png`: existing compact context, with clouds beneath its input/UI.
- `private_survey_1920.png`: actual captured-but-undelivered survey, no anatomy.
- `returned_spider_1920.png` and `returned_beetle_1920.png`: actual returned witnesses.
- `spider_detail.png`: unscaled crop of the returned spider capture.
- `stale_memory_1920.png`: detached old observation loses recognizable anatomy.

Run pinned Godot graphically with `--audio-driver Dummy --script res://tests/probe_chemical_clouds.gd`; performance uses `tests/probe_chemical_performance.gd -- --seconds=60`. Default60seconds per case. Headless-only runs cannot validate the shader appearance. Both probes write under `.godot/card179` and avoid player slots/settings.

The material consumes explicit view-owned time rather than engine `TIME`, which [Godot documents as unaffected by pause](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html#global-built-ins). Noise has an independent fixed seed. Each current visible memory owns its material; normal projection consumes returned report identity/age, never physical predator state.

Remaining visual work includes inward organs, ant art, further supported species/source forms and arc-length trail motion. Menus, dispatch simplification and music remain separate. Card178's specific player save failure remains unresolved by these generic regression/package gates.

## Committed-main Windows package

Revision`3813ae2526e49c01a736e0d7f47fdc3f1d1a6585`, 634 exported resources. Isolated import/export/inventory/extraction, actual extracted release Main and packed save-resume/settings/review checks pass. [Metadata](windows_build.json), [package log](windows_package.log), [native packed-material log](windows_packed_clouds.log).

`tools/package/chemical_smoke.gd` is an external authoring probe, excluded from the package. Run the pinned editor with `--main-pack path/Antzenpile.pck --audio-driver Dummy --script path/tools/package/chemical_smoke.gd -- output.png` to capture six controlled1920×1080 material quads, including both species masks, without mutating the actual run. This verifies the unchanged PCK on RX6650XT; it does not exercise release-template physical input or audio.

The first additional native probe incorrectly entered GameRoot’s editor-only debug lifecycle against the release PCK, which correctly excludes debug code. [Initial failed probe log](windows_packed_clouds_first_attempt.log) is retained. The corrected external probe instantiates the packed OUTWARD renderer directly and uses an unattached GameRoot only for approved status projection; the unchanged PCK then passes cleanly. No production runtime or package was changed to fix this authoring-probe issue.

`SHA256.json` fingerprints normalized Git-blob contents, so text line-ending conversion on Windows does not change the reference bytes. PNGs remain exact native capture bytes.
