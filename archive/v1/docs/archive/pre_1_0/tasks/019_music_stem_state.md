> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/019_music_stem_state.md`. Historical status and recommendations below apply only to their recorded build.

# 019 — Music stem state

Status: complete (2026-09-30).

## Goal

Add a synchronized music layer when Food Exchange develops.

## Why this exists

The slice needs a perceptible musical reward for growth.

## Dependencies

[018](018_food_exchange_development.md) and the preceding task sequence. Read [ARCHITECTURE](../contracts/ARCHITECTURE.md), [CODING_RULES](../../../CODING_RULES.md), and relevant [DATA_MODEL](../contracts/DATA_MODEL.md)/[UI_RULES](../contracts/UI_RULES.md) contracts.

## Allowed scope

MusicState development_level, base loop, synchronized secondary loop, and smooth stem fade using placeholder audio.

## Required behavior

Audio consumes semantic development state. Align compatible loop timing; completion brings in the second stem without restarting gameplay. Headless mode remains audio-free.

Before coding: Resolve loop length/synchronization, fade duration, pause/speed and reload behavior; use authorized or original placeholder assets.

Resolved contract: generate two original, quiet, 8-second mono PCM loops at 22,050 Hz with identical frame counts and seamless integer-cycle components. Keep the generation script as asset provenance. `MusicState` is a detached semantic projection of Food Exchange state (`development_level` 0/1), not another saved or authoritative clock. A graphical-only `AudioController` owns exactly two persistent players, starts both at phase zero in the same frame, loops both without restarting for state changes, and fades the secondary's linear gain from 0 to 1 over three real seconds when development reaches 1. Repeated Developed updates neither add players nor restart playback. Music continues at normal real-time tempo across simulation pause and 1×/4×/16×/64× speeds. A newly composed or reloaded run starts both at phase zero and initializes gain from its current development state; audio phase is deliberately not serialized. Headless mode creates no audio controller.

## Explicit non-goals

Finished soundtrack, crisis/stability systems, and arbitrary audio queries into simulation. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Semantic MusicState and one-way simulation-to-audio dependency; audio time never advances simulation.

## Acceptance tests

Listen for stable synchronization and smooth entry on completion; repeated events do not duplicate players. Verify all speeds and silent/headless simulation; record checks that require real audio output.

## Manual verification

Use pinned Godot 4.7.2 import, full `tests/run_tests.gd` suite, `--quit-after 3` Main smoke, and graphical Main inspection. `tests/test_music.gd` checks semantic mapping, identical loop lengths and sample edges, fade timing, pause/speed independence, stable two-player topology, repeated state updates, and headless exclusion. Listen through real output for stable loop and smooth entry if an audible device is available; do not claim a headless test proves audio quality.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.

## Completion evidence and handoff

- Added original, reproducibly generated base/growth WAV loops and their standard-library generation script, detached MusicState, graphical-only AudioController with two persistent phase-matched players, and GameRoot projection from Food Exchange state. The secondary gain fades over three real seconds; no audio value enters simulation or snapshots.
- Pinned Godot 4.7.2 import, full headless suite and Main smoke passed: 3,502 checks, 0 failures. A brief Compatibility graphical startup also exited successfully without script/runtime errors. The WAVs each have 176,400 frames at 22,050 Hz, and the tests check loop duration, semantics, topology, fade, repeated state, pause/speed independence and headless silence.
- Listening on a real output device was not independently possible in this run. The graphical `--quit-after` diagnostic reports four Godot `AudioStreamWAV`/playback objects still referenced at shutdown; headless tests have no such warning. This does not affect normal gameplay in the observed startup, but output quality and shutdown behavior should be checked during play evaluation.
- Next: task 020 rain exposure, chemical washout and sensory interference; then pause to evaluate the slice as requested.
