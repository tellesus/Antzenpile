# 022 — Vertical slice integration pass

Status: complete; integration baseline recorded and feature expansion paused for evaluation.

## Goal

Make the planned 20–30 minute arc coherent and evaluate it.

## Why this exists

The next expansion depends on evidence that the core experience works.

## Dependencies

[021](021_save_load.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

Fix interface inconsistencies, rough pacing, debug leaks, and integration defects; no new major systems.

## Required behavior

Complete the VERTICAL_SLICE arc, starting conditions, meaningful decisions, rain comparison, growth, Food Exchange and music reward. Keep developer truth inaccessible in normal play.

Before coding: Resolve only integration/pacing issues against playtest evidence; record remaining design questions instead of silently expanding scope.

## Explicit non-goals

Rivals, ecology, adaptation, or any other new major system. Do not implement future systems not explicitly requested.

## Interfaces to preserve

All locked decisions; pause feature expansion after this card and evaluate the questions in VERTICAL_SLICE.

## Acceptance tests

Run full headless suite/save continuation and a timed Windows playthrough. Check 60 FPS desktop target with hardware/workload recorded, bounded object counts, mobile-safe input/effects, debug guards and reduced-bloom legibility.

## Manual verification

Use `tests/test_slice_integration.gd` (registered in `tests/run_tests.gd`) to drive a seeded run through returned carbohydrate and protein evidence, at least two trails, delivered resources, rain, brood emergence, Food Exchange development and the semantic music layer. Assert ledger conservation and normal-view detachment at milestones. Use the existing task-021 save/load suite for exact continuation, then run the full suite with the pinned Godot 4.7.2 console executable.

Run Main graphically on Windows at 1280×720 and inspect OUTWARD/INWARD, selected contexts, touch-sized controls, rain and developed state with bloom disabled. Record actual hardware, renderer, workload, frame-time or FPS samples and scene-object counts in `docs/SLICE_EVALUATION.md`. A scripted run measures simulated duration; it does not establish human play duration or Android usability. Fix only demonstrated integration defects within this card; record unresolved pacing and design questions for evaluation. No new gameplay system or speculative balance change.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.

## Completion evidence and handoff

- Added `tests/test_slice_integration.gd` to the full runner. Seed 3030 reaches returned carbohydrate knowledge at 43.25 s, rain and Food Exchange investment at 65 s, protein knowledge at 92.5 s, Developed and second semantic music layer at 125 s, and eight emerged workers at 360 s. Three routes/signals exist by the end; normal views receive no hidden world fields and the ledger conserves 48 living workers. The existing task-021 suite checks disk save/load and exact 100-tick continuation with scouts, cargo, rain and development in flight.
- Added reproducible graphical `tests/profile_slice.gd` and inspected rain OUTWARD, developed INWARD and scaled 900×600 screenshots. At 1280×720 Compatibility on Ryzen 7 7800X3D / Radeon RX 6650 XT, the busiest 240-frame pass measured 4.28 ms p95, at most eight scene nodes and 61 draw calls; all four sampled modes were under 4.31 ms p95. This meets 60 FPS locally, not on an unmeasured modest desktop or Android device. The probe cleans up audio before quit; abrupt quit may still report the task-019 playback reference warning.
- Pinned Godot 4.7.2 import, Main headless smoke and full headless suite passed: 3,568 checks, zero failures. Normal-play truth isolation, debug-build guard, mouse/touch shared paths and bloom-free visual legibility were checked; physical touch comfort and subjective music quality remain unverified. No gameplay balance or locked architecture was changed.
- A separate normal-speed Windows GUI walkthrough in `tests/timed_slice.gd` passed through OUTWARD scout/trail and INWARD development commands: emergence at 360.00 simulated / 359.83 real seconds, 48 living workers and three routes. This verifies elapsed clock/UI integration, not human decision time.
- `docs/SLICE_EVALUATION.md` records the measured arc and decision points: the scripted six-minute duration falls short of the intended 20–30 minute experience without substantial human decision time; the Food Exchange can complete before protein discovery and brood growth rather than becoming strained; and two resource pools accumulate while water nearly empties. This card did not invent a new strain system or silently retune costs. A timed human Windows playthrough remains for evaluation; the automated GUI pass cannot establish human session length.
- Changed files: this card, `tests/test_slice_integration.gd`, `tests/run_tests.gd`, `tests/profile_slice.gd`, `tests/timed_slice.gd`, `docs/SLICE_EVALUATION.md`, `docs/VERTICAL_SLICE.md`, `README.md`, plus imported GDScript UID files. Next action is a human playtest/design evaluation, not another implementation card.
