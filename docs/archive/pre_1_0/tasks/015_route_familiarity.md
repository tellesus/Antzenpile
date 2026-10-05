> **ARCHIVE ONLY — frozen 2026-10-04.** Historical record; not an active plan, current contract or implementation instruction. Use the [current documentation](../../../README.md). Original path: `docs/tasks/015_route_familiarity.md`. Historical status and recommendations below apply only to their recorded build.

# 015 — Route familiarity

Status: complete (2026-09-30).

## Goal

Preserve slowly learned route memory separately from chemistry.

## Why this exists

Chemical washout must not erase all learned reliability.

## Dependencies

[014](014_pheromone_reinforcement_decay.md) and the preceding task sequence. Read [ARCHITECTURE](../contracts/ARCHITECTURE.md), [CODING_RULES](../../../CODING_RULES.md), and relevant [DATA_MODEL](../contracts/DATA_MODEL.md)/[UI_RULES](../contracts/UI_RULES.md) contracts.

## Allowed scope

Familiarity gain/slow decay, reliability contribution, debug display, and an optional subtle presentation ghost.

## Required behavior

Successful travel raises familiarity more slowly than pheromone; familiarity decays much more slowly and contributes to route reliability without replacing pheromone.

Resolved contract: `TrailConfig` authors +0.008 familiarity per worker in a cargo-bearing cohort on home return and a 900 simulated-second half-life. Fixed ticks decay every segment; values below 0.0001 snap to zero. Familiarity and pheromone each remain clamped to [0,1] and independently serialized. Route reliability is the pure value `0.5 * pheromone + 0.5 * familiarity`; source interaction radius is the task-013 base radius multiplied by `1 + 0.5 * reliability` (maximum 3 m). This is modest tolerance for an imperfect remembered endpoint, never a lookup of live coordinates for UI. Empty returns do not teach the route. Existing in-flight leg durations do not change.

OUTWARD receives detached familiarity and uses a thinner, lower-alpha four-wisp ghost only when pheromone is below 0.1 and familiarity is at least 0.1. A visible known destination remains required; at most six routes render. The ghost does not stand in for an active chemical trail.

## Explicit non-goals

Rain itself, adaptation, and shared-segment routing. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Distinct segment pheromone/familiarity fields; tests must not conflate memory with active chemicals.

## Acceptance tests

Separate values can diverge; suppress/decay chemistry and verify familiarity persists and influences reliability. Debug inspection shows both; ghost is fainter than an active trail.

## Manual verification

Run the pinned Godot 4.7.2 headless suite, import and Main smoke. Render loaded traffic then cancel; after chemical washout, a visibly fainter broken ghost should remain at both 1280×720 and 900×600. F3 displays exact segment chemistry/familiarity. `tests/test_familiarity.gd` covers gain, decay divergence, bounded restore, radius effect, and presentation isolation.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.

## Completion evidence and handoff

- Changed `TrailConfig`, `TrailSegmentState`, `TrailSystem`, detached GameRoot route summaries, OUTWARD TrailVisual/View, tests and architecture/data/UI/decision/README contracts. The debug panel already displayed both chemical and familiarity values from task 014.
- Pinned Godot 4.7.2 headless suite: 3,303 checks, 0 failures. The focused test verifies distinct gain/decay, valid and invalid snapshots, chemistry-free reliability at a near-miss endpoint, detached presentation values and ghost visibility. Main/import smoke and final diff checks are part of completion verification.
- Compatibility previews at 1280×720 and 900×600 showed a cancelled route at pheromone 0.072 and familiarity 0.605: a very faint broken ghost remains and the selected trace says "scent remembered". The renderer has no bloom dependency. Interactive pointer/touch input was not manually exercised here.
- Next: task 016, aggregate brood and worker growth. Rain remains out of scope until 020.
