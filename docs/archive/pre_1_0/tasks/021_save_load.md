> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/021_save_load.md`. Historical status and recommendations below apply only to their recorded build.

# 021 — Save and load

Status: complete (2026-09-30).

## Goal

Persist and resume the complete implemented slice.

## Why this exists

Interrupted sessions must resume without changing future simulation outcomes.

## Dependencies

[020](020_rain.md) and the preceding task sequence. Read [ARCHITECTURE](../contracts/ARCHITECTURE.md), [CODING_RULES](../../../CODING_RULES.md), and relevant [DATA_MODEL](../contracts/DATA_MODEL.md)/[UI_RULES](../contracts/UI_RULES.md) contracts.

## Allowed scope

Versioned explicit save/load of world, pile/ledger, brood, knowledge, scouts, routes/segments/cohorts, chamber state, rain, clock and RNG.

## Required behavior

Store seed/scenario, current RNG state, simulation time/remainders and pending events. Preserve carried versus delivered observations, payloads, and worker ownership. Rebuild presentation/audio from loaded semantic state; validate before replacing the live run.

Before coding: Resolve version/error/atomic-write policy, ID validation, save path, and user controls. Preserve integer RNG state losslessly.

Resolved contract: a run-scoped SaveService writes one local slot at `user://saves/slot_1.json`. The disk envelope has `format = antzenpile-run`, `file_version = 1`, a full-precision JSON payload of the current version-5 RunState dictionary, and a SHA-256 checksum of the payload text. The existing RunState.restore validators remain authoritative for IDs, references, labor, cargo, rain and state consistency. Earlier schema versions are explicitly unsupported: no disk saves existed before this card, so guessing migrations would risk corrupting state. Save writes a sibling `.tmp`, flushes/closes and verifies it, then renames over the slot; failure leaves the last good slot intact. Load verifies envelope, checksum and payload, restores into a fresh RunState, then atomically rebinds SimulationController systems to it. Errors return a short reason and never replace the live run.

Both normal views get touch-sized Save and Load buttons plus named `save_run`/`load_run` actions (Ctrl+S/Ctrl+L). Buttons and keys call the same GameRoot semantic methods. On successful load, presentation selections/facing reset; the debug provider rebinds to the new RunState; the graphical music pair restarts at loop phase zero with gain from the restored Food Exchange state. View nodes, debug visibility and audio phase are not saved. Headless save/load uses no views or sound.

## Explicit non-goals

Replay, cloud saves, broad migration framework, and serialization of view nodes. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Explicit dictionaries/IDs, immutable definitions, all authoritative pending work, and headless compatibility.

## Acceptance tests

Save then continue 100 ticks versus reload then continue 100 ticks: authoritative state matches. Include scout observations, in-flight payloads, chamber progress/rain, invalid save rejection and worker conservation.

## Manual verification

Run pinned Godot 4.7.2 import, full `tests/run_tests.gd` suite, Main headless smoke and graphical control check at 1280×720 and 900×600. `tests/test_save_load.gd` must write/read the injected test slot and compare 100-tick continuation with mid-mission observations, in-flight cargo, Food Exchange progress and active rain; cover 64-bit RNG state, one-slot replacement, checksum/unsupported version/invalid-reference rejection, and worker conservation. Remove only the test slot after the test. The default player slot must not be touched by tests.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.

## Completion evidence and handoff

- Added SaveService, one checksummed/versioned local slot, verified temporary write and replacement, and atomic SimulationController run rebinding. GameRoot now resets transient views, rebinds F3 truth and rephases the semantic music pair after load. Both normal views offer 100×64 logical-pixel Save/Load targets and named Ctrl+S/Ctrl+L actions. Trail restore normalizes its existing ten-decimal chemistry after JSON parsing. Updated project input and architecture/data/UI/decision/README contracts.
- Pinned Godot 4.7.2 import, full headless suite and Main smoke passed: 3,547 checks, 0 failures. `tests/test_save_load.gd` writes only an injected `.godot` test slot, exercises private scout evidence, in-flight cargo, chamber progress, rain, lossless 64-bit RNG text, 100-tick continuation, slot replacement, bad checksum/version/reference/malformed-file rejection, and worker conservation. The test slot and temporary sibling were removed.
- Inspected Compatibility GUI previews at 1280×720 OUTWARD and 900×600 INWARD. Save/Load remain separated, readable and touch-sized after scaling. Their mouse/touch command paths and short feedback were exercised headlessly. Temporary preview script/images were not committed. Android storage/touch and human listening remain unverified; fast graphical shutdown can report the task-019 audio playback reference warning.
- Next: task 022 vertical-slice integration and timed Windows evaluation; then pause feature expansion.
