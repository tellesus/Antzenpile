# 014 — Pheromone reinforcement and decay

Status: complete (2026-09-30).

## Goal

Make chemical trails strengthen through traffic and fade with disuse.

## Why this exists

Trails are living infrastructure rather than permanent UI links.

## Dependencies

[013](013_transit_cohorts_resource_delivery.md) and the preceding task sequence. Read [ARCHITECTURE](../ARCHITECTURE.md), [CODING_RULES](../CODING_RULES.md), and relevant [DATA_MODEL](../DATA_MODEL.md)/[UI_RULES](../UI_RULES.md) contracts.

## Allowed scope

Segment pheromone, successful-traffic reinforcement, natural fixed-time decay, and trail visual response.

## Required behavior

Clamp pheromone to [0,1]. Derive coherent versus gapped/wispy rendering through approved presentation data. Use thin cores/envelopes and bounded effects.

Resolved contract: `TrailConfig` authors a 90 simulated-second pheromone half-life and 0.035 strength per returning worker. Every fixed 0.25-second tick decays all segments before cohort arrivals. Only a cohort that deposits positive cargo on home arrival reinforces its segment and adds its worker count to cumulative successful `traffic`; empty returns do neither. Reinforcement clamps at 1, decay approaches 0 and snaps tiny residue below 0.0001 to 0. Route familiarity remains zero for task 015. Existing segments retain chemistry after cancellation.

OUTWARD receives only segment strength in a detached route summary, never segment endpoints. A visible known destination gets a screen-space sensory link from the home anchor. Strength below 0.1 is invisible, 0.1–0.45 is sparse/wispy, and at least 0.45 is continuous. Thin cores and faint envelopes have fixed widths and alpha derived from strength; no bloom or per-ant marks. Links disappear when the destination signal is outside the current field, but chemical state continues to decay independently.

## Explicit non-goals

Rain, familiarity behavior, custom renderer, and final art. Do not implement future systems not explicitly requested.

## Interfaces to preserve

Segment-owned chemistry, aggregate traffic, and UI_RULES; visual state cannot drive simulation.

## Acceptance tests

Traffic reinforces; no traffic decays; values stay bounded and time-scale results agree. Manually read strong versus weakening trails with bloom reduced.

## Manual verification

Run `--headless --path . --script res://tests/run_tests.gd` and headless Main with the pinned 4.7.2 console build. At 1280×720 and 900×600, use the scout → known carbohydrate → Invest 5 Workers flow. After a loaded return, the OUTWARD trace should gain a thin scent link; cancel and advance time to see it break and fade. F3 should show numerical segment strength and successful traffic. Inspect with bloom disabled (Compatibility renderer already has no bloom dependency). Verify a rear-facing signal has no link. Exact automated fixtures are in `tests/test_pheromone.gd`.

## Done when

The expanded card's checks pass, existing behavior remains intact, and the handoff records changed files, tests, limitations, and next task. One logical commit.

## Completion evidence and handoff

- `tests/test_pheromone.gd` verifies loaded-return reinforcement, empty-return exclusion, [0,1] bounds, inactive decay, pause, snapshot validation/continuation, equal simulated time at 1×/4×/16×/64×, and visible/hidden visual thresholds. Existing task-012 validation now rejects out-of-range chemistry rather than all chemistry.
- Pinned Godot 4.7.2 import passed. `--headless --path . --script res://tests/run_tests.gd`: 3,289 checks, 0 failures. `--headless --path . --quit-after 3`: Main loaded without errors. `git diff --check`: clean.
- Rendered Compatibility previews at 1280×720 and 900×600 with bloom absent: coherent, wispy and absent links remained readable. A second preview used an actual scout report and 20-worker route: strength 0.852 with traffic, then 0.268 after cancellation and 150 simulated seconds; the link visibly broke into wisps. These previews were inspected but not committed. Interactive mouse/touch gameplay was not manually exercised in this task.
- Changed `data/trails/default_trails.tres`, `src/sim/trails/`, `src/core/game_root.gd`, `src/presentation/outward/`, `src/debug/debug_world_view.gd`, the test runner/tests, README and architecture/data/UI/decision docs. Next: task 015, route familiarity, keeping it independent from chemistry and rain.
