> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/020_rain.md`. Historical status and recommendations below apply only to their recorded build.

# 020 — Rain

Status: complete (2026-09-30).

## Goal

Demonstrate exposure-dependent chemical disruption and remembered recovery.

## Why this exists

Rain proves that routes have differing physical vulnerability.

## Dependencies

[019](019_music_stem_state.md) and the preceding task sequence. Read [ARCHITECTURE](../contracts/ARCHITECTURE.md), [CODING_RULES](../../../CODING_RULES.md), and relevant [DATA_MODEL](../contracts/DATA_MODEL.md)/[UI_RULES](../contracts/UI_RULES.md) contracts.

## Allowed scope

One rain event, segment exposure, increased pheromone loss, largely preserved familiarity and sensory/debug feedback.

## Required behavior

After exposed and sheltered trails exist, trigger the slice complication. Apply stronger chemical loss to exposed segments while familiarity still contributes to recovery.

Before coding: Resolve trigger/timing/duration/intensity and exposure formula; specify how interference reaches player perception.

Resolved contract: each new TrailSegment captures mean exposure from 16 evenly spaced midpoint samples along its estimated straight geometry, reading the existing authored terrain's 0–1 exposure. The home boundary at x=20 therefore gives the east carbohydrate route exposure 1 and the west route exposure 0 without a route-ID exception. Exposure is immutable for that segment and validated against the saved world/geometry on restore. One run-owned RainState (`waiting`, `raining`, `finished`; elapsed simulated seconds) triggers on the first fixed tick when at least one segment of exposure ≥0.75 and one ≤0.25 have each recorded at least five successful returning workers. Rain lasts 60 simulated seconds once; no random or wall-clock trigger. RainSystem applies an additional exposed-chemistry half-life of 12 simulated seconds, scaled by exposure, after the normal TrailSystem tick. Sheltered chemistry and all route familiarity retain their existing baseline half-lives. Cargo returns still reinforce normally, making rebuilding possible during and after rain. Rain sends one `rain_started` signal. The snapshot includes rain state and segment exposure (version 5), with no migration until 021.

OUTWARD receives only a detached rain phase, not terrain, exposure values or route geometry. While raining it shows a restrained weather label and sparse thin streaks and dims signal rendering; the existing chemistry/memory trail visuals naturally show exposed washout and ghost memory. F3 shows exact rain state and segment exposure. Rain is not an arbitrary player command.

## Explicit non-goals

Full weather, floods, seasons, ecology, and global arbitrary trail deletion. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Distinct chemistry/memory fields and knowledge/perception boundary; fixed simulated time.

## Acceptance tests

Compare otherwise identical exposure-1 and exposure-0 segments under rain; exposed loses more pheromone while familiarity largely survives. Verify post-rain recovery and player legibility.

## Manual verification

Run pinned Godot 4.7.2 import, full `tests/run_tests.gd` suite, headless Main smoke and graphical OUTWARD inspection. `tests/test_rain.gd` must cover exposure derivation, no trigger before both established routes, one trigger, exposed versus sheltered decay with matched starting chemistry, baseline familiarity, post-rain traffic recovery, pause/speed equivalence, JSON continuation and malformed snapshot rejection. Inspect OUTWARD's interference treatment and F3 diagnostics; record any live-audio/device limitations separately.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.

## Completion evidence and handoff

- Added authored RainConfig, RunState-owned RainState, fixed-tick RainSystem, captured/validated TrailSegment exposure, one event signal, semantic OUTWARD interference and F3 diagnostics. Run snapshots are version 5. Chemistry/familiarity round to ten decimal places for exact JSON continuation. Knowledge archive restore now quantizes Vector2 positions before exact derived-state comparison because the two-route JSON fixture revealed one last-bit decimal difference; identity and other fields remain exact.
- Pinned Godot 4.7.2 import, full headless suite and Main smoke passed: 3,525 checks, 0 failures. `tests/test_rain.gd` verifies both-route trigger, authored 1/0 exposure, one event, stronger exposed washout, preserved familiarity, post-rain return/recovery, pause/speed equivalence, JSON continuation and malformed-state rejection. A brief Compatibility graphical startup exited successfully.
- Inspected 1280×720 OUTWARD rain and F3 preview frames. The label/streaks remain sparse and readable in darkness; F3 weather status fits the header. Temporary preview scripts/images were not committed. Live Android/touch performance and subjective audio listening remain unverified; rapid graphical shutdown can still report Godot audio playback references from task 019.
- Pause here for slice evaluation as requested. The next roadmap card is 021 save/load, after review.
